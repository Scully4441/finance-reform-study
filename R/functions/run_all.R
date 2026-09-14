# Step 10 helpers (design document, Sections 5, 7, 8, 9 and 13): the robustness variants
# of the Callaway-Sant'Anna models, the Lee bounds, the dose-scaled estimate and the
# report. Used by R/10_run_all.R.
#
# Author decisions 2026-09-13 (docs/deviations.md):
#   Variants. Each Section 5 and Section 7 robustness check is one departure from the
#   primary specification (unbalanced panel, primary suppression sample, reference -1),
#   on all three event sets and both weightings: the 5-point and exact-only suppression
#   samples, end years 2013 on (participation), cohorts with fewer than three pre-reform
#   window years dropped, and did's anticipation = 1 in place of the lawsuit-filing date
#   (which also makes -2 the reference period). The balanced panel and the weighted
#   models are steps 5 and 7.
#   Inference on the variants. Bootstrap and Romano-Wolf at 9,999 draws and HonestDiD on
#   every variant; randomization inference at 1,000 reassignments (compute deviation).
#   Lee bounds. Gaps (b) and (c), primary event set, primary model. Tested share = the
#   subgroup's tested count (mean of math and RLA) over its CCD grade 9 membership three
#   years earlier, summed from the school files to the district, all-students counts where
#   the race count is unavailable; the trimming fraction is the larger absolute overall
#   effect on the two subgroups' shares from the same CS design; the treated post-reform
#   district-years are trimmed by that fraction from the top and from the bottom and the
#   primary model is refitted each way.
#   Dose scaling. Revenue = (TSTREV + TLOCREV) / V33 from F-33 (amounts in thousands of
#   dollars, so thousands per pupil), FY = end year, in dollars of the last window year
#   (2021). First stage = the same CS model with revenue as the outcome, on the units of
#   the gap's primary model; gap (a): the 2009-10 membership-weighted top-minus-bottom
#   poverty-quintile gap in revenue per pupil. Dose-scaled effect = overall outcome effect
#   / overall revenue effect (Wald form), with a percentile interval from step 7's Webb
#   draws applied to both.
#
# Blinding (CLAUDE.md rule 7): nothing here prints, and no returned table carries, a
# treatment year. Cohort years stay inside the panels handed to did.

EVENT_FILES  <- c(primary = "event_table.csv", r1 = "event_table_r1.csv", r2 = "event_table_r2.csv")
RETAIN_FLAGS <- c(primary = "retained", r1 = "retained_r1", r2 = "retained_r2")
MBAR_GRID    <- c(0, 0.5, 1, 1.5, 2)     # Section 8
HEADLINE_MBAR <- 1                       # Section 13 headline (author decision 2026-09-13)
MIN_PRE_YEARS <- 3L                      # Section 5 rule 6 robustness
RI_REPS_VARIANT <- 1000L                 # compute deviation 2026-09-13
LEE_LAG <- 3L                            # grade 9 membership three years before the tested year
LEE_FIRST_CCD <- 2007L                   # first archived CCD school file for the shares (data addition 2026-09-14)
DOSE_BASE_YEAR <- 2021L                  # last window year of both outcomes

# The robustness variants, one departure each from the primary specification.
VARIANTS <- list(
  sample_r5               = list(sample = "r5",      from_year = NULL, drop_few_pre = FALSE, anticipation = 0L,
                                 label = "Ranges of 5 points or less (Section 5 rule 3)"),
  sample_exact            = list(sample = "exact",   from_year = NULL, drop_few_pre = FALSE, anticipation = 0L,
                                 label = "Exact values only (Section 5 rule 3)"),
  # 2013 = PART_FROM (sample_rules.R, sourced after this file)
  participation_from_2013 = list(sample = "primary", from_year = 2013L, drop_few_pre = FALSE, anticipation = 0L,
                                 label = "End years 2013 on, participation rule throughout (Section 5 rule 4)"),
  drop_few_pre            = list(sample = "primary", from_year = NULL, drop_few_pre = TRUE, anticipation = 0L,
                                 label = "Cohorts with fewer than three pre-reform years dropped (Section 5 rule 6)"),
  anticipation_1          = list(sample = "primary", from_year = NULL, drop_few_pre = FALSE, anticipation = 1L,
                                 label = "Anticipation = 1, reference period -2 (Section 7; replaces the filing-date version)"))
variants_for <- function(outcome)
  if (outcome == "achievement") names(VARIANTS) else setdiff(names(VARIANTS), "participation_from_2013")

outcome_gaps <- function(outcome)
  if (outcome == "achievement") c("a_poverty", "b_black_white", "c_hispanic_white") else names(GRAD_GAPS)
outcome_window <- function(outcome) if (outcome == "achievement") ACH_WINDOW else GRAD_WINDOW
outcome_wcol <- function(outcome) if (outcome == "achievement") "tested_2010" else GRAD_WEIGHT
race_key <- function(outcome, gap)
  if (outcome == "graduation") GRAD_GAPS[[gap]] else if (gap == "b_black_white") "bw" else "hw"

# ---- inputs and panels -------------------------------------------------------------------

# The gap files and 2009-10 covariates steps 5 and 6 read.
load_cs_inputs <- function(outcome) {
  rd <- function(f) utils::read.csv(f, colClasses = c(leaid = "character"), stringsAsFactors = FALSE, na.strings = "")
  if (outcome == "achievement") {
    race <- rd("data/derived/gaps_race_district_year.csv")
    pov  <- utils::read.csv("data/derived/gap_poverty_state_year.csv", stringsAsFactors = FALSE, na.strings = "")
    smp  <- data.table::fread("data/derived/sample_district_year.csv", select = c("leaid", "sy_end", "saipe_pov_rate_2009"),
                              colClasses = c(leaid = "character"), data.table = FALSE, showProgress = FALSE)
    cov <- cs_covariates(race$leaid, smp, 2010L)
  } else {
    race <- rd("data/derived/gaps_graduation_district_year.csv")
    pov  <- NULL
    cov  <- cs_covariates(race$leaid, graduation_saipe(race$leaid), 2010L)
  }
  list(outcome = outcome, window = outcome_window(outcome), race = race, pov = pov, cov = cov)
}

# The estimation panel of one model, built as step 5 builds it, with a variant's changes.
# from_year: keep end years from that year and code cohorts over the shortened window (a
# state treated in its first year has no pre-period and is left out). drop_few_pre: states
# treated with fewer than MIN_PRE_YEARS window years before their cohort year are removed.
# Returns the panel (id, state, sy_end, y, g, ...), the unit column, the covariate formula
# and unit counts (no treatment years).
cs_model_panel <- function(inp, gap, set, sample = "primary", balanced = FALSE, from_year = NULL,
                           drop_few_pre = FALSE, weighting = "unweighted") {
  flag <- RETAIN_FLAGS[[set]]
  window <- inp$window
  if (gap == "a_poverty") {
    unit <- "state"; xf <- ~1
    p <- pov_panel(inp$pov, flag, window, sample, balanced = balanced)
  } else {
    unit <- "leaid"; xf <- stats::reformulate(CS_COVARIATES)
    rg <- race_key(inp$outcome, gap)
    p <- if (inp$outcome == "graduation") grad_panel(inp$race, rg, flag, window, sample, balanced = balanced) else
      race_panel(inp$race, rg, flag, window, sample, balanced = balanced)
    p <- cbind(p, inp$cov[match(p$leaid, inp$cov$leaid), CS_COVARIATES])
    p <- p[stats::complete.cases(p[CS_COVARIATES]), , drop = FALSE]
  }
  cw <- window
  if (!is.null(from_year)) {
    p <- p[p$sy_end >= from_year, , drop = FALSE]
    cw <- window[window >= from_year]
  }
  ev <- utils::read.csv(file.path("data", "reference", EVENT_FILES[[set]]), stringsAsFactors = FALSE)
  coding <- cohort_coding(ev, cw)
  n_few <- 0L
  if (drop_few_pre) {
    pre <- vapply(seq_len(nrow(coding)), function(i)
      if (coding$cohort_status[i] == "estimable") sum(cw < coding$g[i]) else NA_integer_, integer(1))
    few <- coding$cohort_status == "estimable" & !is.na(pre) & pre < MIN_PRE_YEARS
    n_few <- sum(few & coding$state %in% p$state)
    coding$cohort_status[few] <- "excluded"     # attach_cohorts drops excluded states
    coding$g[few] <- NA_integer_
  }
  ac <- attach_cohorts(p, coding, unit)
  p <- ac$panel
  wcol <- outcome_wcol(inp$outcome)
  if (weighting == "tested_weighted") {
    p <- p[!is.na(p[[wcol]]), , drop = FALSE]
    p$id <- as.integer(factor(p[[unit]]))
  }
  rownames(p) <- NULL
  list(panel = p, unit = unit, xformla = xf, weightsname = if (weighting == "tested_weighted") wcol else NULL,
       units = length(unique(p$id)), states = length(unique(p$state)), states_dropped_few_pre = as.integer(n_few))
}

# ---- inference on a set of fits ------------------------------------------------------------

# The four Section 8 procedures on a named list of fits that share one event set: Webb
# bootstrap on the overall and event times (one weight matrix for all fits), HonestDiD, and
# the per-fit influence functions for Romano-Wolf. fits: list of list(fit, ref).
# Randomization inference is separate (ri_cached()).
infer_fits <- function(fits, seed_step, reps, mbarvec = MBAR_GRID) {
  infs <- lapply(fits, function(f) cs_influence(f$fit))
  ok <- !vapply(infs, is.null, TRUE)
  out <- list(overall = list(), event = list(), honest = list(), t_boot = list(), infs = infs)
  if (!any(ok)) return(out)
  st <- sort(unique(unlist(lapply(infs[ok], `[[`, "states"))))
  set.seed(seed_for(seed_step))
  wm <- webb_weights(length(st), reps)
  for (k in names(fits)[ok]) {
    inf <- infs[[k]]; ref <- fits[[k]]$ref
    w <- wm[, match(inf$states, st), drop = FALSE]
    b <- wcb_test(inf$overall_att, inf$scores[, "overall"], inf$n, w)
    out$overall[[k]] <- b$row
    out$t_boot[[k]] <- b$t_boot
    ev <- data.frame(e = EVENT_MIN:EVENT_MAX, att = NA_real_, se = NA_real_, boot_se = NA_real_, t = NA_real_,
                     crit_val = NA_real_, ci_lo = NA_real_, ci_hi = NA_real_, p_value = NA_real_, reps = reps,
                     clusters = length(inf$states), reference = (EVENT_MIN:EVENT_MAX) == ref)
    for (j in seq_along(inf$egt)) {
      e <- inf$egt[j]
      if (e == ref || !is.finite(inf$se_egt[j]) || !is.finite(inf$att_egt[j])) next
      r <- wcb_test(inf$att_egt[j], inf$scores[, j], inf$n, w)$row
      ev[ev$e == e, names(r)] <- r
    }
    out$event[[k]] <- ev
  }
  # HonestDiD one fit per worker under the caller's future plan (deterministic; the grid
  # widening of honest_rm() makes wide bound sets slow)
  ks <- names(fits)[ok]
  jobs <- lapply(ks, function(k) list(inf = infs[[k]], ref = fits[[k]]$ref))   # not the fits: they are large
  one <- function(j, mbarvec) suppressWarnings(honest_rm(j$inf, mbarvec, ref = j$ref))
  environment(one) <- globalenv()        # so the workers are not sent this frame, fits included
  hs <- furrr::future_map(jobs, one, mbarvec = mbarvec, .options = furrr::furrr_options(seed = NULL))
  out$honest[ks] <- hs
  out
}

# Randomization inference for one fit, saved to cache_file as soon as it finishes and
# reused when the estimate, count and seed step match.
ri_cached <- function(fit, reps, seed_step, cache_file) {
  att <- fit$aggte$overall.att
  if (file.exists(cache_file)) {
    r <- readRDS(cache_file)
    if (identical(r$seed_step, seed_step) && identical(r$reps, reps) && identical(r$att, att)) return(r)
  }
  r <- ri_overall(fit, reps, seed_step)
  r$seed_step <- seed_step; r$att <- att
  saveRDS(r, cache_file)
  r
}

# ---- Lee bounds ----------------------------------------------------------------------------

LONG_RACE <- c(bl = "Black or African American", wh = "White", hi = "Hispanic/Latino")

# CCD grade 9 membership by district from one school membership file (data acquisition
# 2.4): all students and the Black, White and Hispanic counts (male + female). Wide
# layouts through 2015-16 (G09 / BL09M, suffixed with the year in 2009-10), long layout
# from 2016-17 (GRADE, RACE_ETHNICITY, SEX, STUDENT_COUNT, TOTAL_INDICATOR). CCD negative
# codes and blank counts are not reported. g9_all is the sum of the reported school counts
# (NA if none is reported). A race count is NA ("unavailable") when any school with a
# reported all-students grade 9 count above zero lacks that race's male or female count.
# 2006-07 is published as three fixed-width state-group files (sc061c{ai,kn,ow}.dat) with a
# separate record layout (psu061clay.txt): pass the .dat paths and the layout, and the
# fields are cut at the layout's start and end positions (data addition 2026-09-14).
ccd_grade9_district <- function(path, sy_end, layout = NULL) {
  if (!is.null(layout)) return(ccd_grade9_fixed(path, sy_end, layout))
  hdr <- names(data.table::fread(path, nrows = 0L, colClasses = "character"))
  if ("GRADE" %in% hdr) {
    d <- data.table::fread(path, select = c("NCESSCH", "LEAID", "GRADE", "RACE_ETHNICITY", "SEX", "STUDENT_COUNT", "TOTAL_INDICATOR"),
                           colClasses = "character", data.table = FALSE, showProgress = FALSE)
    d <- d[d$GRADE == "Grade 9", , drop = FALSE]
    d$n <- ccd_count(d$STUDENT_COUNT)
    tot <- d[startsWith(d$TOTAL_INDICATOR, "Subtotal 4"), , drop = FALSE]
    sch <- data.frame(ncessch = unique(d$NCESSCH), stringsAsFactors = FALSE)
    sch$leaid <- d$LEAID[match(sch$ncessch, d$NCESSCH)]
    sch$all <- tot$n[match(sch$ncessch, tot$NCESSCH)]
    # The long files leave a race-by-sex cell blank ("Not reported") where a school has no
    # such students: in 2017-18, 13,448 of the 13,450 schools with grade 9 students and a
    # blank cell report cells that sum exactly to the school's grade 9 total. A blank cell
    # counts as zero when the school's reported cells sum to its total, and is unavailable
    # otherwise.
    ca <- d[startsWith(d$TOTAL_INDICATOR, "Category Set A"), , drop = FALSE]
    ca_sum <- tapply(ca$n, ca$NCESSCH, sum, na.rm = TRUE)
    complete <- names(ca_sum)[!is.na(sch$all[match(names(ca_sum), sch$ncessch)]) &
                                ca_sum == sch$all[match(names(ca_sum), sch$ncessch)]]
    d$n[is.na(d$n) & startsWith(d$TOTAL_INDICATOR, "Category Set A") & d$NCESSCH %in% complete] <- 0
    rs <- d[startsWith(d$TOTAL_INDICATOR, "Category Set A") & d$SEX %in% c("Male", "Female"), , drop = FALSE]
    for (s in names(LONG_RACE)) {
      x <- rs[rs$RACE_ETHNICITY == LONG_RACE[[s]], , drop = FALSE]
      m <- x$n[x$SEX == "Male"][match(sch$ncessch, x$NCESSCH[x$SEX == "Male"])]
      f <- x$n[x$SEX == "Female"][match(sch$ncessch, x$NCESSCH[x$SEX == "Female"])]
      sch[[s]] <- m + f
    }
  } else {
    pick <- function(stem) { k <- grep(paste0("^", stem, "([0-9]{2})?$"), hdr, value = TRUE)
      if (length(k) != 1L) stop(basename(path), ": no single column for ", stem); k }
    cols <- c(LEAID = "LEAID", all = pick("G09"),
              stats::setNames(vapply(as.vector(outer(c("BL", "WH", "HI"), c("09M", "09F"), paste0)), pick, ""),
                              as.vector(outer(c("BL", "WH", "HI"), c("09M", "09F"), paste0))))
    d <- data.table::fread(path, select = unname(cols), colClasses = "character", data.table = FALSE, showProgress = FALSE)
    names(d) <- names(cols)
    sch <- data.frame(leaid = trimws(d$LEAID), all = ccd_count(d$all), stringsAsFactors = FALSE)
    for (s in c("bl", "wh", "hi")) sch[[s]] <- ccd_count(d[[paste0(toupper(s), "09M")]]) + ccd_count(d[[paste0(toupper(s), "09F")]])
  }
  sch <- sch[grepl("^[0-9]{7}$", sch$leaid), , drop = FALSE]
  ccd_grade9_agg(sch, sy_end)
}

# District sums of school grade 9 counts (rules in the comment above ccd_grade9_district()).
ccd_grade9_agg <- function(sch, sy_end) {
  offers <- !is.na(sch$all) & sch$all > 0
  by <- split(seq_len(nrow(sch)), sch$leaid)
  race <- function(v) vapply(by, function(i) if (any(offers[i] & is.na(v[i]))) NA_real_ else sum(v[i][offers[i]]), 0)
  data.frame(leaid = names(by), sy_end = as.integer(sy_end),
             g9_all = vapply(by, function(i) if (all(is.na(sch$all[i]))) NA_real_ else sum(sch$all[i], na.rm = TRUE), 0),
             g9_bl = race(sch$bl), g9_wh = race(sch$wh), g9_hi = race(sch$hi), row.names = NULL, stringsAsFactors = FALSE)
}

# Fixed-width school files and their NCES record layout: variable lines read
# "NAME  start  end  length  type  description", a leading "+" marking a subfield.
ccd_grade9_fixed <- function(paths, sy_end, layout) {
  lay <- readLines(layout, warn = FALSE, encoding = "latin1")    # descriptions carry Windows-1252 bytes
  lay <- iconv(lay, "latin1", "ASCII", sub = " ")
  m <- regmatches(lay, regexec("^\\+?([A-Z][A-Z0-9_]*)[ \t]+([0-9]{4})[ \t]+([0-9]{4})[ \t]+[0-9]+[ \t]+(AN|N)[ \t]", lay))
  m <- do.call(rbind, m[lengths(m) == 5L])
  pos <- data.frame(name = m[, 2], start = as.integer(m[, 3]), end = as.integer(m[, 4]), stringsAsFactors = FALSE)
  sfx <- sprintf("%02d", (sy_end - 1L) %% 100L)
  need <- c("LEAID", paste0("G09", sfx), paste0(as.vector(outer(c("BL", "WH", "HI"), c("09M", "09F"), paste0)), sfx))
  if (!all(need %in% pos$name)) stop(basename(layout), " lacks ", paste(setdiff(need, pos$name), collapse = ", "))
  cut <- function(x, v) { k <- match(v, pos$name); trimws(substr(x, pos$start[k], pos$end[k])) }
  # school names carry single-byte accented characters: read as latin1, so one character is
  # one byte and the layout's byte positions hold
  lines <- unlist(lapply(paths, readLines, warn = FALSE, encoding = "latin1"))
  lines <- lines[nchar(lines, type = "bytes") >= max(pos$end[pos$name %in% need])]
  sch <- data.frame(leaid = cut(lines, "LEAID"), all = ccd_count(cut(lines, need[2])), stringsAsFactors = FALSE)
  for (s in c("bl", "wh", "hi"))
    sch[[s]] <- ccd_count(cut(lines, paste0(toupper(s), "09M", sfx))) + ccd_count(cut(lines, paste0(toupper(s), "09F", sfx)))
  sch <- sch[grepl("^[0-9]{7}$", sch$leaid), , drop = FALSE]
  ccd_grade9_agg(sch, sy_end)
}

# The membership zip of a school year (end year) and the data file inside it; a zip inside
# the zip (2017-18) is opened too.
# 2006-07: the three state-group zips, extracted, with the layout path as attribute "layout".
ccd_membership_file <- function(sy_end, exdir) {
  if (sy_end == 2007L) {
    zips <- sprintf("data/raw/ccd/membership-sy2006-07-%s.zip", c("ai", "kn", "ow"))
    lay <- "data/raw/ccd/membership-sy2006-07-layout.txt"
    if (!all(file.exists(c(zips, lay)))) stop("2006-07 CCD school files or layout not found; run R/02_download.R")
    out <- unlist(lapply(zips, function(z) utils::unzip(z, exdir = exdir)))
    return(structure(out, layout = lay))
  }
  zip <- sprintf("data/raw/ccd/membership-sy%d-%02d.zip", sy_end - 1L, sy_end %% 100L)
  if (!file.exists(zip)) stop(zip, " not found")
  inner <- utils::unzip(zip, list = TRUE)$Name
  data <- grep("\\.(txt|csv)$", inner, value = TRUE, ignore.case = TRUE)
  if (length(data) >= 1L) return(utils::unzip(zip, files = data[1], exdir = exdir))
  csvzip <- grep("CSV\\.zip$", inner, value = TRUE, ignore.case = TRUE)
  if (length(csvzip) != 1L) stop(zip, ": no data file")
  z2 <- utils::unzip(zip, files = csvzip, exdir = exdir)
  f <- grep("\\.csv$", utils::unzip(z2, list = TRUE)$Name, value = TRUE, ignore.case = TRUE)
  # the inner CSV is over 2 GB and Deflate64-compressed, which R's internal unzip and bsdtar
  # cannot extract; Info-ZIP unzip can
  tool <- Sys.which("unzip")
  if (!nzchar(tool)) stop("Info-ZIP unzip is needed to extract ", f[1], " from ", z2)
  st <- system2(tool, c("-o", "-q", shQuote(z2), shQuote(f[1]), "-d", shQuote(exdir)))
  out <- file.path(exdir, f[1])
  if (!identical(as.integer(st), 0L) || !file.exists(out)) stop("could not extract ", f[1], " from ", z2)
  unlink(z2)
  out
}

# District-year tested share panel for one subgroup of a gap. base: the step 5 primary
# panel (cs_panel(fit)$panel); smp: sample_district_year rows (leaid, sy_end, n_<subj>_<sg>,
# n_<subj>_all); g9: ccd_grade9_district() rows. A district-year enters from the first end
# year with membership LEE_LAG years earlier. Returns the panel with y = share and
# fallback = 1 where the all-students counts stood in.
lee_share_panel <- function(base, smp, g9, sg, window) {
  units <- base[!duplicated(base$id), c("leaid", "state", "g", CS_COVARIATES)]
  x <- smp[smp$leaid %in% units$leaid & smp$sy_end %in% window, , drop = FALSE]
  tested <- function(s) (x[[paste0("n_math_", s)]] + x[[paste0("n_rla_", s)]]) / 2
  k <- match(paste(x$leaid, x$sy_end - LEE_LAG), paste(g9$leaid, g9$sy_end))
  t_sg <- tested(sg); t_all <- tested("all")
  m_sg <- g9[[paste0("g9_", sg)]][k]; m_all <- g9$g9_all[k]
  use_sg <- !is.na(t_sg) & !is.na(m_sg) & m_sg > 0
  use_all <- !use_sg & !is.na(t_all) & !is.na(m_all) & m_all > 0
  out <- data.frame(leaid = x$leaid, sy_end = x$sy_end,
                    y = ifelse(use_sg, t_sg / m_sg, ifelse(use_all, t_all / m_all, NA_real_)),
                    fallback = as.integer(use_all), stringsAsFactors = FALSE)
  out <- out[!is.na(out$y), , drop = FALSE]
  out <- cbind(out, units[match(out$leaid, units$leaid), c("state", "g", CS_COVARIATES)])
  lee_first <- min(out$sy_end)
  out <- out[out$g == 0 | out$g > lee_first, , drop = FALSE]    # a state treated in the first share year has no pre-period
  out$id <- as.integer(factor(out$leaid))
  rownames(out) <- NULL
  out
}

# Remove the share `frac` of the treated post-reform unit-years with the highest (side
# "top") or lowest ("bottom") outcome. Returns the trimmed panel and the count removed.
lee_trim <- function(panel, frac, side = c("top", "bottom")) {
  side <- match.arg(side)
  tp <- which(panel$g > 0 & panel$sy_end >= panel$g)
  k <- round(min(max(frac, 0), 1) * length(tp))
  if (k == 0L) return(list(panel = panel, removed = 0L, treated_post = length(tp)))
  o <- order(panel$y[tp], decreasing = side == "top")
  drop <- tp[o[seq_len(k)]]
  p <- panel[-drop, , drop = FALSE]
  rownames(p) <- NULL
  list(panel = p, removed = as.integer(k), treated_post = length(tp))
}

# ---- dose scaling ---------------------------------------------------------------------------

# District revenue per pupil from the F-33 files: (TSTREV + TLOCREV) / V33, thousands of
# nominal dollars per pupil (F-33 amounts are in thousands). FY = end year.
read_f33_revenue <- function(years, dir = "data/raw/f33") {
  do.call(rbind, lapply(years, function(y) {
    f <- file.path(dir, sprintf("f33-fy%d.csv", y))
    if (!file.exists(f)) stop(f, " not found")
    # The data rows end in a trailing comma (one more field than the header), which makes
    # fread shift the names; columns are therefore taken by their header position.
    need <- c("NCESID", "V33", "TSTREV", "TLOCREV")
    hdr <- gsub('"', "", strsplit(readLines(f, n = 1L, warn = FALSE), ",", fixed = TRUE)[[1]])
    pos <- match(need, hdr)
    if (anyNA(pos)) stop(f, " lacks ", paste(need[is.na(pos)], collapse = ", "))
    d <- data.table::fread(f, header = FALSE, skip = 1L, select = pos, colClasses = "character",
                           data.table = FALSE, showProgress = FALSE, fill = TRUE)
    names(d) <- need
    num <- function(v) { z <- suppressWarnings(as.numeric(v)); z[!is.na(z) & z < 0] <- NA_real_; z }
    v33 <- num(d$V33); rev <- num(d$TSTREV) + num(d$TLOCREV)
    ok <- grepl("^[0-9]{7}$", d$NCESID) & !is.na(v33) & v33 > 0 & !is.na(rev)
    out <- data.frame(leaid = d$NCESID[ok], sy_end = as.integer(y), rev_sl = rev[ok], v33 = v33[ok],
                      rev_pp = rev[ok] / v33[ok], stringsAsFactors = FALSE)
    out[!duplicated(out$leaid), , drop = FALSE]
  }))
}

# Real revenue per pupil in thousands of DOSE_BASE_YEAR dollars (CPI-U, July-June).
real_revenue <- function(rev, cpi_file = "data/raw/cpi/cuur0000sa0.csv", base = DOSE_BASE_YEAR) {
  m <- utils::read.csv(cpi_file, stringsAsFactors = FALSE)
  cpi <- cpi_school_year(m)
  need <- sort(unique(c(rev$sy_end, base)))
  if (!all(cpi$complete[match(need, cpi$sy_end)] %in% TRUE)) stop("CPI school years incomplete for ", paste(need, collapse = " "))
  rev$rev_pp_real <- deflate_to_base(rev$rev_pp, rev$sy_end, cpi, base)
  rev
}

# Revenue exclusions for the dose first stage (data correction 2026-09-14, docs/deviations.md):
# a district-year with F-33 fall enrollment (V33) below REV_MIN_ENROLL, or with state-plus-
# local revenue per pupil above REV_MAX_PP thousand DOSE_BASE_YEAR dollars, is left out.
# Such values come from tiny enrollment denominators, not from school finance.
REV_MIN_ENROLL <- 30
REV_MAX_PP <- 100            # thousands of 2021 dollars, i.e. $100,000 per pupil
revenue_excluded <- function(rev) rev$v33 < REV_MIN_ENROLL | rev$rev_pp_real > REV_MAX_PP

# Revenue panel on the units of a district model: every window year with a revenue value.
dist_revenue_panel <- function(base, rev, window) {
  units <- base[!duplicated(base$id), c("leaid", "state", "g", intersect(CS_COVARIATES, names(base)))]
  r <- rev[rev$leaid %in% units$leaid & rev$sy_end %in% window, , drop = FALSE]
  p <- cbind(data.frame(leaid = r$leaid, sy_end = r$sy_end, y = r$rev_pp_real, stringsAsFactors = FALSE),
             units[match(r$leaid, units$leaid), setdiff(names(units), "leaid"), drop = FALSE])
  p$id <- as.integer(factor(p$leaid))
  rownames(p) <- NULL
  p
}

# Gap (a) revenue: within each state-year, the 2009-10 membership-weighted mean revenue per
# pupil of quintile 5 districts minus that of quintile 1 districts, over the districts
# that can enter gap (a) (retained under the event set, quintile 1 or 5, valid 2009-10
# membership) and report revenue. d: sample_district_year rows with leaid, state, sy_end,
# the retained flag, pov_quintile_2009 and member_2009.
pov_revenue_panel <- function(d, flag, rev, window, base) {
  x <- d[d[[flag]] == 1L & d$pov_quintile_2009 %in% c(1L, 5L) & !is.na(d$member_2009) & d$member_2009 > 0 &
           d$sy_end %in% window, , drop = FALSE]
  x$rev <- rev$rev_pp_real[match(paste(x$leaid, x$sy_end), paste(rev$leaid, rev$sy_end))]
  x <- x[!is.na(x$rev), , drop = FALSE]
  wm <- function(q) {
    z <- x[x$pov_quintile_2009 == q, , drop = FALSE]
    s <- split(seq_len(nrow(z)), paste(z$state, z$sy_end))
    data.frame(key = names(s), v = vapply(s, function(i) sum(z$rev[i] * z$member_2009[i]) / sum(z$member_2009[i]), 0),
               stringsAsFactors = FALSE)
  }
  q5 <- wm(5L); q1 <- wm(1L)
  k <- intersect(q5$key, q1$key)
  out <- data.frame(state = sub(" .*", "", k), sy_end = as.integer(sub(".* ", "", k)),
                    y = q5$v[match(k, q5$key)] - q1$v[match(k, q1$key)], stringsAsFactors = FALSE)
  st <- base[!duplicated(base$state), c("state", "g")]
  out <- out[out$state %in% st$state, , drop = FALSE]
  out$g <- st$g[match(out$state, st$state)]
  out <- out[order(out$state, out$sy_end), , drop = FALSE]
  out$id <- as.integer(factor(out$state))
  rownames(out) <- NULL
  out
}

# The step 7 Webb draws of one outcome, rebuilt from the same seed steps and state lists.
step7_draws <- function(outcome, reps) {
  in_dir <- if (outcome == "achievement") "outputs/05_primary" else "outputs/05_primary/graduation"
  seed_tag <- if (outcome == "achievement") "07_inference" else "07_inference graduation"
  models <- readRDS(file.path(in_dir, "cs_models.rds"))
  infs <- lapply(models, cs_influence)
  sets <- vapply(strsplit(names(models), ".", fixed = TRUE), `[`, "", 2)
  out <- list()
  for (s in c("primary", "r1", "r2")) {
    k <- which(!vapply(infs, is.null, TRUE) & sets == s)
    if (!length(k)) next
    st <- sort(unique(unlist(lapply(infs[k], `[[`, "states"))))
    set.seed(seed_for(paste(seed_tag, "bootstrap", s)))
    out[[s]] <- list(states = st, w = webb_weights(length(st), reps))
  }
  list(draws = out, models = models, infs = infs)
}

# Dose-scaled effect: overall outcome effect / overall revenue effect, per $1,000 of revenue
# per pupil. The bootstrap perturbs both estimates with the same state weights (the draws
# carry their dependence), and the interval is the percentile interval of the perturbed
# ratios. When the revenue effect's own percentile interval includes zero the ratio's
# confidence set is unbounded (a weak first stage), recorded in the status.
dose_ratio <- function(inf_y, inf_r, draws, level = BOOT_LEVEL) {
  st <- draws$states; w <- draws$w
  if (!all(inf_y$states %in% st) || !all(inf_r$states %in% st)) stop("states outside the step 7 draws")
  dy <- as.vector(w[, match(inf_y$states, st), drop = FALSE] %*% inf_y$scores[, "overall"]) / inf_y$n
  dr <- as.vector(w[, match(inf_r$states, st), drop = FALSE] %*% inf_r$scores[, "overall"]) / inf_r$n
  a <- (1 - level) / 2
  ry <- inf_y$overall_att; rr <- inf_r$overall_att
  rev_ci <- stats::quantile(rr + dr, c(a, 1 - a), names = FALSE)
  ratio_b <- (ry + dy) / (rr + dr)
  ci <- stats::quantile(ratio_b, c(a, 1 - a), names = FALSE, na.rm = TRUE)
  unbounded <- rev_ci[1] <= 0 && rev_ci[2] >= 0
  data.frame(att_outcome = ry, att_revenue = rr, revenue_ci_lo = rev_ci[1], revenue_ci_hi = rev_ci[2],
             dose_scaled = ry / rr, ci_lo = if (unbounded) NA_real_ else ci[1], ci_hi = if (unbounded) NA_real_ else ci[2],
             percentile_lo = ci[1], percentile_hi = ci[2],
             share_draws_revenue_sign_flip = mean(sign(rr + dr) != sign(rr)), reps = nrow(w),
             status = if (unbounded) "unbounded: the revenue effect's bootstrap interval includes zero" else "ok",
             stringsAsFactors = FALSE)
}

# ---- report -----------------------------------------------------------------------------------

fmt <- function(x, d = 3) ifelse(is.na(x), "–", formatC(x, format = "f", digits = d))
fmt_p <- function(x) ifelse(is.na(x), "–", formatC(x, format = "f", digits = 4))

# A markdown table from a data frame.
md_table <- function(df) {
  if (is.null(df) || !nrow(df)) return("_No rows._\n")
  h <- paste0("| ", paste(names(df), collapse = " | "), " |")
  s <- paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
  b <- apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
  paste(c(h, s, b, ""), collapse = "\n")
}

# Event-study plot: event-time estimates with Webb bootstrap intervals, the number of
# cohorts behind each coefficient under the axis, and at the right the overall post-reform
# average with its HonestDiD bound sets (M-bar 0..2; the headline M-bar drawn heavier).
plot_event_study <- function(file, ev, overall_att, honest, title, ref = -1L) {
  grDevices::png(file, width = 1100, height = 650, res = 110)
  on.exit(grDevices::dev.off())
  graphics::par(mar = c(6, 5, 3, 1))
  hb <- honest[!is.na(honest$mbar) & honest$status == "ok", , drop = FALSE]
  x_all <- c(ev$e, EVENT_MAX + 2 + seq_along(MBAR_GRID) * 0.5)
  yr <- range(c(ev$ci_lo, ev$ci_hi, ev$att, hb$lb, hb$ub, overall_att, 0), na.rm = TRUE)
  if (!all(is.finite(yr))) yr <- c(-1, 1)
  yr <- yr + c(-1, 1) * 0.08 * diff(yr)
  graphics::plot(NA, xlim = c(EVENT_MIN - 0.5, max(x_all) + 0.5), ylim = yr, xaxt = "n",
                 xlab = "", ylab = "Effect on the gap (SD units)", main = title)
  graphics::axis(1, at = EVENT_MIN:EVENT_MAX)
  graphics::abline(h = 0, col = "grey60")
  graphics::abline(v = -0.5 + ref + 1, col = "grey80", lty = 3)
  ok <- !is.na(ev$att)
  graphics::segments(ev$e[ok], ev$ci_lo[ok], ev$e[ok], ev$ci_hi[ok], col = "grey30")
  graphics::points(ev$e[ok], ev$att[ok], pch = ifelse(ev$reference[ok], 1, 19))
  graphics::mtext("Event time (years since reform)", side = 1, line = 2.2)
  graphics::axis(1, at = EVENT_MIN:EVENT_MAX, labels = ev$cohorts, line = 3.2, tick = FALSE, cex.axis = 0.7)
  graphics::mtext("cohorts", side = 1, line = 4.1, at = EVENT_MIN - 0.9, cex = 0.7)
  xs <- EVENT_MAX + 2 + seq_along(MBAR_GRID) * 0.5
  for (i in seq_along(MBAR_GRID)) {
    r <- hb[hb$mbar == MBAR_GRID[i], , drop = FALSE]
    if (nrow(r)) graphics::segments(xs[i], r$lb, xs[i], r$ub, lwd = if (MBAR_GRID[i] == HEADLINE_MBAR) 4 else 2,
                                    col = if (MBAR_GRID[i] == HEADLINE_MBAR) "firebrick" else "steelblue")
  }
  if (is.finite(overall_att)) graphics::points(mean(xs), overall_att, pch = 18, cex = 1.6)
  graphics::axis(1, at = xs, labels = paste0("M=", MBAR_GRID), cex.axis = 0.7, las = 2)
  graphics::abline(v = EVENT_MAX + 1, col = "grey80")
  graphics::mtext("HonestDiD bound sets, overall", side = 3, at = mean(xs), line = 0.2, cex = 0.75)
  invisible(file)
}

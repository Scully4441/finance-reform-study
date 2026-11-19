EVENT_FILES  <- c(primary = "event_table.csv", r1 = "event_table_r1.csv", r2 = "event_table_r2.csv")
RETAIN_FLAGS <- c(primary = "retained", r1 = "retained_r1", r2 = "retained_r2")
MBAR_GRID    <- c(0, 0.5, 1, 1.5, 2)
HEADLINE_MBAR <- 1
MIN_PRE_YEARS <- 3L
RI_REPS_VARIANT <- 1000L
LEE_LAG <- 3L
LEE_FIRST_CCD <- 2007L
DOSE_BASE_YEAR <- 2021L

VARIANTS <- list(
  sample_r5               = list(sample = "r5",      from_year = NULL, drop_few_pre = FALSE, anticipation = 0L,
                                 label = "Ranges of 5 points or less (rule 3)"),
  sample_exact            = list(sample = "exact",   from_year = NULL, drop_few_pre = FALSE, anticipation = 0L,
                                 label = "Exact values only (rule 3)"),
  participation_from_2013 = list(sample = "primary", from_year = 2013L, drop_few_pre = FALSE, anticipation = 0L,
                                 label = "End years 2013 on, participation rule throughout (rule 4)"),
  drop_few_pre            = list(sample = "primary", from_year = NULL, drop_few_pre = TRUE, anticipation = 0L,
                                 label = "Cohorts with fewer than three pre-reform years dropped (rule 6)"),
  anticipation_1          = list(sample = "primary", from_year = NULL, drop_few_pre = FALSE, anticipation = 1L,
                                 label = "Anticipation = 1, reference period -2"))
variants_for <- function(outcome)
  if (outcome == "achievement") names(VARIANTS) else setdiff(names(VARIANTS), "participation_from_2013")

outcome_gaps <- function(outcome)
  if (outcome == "achievement") c("a_poverty", "b_black_white", "c_hispanic_white") else names(GRAD_GAPS)
outcome_window <- function(outcome) if (outcome == "achievement") ACH_WINDOW else GRAD_WINDOW
outcome_wcol <- function(outcome) if (outcome == "achievement") "tested_2010" else GRAD_WEIGHT
race_key <- function(outcome, gap)
  if (outcome == "graduation") GRAD_GAPS[[gap]] else if (gap == "b_black_white") "bw" else "hw"


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
    coding$cohort_status[few] <- "excluded"
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
  ks <- names(fits)[ok]
  jobs <- lapply(ks, function(k) list(inf = infs[[k]], ref = fits[[k]]$ref))
  one <- function(j, mbarvec) suppressWarnings(honest_rm(j$inf, mbarvec, ref = j$ref))
  environment(one) <- globalenv()
  hs <- furrr::future_map(jobs, one, mbarvec = mbarvec, .options = furrr::furrr_options(seed = NULL))
  out$honest[ks] <- hs
  out
}

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


LONG_RACE <- c(bl = "Black or African American", wh = "White", hi = "Hispanic/Latino")

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

ccd_grade9_agg <- function(sch, sy_end) {
  offers <- !is.na(sch$all) & sch$all > 0
  by <- split(seq_len(nrow(sch)), sch$leaid)
  race <- function(v) vapply(by, function(i) if (any(offers[i] & is.na(v[i]))) NA_real_ else sum(v[i][offers[i]]), 0)
  data.frame(leaid = names(by), sy_end = as.integer(sy_end),
             g9_all = vapply(by, function(i) if (all(is.na(sch$all[i]))) NA_real_ else sum(sch$all[i], na.rm = TRUE), 0),
             g9_bl = race(sch$bl), g9_wh = race(sch$wh), g9_hi = race(sch$hi), row.names = NULL, stringsAsFactors = FALSE)
}

ccd_grade9_fixed <- function(paths, sy_end, layout) {
  lay <- readLines(layout, warn = FALSE, encoding = "latin1")
  lay <- iconv(lay, "latin1", "ASCII", sub = " ")
  m <- regmatches(lay, regexec("^\\+?([A-Z][A-Z0-9_]*)[ \t]+([0-9]{4})[ \t]+([0-9]{4})[ \t]+[0-9]+[ \t]+(AN|N)[ \t]", lay))
  m <- do.call(rbind, m[lengths(m) == 5L])
  pos <- data.frame(name = m[, 2], start = as.integer(m[, 3]), end = as.integer(m[, 4]), stringsAsFactors = FALSE)
  sfx <- sprintf("%02d", (sy_end - 1L) %% 100L)
  need <- c("LEAID", paste0("G09", sfx), paste0(as.vector(outer(c("BL", "WH", "HI"), c("09M", "09F"), paste0)), sfx))
  if (!all(need %in% pos$name)) stop(basename(layout), " lacks ", paste(setdiff(need, pos$name), collapse = ", "))
  cut <- function(x, v) { k <- match(v, pos$name); trimws(substr(x, pos$start[k], pos$end[k])) }
  lines <- unlist(lapply(paths, readLines, warn = FALSE, encoding = "latin1"))
  lines <- lines[nchar(lines, type = "bytes") >= max(pos$end[pos$name %in% need])]
  sch <- data.frame(leaid = cut(lines, "LEAID"), all = ccd_count(cut(lines, need[2])), stringsAsFactors = FALSE)
  for (s in c("bl", "wh", "hi"))
    sch[[s]] <- ccd_count(cut(lines, paste0(toupper(s), "09M", sfx))) + ccd_count(cut(lines, paste0(toupper(s), "09F", sfx)))
  sch <- sch[grepl("^[0-9]{7}$", sch$leaid), , drop = FALSE]
  ccd_grade9_agg(sch, sy_end)
}

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
  tool <- Sys.which("unzip")
  if (!nzchar(tool)) stop("Info-ZIP unzip is needed to extract ", f[1], " from ", z2)
  st <- system2(tool, c("-o", "-q", shQuote(z2), shQuote(f[1]), "-d", shQuote(exdir)))
  out <- file.path(exdir, f[1])
  if (!identical(as.integer(st), 0L) || !file.exists(out)) stop("could not extract ", f[1], " from ", z2)
  unlink(z2)
  out
}

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
  out <- out[out$g == 0 | out$g > lee_first, , drop = FALSE]
  out$id <- as.integer(factor(out$leaid))
  rownames(out) <- NULL
  out
}

lee_share_levels <- function(fs, panel) {
  if (fs$status != "ok") return(c(q_T = NA_real_, q_C = NA_real_))
  cells <- fs$cells[!is.na(fs$cells$att) & fs$cells$e >= 0 & fs$cells$e <= EVENT_MAX, , drop = FALSE]
  units_g <- tapply(panel$id, panel$g, function(z) length(unique(z)))
  q_e <- vapply(sort(unique(cells$e)), function(e) {
    ce <- cells[cells$e == e, , drop = FALSE]
    m <- vapply(seq_len(nrow(ce)), function(i) mean(panel$y[panel$g == ce$g[i] & panel$sy_end == ce$t[i]]), 0)
    w <- as.numeric(units_g[as.character(ce$g)])
    sum(m * w) / sum(w)
  }, 0)
  q_T <- mean(q_e)
  c(q_T = q_T, q_C = q_T - fs$overall$att)
}

lee_p <- function(q_T, q_C) if (!is.finite(q_T) || !is.finite(q_C) || q_T <= 0) NA_real_ else 1 - q_C / q_T

lee_differential_fraction <- function(p1, p2) if (is.na(p1) || is.na(p2)) NA_real_ else min(abs(p1 - p2), 1)

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


read_f33_revenue <- function(years, dir = "data/raw/f33") {
  do.call(rbind, lapply(years, function(y) {
    f <- file.path(dir, sprintf("f33-fy%d.csv", y))
    if (!file.exists(f)) stop(f, " not found")
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

real_revenue <- function(rev, cpi_file = "data/raw/cpi/cuur0000sa0.csv", base = DOSE_BASE_YEAR) {
  m <- utils::read.csv(cpi_file, stringsAsFactors = FALSE)
  cpi <- cpi_school_year(m)
  need <- sort(unique(c(rev$sy_end, base)))
  if (!all(cpi$complete[match(need, cpi$sy_end)] %in% TRUE)) stop("CPI school years incomplete for ", paste(need, collapse = " "))
  rev$rev_pp_real <- deflate_to_base(rev$rev_pp, rev$sy_end, cpi, base)
  rev
}

REV_MIN_ENROLL <- 30
REV_MAX_PP <- 100
revenue_excluded <- function(rev) rev$v33 < REV_MIN_ENROLL | rev$rev_pp_real > REV_MAX_PP

dist_revenue_panel <- function(base, rev, window) {
  units <- base[!duplicated(base$id), c("leaid", "state", "g", intersect(CS_COVARIATES, names(base)))]
  r <- rev[rev$leaid %in% units$leaid & rev$sy_end %in% window, , drop = FALSE]
  p <- cbind(data.frame(leaid = r$leaid, sy_end = r$sy_end, y = r$rev_pp_real, stringsAsFactors = FALSE),
             units[match(r$leaid, units$leaid), setdiff(names(units), "leaid"), drop = FALSE])
  p$id <- as.integer(factor(p$leaid))
  rownames(p) <- NULL
  p
}

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


fmt <- function(x, d = 3) ifelse(is.na(x), "–", formatC(x, format = "f", digits = d))
fmt_p <- function(x) ifelse(is.na(x), "–", formatC(x, format = "f", digits = 4))

md_table <- function(df) {
  if (is.null(df) || !nrow(df)) return("_No rows._\n")
  h <- paste0("| ", paste(names(df), collapse = " | "), " |")
  s <- paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
  b <- apply(df, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
  paste(c(h, s, b, ""), collapse = "\n")
}

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

FAMILIES <- c("seda", "hs")
FAMILY_GAPS <- c("a_poverty", "b_black_white", "c_hispanic_white")
FAMILY_WINDOWS <- list(seda = c(2009:2019, 2022:2025),
                     hs = c(2010:2019, 2021:2025))
EDFACTS_YEARS <- c(2010:2019, 2021L)
RC_FROM <- 2022L
FAMILY_WEIGHT_YEAR <- 2010L
SOURCE_COV <- "rc_first"
HS_CONTROLS <- c("test_replaced", "cep", "rc")
SEDA_CONTROLS <- "cep"
BOOT_REPS <- 9999L
RI_REPS <- 10000L
COHORT_FLOOR <- 20L
CONFIRMED_STATES <- c("AL", "CA", "CO", "CT", "DE", "GA", "KS", "MA", "MI", "MO", "NC", "NV", "NY", "OR",
                           "RI", "TX", "WA")
HONEST_NOT_CONSEC <- "event times are not consecutive around the reference period"

FAMILY_VARIANTS <- list(
  sample_r5               = list(families = "hs", sample = "r5", from_year = NULL, years = NULL, states = NULL,
                                 drop_few_pre = FALSE, anticipation = 0L, split = FALSE,
                                 label = "Ranges of 5 points or less (rule 3)"),
  sample_exact            = list(families = "hs", sample = "exact", from_year = NULL, years = NULL, states = NULL,
                                 drop_few_pre = FALSE, anticipation = 0L, split = FALSE,
                                 label = "Exact values only (rule 3)"),
  participation_from_2013 = list(families = "hs", sample = "primary", from_year = 2013L, years = NULL, states = NULL,
                                 drop_few_pre = FALSE, anticipation = 0L, split = FALSE,
                                 label = "End years 2013 on (rule 4; report-card years test participation where the state prints it)"),
  drop_few_pre            = list(families = c("seda", "hs"), sample = "primary", from_year = NULL, years = NULL, states = NULL,
                                 drop_few_pre = TRUE, anticipation = 0L, split = FALSE,
                                 label = "Cohorts with fewer than three pre-reform years dropped (rule 6)"),
  anticipation_1          = list(families = c("seda", "hs"), sample = "primary", from_year = NULL, years = NULL, states = NULL,
                                 drop_few_pre = FALSE, anticipation = 1L, split = FALSE,
                                 label = "Anticipation = 1, reference period -2"),
  seda_2009_2019          = list(families = "seda", sample = "primary", from_year = NULL, years = 2009:2019, states = NULL,
                                 drop_few_pre = FALSE, anticipation = 0L, split = TRUE,
                                 label = "SEDA 2009-2019 alone (span split)"),
  seda_2022_2025          = list(families = "seda", sample = "primary", from_year = NULL, years = 2022:2025, states = NULL,
                                 drop_few_pre = FALSE, anticipation = 0L, split = TRUE,
                                 label = "SEDA 2022-2025 alone (span split)"),
  hs_edfacts_years        = list(families = "hs", sample = "primary", from_year = NULL, years = c(2010:2019, 2021L), states = NULL,
                                 drop_few_pre = FALSE, anticipation = 0L, split = TRUE,
                                 label = "EDFacts years alone, 2010-2021 (source split; the federal-file window)"),
  hs_17_states            = list(families = "hs", sample = "primary", from_year = NULL, years = NULL, states = CONFIRMED_STATES,
                                 drop_few_pre = FALSE, anticipation = 0L, split = TRUE,
                                 label = "The seventeen confirmed states only, every year (coverage split)"))
family_variants_for <- function(family, split = NULL) {
  v <- names(FAMILY_VARIANTS)[vapply(FAMILY_VARIANTS, function(x) family %in% x$families, TRUE)]
  if (is.null(split)) v else v[vapply(FAMILY_VARIANTS[v], function(x) identical(x$split, split), TRUE)]
}

family_weightings <- function(gap) if (gap == "a_poverty") "unweighted" else c("unweighted", "tested_weighted")


read_seda_extras <- function(path = seda_long_file()) {
  need <- c("sedaadmin", "subject", "grade", "year", "cs_mn_all", "cs_mn_se_all", "tot_asmt_wht", "tot_asmt_blk", "tot_asmt_hsp")
  d <- data.table::fread(path, select = need, colClasses = list(character = c("sedaadmin", "subject")),
                         showProgress = FALSE, data.table = FALSE)
  miss <- setdiff(need, names(d))
  if (length(miss)) stop(basename(path), " lacks columns: ", paste(miss, collapse = ", "))
  id <- formatC(as.integer(trimws(d$sedaadmin)), width = 7, flag = "0")
  keep <- substr(id, 1, 2) %in% STATE_FIPS
  d <- d[keep, , drop = FALSE]
  num <- function(v) suppressWarnings(as.numeric(v))
  data.frame(leaid = id[keep], sy_end = as.integer(d$year), subject = names(SEDA_SUBJECTS)[match(d$subject, SEDA_SUBJECTS)],
             grade = as.integer(d$grade),
             has_all = !is.na(num(d$cs_mn_all)) & !is.na(num(d$cs_mn_se_all)) & num(d$cs_mn_se_all) > 0,
             n_wh = num(d$tot_asmt_wht), n_bl = num(d$tot_asmt_blk), n_hi = num(d$tot_asmt_hsp), stringsAsFactors = FALSE)
}

seda_tested_weights <- function(ex, year = FAMILY_WEIGHT_YEAR) {
  x <- ex[ex$sy_end == year, , drop = FALSE]
  key <- paste(x$leaid, x$subject)
  gsum <- function(v) vapply(split(v, key), function(z) if (all(is.na(z))) NA_real_ else sum(z, na.rm = TRUE), 0)
  wh <- gsum(x$n_wh); bl <- gsum(x$n_bl); hi <- gsum(x$n_hi)
  k <- names(wh)
  per <- data.frame(leaid = sub(" .*", "", k), subject = sub(".* ", "", k), bw = bl[k] + wh[k], hw = hi[k] + wh[k],
                    stringsAsFactors = FALSE)
  w <- merge(per[per$subject == "math", ], per[per$subject == "rla", ], by = "leaid", suffixes = c("_math", "_rla"))
  pos <- function(v) ifelse(!is.na(v) & v > 0, v, NA_real_)
  out <- data.frame(leaid = w$leaid, b_black_white = pos((w$bw_math + w$bw_rla) / 2),
                    c_hispanic_white = pos((w$hw_math + w$hw_rla) / 2), stringsAsFactors = FALSE)
  out[order(out$leaid), , drop = FALSE]
}

seda_all_both <- function(ex) {
  a <- unique(ex[ex$has_all, c("leaid", "sy_end", "subject")])
  m <- a[a$subject == "math", c("leaid", "sy_end")]; r <- a[a$subject == "rla", c("leaid", "sy_end")]
  out <- merge(m, r, by = c("leaid", "sy_end"))
  out[order(out$leaid, out$sy_end), , drop = FALSE]
}

seda_districts_all_sets <- function(seda_leaids) {
  d <- seda_gap_a_districts(seda_leaids)
  for (s in c("r1", "r2")) {
    ev <- utils::read.csv(file.path("data", "reference", EVENT_FILES[[s]]), stringsAsFactors = FALSE)
    d[[RETAIN_FLAGS[[s]]]] <- as.integer(seda_reason(d$rule12, d$saipe_pov_rate_2009, ev$group[match(d$state, ev$state)]) == "retained")
  }
  d
}

hs_gap_a_districts_all_sets <- function(path = "data/derived/sample_district_year.csv") {
  s <- data.table::fread(path, select = c("leaid", "state", "retained", "retained_r1", "retained_r2", "pov_quintile_2009"),
                         colClasses = c(leaid = "character"), data.table = FALSE, showProgress = FALSE)
  d <- unique(s)
  if (anyDuplicated(d$leaid)) stop(basename(path), ": a retained flag or quintile differs within a district")
  td <- tempfile("ccd"); dir.create(td)
  l09 <- read_ccd_lea(utils::unzip("data/raw/ccd/lea-directory-sy2009-10.zip", exdir = td), 2010L, extra = "MEMBER")
  d$member_2009 <- ccd_count(l09$member)[match(d$leaid, l09$leaid)]
  d
}


family_load_inputs <- function(family, seda_weights = NULL) {
  rd <- function(f, ...) data.table::fread(f, colClasses = c(leaid = "character"), data.table = FALSE, showProgress = FALSE,
                                           na.strings = "", ...)
  if (family == "seda") {
    g <- rd("data/derived/seda_gaps.csv", select = c("gap", "state", "leaid", "sy_end", "retained", "retained_r1", "retained_r2", "v"))
    saipe <- read_saipe("data/raw/saipe/saipe-district-2009.txt")
    smp <- data.frame(leaid = saipe$leaid, sy_end = 2010L, saipe_pov_rate_2009 = saipe$pov_rate, stringsAsFactors = FALSE)
  } else if (family == "hs") {
    g <- rd("data/derived/hs_gaps.csv", select = c("gap", "state", "leaid", "sy_end", "subject", "sample", "source",
                                                         "retained", "retained_r1", "retained_r2", "v", "n_group", "n_wh"))
    smp <- rd("data/derived/sample_district_year.csv", select = c("leaid", "sy_end", "saipe_pov_rate_2009"))
  } else stop("unknown family ", family)
  stopifnot(all(g$sy_end %in% FAMILY_WINDOWS[[family]]))
  race <- g[g$gap != "a_poverty", , drop = FALSE]
  list(family = family, window = FAMILY_WINDOWS[[family]], race = race, pov = g[g$gap == "a_poverty", , drop = FALSE],
       cov = cs_covariates(race$leaid, smp, 2010L), weights = seda_weights)
}


family_outcome_rows <- function(inp, gap, flag, sample = "primary") {
  unit <- if (gap == "a_poverty") "state" else "leaid"
  x <- if (gap == "a_poverty") inp$pov else inp$race[inp$race$gap == gap, , drop = FALSE]
  if (inp$family == "seda") {
    if (sample != "primary") stop("SEDA has no suppression samples")
    x <- x[x[[flag]] %in% 1L & !is.na(x$v) & x$sy_end %in% inp$window, , drop = FALSE]
    stopifnot(!anyDuplicated(x[c(unit, "sy_end")]))
    out <- data.frame(x[unique(c(unit, "state"))], sy_end = x$sy_end, y = x$v, stringsAsFactors = FALSE)
    if (gap != "a_poverty") {
      w <- if (is.null(inp$weights)) rep(NA_real_, nrow(out)) else inp$weights[[gap]][match(out$leaid, inp$weights$leaid)]
      out$tested <- ifelse(out$sy_end == FAMILY_WEIGHT_YEAR, w, NA_real_)
    }
  } else {
    x <- x[x$sample == sample & x[[flag]] %in% 1L & !is.na(x$v), , drop = FALSE]
    x$rc <- as.integer(x$source == "report_card")
    x$tested <- x$n_group + x$n_wh
    out <- both_subjects(x, unit, "v", inp$window, carry = c("rc", if (gap != "a_poverty") "tested"), balanced = FALSE)
  }
  if (gap != "a_poverty") {
    w <- out$tested[out$sy_end == FAMILY_WEIGHT_YEAR]
    out$tested_2010 <- w[match(out$leaid, out$leaid[out$sy_end == FAMILY_WEIGHT_YEAR])]
    out$tested <- NULL
  }
  out <- out[order(out[[unit]], out$sy_end), , drop = FALSE]
  rownames(out) <- NULL
  out
}

family_model_panel <- function(inp, gap, set, sample = "primary", balanced = FALSE, from_year = NULL, years = NULL,
                             states = NULL, drop_few_pre = FALSE, weighting = "unweighted", events = NULL,
                             cohort_floor = FALSE) {
  unit <- if (gap == "a_poverty") "state" else "leaid"
  p <- family_outcome_rows(inp, gap, RETAIN_FLAGS[[set]], sample)
  cw <- sort(inp$window)
  if (!is.null(years)) cw <- cw[cw %in% years]
  if (!is.null(from_year)) cw <- cw[cw >= from_year]
  p <- p[p$sy_end %in% cw, , drop = FALSE]
  if (!is.null(states)) p <- p[p$state %in% states, , drop = FALSE]
  if (balanced) {
    full <- tapply(p$sy_end, p[[unit]], function(t) all(cw %in% t))
    p <- p[p[[unit]] %in% names(full)[full], , drop = FALSE]
  }
  covs <- character()
  if (gap != "a_poverty") {
    covs <- CS_COVARIATES
    p <- cbind(p, inp$cov[match(p$leaid, inp$cov$leaid), CS_COVARIATES])
    p <- p[stats::complete.cases(p[CS_COVARIATES]), , drop = FALSE]
  }
  ev <- if (is.null(events)) utils::read.csv(file.path("data", "reference", EVENT_FILES[[set]]), stringsAsFactors = FALSE) else events
  coding <- cohort_coding(ev, cw)
  n_few <- 0L
  if (drop_few_pre) {
    pre <- vapply(seq_len(nrow(coding)), function(i)
      if (coding$cohort_status[i] == "estimable") sum(cw < coding$g[i]) else NA_integer_, integer(1))
    few <- coding$cohort_status == "estimable" & !is.na(pre) & pre < MIN_PRE_YEARS
    n_few <- sum(few & coding$state %in% p$state)
    coding$cohort_status[few] <- "excluded"
    coding$g[few] <- NA_integer_
  }
  removed <- data.frame(cohort = integer(), states = character(), treated_units_base = integer(), stringsAsFactors = FALSE)
  if (cohort_floor && length(covs)) {
    fl <- family_cohort_floor(inp, gap, set, events = events)
    fl <- fl[fl$below_floor, , drop = FALSE]
    thin <- coding$cohort_status == "estimable" & coding$g %in% fl$cohort
    removed <- fl[fl$cohort %in% coding$g[thin], c("cohort", "states", "treated_units_base"), drop = FALSE]
    coding$cohort_status[thin] <- "excluded"
    coding$g[thin] <- NA_integer_
  }
  p <- attach_cohorts(p, coding, unit)$panel
  if (weighting == "tested_weighted") {
    p <- p[!is.na(p$tested_2010), , drop = FALSE]
    p$id <- as.integer(factor(p[[unit]]))
  }
  src <- NA_character_
  if (inp$family == "hs") {
    first <- p[order(p$id, p$sy_end), , drop = FALSE]
    first <- first[!duplicated(first$id), c("id", "rc")]
    p$rc_first <- as.integer(first$rc[match(p$id, first$id)] == 1)
    src <- if (length(unique(p$rc_first)) > 1L)
      "not entered: report-card-only units have no pre-2022 rows" else "not entered: constant in this panel"
  }
  rownames(p) <- NULL
  list(panel = p, unit = unit, xformla = if (length(covs)) stats::reformulate(covs) else ~1,
       weightsname = if (weighting == "tested_weighted") "tested_2010" else NULL,
       units = length(unique(p$id)), states = length(unique(p$state)), states_dropped_few_pre = as.integer(n_few),
       window = cw, source_covariate = src, floor_removed = removed)
}

family_cohort_floor <- function(inp, gap, set, events = NULL, floor = COHORT_FLOOR) {
  out <- data.frame(gap = character(), event_set = character(), cohort = integer(), states = character(), base_year = integer(),
                    treated_units_base = integer(), treated_units = integer(), below_floor = logical(), stringsAsFactors = FALSE)
  if (gap == "a_poverty") return(out)
  p <- family_model_panel(inp, gap, set, events = events)$panel
  cw <- sort(inp$window)
  gs <- sort(unique(p$g[p$g > 0]))
  if (!length(gs)) return(out)
  base <- vapply(gs, function(g) max(cw[cw < g]), 0)
  nb <- vapply(seq_along(gs), function(i) length(unique(p$id[p$g == gs[i] & p$sy_end == base[i]])), 0L)
  data.frame(gap = gap, event_set = set, cohort = as.integer(gs),
             states = vapply(gs, function(g) paste(sort(unique(p$state[p$g == g])), collapse = " "), ""),
             base_year = as.integer(base), treated_units_base = as.integer(nb),
             treated_units = vapply(gs, function(g) length(unique(p$id[p$g == g])), 0L),
             below_floor = nb < floor, stringsAsFactors = FALSE)
}


hs_controls <- function(rows) list(family = "hs", rows = rows)

seda_controls <- function(race, dist, all_both, cep_fun = cep_indicator) {
  q <- dist[dist$in_quintile_set & dist$pov_quintile_2009 %in% c(1L, 5L) & !is.na(dist$member_2009) & dist$member_2009 > 0, , drop = FALSE]
  qa <- all_both[all_both$leaid %in% q$leaid & all_both$sy_end %in% FAMILY_WINDOWS$seda, , drop = FALSE]
  qa$state <- q$state[match(qa$leaid, q$leaid)]
  dy <- unique(rbind(race[!is.na(race$leaid), c("leaid", "state", "sy_end")], qa[c("leaid", "state", "sy_end")]))
  dy$cep <- cep_fun(dy$leaid, dy$state, pmin(dy$sy_end, max(CDID_F33_YEARS)))
  cep_a <- lapply(stats::setNames(names(RETAIN_FLAGS), names(RETAIN_FLAGS)), function(s) {
    x <- qa[qa$leaid %in% q$leaid[q[[RETAIN_FLAGS[[s]]]] %in% 1L], , drop = FALSE]
    x$cep <- dy$cep[match(paste(x$leaid, x$sy_end), paste(dy$leaid, dy$sy_end))]
    if (!nrow(x)) return(data.frame(state = character(), sy_end = integer(), cep = numeric()))
    stats::aggregate(list(cep = x$cep), list(state = x$state, sy_end = x$sy_end), mean)
  })
  list(family = "seda", cep = dy, cep_a = cep_a)
}

family_attach_controls <- function(ctrl, panel, gap, set) {
  if (ctrl$family == "seda") {
    if (gap == "a_poverty") {
      a <- ctrl$cep_a[[set]]
      k <- match(paste(panel$state, panel$sy_end), paste(a$state, a$sy_end))
      if (anyNA(k)) stop("state-years without a CEP share: ", sum(is.na(k)))
      panel$cep <- a$cep[k]
    } else panel <- attach_district_flags(panel, ctrl$cep, "cep")
    return(list(panel = panel, controls = SEDA_CONTROLS))
  }
  if (gap == "a_poverty") {
    panel <- attach_flags(panel, gap_a_flags(ctrl$rows, RETAIN_FLAGS[[set]], sort(unique(panel$sy_end)), "primary"))
  } else panel <- attach_district_flags(panel, ctrl$rows, c("test_replaced", "cep"))
  list(panel = panel, controls = HS_CONTROLS)
}


honest_block_rule <- function(honest, infs, refs, mbarvec = MBAR_GRID) {
  ks <- names(honest)
  aff <- ks[vapply(ks, function(k) any(honest[[k]]$status %in% HONEST_NOT_CONSEC) && !is.null(infs[[k]]), TRUE)]
  if (length(aff)) {
    jobs <- lapply(aff, function(k) list(inf = infs[[k]], ref = as.integer(refs[[k]])))
    one <- function(j, mbarvec) suppressWarnings(honest_block(j$inf, mbarvec, ref = j$ref))
    environment(one) <- globalenv()
    honest[aff] <- furrr::future_map(jobs, one, mbarvec = mbarvec, .options = furrr::furrr_options(seed = NULL))
  }
  lapply(honest, function(h) {
    if (!"event_block" %in% names(h)) { h$event_block <- rep(NA_character_, nrow(h)); h$event_block_note <- rep(NA_character_, nrow(h)) }
    h
  })
}


family_gap_a_revenue_panel <- function(d, flag, rev, years, base) {
  x <- d
  x$retained <- x[[flag]]
  r <- quintile_revenue_gap(gap_a_district_years(x, years), rev)
  st <- base[!duplicated(base$state), c("state", "g")]
  out <- data.frame(state = r$state, sy_end = r$sy_end, y = r$rev_gap, stringsAsFactors = FALSE)
  out <- out[out$state %in% st$state, , drop = FALSE]
  out$g <- st$g[match(out$state, st$state)]
  out <- out[order(out$state, out$sy_end), , drop = FALSE]
  out$id <- as.integer(factor(out$state))
  rownames(out) <- NULL
  out
}

# State report-card high school outcomes, end years 2022-2025 (docs/design_extension.md,
# Sections 3-6 and 9). Functions used by R/12_hs_reportcard_outcomes.R.
#
# One loader per state (HS_RC_LOADERS), called once per mapped state-year row of
# data/reference/hs_reportcard_harmonization.csv; each returns long rows in the common layout
# of rc_long() below. rc_cells() applies the Run 1 cell rules to them and returns one row per
# district-year in the step 3 sample-file layout (n_, p_, w_, cell_, part_, part_ok_).
#
# Author decisions 2026-09-16 (docs/deviations_run2.md):
#   30-student floor: on the exact tested count where the file prints one, on the band's lower
#   bound for banded counts (NH, WY), and on the state's minimum group size
#   (harmonization column min_group_size) where no count is printed: a published rate means the
#   group reached that size. The count used to clamp a share of 0 or 1 in V is the exact count,
#   the band's lower bound, or the minimum group size, in that order; the binomial standard
#   error is left blank unless the count is exact.
#   Pooled tests (GA, CO, DC, NY 2024): the components whose tested count and rate are both
#   printed are pooled with the counts; one printed component is used alone; none printed leaves
#   the cell missing.
#   Participation: tested with the Run 1 95% rule where the file prints a rate by group
#   (harmonization column participation_col); not applicable (NA) elsewhere.
#   Gap (a) all-students rows: harmonization column subgroup_all; blank where none is printed.

HS_RC_WINDOW <- 2022:2025
HS_RC_DIR    <- "data/raw/hs_reportcards"
RC_SUBGROUPS <- c("all", "wh", "bl", "hi")          # ecd is not read from report cards
RC_SAMPLE_SUBGROUPS <- c("all", "wh", "bl", "hi", "ecd")   # the step 3 layout (unname(SUBGROUPS))

read_hs_harmonization <- function(path = "data/reference/hs_reportcard_harmonization.csv") {
  h <- utils::read.csv(path, colClasses = "character", na.strings = character(), check.names = FALSE,
                       encoding = "UTF-8")
  h$sy_end <- as.integer(h$sy_end)
  h
}

# The archived files of one harmonization row, in the order file_name lists them.
rc_files <- function(row) {
  f <- trimws(strsplit(row$file_name, "|", fixed = TRUE)[[1]])
  f <- sub(" \\(.*\\)$", "", f)                      # "SRC2022.zip (SRC2022_GroupIV.mdb)"
  file.path("data/raw", f)                          # file_name starts with hs_reportcards/
}

# ---- value parsing -------------------------------------------------------------------------

# Printed counts: digits with optional thousands separators and a trailing ".0"; anything
# else (suppression symbols, blanks, negative mask codes) is NA.
rc_count <- function(x) {
  x <- gsub("[, ]", "", trimws(as.character(x)))
  x <- sub("\\.0+$", "", x)
  out <- suppressWarnings(as.numeric(x))
  out[!grepl("^[0-9]+$", x)] <- NA_real_
  out
}

# A count printed as a band, "30 - 35" or "270 - 279": the lower bound (NA otherwise).
rc_count_band_lo <- function(x) {
  x <- trimws(as.character(x))
  ok <- grepl("^[0-9,]+ *- *[0-9,]+$", x)
  out <- rep(NA_real_, length(x))
  out[ok] <- as.numeric(gsub(",", "", sub(" *-.*$", "", x[ok])))
  out
}

# A printed percentage as a range in percentage points, from its printed endpoints, closing
# one-sided labels at 0 and 100 as edfacts_range() does: "45.2" or "45.2%" is [45.2, 45.2];
# "20-29%" is [20, 29]; "<5", "< 5.0%", "<=10%", the less-or-equal sign, "LT5" are [0, x]; ">95", ">= 90%",
# the greater-or-equal sign are [x, 100]. scale = 100 multiplies the numbers first, for files that print
# proportions (0-1). Suppression symbols and blanks give NA.
rc_pct <- function(x, scale = 1) {
  x <- toupper(trimws(as.character(x)))
  x <- gsub("\u2264", "<=", gsub("\u2265", ">=", x))   # the characters less-or-equal and greater-or-equal
  x <- gsub("[% ]", "", x)
  num <- "[0-9]*\\.?[0-9]+"
  lo <- hi <- rep(NA_real_, length(x))
  ex <- grepl(paste0("^", num, "$"), x)
  lo[ex] <- hi[ex] <- as.numeric(x[ex]) * scale
  rg <- grepl(paste0("^", num, "-", num, "$"), x)
  lo[rg] <- as.numeric(sub("-.*$", "", x[rg])) * scale
  hi[rg] <- as.numeric(sub("^.*-", "", x[rg])) * scale
  up <- grepl(paste0("^(>=?|G[ET])", num, "$"), x)
  lo[up] <- as.numeric(sub("^(>=?|G[ET])", "", x[up])) * scale
  hi[up] <- 100
  dn <- grepl(paste0("^(<=?|L[ET])", num, "$"), x)
  lo[dn] <- 0
  hi[dn] <- as.numeric(sub("^(<=?|L[ET])", "", x[dn])) * scale
  lo <- round(lo, 6); hi <- round(hi, 6)
  bad <- !is.na(lo) & (lo > hi | hi > 100 + 1e-6 | lo < 0)
  if (any(bad)) stop("percent range reversed or outside 0-100: ", paste(utils::head(unique(x[bad])), collapse = ", "))
  data.frame(lo = lo, hi = pmin(hi, 100))
}

# The sum of several printed levels (e.g. Level 3 % + Level 4 %) as a range: the sum of the
# lower endpoints to the sum of the upper endpoints, capped at 100; NA if any level is NA.
rc_pct_sum <- function(..., scale = 1) {
  parts <- lapply(list(...), rc_pct, scale = scale)
  lo <- Reduce(`+`, lapply(parts, `[[`, "lo"))
  hi <- Reduce(`+`, lapply(parts, `[[`, "hi"))
  data.frame(lo = pmin(lo, 100), hi = pmin(hi, 100))
}

# ---- the common long layout ----------------------------------------------------------------

# One row per state-year-district-subject-subgroup (-component for pooled tests).
#   st_id     the state's district code as the loader normalizes it (crosswalk key)
#   name      the district name as printed (crosswalk key for name-only states)
#   subject   math, rla;  sg  all, wh, bl, hi
#   n         exact tested count (NA if not printed or not exact)
#   n_band_lo lower bound of a banded tested count (NH, WY), else NA
#   p_lo, p_hi  percent proficient range in points (equal when exact), NA when not printed
#   part      participation rate as printed (character), NA when the file prints none
#   component test within a pooled result (e.g. "Algebra I"), NA for single tests
#   part_n    students expected to test, the weight for pooling participation (pooled tests only)
rc_long <- function(state, sy_end, st_id, name, subject, sg, n = NA_real_, p = NULL,
                    n_band_lo = NA_real_, part = NA_character_, component = NA_character_,
                    part_n = NA_real_) {
  # rows: the longest argument (name-only states pass st_id = NA; a scalar is recycled)
  k <- max(length(st_id), length(name), length(subject), length(sg), length(n), length(n_band_lo),
           length(part), length(component), length(part_n), if (is.null(p)) 0L else nrow(p))
  lens <- c(length(st_id), length(name), length(subject), length(sg), length(n), length(n_band_lo),
            length(part), length(component), length(part_n))
  if (any(!lens %in% c(1L, k)) || (!is.null(p) && !nrow(p) %in% c(1L, k))) stop("rc_long: arguments of unequal length")
  if (is.null(p)) p <- data.frame(lo = rep(NA_real_, k), hi = rep(NA_real_, k))
  out <- data.frame(state = rep(state, k), sy_end = rep(as.integer(sy_end), k),
                    st_id = rep_len(as.character(st_id), k), name = rep_len(trimws(as.character(name)), k),
                    subject = rep_len(subject, k), sg = rep_len(sg, k),
                    n = rep_len(as.numeric(n), k), n_band_lo = rep_len(as.numeric(n_band_lo), k),
                    p_lo = rep_len(p$lo, k), p_hi = rep_len(p$hi, k), part = rep_len(as.character(part), k),
                    component = rep_len(as.character(component), k), part_n = rep_len(as.numeric(part_n), k),
                    stringsAsFactors = FALSE)
  stopifnot(all(out$subject %in% c("math", "rla")), all(out$sg %in% RC_SUBGROUPS))
  out
}

# Map printed subgroup labels to sg codes: labels is a named vector c(all = "All Students", ...).
# Rows whose label is not one of them get NA (dropped by the loaders).
rc_sg <- function(x, labels) {
  x <- trimws(as.character(x))
  names(labels)[match(x, labels)]
}

# Pooled tests (author decision 2026-09-16): within state-year-district-subject-subgroup, the
# printed components are pooled with the counts, p = sum(n p) / sum(n) on each endpoint; a
# single printed component is used alone; none printed leaves no row. A component is printed
# when both its exact tested count and its rate are printed: the files suppress the rate of a
# course taken by a handful of students (GA prints counts of 1-5 with the rate TFS), and such a
# course is treated as suppressed.
rc_pool <- function(x) {
  single <- x[is.na(x$component), ]
  pooled <- x[!is.na(x$component), ]
  if (!nrow(pooled)) return(single)
  pooled <- pooled[!is.na(pooled$n) & !is.na(pooled$p_lo), ]
  if (!nrow(pooled)) return(single)
  key <- paste(pooled$state, pooled$sy_end, pooled$st_id, pooled$name, pooled$subject, pooled$sg, sep = "\r")
  f <- factor(key, levels = unique(key))
  sn <- as.vector(tapply(pooled$n, f, sum))
  lo <- as.vector(tapply(pooled$n * pooled$p_lo, f, sum)) / sn   # NA if any component's rate is NA
  hi <- as.vector(tapply(pooled$n * pooled$p_hi, f, sum)) / sn
  first <- pooled[match(levels(f), key), ]
  first$n <- sn
  first$p_lo <- round(lo, 6); first$p_hi <- round(hi, 6)
  first$component <- NA_character_
  # Participation of a pooled result: the printed component rates weighted by part_n (the
  # students expected to test in each component); NA unless every pooled component prints both.
  pr <- rc_pct(pooled$part)$lo
  pp <- as.vector(tapply(pooled$part_n * pr, f, sum)) / as.vector(tapply(pooled$part_n, f, sum))
  first$part <- ifelse(is.na(pp), NA_character_, format(round(pp, 6), trim = TRUE))
  first$part_n <- as.vector(tapply(pooled$part_n, f, sum))
  rbind(single, first)
}

# ---- cells in the step 3 layout --------------------------------------------------------------

# The Run 1 rules on report-card long rows (after rc_pool() and the crosswalk: needs leaid).
# min_n: the state's minimum group size; part_applies: whether the state prints participation
# by group. Returns one row per leaid-sy_end with, for subj in math, rla and sg in
# RC_SAMPLE_SUBGROUPS, the step 3 columns
#   n_  exact tested count;  p_  percent entering (exact or midpoint), NA unless usable;
#   w_  range width in points;  cell_  not_reported / below_30 / suppressed / wide_range / usable;
#   part_, part_ok_  participation as printed and the 95% rule (NA: not applicable)
# and the step 12 columns
#   nbasis_  exact / band_lower / min_group / none: what the 30 floor was applied to
#   nclamp_  the count used to clamp a share of 0 or 1 in V (exact, band lower bound, or min_n)
rc_cells <- function(x, min_n, part_applies, floor = 30) {
  stopifnot(!anyDuplicated(x[c("leaid", "sy_end", "subject", "sg")]))
  w <- x$p_hi - x$p_lo
  has_p <- !is.na(w)
  basis <- ifelse(!is.na(x$n), "exact", ifelse(!is.na(x$n_band_lo), "band_lower",
                  ifelse(has_p & !is.na(min_n), "min_group", "none")))
  n_floor <- ifelse(basis == "exact", x$n, ifelse(basis == "band_lower", x$n_band_lo,
                    ifelse(basis == "min_group", Inf, NA_real_)))
  status <- ifelse(basis == "none", "not_reported",
                   ifelse(n_floor < floor, "below_30",
                          ifelse(!has_p, "suppressed",
                                 ifelse(w > MAX_WIDTH[["primary"]] + 1e-9, "wide_range", "usable"))))
  x$cell <- status
  x$w <- round(w, 6)
  x$p <- ifelse(status == "usable", (x$p_lo + x$p_hi) / 2, NA_real_)
  x$nbasis <- basis
  x$nclamp <- ifelse(basis == "exact", x$n, ifelse(basis == "band_lower", x$n_band_lo,
                     ifelse(basis == "min_group", min_n, NA_real_)))
  # Run 1 rule 4 on the printed value: the exact value or the band midpoint must be at least 95
  # (part_pass()), read with rc_pct() so that "100.00%", ">95" and "< 5.0%" parse; nothing printed fails.
  if (part_applies) {
    pr <- rc_pct(x$part)
    x$part_ok <- as.integer(!is.na(pr$lo) & (pr$lo + pr$hi) / 2 >= 95)
  } else x$part_ok <- NA_integer_
  if (!part_applies) x$part <- NA_character_
  ids <- unique(x[c("leaid", "state", "sy_end")])
  ids <- ids[order(ids$leaid, ids$sy_end), ]
  key <- paste(ids$leaid, ids$sy_end)
  out <- ids
  for (subj in c("math", "rla")) for (s in RC_SAMPLE_SUBGROUPS) {
    y <- x[x$subject == subj & x$sg == s, ]
    k <- match(key, paste(y$leaid, y$sy_end))
    sfx <- paste0("_", subj, "_", s)
    out[[paste0("part", sfx)]]    <- y$part[k]
    out[[paste0("part_ok", sfx)]] <- if (part_applies) ifelse(is.na(k), 0L, y$part_ok[k]) else NA_integer_
    out[[paste0("n", sfx)]]       <- y$n[k]
    out[[paste0("p", sfx)]]       <- y$p[k]
    out[[paste0("w", sfx)]]       <- y$w[k]
    out[[paste0("cell", sfx)]]    <- ifelse(is.na(k), "not_reported", y$cell[k])
    out[[paste0("nbasis", sfx)]]  <- ifelse(is.na(k), "none", y$nbasis[k])
    out[[paste0("nclamp", sfx)]]  <- y$nclamp[k]
  }
  rownames(out) <- NULL
  out
}

# ---- gaps ----------------------------------------------------------------------------------

# Gaps (b) and (c) on panel rows, as race_gaps() (R/functions/outcomes.R) but with the clamping
# count nclamp_* in place of n_* and a blank standard error unless both counts are exact.
rc_race_gaps <- function(d, subj, sample) {
  col <- function(pre, s) d[[paste0(pre, "_", subj, "_", s)]]
  out <- data.frame(leaid = d$leaid, state = d$state, sy_end = d$sy_end,
                    subject = rep(subj, nrow(d)), sample = rep(sample, nrow(d)),
                    retained = d$retained, retained_r1 = d$retained_r1, retained_r2 = d$retained_r2,
                    stringsAsFactors = FALSE)
  any_ok <- rep(FALSE, nrow(d))
  for (g in names(RACE_GAPS)) {
    a <- RACE_GAPS[[g]][1]; b <- RACE_GAPS[[g]][2]
    ok <- gap_cells_ok(d, subj, c(a, b), sample)
    v <- se <- rep(NA_real_, nrow(d))
    pa <- col("p", a)[ok] / 100; pb <- col("p", b)[ok] / 100
    v[ok] <- v_gap(pa, pb, col("nclamp", a)[ok], col("nclamp", b)[ok])
    exact <- !is.na(col("n", a)[ok]) & !is.na(col("n", b)[ok])
    se_ok <- rep(NA_real_, sum(ok))
    se_ok[exact] <- v_gap_se(pa[exact], pb[exact], col("n", a)[ok][exact], col("n", b)[ok][exact])
    se[ok] <- se_ok
    out[[paste0("v_", g)]]  <- v
    out[[paste0("se_", g)]] <- se
    any_ok <- any_ok | ok
  }
  for (pre in c("n", "p", "w")) for (s in c("wh", "bl", "hi")) {
    x <- col(pre, s)
    out[[paste0(pre, "_", s)]] <- if (pre == "p") x / 100 else x
  }
  out <- out[any_ok, ]
  rownames(out) <- NULL
  out
}

# Gap (a) on panel rows, as poverty_gap() but clamping with nclamp_*_all; tested_q* sums the
# exact counts only (NA where a quintile has a district without one).
rc_poverty_gap <- function(d, subj, sample) {
  d[[paste0("n_", subj, "_all_exact")]] <- d[[paste0("n_", subj, "_all")]]
  d[[paste0("n_", subj, "_all")]] <- d[[paste0("nclamp_", subj, "_all")]]
  out <- poverty_gap(d, subj, sample)
  if (!nrow(out)) return(out)
  n_col <- paste0("n_", subj, "_all_exact")
  wt_ok <- !is.na(d$member_2009) & d$member_2009 > 0
  x <- d[d$pov_quintile_2009 %in% c(1L, 5L) & wt_ok & gap_cells_ok(d, subj, "all", sample), ]
  key <- paste(x$state, x$sy_end)
  for (q in c(1L, 5L)) {
    t <- tapply(x[[n_col]][x$pov_quintile_2009 == q], key[x$pov_quintile_2009 == q], sum)
    out[[paste0("tested_q", q)]] <- as.vector(t[paste(out$state, out$sy_end)])
  }
  out
}

# ---- district identifiers: the NCES crosswalk (author decision 2026-09-16) ----------------------

HS_RC_CROSSWALK <- "data/reference/hs_reportcard_leaid_crosswalk.csv"
HS_RC_NAME_STATES <- c("NH", "RI", "UT", "WY")             # files print district names only
HS_RC_CCD_YEARS <- 2022:2024                                # CCD LEA directories archived for the report-card years

# One CCD LEA directory year with the fields the crosswalk and rules need: leaid, state,
# st_leaid (the state's code, "XX-" prefix removed), lea_name, agency_type, status (UPDATED_STATUS).
rc_ccd_directory <- function(sy_end, exdir = tempfile("ccdlea")) {
  z <- ccd_lea_zip(sy_end)
  if (!file.exists(z)) stop("missing CCD LEA directory for end year ", sy_end, ": ", z)
  dir.create(exdir, recursive = TRUE, showWarnings = FALSE)
  f <- utils::unzip(z, files = ccd_lea_member(z), exdir = exdir)
  d <- data.table::fread(f, select = c("ST", "LEAID", "ST_LEAID", "LEA_NAME", "LEA_TYPE", "UPDATED_STATUS"),
                         colClasses = "character", encoding = "Latin-1", showProgress = FALSE, data.table = FALSE)
  unlink(exdir, recursive = TRUE)
  data.frame(sy_end = as.integer(sy_end), state = d$ST, leaid = trimws(d$LEAID),
             st_leaid = sub("^[A-Z]{2}-", "", trimws(d$ST_LEAID)), lea_name = trimws(d$LEA_NAME),
             agency_type = as.integer(d$LEA_TYPE), status = as.integer(d$UPDATED_STATUS), stringsAsFactors = FALSE)
}

# A district name reduced for matching: upper case, "&" as AND, punctuation dropped, and the
# generic words SCHOOL(S), DISTRICT, PUBLIC, COUNTY, SD, NO removed ("Albany County School District #1"
# and "Albany #1" both give "ALBANY 1").
rc_name_key <- function(x) {
  x <- toupper(iconv(x, to = "ASCII//TRANSLIT", sub = ""))
  x <- gsub("&", " AND ", x)
  x <- gsub("[^A-Z0-9 ]", " ", x)
  w <- strsplit(trimws(gsub(" +", " ", x)), " ")
  drop <- c("SCHOOL", "SCHOOLS", "DISTRICT", "PUBLIC", "COUNTY", "SD", "NO", "THE")
  vapply(w, function(v) paste(v[!v %in% drop], collapse = " "), "")
}

# Draft crosswalk rows for report-card district keys (state, st_id, name). Code states match st_id
# to the CCD state code (method st_leaid); name-only states match rc_name_key() within state
# (method name, a unique match only). The latest CCD year with a match is used. Unmatched keys get
# method unmatched and a blank leaid. author_check is left blank for the author.
rc_crosswalk_draft <- function(keys, ccd) {
  ccd <- ccd[order(-ccd$sy_end), ]
  out <- keys
  out$leaid <- out$ccd_st_leaid <- out$ccd_name <- NA_character_
  out$ccd_sy_end <- NA_integer_
  out$method <- "unmatched"
  code <- !out$state %in% HS_RC_NAME_STATES
  k <- match(paste(out$state[code], out$st_id[code]), paste(ccd$state, ccd$st_leaid))
  hit <- which(code)[!is.na(k)]; k <- k[!is.na(k)]
  out$leaid[hit] <- ccd$leaid[k]; out$ccd_st_leaid[hit] <- ccd$st_leaid[k]
  out$ccd_name[hit] <- ccd$lea_name[k]; out$ccd_sy_end[hit] <- ccd$sy_end[k]; out$method[hit] <- "st_leaid"
  cn <- ccd[!duplicated(paste(ccd$state, ccd$leaid)), ]
  cn$key <- paste(cn$state, rc_name_key(cn$lea_name))
  for (i in which(!code)) {
    j <- which(cn$key == paste(out$state[i], rc_name_key(out$name[i])))
    if (length(unique(cn$leaid[j])) == 1L) {
      j <- j[1]
      out$leaid[i] <- cn$leaid[j]; out$ccd_st_leaid[i] <- cn$st_leaid[j]; out$ccd_name[i] <- cn$lea_name[j]
      out$ccd_sy_end[i] <- cn$sy_end[j]; out$method[i] <- "name"
    } else if (length(j) > 1L) out$method[i] <- "ambiguous"
  }
  out$author_check <- ""
  out[c("state", "st_id", "name", "leaid", "method", "ccd_st_leaid", "ccd_name", "ccd_sy_end", "author_check")]
}

# The crosswalk key of long rows: st_id for code states, the printed name for name-only states.
rc_xw_key <- function(state, st_id, name) ifelse(state %in% HS_RC_NAME_STATES, paste(state, "name", name), paste(state, "id", st_id))

# ---- rules 1 and 2 in the report-card years (author decision 2026-09-16) ------------------------

# Run 1's retained flags stand; a report-card row is also removed when the district fails rules
# 1 or 2 in that year's CCD LEA directory: agency type not 1 or 2, not operational (UPDATED_STATUS
# 2 closed, 6 inactive, 7 future), a boundary change (5) or a reopening (8), or not listed. End year
# 2025 has no directory and takes the district's 2024 result.
rc_rule12 <- function(leaid, sy_end, ccd) {
  y <- pmin(sy_end, max(HS_RC_CCD_YEARS))
  k <- match(paste(leaid, y), paste(ccd$leaid, ccd$sy_end))
  ty <- ccd$agency_type[k]; st <- ccd$status[k]
  ifelse(is.na(k), "rule 2: not in the CCD LEA directory",
         ifelse(!ty %in% 1:2, "rule 1: agency type not 1 or 2",
                ifelse(st %in% c(2L, 6L, 7L), "rule 2: not operational",
                       ifelse(st %in% BOUND_CHANGE, "rule 2: boundary change (5 or 8)", "pass"))))
}

# ---- CEP (author decision 2026-09-16) ---------------------------------------------------------

# District-year CEP for the report-card years: the CCD school characteristics files for 2022-2024
# (cep_from_ccd()); 2025 has no file and carries each district's 2024 value (cep_carried = 1).
rc_cep <- function(leaid, sy_end) {
  cep <- integer(length(leaid))
  for (y in HS_RC_CCD_YEARS) {
    d <- cep_from_ccd(y)
    k <- which(pmin(sy_end, max(HS_RC_CCD_YEARS)) == y)
    m <- match(leaid[k], d$leaid)
    cep[k] <- ifelse(is.na(m), 0L, d$cep[m])
  }
  data.frame(cep = cep, cep_carried = as.integer(sy_end > max(HS_RC_CCD_YEARS)))
}

# Identical duplicate long rows are kept once; district-year-subject-subgroup keys with differing
# values are dropped (returned in attribute "conflicts").
rc_dedupe <- function(x) {
  x <- x[!duplicated(x), ]
  key <- paste(x$leaid, x$sy_end, x$subject, x$sg)
  bad <- key %in% key[duplicated(key)]
  out <- x[!bad, ]
  attr(out, "conflicts") <- x[bad, ]
  out
}

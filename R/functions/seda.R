# SEDA 2025.2 grades 3-8 outcomes (docs/design_extension.md, Sections 3, 5 and 6).
# Functions used by R/11_seda_outcomes.R.
# Author decisions 2026-09-16 (docs/deviations_run2.md):
#   precision weights and pooled standard errors use SEDA's unadjusted standard error
#   (cs_mn_se_*), which SEDA gives as the one for within-state comparisons; a grade whose
#   mean has no unadjusted standard error does not enter the pool;
#   Run 1 rules 1 and 2 are tested in the SEDA end years with an archived CCD LEA
#   directory (SEDA_RULES_WINDOW), and the 2009 and 2025 rows take the district's result;
#   the gap (a) poverty quintiles are formed among districts whose 2009-10 CCD grade span
#   (GSLO-GSHI) includes a grade from 3 to 8, in place of Run 1's span reaching 12.
# Sign: gaps (b) and (c) are Black minus White and Hispanic minus White, gap (a) top-poverty
# minus bottom-poverty quintile, as in Run 1. SEDA's own gap columns (White minus group)
# are not read.

SEDA_WINDOW       <- c(2009:2019, 2022:2025)   # Section 3: 2020 and 2021 do not exist in SEDA
SEDA_RULES_WINDOW <- c(2010:2019, 2022:2024)   # SEDA years with a CCD LEA directory file
SEDA_PUBLIC_FROM  <- 2022L                     # 2022-2025 built from public EDC data (Section 6)
SEDA_GRADES       <- 3:8
SEDA_SUBJECTS     <- c(math = "mth", rla = "rla")
SEDA_SUBGROUPS    <- c(all = "all", wh = "wht", bl = "blk", hi = "hsp")
# The gap's group and its reference group, in the study's orientation (group minus White).
SEDA_GAPS <- list(b_black_white = c("bl", "wh"), c_hispanic_white = c("hi", "wh"))

seda_long_file <- function(release = "2025.2")
  sprintf("data/raw/seda/seda_admindist_long_cs_%s.csv", release)

# The SEDA administrative-district long file, CS scale, reduced to the columns used here:
# leaid (7-digit NCES LEAID, zero-padded from sedaadmin), state, sy_end, subject (math, rla),
# grade, and mn_<sg> / se_<sg> (cs_mn_* and cs_mn_se_*) for sg in all, wh, bl, hi.
read_seda_long <- function(path = seda_long_file()) {
  src <- as.vector(outer(c("cs_mn_", "cs_mn_se_"), SEDA_SUBGROUPS, paste0))
  need <- c("sedaadmin", "subject", "grade", "year", "fips", "stateabb", src)
  d <- data.table::fread(path, select = need, colClasses = list(character = c("sedaadmin", "subject", "stateabb")),
                         showProgress = FALSE, data.table = FALSE)
  miss <- setdiff(need, names(d))
  if (length(miss)) stop(basename(path), " lacks columns: ", paste(miss, collapse = ", "))
  id <- trimws(d$sedaadmin)
  if (!all(grepl("^[0-9]{1,7}$", id))) stop(basename(path), ": sedaadmin not a number of up to 7 digits")
  id <- formatC(as.integer(id), width = 7, flag = "0")
  # BIE agencies (NCES prefix 59) carry the FIPS code of the state they are in.
  pre <- substr(id, 1, 2)
  if (!all(pre == sprintf("%02d", as.integer(d$fips)) | pre == "59"))
    stop(basename(path), ": sedaadmin does not begin with the state FIPS code (or 59, BIE)")
  if (!all(d$subject %in% SEDA_SUBJECTS)) stop(basename(path), ": subject outside ", paste(SEDA_SUBJECTS, collapse = ", "))
  if (!all(d$grade %in% SEDA_GRADES)) stop(basename(path), ": grade outside 3-8")
  if (!all(d$year %in% SEDA_WINDOW)) stop(basename(path), ": year outside the SEDA window")
  out <- data.frame(leaid = id, state = d$stateabb, sy_end = as.integer(d$year),
                    subject = names(SEDA_SUBJECTS)[match(d$subject, SEDA_SUBJECTS)],
                    grade = as.integer(d$grade), stringsAsFactors = FALSE)
  if (anyDuplicated(out[c("leaid", "sy_end", "subject", "grade")]))
    stop(basename(path), ": duplicate district-year-subject-grade")
  for (sg in names(SEDA_SUBGROUPS)) {
    out[[paste0("mn_", sg)]] <- as.numeric(d[[paste0("cs_mn_", SEDA_SUBGROUPS[[sg]])]])
    out[[paste0("se_", sg)]] <- as.numeric(d[[paste0("cs_mn_se_", SEDA_SUBGROUPS[[sg]])]])
  }
  out
}

# Section 6 pooling. For each district-year-subject and subgroup, the grade 3-8 means are
# combined with weights 1 / se^2; the pooled standard error is 1 / sqrt(sum of weights).
# A grade enters a subgroup's pool when its mean and a positive standard error are both
# present. Returns one row per district-year-subject with mn_<sg>, se_<sg> (NA when no
# grade enters), grades_<sg> (grades pooled) and gmask_<sg> (bit g - 3 set for each grade g
# pooled, so the grade sets of two subgroups can be compared).
seda_pool <- function(x) {
  key <- paste(x$leaid, x$sy_end, x$subject, sep = "|")
  ukey <- unique(key)
  f <- factor(key, levels = ukey)
  first <- match(ukey, key)
  out <- x[first, c("leaid", "state", "sy_end", "subject")]
  rownames(out) <- NULL
  for (sg in names(SEDA_SUBGROUPS)) {
    m <- x[[paste0("mn_", sg)]]; s <- x[[paste0("se_", sg)]]
    ok <- !is.na(m) & !is.na(s) & s > 0
    w <- ifelse(ok, 1 / s^2, 0)
    sw <- as.vector(rowsum(w, f, reorder = FALSE))
    swm <- as.vector(rowsum(ifelse(ok, w * m, 0), f, reorder = FALSE))
    out[[paste0("mn_", sg)]] <- ifelse(sw > 0, swm / sw, NA_real_)
    out[[paste0("se_", sg)]] <- ifelse(sw > 0, 1 / sqrt(sw), NA_real_)
    out[[paste0("grades_", sg)]] <- as.integer(rowsum(as.integer(ok), f, reorder = FALSE))
    out[[paste0("gmask_", sg)]] <- as.integer(rowsum(ifelse(ok, 2L^(x$grade - 3L), 0L), f, reorder = FALSE))
  }
  out
}

# Math and RLA side by side for keyed rows (one row per key and subject): v_<subj> and
# se_<subj> from value and se, and v = the mean of the two subjects, NA unless both are
# present (Section 6: both subjects required). Further columns in carry are kept with a
# _<subj> suffix. keys identify the unit-year; they must not include subject.
seda_subject_wide <- function(x, keys, carry = character()) {
  sides <- lapply(names(SEDA_SUBJECTS), function(subj) {
    y <- x[x$subject == subj, c(keys, "value", "se", carry), drop = FALSE]
    names(y) <- c(keys, paste0(c("v", "se", carry), "_", subj))
    y
  })
  w <- merge(sides[[1]], sides[[2]], by = keys, all = TRUE, sort = FALSE)
  w$v <- (w$v_math + w$v_rla) / 2
  w[c(keys, "v", as.vector(t(outer(c("v", "se", carry), names(SEDA_SUBJECTS), paste, sep = "_"))))]
}

# Gaps (b) and (c) from pooled rows (seda_pool()). A district-year-subject enters a gap when
# the all-students mean and both subgroup means of the gap are present (Section 5). The
# subject gap is group minus White; its standard error is sqrt(se_group^2 + se_White^2),
# SEDA's own formula for a within-district gap. Returns one row per gap and district-year
# with at least one subject gap: gap, leaid, state, sy_end, v, v_<subj>, se_<subj>, and per
# subject the pooled means, standard errors and grades of all students, the gap's group
# and White (mean_all_<subj>, mean_group_<subj>, mean_wh_<subj>, se_..., grades_...).
seda_race_gaps <- function(p) {
  do.call(rbind, lapply(names(SEDA_GAPS), function(g) {
    a <- SEDA_GAPS[[g]][1]; b <- SEDA_GAPS[[g]][2]
    ok <- !is.na(p$mn_all) & !is.na(p[[paste0("mn_", a)]]) & !is.na(p[[paste0("mn_", b)]])
    y <- p[ok, ]
    if (!nrow(y)) return(NULL)
    y$value <- y[[paste0("mn_", a)]] - y[[paste0("mn_", b)]]
    y$se <- sqrt(y[[paste0("se_", a)]]^2 + y[[paste0("se_", b)]]^2)
    for (pre in c("mn", "se", "grades")) {
      nm <- if (pre == "mn") "mean" else pre
      y[[paste0(nm, "_all")]]   <- y[[paste0(pre, "_all")]]
      y[[paste0(nm, "_group")]] <- y[[paste0(pre, "_", a)]]
      y[[paste0(nm, "_wh")]]    <- y[[paste0(pre, "_", b)]]
    }
    carry <- as.vector(outer(c("mean", "se", "grades"), c("all", "group", "wh"), paste, sep = "_"))
    w <- seda_subject_wide(y, c("leaid", "state", "sy_end"), carry)
    cbind(gap = rep(g, nrow(w)), w, stringsAsFactors = FALSE)
  }))
}

# Gap (a) from pooled rows and a district table (leaid, pov_quintile_2009, member_2009).
# For each state-year-subject, each quintile's score is the member_2009-weighted mean of
# the pooled all-students means of its districts with a mean that year; the standard error
# is sqrt(sum(w^2 se^2)) / sum(w), districts independent. v = score_q5 - score_q1, with
# se = sqrt(se_q5^2 + se_q1^2). Districts without a positive member_2009 are left out, as in
# Run 1. A state-year-subject enters when both quintiles have a district. Returns one row
# per state-year with at least one subject: gap, state, sy_end, v, v_<subj>, se_<subj>,
# mean_q5_<subj>, mean_q1_<subj>, districts_q5_<subj>, districts_q1_<subj>.
seda_poverty_gap <- function(p, dist) {
  k <- match(p$leaid, dist$leaid)
  x <- p[!is.na(k), ]
  x$q <- dist$pov_quintile_2009[k[!is.na(k)]]
  x$member <- dist$member_2009[k[!is.na(k)]]
  x <- x[x$q %in% c(1L, 5L) & !is.na(x$member) & x$member > 0 & !is.na(x$mn_all), ]
  if (!nrow(x)) return(NULL)
  x$key <- paste(x$state, x$sy_end, x$subject, sep = "|")
  keys <- unique(x$key)
  by_q <- function(qq) {
    y <- x[x$q == qq, ]
    f <- factor(y$key, levels = keys)          # a key with no district in this quintile gives NA
    sw <- as.vector(tapply(y$member, f, sum))
    list(score = as.vector(tapply(y$member * y$mn_all, f, sum)) / sw,
         se = sqrt(as.vector(tapply(y$member^2 * y$se_all^2, f, sum))) / sw,
         districts = as.vector(table(f)))
  }
  lo <- by_q(1L); hi <- by_q(5L)
  first <- x[match(keys, x$key), c("state", "sy_end", "subject")]
  y <- data.frame(first, value = hi$score - lo$score, se = sqrt(hi$se^2 + lo$se^2),
                  mean_q5 = hi$score, mean_q1 = lo$score, districts_q5 = hi$districts, districts_q1 = lo$districts,
                  stringsAsFactors = FALSE)
  y <- y[y$districts_q1 > 0 & y$districts_q5 > 0, ]
  if (!nrow(y)) return(NULL)
  w <- seda_subject_wide(y, c("state", "sy_end"), c("mean_q5", "mean_q1", "districts_q5", "districts_q1"))
  cbind(gap = rep("a_poverty", nrow(w)), w, stringsAsFactors = FALSE)
}

# CCD grade codes as numbers: PK -1, KG 0, 01-12 as 1-12; UG (ungraded), N (no students)
# and anything else NA.
ccd_grade_num <- function(x) {
  x <- toupper(trimws(x))
  out <- suppressWarnings(as.numeric(x))
  out[!grepl("^[0-9]{1,2}$", x)] <- NA_real_
  out[x == "PK"] <- -1
  out[x == "KG"] <- 0
  out
}

# TRUE when the grade span GSLO-GSHI includes a grade from lo to hi. A span with an
# ungraded or missing end is FALSE.
span_overlaps <- function(gslo, gshi, lo = min(SEDA_GRADES), hi = max(SEDA_GRADES)) {
  a <- ccd_grade_num(gslo); b <- ccd_grade_num(gshi)
  !is.na(a) & !is.na(b) & a <= hi & b >= lo
}

# District retention reason for SEDA districts (Section 5: Run 1 rules 1, 2, 6 and 7).
# rule12 is district_rules()'s result (NA for a district in no CCD file of the rules
# window, which fails rule 2), pov_rate the SAIPE 2009 rate, group the state's group in
# one event set.
SEDA_NO_SAIPE <- "no SAIPE 2009 poverty rate"
seda_reason <- function(rule12, pov_rate, group) {
  r <- ifelse(is.na(rule12), "rule 2: not operational in every window year", rule12)
  ifelse(r != "pass", r,
         ifelse(is.na(pov_rate), SEDA_NO_SAIPE,
                ifelse(group == "excluded", "rule 6: state excluded (reform in 2005-2009)", "retained")))
}

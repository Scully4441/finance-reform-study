# Run 2 step 14 helpers (docs/design_extension.md, Sections 7, 8, 10 and 12): the estimation
# panels of the SEDA gaps and of the extended high school panel, their controls and weights,
# the Run 2 robustness variants and splits, the block rule for HonestDiD, and the gap (a)
# revenue panels of the dose scaling. Used by R/14_run_all_run2.R, which runs Run 1's steps
# 5-7 and step 10 through the existing functions (primary.R, secondary.R, inference.R,
# run_all.R) on these panels.
#
# Author decisions 2026-09-16 (docs/deviations_run2.md):
#   Source indicator (extended high school panel, Section 7). The Callaway-Sant'Anna models take
#   rc_first, a fixed unit covariate = 1 when the unit's first year in the model panel is a
#   report-card year; it enters only when it varies within the panel (a constant covariate is
#   collinear with the intercept) and the panel counts record whether it entered. The regression
#   estimators take the year-varying indicator rc (1 in report-card years) as a control; report-card
#   rows are exactly the end years 2022-2025, so the year fixed effects absorb it and fixest notes
#   it as collinear.
#   SEDA controls (regression estimators). CEP by district-year (the phase-in table before 2014, the
#   district's CCD status 2014-2024, 2025 carrying 2024's value) and, for gaps (b) and (c), the four
#   2009 covariates by year; gap (a) takes the CEP share of its quintile 1 and 5 districts retained
#   under the event set, with 2009-10 membership above 0 and a pooled all-students mean in both
#   subjects that year. No test-replacement flag (Section 5: rule 5 does not apply to SEDA).
#   High school controls: test_replaced and cep (Run 1), and rc.
#   SEDA tested-count weight (gaps (b) and (c)). SEDA's tot_asmt of the gap's two groups in end year
#   2010 (2009-10), summed over grades 3-8, mean of math and RLA (both required), fixed; like Run 1's
#   weight it attaches to a district with an outcome row in 2010, and the others leave the weighted
#   models only.
#   Variants and splits. Run 1's robustness variants apply to the high school panel; for SEDA the
#   suppression samples and the end-years-2013-on variant do not (Section 5 replaces rules 3 and 4
#   with SEDA's own screens). The Section 10 splits run as variants (Callaway-Sant'Anna, all three
#   event sets, both weightings, the variants' inference): SEDA 2009-2019 alone and 2022-2025 alone;
#   the high school panel on the EDFacts years alone (the extended panel with the report-card years
#   is the primary model); the seventeen confirmed states only, every year of the panel. A shortened
#   window codes cohorts over its own years (Run 1 rule: a state treated in its first year cannot
#   enter).
#   Block rule. Every bound set with Run 1's status "event times are not consecutive around the
#   reference period" is computed on the reduced event-time block at once (honest_block(), Run 1's
#   post-freeze inference correction of 2026-09-15), not in a later pass.
#   Dose scaling, gap (a). The revenue gap is step 13's gap (a) treatment before binning
#   (quintile_revenue_gap()): quintile 5 minus quintile 1 membership-weighted revenue per pupil over a
#   district set fixed across fiscal years, retained under the event set.

RUN2_FAMILIES <- c("seda", "hs")
RUN2_GAPS <- c("a_poverty", "b_black_white", "c_hispanic_white")
RUN2_WINDOWS <- list(seda = c(2009:2019, 2022:2025),            # = SEDA_WINDOW (seda.R)
                     hs = c(2010:2019, 2021:2025))              # = c(ACH_WINDOW, HS_RC_WINDOW)
RUN2_EDFACTS_YEARS <- c(2010:2019, 2021L)                       # the Run 1 window
RUN2_RC_FROM <- 2022L                                           # first report-card end year
RUN2_WEIGHT_YEAR <- 2010L                                       # the fixed tested-count weight's year (2009-10)
RUN2_SOURCE_COV <- "rc_first"
RUN2_HS_CONTROLS <- c("test_replaced", "cep", "rc")
RUN2_SEDA_CONTROLS <- "cep"
RUN2_BOOT_REPS <- 9999L                                         # Section 8
RUN2_RI_REPS <- 10000L                                          # Section 8: the step 5 models of each family
# Section 4: the seventeen states confirmed from the file description.
RUN2_CONFIRMED_STATES <- c("AL", "CA", "CO", "CT", "DE", "GA", "KS", "MA", "MI", "MO", "NC", "NV", "NY", "OR",
                           "RI", "TX", "WA")
# honest_rm()'s status for a model whose estimated event times have a hole around the reference period
HONEST_NOT_CONSEC <- "event times are not consecutive around the reference period"

# The Run 2 variants, one departure each from the primary specification of their family.
# years: the window years kept; from_year: end years from that year; states: the states kept.
RUN2_VARIANTS <- list(
  sample_r5               = list(families = "hs", sample = "r5", from_year = NULL, years = NULL, states = NULL,
                                 drop_few_pre = FALSE, anticipation = 0L, split = FALSE,
                                 label = "Ranges of 5 points or less (Run 1 Section 5 rule 3)"),
  sample_exact            = list(families = "hs", sample = "exact", from_year = NULL, years = NULL, states = NULL,
                                 drop_few_pre = FALSE, anticipation = 0L, split = FALSE,
                                 label = "Exact values only (Run 1 Section 5 rule 3)"),
  participation_from_2013 = list(families = "hs", sample = "primary", from_year = 2013L, years = NULL, states = NULL,
                                 drop_few_pre = FALSE, anticipation = 0L, split = FALSE,
                                 label = "End years 2013 on (Run 1 Section 5 rule 4; report-card years test participation where the state prints it)"),
  drop_few_pre            = list(families = c("seda", "hs"), sample = "primary", from_year = NULL, years = NULL, states = NULL,
                                 drop_few_pre = TRUE, anticipation = 0L, split = FALSE,
                                 label = "Cohorts with fewer than three pre-reform years dropped (Run 1 Section 5 rule 6)"),
  anticipation_1          = list(families = c("seda", "hs"), sample = "primary", from_year = NULL, years = NULL, states = NULL,
                                 drop_few_pre = FALSE, anticipation = 1L, split = FALSE,
                                 label = "Anticipation = 1, reference period -2 (Run 1 step 10)"),
  seda_2009_2019          = list(families = "seda", sample = "primary", from_year = NULL, years = 2009:2019, states = NULL,
                                 drop_few_pre = FALSE, anticipation = 0L, split = TRUE,
                                 label = "SEDA 2009-2019 alone (Section 10 span split)"),
  seda_2022_2025          = list(families = "seda", sample = "primary", from_year = NULL, years = 2022:2025, states = NULL,
                                 drop_few_pre = FALSE, anticipation = 0L, split = TRUE,
                                 label = "SEDA 2022-2025 alone (Section 10 span split)"),
  hs_edfacts_years        = list(families = "hs", sample = "primary", from_year = NULL, years = c(2010:2019, 2021L), states = NULL,
                                 drop_few_pre = FALSE, anticipation = 0L, split = TRUE,
                                 label = "EDFacts years alone, 2010-2021 (Section 10 source split; Run 1's window)"),
  hs_17_states            = list(families = "hs", sample = "primary", from_year = NULL, years = NULL, states = RUN2_CONFIRMED_STATES,
                                 drop_few_pre = FALSE, anticipation = 0L, split = TRUE,
                                 label = "The seventeen confirmed states only, every year (Section 10 coverage split)"))
run2_variants_for <- function(family, split = NULL) {
  v <- names(RUN2_VARIANTS)[vapply(RUN2_VARIANTS, function(x) family %in% x$families, TRUE)]
  if (is.null(split)) v else v[vapply(RUN2_VARIANTS[v], function(x) identical(x$split, split), TRUE)]
}

run2_weightings <- function(gap) if (gap == "a_poverty") "unweighted" else c("unweighted", "tested_weighted")

# ---- SEDA extras: tested counts and all-students availability -------------------------------------

# The SEDA long file columns step 11 does not carry: tot_asmt of White, Black and Hispanic students
# and whether the all-students mean can enter a grade pool (mean and a positive unadjusted standard
# error, as seda_pool()). Units outside the 50 states and DC are dropped, as in step 11.
read_seda_run2_extras <- function(path = seda_long_file()) {
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

# The fixed SEDA weight of each district and gap (author decision above): tot_asmt of the gap's two
# groups in `year`, summed over the grades that report it (NA when no grade does), mean of math and
# RLA, both required and positive. Returns leaid, b_black_white, c_hispanic_white.
seda_tested_weights <- function(ex, year = RUN2_WEIGHT_YEAR) {
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

# District-years whose pooled all-students mean exists in both subjects: leaid, sy_end.
seda_all_both <- function(ex) {
  a <- unique(ex[ex$has_all, c("leaid", "sy_end", "subject")])
  m <- a[a$subject == "math", c("leaid", "sy_end")]; r <- a[a$subject == "rla", c("leaid", "sy_end")]
  out <- merge(m, r, by = c("leaid", "sy_end"))
  out[order(out$leaid, out$sy_end), , drop = FALSE]
}

# SEDA gap (a) districts with the retained flag of every event set: seda_gap_a_districts() (the
# primary set, as step 13 rebuilds it) with retained_r1 and retained_r2 from the same rules and the
# robustness event tables' groups.
run2_seda_districts <- function(seda_leaids) {
  d <- seda_gap_a_districts(seda_leaids)
  for (s in c("r1", "r2")) {
    ev <- utils::read.csv(file.path("data", "reference", EVENT_FILES[[s]]), stringsAsFactors = FALSE)
    d[[RETAIN_FLAGS[[s]]]] <- as.integer(seda_reason(d$rule12, d$saipe_pov_rate_2009, ev$group[match(d$state, ev$state)]) == "retained")
  }
  d
}

# High school gap (a) districts (Run 1's sample file) with the retained flag of every event set and
# 2009-10 membership: one row per district.
run2_hs_gap_a_districts <- function(path = "data/derived/sample_district_year.csv") {
  s <- data.table::fread(path, select = c("leaid", "state", "retained", "retained_r1", "retained_r2", "pov_quintile_2009"),
                         colClasses = c(leaid = "character"), data.table = FALSE, showProgress = FALSE)
  d <- unique(s)
  if (anyDuplicated(d$leaid)) stop(basename(path), ": a retained flag or quintile differs within a district")
  td <- tempfile("ccd"); dir.create(td)
  l09 <- read_ccd_lea(utils::unzip("data/raw/ccd/lea-directory-sy2009-10.zip", exdir = td), 2010L, extra = "MEMBER")
  d$member_2009 <- ccd_count(l09$member)[match(d$leaid, l09$leaid)]
  d
}

# ---- inputs -------------------------------------------------------------------------------------

# The gap rows and 2009-10 covariates of one family. seda: data/derived/seda_gaps.csv (one row per gap
# and unit-year) and the SEDA weights; hs: data/derived/hs_gaps_run2.csv (one row per gap, unit-year,
# subject and suppression sample). cov: CS_COVARIATES per district; weights (seda only): as
# seda_tested_weights().
run2_load_inputs <- function(family, seda_weights = NULL) {
  rd <- function(f, ...) data.table::fread(f, colClasses = c(leaid = "character"), data.table = FALSE, showProgress = FALSE,
                                           na.strings = "", ...)
  if (family == "seda") {
    g <- rd("data/derived/seda_gaps.csv", select = c("gap", "state", "leaid", "sy_end", "retained", "retained_r1", "retained_r2", "v"))
    saipe <- read_saipe("data/raw/saipe/saipe-district-2009.txt")
    smp <- data.frame(leaid = saipe$leaid, sy_end = 2010L, saipe_pov_rate_2009 = saipe$pov_rate, stringsAsFactors = FALSE)
  } else if (family == "hs") {
    g <- rd("data/derived/hs_gaps_run2.csv", select = c("gap", "state", "leaid", "sy_end", "subject", "sample", "source",
                                                         "retained", "retained_r1", "retained_r2", "v", "n_group", "n_wh"))
    smp <- rd("data/derived/sample_district_year.csv", select = c("leaid", "sy_end", "saipe_pov_rate_2009"))
  } else stop("unknown family ", family)
  stopifnot(all(g$sy_end %in% RUN2_WINDOWS[[family]]))
  race <- g[g$gap != "a_poverty", , drop = FALSE]
  list(family = family, window = RUN2_WINDOWS[[family]], race = race, pov = g[g$gap == "a_poverty", , drop = FALSE],
       cov = cs_covariates(race$leaid, smp, 2010L), weights = seda_weights)
}

# ---- panels ---------------------------------------------------------------------------------------

# Unit-year outcome rows of one gap under one event-set flag and suppression sample, over the family
# window: the unit column (leaid, or state for gap (a)), state, sy_end, y; rc (high school: 1 in
# report-card years); tested_2010 for gaps (b) and (c), the fixed weight, NA for a district without
# an outcome row in RUN2_WEIGHT_YEAR. High school: the mean of math and RLA V, both required (Run 1).
run2_outcome_rows <- function(inp, gap, flag, sample = "primary") {
  unit <- if (gap == "a_poverty") "state" else "leaid"
  x <- if (gap == "a_poverty") inp$pov else inp$race[inp$race$gap == gap, , drop = FALSE]
  if (inp$family == "seda") {
    if (sample != "primary") stop("SEDA has no suppression samples (extension design Section 10)")
    x <- x[x[[flag]] %in% 1L & !is.na(x$v) & x$sy_end %in% inp$window, , drop = FALSE]
    stopifnot(!anyDuplicated(x[c(unit, "sy_end")]))
    out <- data.frame(x[unique(c(unit, "state"))], sy_end = x$sy_end, y = x$v, stringsAsFactors = FALSE)
    if (gap != "a_poverty") {
      w <- if (is.null(inp$weights)) rep(NA_real_, nrow(out)) else inp$weights[[gap]][match(out$leaid, inp$weights$leaid)]
      out$tested <- ifelse(out$sy_end == RUN2_WEIGHT_YEAR, w, NA_real_)
    }
  } else {
    x <- x[x$sample == sample & x[[flag]] %in% 1L & !is.na(x$v), , drop = FALSE]
    x$rc <- as.integer(x$source == "report_card")
    x$tested <- x$n_group + x$n_wh
    out <- both_subjects(x, unit, "v", inp$window, carry = c("rc", if (gap != "a_poverty") "tested"), balanced = FALSE)
  }
  if (gap != "a_poverty") {
    w <- out$tested[out$sy_end == RUN2_WEIGHT_YEAR]
    out$tested_2010 <- w[match(out$leaid, out$leaid[out$sy_end == RUN2_WEIGHT_YEAR])]
    out$tested <- NULL
  }
  out <- out[order(out[[unit]], out$sy_end), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# The estimation panel of one model, built as step 5 builds Run 1's (cs_model_panel()), with a
# variant's changes: years (window years kept), from_year, states (states kept), balanced (every kept
# window year), drop_few_pre. Cohorts are coded over the kept years. High school: rc_first enters the
# covariate formula when it varies within the final panel. events: an event table in place of the
# file (tests). Returns the panel, unit, covariate formula, weight column, counts, the kept years and
# the source covariate's status (NA for SEDA).
run2_model_panel <- function(inp, gap, set, sample = "primary", balanced = FALSE, from_year = NULL, years = NULL,
                             states = NULL, drop_few_pre = FALSE, weighting = "unweighted", events = NULL) {
  unit <- if (gap == "a_poverty") "state" else "leaid"
  p <- run2_outcome_rows(inp, gap, RETAIN_FLAGS[[set]], sample)
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
    if (length(unique(p$rc_first)) > 1L) {
      covs <- c(covs, RUN2_SOURCE_COV); src <- "entered"
    } else src <- "not entered: constant in this panel"
  }
  rownames(p) <- NULL
  list(panel = p, unit = unit, xformla = if (length(covs)) stats::reformulate(covs) else ~1,
       weightsname = if (weighting == "tested_weighted") "tested_2010" else NULL,
       units = length(unique(p$id)), states = length(unique(p$state)), states_dropped_few_pre = as.integer(n_few),
       window = cw, source_covariate = src)
}

# ---- controls of the regression estimators ----------------------------------------------------------

# The district-year and state-year controls of one family (author decisions above).
# hs: rows of data/derived/hs_panel_run2.csv (leaid, state, sy_end, the retained flags,
# pov_quintile_2009, test_replaced, cep and the all-students cells) with member_2009.
# seda: cep for district-years (leaid, state, sy_end) and the gap (a) CEP shares per event set.
run2_hs_controls <- function(rows) list(family = "hs", rows = rows)

run2_seda_controls <- function(race, dist, all_both, cep_fun = cep_indicator) {
  q <- dist[dist$in_quintile_set & dist$pov_quintile_2009 %in% c(1L, 5L) & !is.na(dist$member_2009) & dist$member_2009 > 0, , drop = FALSE]
  qa <- all_both[all_both$leaid %in% q$leaid & all_both$sy_end %in% RUN2_WINDOWS$seda, , drop = FALSE]
  qa$state <- q$state[match(qa$leaid, q$leaid)]
  dy <- unique(rbind(race[!is.na(race$leaid), c("leaid", "state", "sy_end")], qa[c("leaid", "state", "sy_end")]))
  dy$cep <- cep_fun(dy$leaid, dy$state, pmin(dy$sy_end, max(CDID_F33_YEARS)))   # 2025 carries 2024 (no CCD file)
  cep_a <- lapply(stats::setNames(names(RETAIN_FLAGS), names(RETAIN_FLAGS)), function(s) {
    x <- qa[qa$leaid %in% q$leaid[q[[RETAIN_FLAGS[[s]]]] %in% 1L], , drop = FALSE]
    x$cep <- dy$cep[match(paste(x$leaid, x$sy_end), paste(dy$leaid, dy$sy_end))]
    if (!nrow(x)) return(data.frame(state = character(), sy_end = integer(), cep = numeric()))
    stats::aggregate(list(cep = x$cep), list(state = x$state, sy_end = x$sy_end), mean)
  })
  list(family = "seda", cep = dy, cep_a = cep_a)
}

# Attach the controls to a model panel. Returns the panel and the control names.
run2_attach_controls <- function(ctrl, panel, gap, set) {
  if (ctrl$family == "seda") {
    if (gap == "a_poverty") {
      a <- ctrl$cep_a[[set]]
      k <- match(paste(panel$state, panel$sy_end), paste(a$state, a$sy_end))
      if (anyNA(k)) stop("state-years without a CEP share: ", sum(is.na(k)))
      panel$cep <- a$cep[k]
    } else panel <- attach_district_flags(panel, ctrl$cep, "cep")
    return(list(panel = panel, controls = RUN2_SEDA_CONTROLS))
  }
  if (gap == "a_poverty") {
    panel <- attach_flags(panel, gap_a_flags(ctrl$rows, RETAIN_FLAGS[[set]], sort(unique(panel$sy_end)), "primary"))
  } else panel <- attach_district_flags(panel, ctrl$rows, c("test_replaced", "cep"))
  list(panel = panel, controls = RUN2_HS_CONTROLS)
}

# ---- HonestDiD block rule -----------------------------------------------------------------------------

# honest: named list of honest_rm() tables; infs: the matching cs_influence() results; refs: the
# reference period of each. Every table carrying HONEST_NOT_CONSEC is replaced by honest_block() on
# the model's influence function, one model per worker under the caller's future plan; every table
# gains event_block and event_block_note (NA where the rule did not apply).
run2_block_rule <- function(honest, infs, refs, mbarvec = MBAR_GRID) {
  ks <- names(honest)
  aff <- ks[vapply(ks, function(k) any(honest[[k]]$status %in% HONEST_NOT_CONSEC) && !is.null(infs[[k]]), TRUE)]
  if (length(aff)) {
    jobs <- lapply(aff, function(k) list(inf = infs[[k]], ref = as.integer(refs[[k]])))
    one <- function(j, mbarvec) suppressWarnings(honest_block(j$inf, mbarvec, ref = j$ref))
    environment(one) <- globalenv()      # the workers are sent the job, not this frame
    honest[aff] <- furrr::future_map(jobs, one, mbarvec = mbarvec, .options = furrr::furrr_options(seed = NULL))
  }
  lapply(honest, function(h) {
    if (!"event_block" %in% names(h)) { h$event_block <- rep(NA_character_, nrow(h)); h$event_block_note <- rep(NA_character_, nrow(h)) }
    h
  })
}

# ---- dose scaling: gap (a) revenue ----------------------------------------------------------------------

# Gap (a) revenue panel under one event set (author decision above): d, one row per district (leaid,
# state, pov_quintile_2009, member_2009 and the retained flags); rev: leaid, sy_end, rev_pp_real,
# excluded; years: the fiscal years; base: the gap's outcome panel (state, g). Returns state, sy_end,
# y (quintile 5 minus quintile 1 revenue per pupil), g, id.
run2_gap_a_revenue_panel <- function(d, flag, rev, years, base) {
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

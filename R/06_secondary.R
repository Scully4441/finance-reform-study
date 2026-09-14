# Step 6. Secondary estimators (design document, Section 7).
# Run from the repository folder:
#   Rscript R/06_secondary.R                        the achievement gaps
#   Rscript R/06_secondary.R --outcome graduation   the secondary graduation gaps
#
# Graduation pass (design v18, Section 6; R/functions/graduation.R): the same estimators
# on the step 5 graduation panels (outputs/05_primary/graduation/panel_counts.csv),
# end years 2011-2021, for all three event sets. Controls in the regression estimators:
# cep, district-year, plus the four 2009 covariates interacted with year; the
# test-replacement flag is an assessment flag and does not enter (author decision
# 2026-09-12). Outputs in outputs/06_secondary/graduation/ under the file names below.
#
# Inputs: those of step 5 (R/05_primary.R), plus the state-year test-replacement and
# CEP flags (test_replaced, cep) in data/derived/sample_district_year.csv.
# Panels: the step 5 panels: primary suppression sample; mean of math and RLA V, both
# required; gaps (b) and (c) with all four 2009 covariates; states treated in the first
# window year left out; states treated after the window are controls (g = 0). The script
# stops if a panel's size differs from the matching row of outputs/05_primary/panel_counts.csv.
# Panel rule (author, 2026-09-13; docs/deviations.md, Section 7): the estimators run on
# the step 5 unbalanced panel, the one the primary Callaway-Sant'Anna models use, and the
# results go to the main files. The balanced panel held 69 districts in 9 states for gap
# (b) and 35 in 12 for gap (c) at the full window, too few for the Section 13 agreement
# table. The balanced-panel versions of every estimator are written to appendix/ (below).
# synthdid stays at the state level and needs a rectangular state-by-year matrix: on the
# unbalanced panel its state-year means are taken over the panel's districts and the
# states with a mean in every window year enter (run_sdid(complete_states = TRUE)); the
# states left out are counted in the notes and in panel_counts.csv.
# Event sets: all three (event_table.csv, _r1, _r2) for both outcomes. The achievement pass
# ran the primary set alone until step 10 (2026-09-13), which asked for all three.
# Estimators (R/functions/secondary.R), all unweighted (Section 7: the weighted
# robustness check is a did model, step 5):
#   sun_abraham   fixest, the sunab cohort-by-period indicators with never-treated
#                 states as the comparison group and reference period -1. The
#                 indicators are built in sa_terms() rather than by calling
#                 fixest::sunab(), which in fixest 0.14.2 drops a cohort whose treated
#                 units supply a single pre-treatment observation (gap (a), where a
#                 cohort is one state). See R/functions/secondary.R.
#   imputation    didimputation (Borusyak, Jaravel and Spiess)
#   synthdid      synthdid, state level, cohort by cohort, placebo standard errors
#   stacked       fixest, sub-experiments over event times -5..+5, clean controls,
#                 corrective weights
#   twfe          two-way fixed effects event study, for comparison only
#   twfe_static   two-way fixed effects with one post-reform indicator, overall row only
# Controls (regression estimators): test_replaced and cep for every gap; for gaps (b)
# and (c) also the four 2009 covariates interacted with year. synthdid: none.
# Author decisions 2026-09-11 (docs/decision_log.md): controls, synthdid design,
# stacked window, and the overall post-reform average (equal-weight mean of event
# times 0..+8, as step 5).
# Outputs (outputs/06_secondary/, graduation in outputs/06_secondary/graduation/): the
# step 5 files with an estimator column first, so the Section 13 agreement table can bind
# them to step 5's. Every output row carries the `panel` column step 5 writes: `unbalanced`
# in the main files; the same files with `balanced` rows in outputs/06_secondary/appendix/
# (graduation: outputs/06_secondary/appendix/graduation/).
#   event_time_estimates.csv  one row per estimator (not twfe_static), gap and event time
#                             -5..+8, with the cohorts, treated states and treated units
#                             behind each coefficient
#   overall_estimates.csv     the overall post-reform average per estimator and gap
#   group_time_estimates.csv  cohort-by-period estimates (Sun-Abraham, imputation, synthdid)
#   model_status.csv          status and the packages' warnings and messages per model
#   panel_counts.csv          units, states, cohorts and observations in each model
#   synthdid_pooled.csv       synthdid's pooled ATT (cohorts weighted by treated state-years)
#   secondary_models.rds      the fitted models, for step 7
#   outputs/logs/06_secondary_<stamp>.log
# Blinding (CLAUDE.md rule 7): the console shows panel sizes only. Everything that
# depends on treatment years goes to the files and the log.

for (f in list.files("R/functions", full.names = TRUE)) source(f)

OUTCOME <- outcome_arg()
stage <- as.integer(readLines("data/stage.txt", n = 1, warn = FALSE))
SAMPLE <- "primary"    # suppression sample, as step 5
FLAGS      <- c(primary = "retained", r1 = "retained_r1", r2 = "retained_r2")
# The step 5 panel rules, in run order, and where each pass writes (see the header).
PANEL_DIRS <- c(unbalanced = "", balanced = "appendix")
if (OUTCOME == "achievement") {
  if (!identical(stage, 2L)) stop("the achievement pass reads the full window, which needs stage 2")
  WINDOW <- ACH_WINDOW   # end years 2010-2019 and 2021 (design Section 3)
  # all three event sets, as the graduation pass (step 10 instruction, 2026-09-13)
  EVENT_SETS <- c(primary = "event_table.csv", r1 = "event_table_r1.csv", r2 = "event_table_r2.csv")
  GAPS <- c("a_poverty", "b_black_white", "c_hispanic_white")
  CONTROLS <- SEC_FLAGS
} else {
  if (!identical(stage, 2L)) stop("the graduation pass needs stage 2 (graduation files after 2012-13)")
  WINDOW <- GRAD_WINDOW
  EVENT_SETS <- c(primary = "event_table.csv", r1 = "event_table_r1.csv", r2 = "event_table_r2.csv")
  GAPS <- names(GRAD_GAPS)
  CONTROLS <- GRAD_SEC_FLAGS
}
ESTIMATORS <- c("sun_abraham", "imputation", "synthdid", "stacked", "twfe", "twfe_static")

stamp   <- format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ")
out_dir_for <- function(pan) do.call(file.path, as.list(c("outputs/06_secondary",
  if (nzchar(PANEL_DIRS[[pan]])) PANEL_DIRS[[pan]], if (OUTCOME == "graduation") "graduation")))
out_dir <- out_dir_for("unbalanced")
for (pan in names(PANEL_DIRS)) dir.create(out_dir_for(pan), recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/logs", recursive = TRUE, showWarnings = FALSE)
log_file <- file.path("outputs", "logs", paste0(if (OUTCOME == "achievement") "06_secondary_" else "06_secondary_graduation_", stamp, ".log"))
say <- function(...) {                      # console and log
  txt <- paste0(...)
  cat(txt, "\n", sep = "")
  cat(txt, "\n", sep = "", file = log_file, append = TRUE)
}
note <- function(...) cat(paste0(...), "\n", sep = "", file = log_file, append = TRUE)   # log only
note_df <- function(x) note(paste(utils::capture.output(print(x, row.names = FALSE)), collapse = "\n"))

say("Step 6 secondary estimators (", OUTCOME, "), run ", stamp, "; stage ", stage, "; blinding ",
    readLines("data/reference/blinding_status.txt", n = 1, warn = FALSE), "; fixest ", utils::packageVersion("fixest"),
    ", didimputation ", utils::packageVersion("didimputation"), ", synthdid ", utils::packageVersion("synthdid"))
say("Console: panel sizes only. Cohort counts, estimates and model status: ", out_dir, " (unbalanced), ",
    out_dir_for("balanced"), " (balanced, appendix) and ", log_file)

# ---- inputs ----------------------------------------------------------------------
if (OUTCOME == "achievement") {
  race <- utils::read.csv("data/derived/gaps_race_district_year.csv", colClasses = c(leaid = "character"),
                          stringsAsFactors = FALSE, na.strings = "")
  pov  <- utils::read.csv("data/derived/gap_poverty_state_year.csv", stringsAsFactors = FALSE, na.strings = "")
  stopifnot(all(race$sy_end %in% WINDOW), all(pov$sy_end %in% WINDOW),
            SAMPLE %in% race$sample, SAMPLE %in% pov$sample)
  cell_cols <- as.vector(outer(c("cell_", "w_", "part_ok_"), paste0(names(SUBJECTS), "_all"), paste0))
  smp <- data.table::fread("data/derived/sample_district_year.csv",
                           select = c("leaid", "state", "sy_end", "retained", "retained_r1", "retained_r2",
                                      "saipe_pov_rate_2009", "pov_quintile_2009", SEC_FLAGS, cell_cols),
                           colClasses = c(leaid = "character"), data.table = FALSE, showProgress = FALSE)
  cov <- cs_covariates(race$leaid, smp, min(WINDOW))
  # CEP is district-year from 2014 (author decision 2026-09-12): gaps (b) and (c) take the
  # flags by district-year; gap (a) takes gap_a_flags() per event set, with the 2009-10
  # membership that decides which districts enter gap (a).
  td09 <- tempfile("ccd"); dir.create(td09)
  m09 <- read_ccd_lea(utils::unzip("data/raw/ccd/lea-directory-sy2009-10.zip", exdir = td09), 2010L, extra = "MEMBER")
  smp$member_2009 <- ccd_count(m09$member)[match(smp$leaid, m09$leaid)]
  dflags <- smp[c("leaid", "sy_end", SEC_FLAGS)]
  say("Covariates for the ", nrow(cov), " districts in the gap (b)/(c) file; district-year flags: ", nrow(dflags),
      " district-years (", paste(SEC_FLAGS, collapse = ", "), "); gap (a): state-year test_replaced and CEP share")
} else {
  race <- utils::read.csv("data/derived/gaps_graduation_district_year.csv", colClasses = c(leaid = "character"),
                          stringsAsFactors = FALSE, na.strings = "")
  stopifnot(all(race$sy_end %in% WINDOW), SAMPLE %in% race$sample)
  cov <- cs_covariates(race$leaid, graduation_saipe(race$leaid), 2010L)
  dflags <- data.table::fread("data/derived/graduation_sample_district_year.csv",
                              select = c("leaid", "sy_end", GRAD_SEC_FLAGS), colClasses = c(leaid = "character"),
                              data.table = FALSE, showProgress = FALSE)
  say("Covariates for the ", nrow(cov), " districts in the graduation gap file; district-year flags: ",
      nrow(dflags), " district-years (", paste(GRAD_SEC_FLAGS, collapse = ", "), ")")
}
pc5_file <- file.path(if (OUTCOME == "achievement") "outputs/05_primary" else "outputs/05_primary/graduation",
                      "panel_counts.csv")
pc5 <- if (file.exists(pc5_file)) utils::read.csv(pc5_file, stringsAsFactors = FALSE) else NULL
if (is.null(pc5)) say("No step 5 panel counts found; the panels are not checked against step 5.")

# ---- models ----------------------------------------------------------------------
for (pan in names(PANEL_DIRS)) {
res <- list()
pan_dir <- out_dir_for(pan)
bal <- pan == "balanced"
say("\n== Panels (the step 5 ", pan, " panels", if (bal) ", appendix" else "", "), primary suppression sample, ", OUTCOME)
for (set in names(EVENT_SETS)) {
  flag <- FLAGS[[set]]
  ev <- utils::read.csv(file.path("data", "reference", EVENT_SETS[[set]]), stringsAsFactors = FALSE)
  coding <- cohort_coding(ev, WINDOW)
  for (gap in GAPS) {
    if (gap == "a_poverty") {
      unit <- "state"
      p <- pov_panel(pov, flag, WINDOW, SAMPLE, balanced = bal)
      covs <- character()
    } else if (OUTCOME == "graduation") {
      unit <- "leaid"
      p <- grad_panel(race, GRAD_GAPS[[gap]], flag, WINDOW, SAMPLE, balanced = bal)
      p <- cbind(p, cov[match(p$leaid, cov$leaid), CS_COVARIATES])
      p <- p[stats::complete.cases(p[CS_COVARIATES]), ]
      covs <- CS_COVARIATES
    } else {
      unit <- "leaid"
      p <- race_panel(race, if (gap == "b_black_white") "bw" else "hw", flag, WINDOW, SAMPLE, balanced = bal)
      p <- cbind(p, cov[match(p$leaid, cov$leaid), CS_COVARIATES])
      p <- p[stats::complete.cases(p[CS_COVARIATES]), ]
      covs <- CS_COVARIATES
    }
    ac <- attach_cohorts(p, coding, unit)
    stopifnot(ac$dropped[["excluded"]] == 0L)
    p <- if (OUTCOME == "graduation") attach_district_flags(ac$panel, dflags)
         else if (gap == "a_poverty") attach_flags(ac$panel, gap_a_flags(smp, flag, WINDOW, SAMPLE))
         else attach_district_flags(ac$panel, dflags, SEC_FLAGS)
    n_units <- length(unique(p$id))
    if (!is.null(pc5)) {
      n5 <- pc5$units_in_model[pc5$gap == gap & pc5$event_set == set & pc5$panel == pan]
      if (length(n5) == 1L && n5 != n_units)
        stop(gap, " (", set, "): ", n_units, " units against ", n5,
             " in the step 5 ", pan, " panel; the panels must match")
    }
    say(sprintf("%-19s %-7s %-10s %5d %s in %2d states", gap, set, pan, n_units,
                if (unit == "state") "states   " else "districts", length(unique(p$state))))
    label <- if (unit == "state") "state" else "district"
    tw <- run_twfe(p, CONTROLS, covs, WINDOW)
    fits <- list(sun_abraham = run_sunab(p, CONTROLS, covs, WINDOW),
                 imputation  = run_imputation(p, CONTROLS, covs, WINDOW),
                 # the balanced pass keeps the seed steps of the earlier balanced-only runs
                 synthdid    = run_sdid(p, seed_step = paste0(if (OUTCOME == "achievement") "06_secondary synthdid "
                                                              else "06_secondary graduation synthdid ", gap, " ", set,
                                                              if (bal) "" else " unbalanced"),
                                        complete_states = !bal),
                 stacked     = run_stacked(p, CONTROLS, covs),
                 twfe        = tw$dynamic,
                 twfe_static = tw$static)
    stopifnot(identical(names(fits), ESTIMATORS))
    for (est in ESTIMATORS)
      res[[paste(est, gap, set, sep = ".")]] <- c(list(estimator = est, gap = gap, event_set = set,
                                                      weighting = "unweighted", panel = pan,
                                                      unit = if (est == "synthdid") "state" else label),
                                                 fits[[est]])
  }
}

# ---- outputs ---------------------------------------------------------------------
keys <- data.frame(estimator = character(), gap = character(), event_set = character(), weighting = character(),
                   panel = character(), stringsAsFactors = FALSE)
tag <- function(r, x) if (!is.null(x) && nrow(x))
  data.frame(estimator = r$estimator, gap = r$gap, event_set = r$event_set, weighting = r$weighting,
             panel = r$panel, x, stringsAsFactors = FALSE)
stack <- function(part, template) {
  x <- do.call(rbind, lapply(res, function(r) tag(r, r[[part]])))
  if (is.null(x)) x <- cbind(keys, template[0, , drop = FALSE])
  rownames(x) <- NULL
  x
}
event   <- stack("event", event_template())
overall <- stack("overall", overall_template())
cells   <- stack("cells", empty_cells())
pooled  <- stack("pooled", data.frame(att = numeric(), se = numeric(), ci_lo = numeric(), ci_hi = numeric(),
                                      cohorts = integer(), treated_states = integer()))
status  <- do.call(rbind, lapply(res, function(r)
  data.frame(estimator = r$estimator, gap = r$gap, event_set = r$event_set, weighting = r$weighting,
             panel = r$panel, status = r$status, notes = paste(r$notes, collapse = " | "),
             stringsAsFactors = FALSE)))
rownames(status) <- NULL
pc <- do.call(rbind, lapply(res, function(r) if (!is.null(r$size))
  data.frame(estimator = r$estimator, gap = r$gap, event_set = r$event_set, panel = r$panel,
             unit = r$unit, r$size, stringsAsFactors = FALSE)))
rownames(pc) <- NULL

files <- c(event_time_estimates = "event", overall_estimates = "overall", group_time_estimates = "cells",
           model_status = "status", panel_counts = "pc", synthdid_pooled = "pooled")
for (fn in names(files))
  utils::write.csv(get(files[[fn]]), file.path(pan_dir, paste0(fn, ".csv")), row.names = FALSE, na = "")
saveRDS(lapply(res, `[[`, "fit"), file.path(pan_dir, "secondary_models.rds"))

note("\n== ", pan, " panel: units, states, cohorts and observations in each model (", pan_dir, "/panel_counts.csv)")
note_df(pc)
for (key in names(res)) {
  r <- res[[key]]
  note("\n== ", key, " (", pan, "): ", r$status)
  if (length(r$notes)) note("notes: ", paste(r$notes, collapse = " | "))
  if (!is.null(r$event))
    note_df(r$event[c("e", "att", "se", "ci_lo", "ci_hi", "cohorts", "treated_states", "treated_units")])
  note("overall post-reform average:"); note_df(r$overall)
  if (!is.null(r$pooled)) { note("synthdid pooled ATT:"); note_df(r$pooled) }
}

n_err <- sum(startsWith(status$status, "error"))
say("\nWrote ", paste0(pan_dir, "/", c(paste0(names(files), ".csv"), "secondary_models.rds"), collapse = ", "))
say(nrow(status), " ", OUTCOME, " models on the ", pan, " panel (", length(ESTIMATORS), " estimators, ", length(GAPS),
    " gaps, ", length(EVENT_SETS), " event set(s)); models that stopped with an error: ", n_err,
    ". Status per model: ", file.path(pan_dir, "model_status.csv"))
}
say("Log: ", log_file)

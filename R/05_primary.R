# Step 5. Primary estimator: Callaway-Sant'Anna (design document, Section 7).
# Run from the repository folder:
#   Rscript R/05_primary.R                          the achievement gaps (a), (b), (c)
#   Rscript R/05_primary.R --outcome graduation     the secondary graduation gaps
#
# Graduation pass (design v18, Section 6; R/functions/graduation.R): the same estimator,
# panel rules, covariates and event sets on data/derived/gaps_graduation_district_year.csv
# (R/04g_graduation_outcomes.R), end years 2011-2021. Models grad_black_white and
# grad_hispanic_white, unweighted and weighted by the 2010-11 cohort count in the gap's
# two groups (cohort_2011; author decision 2026-09-12): 24 models, written to
# outputs/05_primary/graduation/ under the file names below.
#
# Inputs
#   data/derived/gaps_race_district_year.csv   R/04_outcomes.R: gaps (b) and (c)
#   data/derived/gap_poverty_state_year.csv    R/04_outcomes.R: gap (a)
#   data/derived/sample_district_year.csv      R/03_sample.R: SAIPE 2009 child-poverty rate
#   data/raw/ccd/lea-directory-sy2009-10.zip   2009-10 CCD membership (enrollment covariate)
#   data/raw/ccd/membership-sy2009-10.zip      2009-10 CCD school membership by race
#   data/reference/event_table.csv (primary), event_table_r1.csv, event_table_r2.csv (robustness)
# Models, primary suppression sample, each on all three event sets and on both panel
# rules (unbalanced, the primary rule; balanced, the robustness rule):
#   a_poverty         state-year gap (a); no covariates; unweighted
#   b_black_white     district-year gap (b); unweighted (primary) and tested-count weighted
#   c_hispanic_white  district-year gap (c); unweighted (primary) and tested-count weighted
# Estimator (R/functions/primary.R, run_cs()): did::att_gt with not-yet-treated
# controls, the doubly robust estimator, a universal base period (event time -1 is
# the reference) and state clusters through did's multiplier bootstrap (did defaults:
# 1,000 draws, uniform bands); did::aggte dynamic aggregation over event times -5 to
# +8, and its overall post-reform average (the mean of the event-time estimates from
# 0 on). Inference for the study is step 7.
# Panel rule (author decision 2026-09-11, replacing the balanced-panel rule of the same
# day): the primary models keep every unit-year with both subjects and run did with
# allow_unbalanced_panel = TRUE; the balanced panel, where a unit needs the outcome in
# every window year, is the robustness model. Both run on all three event sets and both
# weightings, so the `panel` column of every output names which rule a row came from and
# the model key is gap.event_set.weighting.panel. On the unbalanced panel a district
# without a first-window-year row has no fixed tested-count weight and is left out of the
# weighted models alone (dropped_missing_weight in panel_counts.csv).
# Other author decisions 2026-09-11 (docs/decision_log.md): outcome = mean of math and
# RLA V, both required; covariates for (b) and (c) = log 2009-10 CCD membership, SAIPE
# 2009 child-poverty rate, Black and Hispanic shares of 2009-10 membership; none for (a);
# test-replacement and CEP flags not in the CS models; weight = 2009-10 tested count in
# the gap's two groups, averaged over subjects.
# Cohorts: a state treated after the last window year has no post-period in the
# window and is a not-yet-treated control (g = 0); a state treated in the first window
# year has no pre-period and cannot enter. Both are counted in panel_counts.csv.
# Outputs (outputs/05_primary/)
#   event_time_estimates.csv  one row per model and event time -5..+8, with the cohorts,
#                             treated states and treated units behind each coefficient
#   overall_estimates.csv     the overall post-reform average per model
#   group_time_estimates.csv  did's ATT(g, t) cells
#   model_status.csv          status and did's warnings and messages per model
#   panel_counts.csv          units and states entering each model, by panel rule, sample
#                             rule and cohort status
#   cs_models.rds             the att_gt and aggte objects, for step 7
#   outputs/logs/05_primary_<stamp>.log
# Blinding (CLAUDE.md rule 7): the console shows panel sizes only. Everything that
# depends on treatment years (cohort status, cohort counts, estimates, model status)
# goes to the files and the log.

for (f in list.files("R/functions", full.names = TRUE)) source(f)

OUTCOME <- outcome_arg()
stage <- as.integer(readLines("data/stage.txt", n = 1, warn = FALSE))
if (OUTCOME == "achievement") {
  if (!identical(stage, 2L)) stop("the achievement pass reads the full window, which needs stage 2")
  WINDOW <- ACH_WINDOW   # end years 2010-2019 and 2021 (design Section 3)
  GAPS   <- c("a_poverty", "b_black_white", "c_hispanic_white")
  WCOL   <- "tested_2010"
} else {
  if (!identical(stage, 2L)) stop("the graduation pass needs stage 2 (graduation files after 2012-13)")
  WINDOW <- GRAD_WINDOW
  GAPS   <- names(GRAD_GAPS)
  WCOL   <- GRAD_WEIGHT
}
SAMPLE <- "primary"    # suppression sample (MAX_WIDTH); r5 and exact are robustness samples
EVENT_SETS <- c(primary = "event_table.csv", r1 = "event_table_r1.csv", r2 = "event_table_r2.csv")
FLAGS      <- c(primary = "retained", r1 = "retained_r1", r2 = "retained_r2")
STATUS_LEVELS <- c("estimable", "after_window", "never", "first_year", "excluded")

stamp   <- format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ")
out_dir <- if (OUTCOME == "achievement") "outputs/05_primary" else "outputs/05_primary/graduation"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/logs", recursive = TRUE, showWarnings = FALSE)
log_file <- file.path("outputs", "logs", paste0(if (OUTCOME == "achievement") "05_primary_" else "05_primary_graduation_", stamp, ".log"))
say <- function(...) {                      # console and log
  txt <- paste0(...)
  cat(txt, "\n", sep = "")
  cat(txt, "\n", sep = "", file = log_file, append = TRUE)
}
note <- function(...) cat(paste0(...), "\n", sep = "", file = log_file, append = TRUE)   # log only
note_df <- function(x) note(paste(utils::capture.output(print(x, row.names = FALSE)), collapse = "\n"))

say("Step 5 primary estimator (", OUTCOME, "), run ", stamp, "; stage ", stage, "; blinding ",
    readLines("data/reference/blinding_status.txt", n = 1, warn = FALSE), "; did ", utils::packageVersion("did"))
say("Console: panel sizes only. Cohort counts, estimates and model status: ", out_dir, " and ", log_file)

# ---- inputs ----------------------------------------------------------------------
if (OUTCOME == "achievement") {
  race <- utils::read.csv("data/derived/gaps_race_district_year.csv", colClasses = c(leaid = "character"),
                          stringsAsFactors = FALSE, na.strings = "")
  pov  <- utils::read.csv("data/derived/gap_poverty_state_year.csv", stringsAsFactors = FALSE, na.strings = "")
  stopifnot(all(race$sy_end %in% WINDOW), all(pov$sy_end %in% WINDOW),
            SAMPLE %in% race$sample, SAMPLE %in% pov$sample)
  smp <- data.table::fread("data/derived/sample_district_year.csv", select = c("leaid", "sy_end", "saipe_pov_rate_2009"),
                           colClasses = c(leaid = "character"), data.table = FALSE, showProgress = FALSE)
} else {
  race <- utils::read.csv("data/derived/gaps_graduation_district_year.csv", colClasses = c(leaid = "character"),
                          stringsAsFactors = FALSE, na.strings = "")
  stopifnot(all(race$sy_end %in% WINDOW), SAMPLE %in% race$sample)
  smp <- graduation_saipe(race$leaid)
}

# Covariates for the district gaps, all fixed at 2009-10 (author decisions 2026-09-11;
# the same four for the graduation gaps).
cov <- cs_covariates(race$leaid, smp, 2010L)
say("Covariates for the ", nrow(cov), " districts in the district gap file; missing: ",
    paste(CS_COVARIATES, colSums(is.na(cov[CS_COVARIATES])), collapse = ", "))

# ---- models ----------------------------------------------------------------------
XF <- stats::reformulate(CS_COVARIATES)
res <- list(); counts <- list()
say("\n== Panels (", if (OUTCOME == "achievement") "both subjects; gaps (b) and (c)" else "graduation gaps",
    " with all covariates), primary suppression",
    " sample, end years ", min(WINDOW), "-", max(WINDOW))
say("   unbalanced = the primary rule (any window year); balanced = the robustness rule",
    " (every window year)")
for (set in names(EVENT_SETS)) {
  flag <- FLAGS[[set]]
  ev <- utils::read.csv(file.path("data", "reference", EVENT_SETS[[set]]), stringsAsFactors = FALSE)
  coding <- cohort_coding(ev, WINDOW)
  note("\n== Event set ", set, " (", EVENT_SETS[[set]], "): states by cohort status")
  note_df(as.data.frame(table(cohort_status = factor(coding$cohort_status, levels = STATUS_LEVELS)),
                        responseName = "states"))
  for (gap in GAPS) {
    for (pan in names(PANEL_TYPES)) {
      bal <- !PANEL_TYPES[[pan]]                 # PANEL_TYPES holds allow_unbalanced_panel
      if (gap == "a_poverty") {
        unit <- "state"
        n_any <- length(unique(pov$state[pov$sample == SAMPLE & pov[[flag]] == 1L & !is.na(pov$v_pov)]))
        p <- pov_panel(pov, flag, WINDOW, SAMPLE, balanced = bal)
        n_panel <- length(unique(p$state)); n_nocov <- 0L
        xf <- ~1; weightings <- "unweighted"
      } else {
        unit <- "leaid"
        rg <- if (OUTCOME == "graduation") GRAD_GAPS[[gap]] else if (gap == "b_black_white") "bw" else "hw"
        v <- paste0("v_", rg)
        n_any <- length(unique(race$leaid[race$sample == SAMPLE & race[[flag]] == 1L & !is.na(race[[v]])]))
        p <- if (OUTCOME == "graduation") grad_panel(race, rg, flag, WINDOW, SAMPLE, balanced = bal) else
          race_panel(race, rg, flag, WINDOW, SAMPLE, balanced = bal)
        n_panel <- length(unique(p$leaid))
        p <- cbind(p, cov[match(p$leaid, cov$leaid), CS_COVARIATES])
        miss <- !stats::complete.cases(p[CS_COVARIATES])
        n_nocov <- length(unique(p$leaid[miss]))
        p <- p[!miss, ]
        xf <- XF; weightings <- c("unweighted", "tested_weighted")
      }
      say(sprintf("%-19s %-7s %-10s %5d %s in %2d states", gap, set, pan, length(unique(p[[unit]])),
                  if (unit == "state") "states   " else "districts", length(unique(p$state))))
      ac <- attach_cohorts(p, coding, unit)
      stopifnot(ac$dropped[["excluded"]] == 0L)    # rule 6 exclusions never reach the gap files
      p <- ac$panel
      # The tested-count weight (graduation: the cohort count) is fixed at the first
      # window year, so a unit without a first-window-year row cannot carry one and is
      # left out of the weighted models alone (author decisions 2026-09-11 and
      # 2026-09-12). On the balanced panel there are none.
      n_now <- 0L
      if (WCOL %in% names(p)) n_now <- length(unique(p[[unit]][is.na(p[[WCOL]])]))
      for (wt in weightings) {
        key <- paste(gap, set, wt, pan, sep = ".")
        pw <- if (wt == "tested_weighted" && n_now > 0L) p[!is.na(p[[WCOL]]), ] else p
        fit <- run_cs(pw, xformla = xf, weightsname = if (wt == "tested_weighted") WCOL else NULL,
                      seed_step = if (OUTCOME == "achievement") paste("05_primary", key) else
                        paste("05_primary graduation", key),
                      allow_unbalanced_panel = PANEL_TYPES[[pan]])
        res[[key]] <- c(list(gap = gap, event_set = set, weighting = wt, panel = pan), fit)
      }
      by_status <- function(x) {
        n <- tapply(x, factor(p$cohort_status, levels = STATUS_LEVELS[1:3]), function(z) length(unique(z)))
        n[is.na(n)] <- 0L
        n
      }
      us <- by_status(p[[unit]]); ss <- by_status(p$state)
      counts[[paste(gap, set, pan)]] <- data.frame(
        gap = gap, event_set = set, panel = pan, unit = if (unit == "state") "state" else "district",
        units_with_outcome = n_any, units_in_panel = n_panel, dropped_missing_covariates = n_nocov,
        dropped_first_year_state = as.integer(ac$dropped[["first_year"]]),
        units_in_model = length(unique(p$id)), states_in_model = length(unique(p$state)),
        dropped_missing_weight = as.integer(n_now), unit_years = nrow(p),
        unit_years_per_unit = nrow(p) / length(unique(p$id)),
        units_estimable = as.integer(us[["estimable"]]), units_after_window = as.integer(us[["after_window"]]),
        units_never = as.integer(us[["never"]]), states_estimable = as.integer(ss[["estimable"]]),
        states_after_window = as.integer(ss[["after_window"]]), states_never = as.integer(ss[["never"]]),
        stringsAsFactors = FALSE)
    }
  }
}

# ---- outputs ---------------------------------------------------------------------
tag <- function(r, x) if (nrow(x)) data.frame(gap = r$gap, event_set = r$event_set, weighting = r$weighting,
                                              panel = r$panel, x, stringsAsFactors = FALSE)
stack <- function(part) {
  x <- do.call(rbind, lapply(res, function(r) tag(r, r[[part]])))
  if (is.null(x)) x <- tag(list(gap = NA, event_set = NA, weighting = NA, panel = NA),
                           res[[1]][[part]][0, ])
  rownames(x) <- NULL
  x
}
event   <- stack("event")
overall <- stack("overall")
cells   <- stack("cells")
status  <- do.call(rbind, lapply(res, function(r)
  data.frame(gap = r$gap, event_set = r$event_set, weighting = r$weighting, panel = r$panel,
             status = r$status, notes = paste(r$notes, collapse = " | "), stringsAsFactors = FALSE)))
rownames(status) <- NULL
pc <- do.call(rbind, counts); rownames(pc) <- NULL

files <- c(event_time_estimates = "event", overall_estimates = "overall", group_time_estimates = "cells",
           model_status = "status", panel_counts = "pc")
for (fn in names(files))
  utils::write.csv(get(files[[fn]]), file.path(out_dir, paste0(fn, ".csv")), row.names = FALSE, na = "")
saveRDS(lapply(res, `[[`, "fit"), file.path(out_dir, "cs_models.rds"))

note("\n== Units and states entering each model (panel_counts.csv)")
note_df(pc)
for (key in names(res)) {
  r <- res[[key]]
  note("\n== ", key, ": ", r$status)
  if (length(r$notes)) note("did: ", paste(r$notes, collapse = " | "))
  note_df(r$event[c("e", "att", "se", "ci_lo", "ci_hi", "cohorts", "treated_states", "treated_units")])
  note("overall post-reform average:"); note_df(r$overall)
}

n_err <- sum(startsWith(status$status, "error"))
say("\nWrote ", paste0(out_dir, "/", c(paste0(names(files), ".csv"), "cs_models.rds"), collapse = ", "))
say(nrow(status), " ", OUTCOME, " models (", length(EVENT_SETS), " event sets x ", length(PANEL_TYPES),
    " panel rules); models that stopped with an error: ", n_err,
    ". Status per model: ", file.path(out_dir, "model_status.csv"))
say("Log: ", log_file)

# Step 8. Power (design document, Section 10).
# Run from the repository folder:
#   Rscript R/08_power.R           the registered 2,000 placebo runs
#   Rscript R/08_power.R --quick   a reduced count, for a test run only
#
# Inputs
#   outputs/05_primary/cs_models.rds          R/05_primary.R: the att_gt and aggte fits
#   outputs/05_primary/overall_estimates.csv  cross-check on the fits
#   outputs/05_primary/panel_counts.csv       cross-check on the panels
# Section 10 computes power by simulation on the stage 1 assessment files (end years
# 2010-2013), before any outcome file for a later school year is downloaded. Placebo
# reform years are assigned to random states, the Callaway-Sant'Anna pipeline is rerun
# 2,000 times, and the spread of the placebo estimates gives the minimum detectable
# effect at 80 percent power and a 5 percent two-sided test for each primary gap. If the
# MDE exceeds 0.10 SD for every primary gap the study is registered as underpowered and
# proceeds only as a bounds analysis.
# Models: the three primary gaps on the primary event set, unweighted and on the primary
# suppression sample, which is what "primary gap" means everywhere else in the pipeline.
# Each runs on its own step 5 estimation panel (R/functions/inference.R, cs_panel()), so
# the placebo runs use exactly the panel, covariates and estimator settings of step 5.
# Author decisions 2026-09-11 (docs/decision_log.md, and R/functions/power.R): the
# placebo assignment is the reassignment Section 8 already fixes for randomization
# inference (treated states drawn from every state in the panel, given the observed
# cohort years, keeping the number of states per cohort year); the MDE is the exact
# inversion of the placebo distribution rather than a normal approximation, with the
# normal-approximation figure reported beside it.
# Every draw comes from seed_for("power") (CLAUDE.md rule 4), drawn in this process and
# then handed to the workers, so the result does not depend on how many workers run it.
# Outputs (outputs/08_power/)
#   mde.csv                minimum detectable effect per gap, with the placebo spread it
#                          comes from and the Section 10 underpowered verdict
#   placebo_draws.csv      every placebo estimate, so the MDE can be rebuilt
#   power_curve.csv        power against effect size per gap, on a grid through the MDE
#   model_status.csv       status and notes per gap
#   power_settings.csv     counts, seeds and versions of this run
#   outputs/logs/08_power_<stamp>.log
# Blinding (CLAUDE.md rule 7): no treatment year is printed. The placebo cohort years are
# reassigned inside R/functions/power.R and never leave it; the files carry counts of
# treated and eligible states, the placebo distribution and the MDE, none of which say
# which state reformed when.

for (f in list.files("R/functions", full.names = TRUE)) source(f)

stage <- as.integer(readLines("data/stage.txt", n = 1, warn = FALSE))
if (!identical(stage, 1L))
  stop("R/08_power.R is the Section 10 simulation on the stage 1 files (end years 2010-2013). ",
       "It is run before the registration, while data/stage.txt reads 1.")

GAPS       <- c("a_poverty", "b_black_white", "c_hispanic_white")
EVENT_SET  <- "primary"     # the primary event set (design Section 3)
WEIGHTING  <- "unweighted"  # the primary weighting for all three gaps (design Section 7)
WORKERS    <- 12L           # CLAUDE.md conventions: 14 cores, no forking
QUICK_REPS <- 200L
quick <- "--quick" %in% commandArgs(trailingOnly = TRUE)
reps  <- if (quick) QUICK_REPS else POWER_REPS

stamp   <- format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ")
out_dir <- "outputs/08_power"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/logs", recursive = TRUE, showWarnings = FALSE)
log_file <- file.path("outputs", "logs", paste0("08_power_", stamp, ".log"))
say <- function(...) {                      # console and log
  txt <- paste0(...)
  cat(txt, "\n", sep = "")
  cat(txt, "\n", sep = "", file = log_file, append = TRUE)
}
note <- function(...) cat(paste0(...), "\n", sep = "", file = log_file, append = TRUE)   # log only
note_df <- function(x) note(paste(utils::capture.output(print(x, row.names = FALSE)), collapse = "\n"))

say("Step 8 power, run ", stamp, "; stage ", stage, "; blinding ",
    readLines("data/reference/blinding_status.txt", n = 1, warn = FALSE),
    "; did ", utils::packageVersion("did"))
say("Placebo runs per gap: ", reps,
    if (quick) "  (--quick: a test run, not the registered count)" else "  (the registered count)")
say("Minimum detectable effect at ", POWER_TARGET * 100, "% power, ", (1 - POWER_LEVEL) * 100,
    "% two-sided test; Section 10 calls the study underpowered if every gap exceeds ",
    POWER_CEILING, " SD")

# ---- inputs --------------------------------------------------------------------------
rds <- file.path("outputs", "05_primary", "cs_models.rds")
if (!file.exists(rds)) stop("outputs/05_primary/cs_models.rds not found. Run R/05_primary.R first.")
models <- readRDS(rds)
ov5 <- utils::read.csv(file.path("outputs", "05_primary", "overall_estimates.csv"),
                       stringsAsFactors = FALSE, na.strings = "")
pc5 <- utils::read.csv(file.path("outputs", "05_primary", "panel_counts.csv"), stringsAsFactors = FALSE)

status <- data.frame(gap = GAPS, event_set = EVENT_SET, weighting = WEIGHTING, status = "ok",
                     notes = "", stringsAsFactors = FALSE)
panels <- list(); cohorts <- list()
say("\n== Step 5 panels the placebo runs are built on")
for (i in seq_along(GAPS)) {
  key <- paste(GAPS[i], EVENT_SET, WEIGHTING, sep = ".")
  fit <- models[[key]]
  if (is.null(fit)) { status$status[i] <- "no step 5 fit"; next }
  cp <- cs_panel(fit)
  gs <- panel_cohort_years(cp$panel)
  states <- sort(unique(cp$panel$state))
  if (!length(gs) || length(states) <= length(gs)) {
    status$status[i] <- "no placebo assignment possible"
    next
  }
  # The panel must be the one step 5 estimated on, and the fit the one it reported.
  k5 <- which(pc5$gap == GAPS[i] & pc5$event_set == EVENT_SET)
  o5 <- which(ov5$gap == GAPS[i] & ov5$event_set == EVENT_SET & ov5$weighting == WEIGHTING)
  stopifnot(length(k5) == 1L, length(o5) == 1L,
            length(unique(cp$panel$id)) == pc5$units_in_model[k5],
            length(states) == pc5$states_in_model[k5],
            abs(fit$aggte$overall.att - ov5$att[o5]) < 1e-10)
  panels[[GAPS[i]]] <- cp
  cohorts[[GAPS[i]]] <- gs
  say(sprintf("%-16s %5d %s in %2d states, %d treated at random per placebo run",
              GAPS[i], length(unique(cp$panel$id)),
              if (GAPS[i] == "a_poverty") "states   " else "districts", length(states), length(gs)))
}
say("Panels and estimates agree with outputs/05_primary/panel_counts.csv and overall_estimates.csv")

# ---- placebo assignments ---------------------------------------------------------------
# Drawn here, in the parent process, from the one seed Section 10 uses for this step.
set.seed(seed_for("power"))
picks <- list()
for (gap in GAPS) {
  if (is.null(panels[[gap]])) next
  picks[[gap]] <- placebo_state_draws(sort(unique(panels[[gap]]$panel$state)),
                                      length(cohorts[[gap]]), reps)
}

# ---- the placebo runs --------------------------------------------------------------------
say("\n== Placebo runs: ", reps, " per gap on ", WORKERS, " workers")
future::plan(future::multisession, workers = WORKERS)
on.exit(future::plan(future::sequential), add = TRUE)
draws <- list(); mde <- list(); curve <- list()
for (i in seq_along(GAPS)) {
  gap <- GAPS[i]
  if (is.null(panels[[gap]])) { say(sprintf("  %-16s skipped: %s", gap, status$status[i])); next }
  t0 <- Sys.time()
  v <- placebo_estimates(panels[[gap]], cohorts[[gap]], picks[[gap]], seed = seed_for("power"))
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  m <- mde_from_placebo(v)
  ok <- is.finite(v)
  states <- sort(unique(panels[[gap]]$panel$state))
  o5 <- which(ov5$gap == gap & ov5$event_set == EVENT_SET & ov5$weighting == WEIGHTING)
  mde[[gap]] <- data.frame(
    gap = gap, event_set = EVENT_SET, weighting = WEIGHTING,
    reps = as.integer(reps), draws_ok = as.integer(m$draws),
    treated_states = length(cohorts[[gap]]), eligible_states = length(states),
    placebo_mean = if (any(ok)) mean(v[ok]) else NA_real_,
    placebo_sd = if (m$draws > 1L) stats::sd(v[ok]) else NA_real_,
    placebo_q05 = if (any(ok)) unname(stats::quantile(v[ok], 0.05)) else NA_real_,
    placebo_q95 = if (any(ok)) unname(stats::quantile(v[ok], 0.95)) else NA_real_,
    level = POWER_LEVEL, power_target = POWER_TARGET, crit_value = m$crit,
    mde = m$mde, power_at_mde = m$power_at_mde, mde_normal = m$mde_normal,
    model_se = ov5$se[o5], mde_over_model_se = m$mde / ov5$se[o5],
    ceiling = POWER_CEILING, underpowered = as.integer(!is.finite(m$mde) | m$mde > POWER_CEILING),
    seconds = secs, stringsAsFactors = FALSE)
  draws[[gap]] <- data.frame(gap = gap, event_set = EVENT_SET, weighting = WEIGHTING,
                             draw = seq_along(v), att = v, stringsAsFactors = FALSE)
  # Power against effect size, on a grid running past the MDE.
  top <- if (is.finite(m$mde)) 1.5 * m$mde else 4 * m$crit
  d <- seq(0, top, length.out = 61)
  curve[[gap]] <- data.frame(gap = gap, event_set = EVENT_SET, weighting = WEIGHTING,
                             effect = d, power = power_at(v, m$crit, d), stringsAsFactors = FALSE)
  if (!any(ok)) status$status[i] <- "every placebo run failed"
  else if (sum(ok) < reps)
    status$notes[i] <- sprintf("%d of %d placebo runs had no estimable cell", reps - sum(ok), reps)
  if (!is.finite(m$mde))
    status$notes[i] <- trimws(paste(status$notes[i],
                                    "| no shift on the placebo draws reaches the power target"))
  say(sprintf("  %-16s %4d/%4d runs estimated, %5.1f s", gap, sum(ok), reps, secs))
}

# ---- outputs -----------------------------------------------------------------------------
bind <- function(x) { y <- do.call(rbind, x); if (!is.null(y)) rownames(y) <- NULL; y }
mt <- bind(mde); dt <- bind(draws); ct <- bind(curve)
status$notes <- trimws(sub("^\\| ", "", status$notes))

settings <- data.frame(
  setting = c("run", "stage", "blinding", "quick_run", "placebo_reps", "event_set", "weighting",
              "test_level", "power_target", "mde_ceiling", "seed_step", "master_seed", "workers",
              "r_version", "did", "future", "furrr"),
  value = c(stamp, stage, readLines("data/reference/blinding_status.txt", n = 1, warn = FALSE),
            tolower(as.character(quick)), reps, EVENT_SET, WEIGHTING, POWER_LEVEL, POWER_TARGET,
            POWER_CEILING, "power", MASTER_SEED, WORKERS, R.version.string,
            as.character(utils::packageVersion("did")), as.character(utils::packageVersion("future")),
            as.character(utils::packageVersion("furrr"))),
  stringsAsFactors = FALSE)

files <- list(mde = mt, placebo_draws = dt, power_curve = ct, model_status = status,
              power_settings = settings)
for (fn in names(files))
  utils::write.csv(files[[fn]], file.path(out_dir, paste0(fn, ".csv")), row.names = FALSE, na = "")

note("\n== settings"); note_df(settings)
note("\n== minimum detectable effect"); note_df(mt)
note("\n== placebo distribution, deciles")
if (!is.null(dt)) for (g in unique(dt$gap)) {
  v <- dt$att[dt$gap == g & is.finite(dt$att)]
  note(g, ": ", paste(sprintf("%.3f", stats::quantile(v, seq(0, 1, 0.1))), collapse = " "))
}
note("\n== power against effect size"); note_df(ct)
note("\n== model status"); note_df(status)

# The MDE is the product of this step and says nothing about which state reformed when,
# so it goes to the console as well as the files.
if (!is.null(mt)) {
  say("\n== Minimum detectable effect, ", POWER_TARGET * 100, "% power, ", (1 - POWER_LEVEL) * 100,
      "% two-sided test (V units, that is SD)")
  show <- data.frame(gap = mt$gap, placebo_sd = round(mt$placebo_sd, 4),
                     crit_value = round(mt$crit_value, 4), mde = round(mt$mde, 4),
                     mde_normal = round(mt$mde_normal, 4),
                     over_ceiling = ifelse(mt$underpowered == 1L, "yes", "no"),
                     stringsAsFactors = FALSE)
  say(paste(utils::capture.output(print(show, row.names = FALSE)), collapse = "\n"))
  under <- nrow(mt) == length(GAPS) && all(mt$underpowered == 1L)
  say("Section 10 verdict: the MDE exceeds ", POWER_CEILING, " SD for ", sum(mt$underpowered),
      " of ", nrow(mt), " primary gaps -> ",
      if (under) "UNDERPOWERED, the study proceeds as a bounds analysis"
      else "not underpowered on this criterion")
}

say("\nWrote ", paste0(out_dir, "/", names(files), ".csv", collapse = ", "))
if (quick) say("NOTE: --quick run. The registered count is ", POWER_REPS, " placebo runs per gap.")
say("Log: ", log_file)

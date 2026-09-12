# Step 8. Power (design document, Section 10).
# Run from the repository folder:
#   Rscript R/08_power.R           the registered 2,000 placebo runs
#   Rscript R/08_power.R --quick   a reduced count, for a test run only
#
# Inputs
#   outputs/05_primary/cs_models.rds          R/05_primary.R: the att_gt and aggte fits
#   outputs/05_primary/overall_estimates.csv  cross-check on the fits
#   outputs/05_primary/panel_counts.csv       cross-check on the panels
#   data/reference/event_table.csv            treated-state count and cohort years, for
#                                             the projection only (read, never edited)
# Section 10 computes power by simulation on the stage 1 assessment files (end years
# 2010-2013), before any outcome file for a later school year is downloaded. Placebo
# reform years are assigned to random states, the Callaway-Sant'Anna pipeline is rerun
# 2,000 times, and the spread of the placebo estimates gives the minimum detectable
# effect at 80 percent power and a 5 percent two-sided test for each primary gap. If the
# MDE exceeds 0.10 SD for every primary gap the study is registered as underpowered and
# proceeds only as a bounds analysis.
# Models: the three primary gaps on the primary event set, unweighted, on the primary
# suppression sample and on the primary (unbalanced) panel rule, which is what "primary
# gap" means everywhere else in the pipeline.
# Each runs on its own step 5 estimation panel (R/functions/inference.R, cs_panel()), so
# the placebo runs use exactly the panel, covariates and estimator settings of step 5.
# Three scenarios (author decisions 2026-09-11, docs/decision_log.md), each at 2,000 runs:
#   observed      the reassignment Section 8 fixes for randomization inference: the
#                 treated states are drawn from every state in the panel and given the
#                 observed cohort years, keeping the number of states per cohort year. In
#                 the stage 1 window that is two treated states, which is the pre-period's
#                 own cohort count and not the registered design's. Sensitivity only.
#                 Written to mde.csv; draws from seed_for("power").
#   six_state     SIX_STATES placebo-treated states, cohort years drawn uniformly from
#                 PLACEBO_YEARS. SIX_STATES is the treated states the event table carries
#                 with post-reform data by REG_END, the registration end year 2021, so this
#                 is the registered power calculation and the one the 0.10 SD rule of
#                 Section 10 is applied against (REGISTERED). Written to mde_6states.csv,
#                 with the projection columns; draws from seed_for("power_6").
#   ten_state     TEN_STATES placebo-treated states, cohort years drawn the same way.
#                 Sensitivity, and one of the two runs made while the end year was still
#                 assumed to be 2025. Written to mde_10states.csv, with the projection
#                 columns; draws from seed_for("power_10").
#   twelve_state  TWELVE_STATES placebo-treated states, cohort years drawn the same way.
#                 Twelve is the treated states the event table carries by 2025, so this was
#                 the registered calculation while 2025 was the assumed end year; with the
#                 end year fixed at 2021 it is a sensitivity run. Written to
#                 mde_12states.csv; draws from seed_for("power_12").
# All three draw in this process and hand the assignments to the workers (CLAUDE.md rule
# 4), so no result depends on how many workers run it.
# Outputs (outputs/08_power/)
#   mde.csv                 observed-cohort scenario: MDE per gap and the placebo spread
#   mde_6states.csv         six-state scenario (the registered one): the same, plus the
#                           projection columns
#   mde_10states.csv        ten-state scenario: the same columns
#   mde_12states.csv        twelve-state scenario: the same columns
#   placebo_draws.csv       every placebo estimate of the observed scenario
#   placebo_draws_6states.csv   every placebo estimate of the six-state scenario
#   placebo_draws_10states.csv  every placebo estimate of the ten-state scenario
#   placebo_draws_12states.csv  every placebo estimate of the twelve-state scenario
#   power_curve.csv         power against effect size per scenario and gap
#   model_status.csv        status and notes per scenario and gap
#   power_settings.csv      counts, seeds and versions of this run
#   outputs/logs/08_power_<stamp>.log
# Blinding (CLAUDE.md rule 7): no treatment year is printed. The placebo cohort years are
# reassigned inside R/functions/power.R and never leave it. The projection is the one
# quantity here that summarises the event table's years, so it goes to the files and the
# log but not to the console; the console carries counts, panel sizes, timings and the
# MDEs, none of which say which state reformed when.

for (f in list.files("R/functions", full.names = TRUE)) source(f)

stage <- as.integer(readLines("data/stage.txt", n = 1, warn = FALSE))
if (!identical(stage, 1L))
  stop("R/08_power.R is the Section 10 simulation on the stage 1 files (end years 2010-2013). ",
       "It is run before the registration, while data/stage.txt reads 1.")

GAPS       <- c("a_poverty", "b_black_white", "c_hispanic_white")
EVENT_SET  <- "primary"     # the primary event set (design Section 3)
WEIGHTING  <- "unweighted"  # the primary weighting for all three gaps (design Section 7)
PANEL      <- "unbalanced"  # the primary panel rule of step 5 (author, 2026-09-11)
WORKERS    <- 12L           # CLAUDE.md conventions: 14 cores, no forking
QUICK_REPS <- 200L
# Placebo-treated state counts (author, 2026-09-11). SIX_STATES is the treated states the
# event table carries with post-reform data by REG_END, the registration end year, and is
# the registered power calculation; TEN_STATES and TWELVE_STATES are the counts of the runs
# made while the end year was still assumed to be 2025, kept as sensitivity runs. The design
# block below checks the registered scenario's count against the event table.
SIX_STATES    <- 6L
TEN_STATES    <- 10L
TWELVE_STATES <- 12L
REGISTERED    <- "six_state"      # the scenario Section 10's 0.10 SD rule is applied to
PLACEBO_YEARS <- 2011:2013  # cohort years a stage 1 placebo can take: 2010 has no pre-period
REG_END    <- 2021L         # registration end year (author, 2026-09-11; decision log, Section 3)
REG_DROP   <- 2020L         # end years the design leaves out of the panel (no EDFacts file)

drawn_label <- function(n) sprintf("%d placebo-treated states, cohort years drawn uniformly from %d-%d",
                                   n, min(PLACEBO_YEARS), max(PLACEBO_YEARS))
SCENARIOS <- list(
  observed     = list(seed_step = "power",    mde_file = "mde",
                      draws_file = "placebo_draws", n_treated = NA_integer_, projection = FALSE,
                      label = "observed cohort count and observed cohort years"),
  six_state    = list(seed_step = "power_6",  mde_file = "mde_6states",
                      draws_file = "placebo_draws_6states", n_treated = SIX_STATES,
                      projection = TRUE, label = drawn_label(SIX_STATES)),
  ten_state    = list(seed_step = "power_10", mde_file = "mde_10states",
                      draws_file = "placebo_draws_10states", n_treated = TEN_STATES,
                      projection = TRUE, label = drawn_label(TEN_STATES)),
  twelve_state = list(seed_step = "power_12", mde_file = "mde_12states",
                      draws_file = "placebo_draws_12states", n_treated = TWELVE_STATES,
                      projection = TRUE, label = drawn_label(TWELVE_STATES)))
stopifnot(REGISTERED %in% names(SCENARIOS))
MAX_TREATED <- max(vapply(SCENARIOS, function(x) as.numeric(x$n_treated), numeric(1)), na.rm = TRUE)
DRAWN <- vapply(SCENARIOS, function(x) isTRUE(x$projection), TRUE)   # the drawn-year scenarios
DRAWN_COUNTS <- vapply(SCENARIOS[DRAWN], function(x) as.integer(x$n_treated), integer(1))

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
say("Placebo runs per gap and scenario: ", reps,
    if (quick) "  (--quick: a test run, not the registered count)" else "  (the registered count)")
say("Minimum detectable effect at ", POWER_TARGET * 100, "% power, ", (1 - POWER_LEVEL) * 100,
    "% two-sided test; Section 10 calls the study underpowered if every gap exceeds ",
    POWER_CEILING, " SD")
for (s in names(SCENARIOS))
  say(sprintf("  scenario %-12s %s -> %s.csv%s", s, SCENARIOS[[s]]$label, SCENARIOS[[s]]$mde_file,
              if (s == REGISTERED) "   (the registered power calculation)" else "   (sensitivity)"))

# ---- inputs ------------------------------------------------------------------------------
rds <- file.path("outputs", "05_primary", "cs_models.rds")
if (!file.exists(rds)) stop("outputs/05_primary/cs_models.rds not found. Run R/05_primary.R first.")
models <- readRDS(rds)
ov5 <- utils::read.csv(file.path("outputs", "05_primary", "overall_estimates.csv"),
                       stringsAsFactors = FALSE, na.strings = "")
pc5 <- utils::read.csv(file.path("outputs", "05_primary", "panel_counts.csv"), stringsAsFactors = FALSE)

panels <- list(); cohorts <- list(); usable <- character()
say("\n== Step 5 panels the placebo runs are built on")
for (gap in GAPS) {
  fit <- models[[paste(gap, EVENT_SET, WEIGHTING, PANEL, sep = ".")]]
  if (is.null(fit)) next
  cp <- cs_panel(fit)
  gs <- panel_cohort_years(cp$panel)
  states <- sort(unique(cp$panel$state))
  if (!length(gs) || length(states) <= max(length(gs), MAX_TREATED)) next
  # The panel must be the one step 5 estimated on, and the fit the one it reported.
  k5 <- which(pc5$gap == gap & pc5$event_set == EVENT_SET & pc5$panel == PANEL)
  o5 <- which(ov5$gap == gap & ov5$event_set == EVENT_SET & ov5$weighting == WEIGHTING &
                ov5$panel == PANEL)
  stopifnot(length(k5) == 1L, length(o5) == 1L,
            length(unique(cp$panel$id)) == pc5$units_in_model[k5],
            length(states) == pc5$states_in_model[k5],
            abs(fit$aggte$overall.att - ov5$att[o5]) < 1e-10)
  panels[[gap]] <- cp
  cohorts[[gap]] <- gs
  usable <- c(usable, gap)
  say(sprintf("%-16s %5d %s in %2d states, %s panel; %d treated per observed draw, %s in the drawn-year scenarios",
              gap, length(unique(cp$panel$id)),
              if (gap == "a_poverty") "states   " else "districts", length(states), PANEL,
              length(gs), paste(DRAWN_COUNTS, collapse = ", ")))
}
say("Panels and estimates agree with outputs/05_primary/panel_counts.csv and overall_estimates.csv")
win <- sort(unique(panels[[usable[1]]]$panel$sy_end))
stopifnot(all(vapply(usable, function(g) identical(sort(unique(panels[[g]]$panel$sy_end)), win), TRUE)))

# ---- the registered design, for the projection ---------------------------------------------
# Counts and cohort years of the treated states. The permutation that blinds the event
# table shuffles which state carries which year but keeps the group of each state and the
# multiset of years, so both the count and the mean post-period length below are the real
# ones. Neither is printed (CLAUDE.md rule 7); they go to the files and the log.
evt <- utils::read.csv(file.path("data", "reference", "event_table.csv"), stringsAsFactors = FALSE)
g_full <- evt$treat_year[evt$group == "treated" & !is.na(evt$treat_year)]
g_full <- g_full[g_full > min(win) & g_full <= REG_END]
full_post <- post_years(g_full, REG_END, REG_DROP)
design <- list(states = length(g_full), mean_post = mean(full_post), state_years = sum(full_post))
say("\n== Registered design, for the projection (end year ", REG_END, ", ", REG_DROP,
    " left out)")
say("Treated states with post-reform data by ", REG_END, ": ", design$states,
    "; the registered scenario simulates ", SCENARIOS[[REGISTERED]]$n_treated,
    if (design$states != SCENARIOS[[REGISTERED]]$n_treated)
      "  <- these differ, see the log and the report" else "  (they agree)")
if (design$states != SCENARIOS[[REGISTERED]]$n_treated)
  warning("The registered scenario (", REGISTERED, ") simulates ",
          SCENARIOS[[REGISTERED]]$n_treated, " placebo-treated states but the event table carries ",
          design$states, " treated states with post-reform data by ", REG_END, call. = FALSE)
note("Mean post-reform end years per treated state: ", round(design$mean_post, 4),
     "; design post-reform state-years: ", design$state_years)

# ---- placebo assignments ---------------------------------------------------------------------
# Drawn here, in the parent process, one seed per scenario.
picks <- list(); years <- list()
for (s in names(SCENARIOS)) {
  set.seed(seed_for(SCENARIOS[[s]]$seed_step))
  picks[[s]] <- list(); years[[s]] <- list()
  for (gap in usable) {
    states <- sort(unique(panels[[gap]]$panel$state))
    n_t <- SCENARIOS[[s]]$n_treated
    if (s == "observed") {
      picks[[s]][[gap]] <- placebo_state_draws(states, length(cohorts[[gap]]), reps)
      years[[s]][[gap]] <- cohorts[[gap]]           # one vector, reused by every draw
    } else {
      picks[[s]][[gap]] <- placebo_state_draws(states, n_t, reps)
      years[[s]][[gap]] <- placebo_year_draws(PLACEBO_YEARS, n_t, reps)
    }
  }
}

# ---- the placebo runs ----------------------------------------------------------------------
say("\n== Placebo runs: ", reps, " per gap and scenario on ", WORKERS, " workers")
future::plan(future::multisession, workers = WORKERS)
on.exit(future::plan(future::sequential), add = TRUE)
status <- list(); mde <- list(); draws <- list(); curve <- list()
for (s in names(SCENARIOS)) {
  sc <- SCENARIOS[[s]]
  for (gap in GAPS) {
    st <- data.frame(scenario = s, gap = gap, event_set = EVENT_SET, weighting = WEIGHTING,
                     panel = PANEL, status = "ok", notes = "", stringsAsFactors = FALSE)
    if (!gap %in% usable) {
      st$status <- "no placebo assignment possible"
      status[[paste(s, gap)]] <- st
      say(sprintf("  %-12s %-16s skipped: %s", s, gap, st$status))
      next
    }
    t0 <- Sys.time()
    v <- placebo_estimates(panels[[gap]], years[[s]][[gap]], picks[[s]][[gap]],
                           seed = seed_for(sc$seed_step))
    secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    m <- mde_from_placebo(v)
    ok <- is.finite(v)
    states <- sort(unique(panels[[gap]]$panel$state))
    o5 <- which(ov5$gap == gap & ov5$event_set == EVENT_SET & ov5$weighting == WEIGHTING &
                  ov5$panel == PANEL)
    stopifnot(length(o5) == 1L)
    n_t <- if (s == "observed") length(cohorts[[gap]]) else sc$n_treated
    row <- data.frame(
      scenario = s, gap = gap, event_set = EVENT_SET, weighting = WEIGHTING, panel = PANEL,
      reps = as.integer(reps), draws_ok = as.integer(m$draws),
      treated_states = as.integer(n_t), eligible_states = length(states),
      placebo_mean = if (any(ok)) mean(v[ok]) else NA_real_,
      placebo_sd = if (m$draws > 1L) stats::sd(v[ok]) else NA_real_,
      placebo_q05 = if (any(ok)) unname(stats::quantile(v[ok], 0.05)) else NA_real_,
      placebo_q95 = if (any(ok)) unname(stats::quantile(v[ok], 0.95)) else NA_real_,
      level = POWER_LEVEL, power_target = POWER_TARGET, crit_value = m$crit,
      mde = m$mde, power_at_mde = m$power_at_mde, mde_normal = m$mde_normal,
      model_se = ov5$se[o5], mde_over_model_se = m$mde / ov5$se[o5],
      ceiling = POWER_CEILING, underpowered = as.integer(!is.finite(m$mde) | m$mde > POWER_CEILING),
      seconds = secs, stringsAsFactors = FALSE)
    # The projection columns exist on every row so the scenarios bind into one table;
    # only the drawn-year scenarios fill them (PROJECTION_COLS, written to their files).
    row$placebo_post_state_years <- NA_real_
    row$design_treated_states <- NA_integer_
    row$design_mean_post_years <- NA_real_
    row$design_post_state_years <- NA_real_
    row$projection_scale <- NA_real_
    row$mde_projection <- NA_real_
    row$projection_basis <- NA_character_
    if (isTRUE(sc$projection)) {
      # Post-reform state-years the placebo runs actually bought, averaged over the draws.
      pl_sy <- mean(vapply(years[[s]][[gap]], function(y) sum(post_years(y, max(win))), numeric(1)))
      row$placebo_post_state_years <- pl_sy
      row$design_treated_states <- as.integer(design$states)
      row$design_mean_post_years <- design$mean_post
      row$design_post_state_years <- design$state_years
      row$projection_scale <- sqrt(pl_sy / design$state_years)
      row$mde_projection <- mde_projection(m$mde, pl_sy, design$state_years)
      row$projection_basis <- paste0(
        "supplementary projection, not a power calculation: this scenario's MDE times ",
        "sqrt(placebo post-reform state-years / design post-reform state-years), the design ",
        "side from data/reference/event_table.csv with the registration end year ", REG_END,
        " and ", REG_DROP, " left out. Holds the outcome variance, the control-state count and ",
        "the panel's unit count fixed, none of which the registered window holds fixed.")
    }
    mde[[paste(s, gap)]] <- row
    draws[[paste(s, gap)]] <- data.frame(scenario = s, gap = gap, event_set = EVENT_SET,
                                         weighting = WEIGHTING, panel = PANEL,
                                         draw = seq_along(v), att = v, stringsAsFactors = FALSE)
    top <- if (is.finite(m$mde)) 1.5 * m$mde else 4 * m$crit
    d <- seq(0, top, length.out = 61)
    curve[[paste(s, gap)]] <- data.frame(scenario = s, gap = gap, event_set = EVENT_SET,
                                         weighting = WEIGHTING, panel = PANEL, effect = d,
                                         power = power_at(v, m$crit, d), stringsAsFactors = FALSE)
    if (!any(ok)) st$status <- "every placebo run failed"
    else if (sum(ok) < reps)
      st$notes <- sprintf("%d of %d placebo runs had no estimable cell", reps - sum(ok), reps)
    if (!is.finite(m$mde))
      st$notes <- trimws(paste(st$notes, "| no shift on the placebo draws reaches the power target"))
    st$notes <- trimws(sub("^\\| ", "", st$notes))
    status[[paste(s, gap)]] <- st
    say(sprintf("  %-12s %-16s %4d/%4d runs estimated, %6.1f s", s, gap, sum(ok), reps, secs))
  }
}

# ---- outputs -------------------------------------------------------------------------------
bind <- function(x) { y <- do.call(rbind, x); if (!is.null(y)) rownames(y) <- NULL; y }
mt <- bind(mde); dt <- bind(draws); ct <- bind(curve); stt <- bind(status)

settings <- data.frame(
  setting = c("run", "stage", "blinding", "quick_run", "placebo_reps", "event_set", "weighting",
              "panel", "test_level", "power_target", "mde_ceiling", "registered_scenario",
              "seed_step_observed", "seed_step_six_state", "seed_step_ten_state",
              "seed_step_twelve_state", "six_state_count", "ten_state_count",
              "twelve_state_count", "placebo_cohort_years",
              "projection_end_year",
              "projection_dropped_years", "master_seed", "workers", "r_version", "did", "future",
              "furrr"),
  value = c(stamp, stage, readLines("data/reference/blinding_status.txt", n = 1, warn = FALSE),
            tolower(as.character(quick)), reps, EVENT_SET, WEIGHTING, PANEL, POWER_LEVEL,
            POWER_TARGET, POWER_CEILING, REGISTERED, SCENARIOS$observed$seed_step,
            SCENARIOS$six_state$seed_step, SCENARIOS$ten_state$seed_step,
            SCENARIOS$twelve_state$seed_step, SIX_STATES, TEN_STATES, TWELVE_STATES,
            paste0(min(PLACEBO_YEARS), "-", max(PLACEBO_YEARS)), REG_END, REG_DROP,
            MASTER_SEED, WORKERS, R.version.string,
            as.character(utils::packageVersion("did")), as.character(utils::packageVersion("future")),
            as.character(utils::packageVersion("furrr"))),
  stringsAsFactors = FALSE)

wr <- function(x, fn) utils::write.csv(x, file.path(out_dir, paste0(fn, ".csv")), row.names = FALSE, na = "")
PROJECTION_COLS <- c("placebo_post_state_years", "design_treated_states", "design_mean_post_years",
                     "design_post_state_years", "projection_scale", "mde_projection",
                     "projection_basis")
written <- character()
for (s in names(SCENARIOS)) {
  sc <- SCENARIOS[[s]]
  keep <- if (isTRUE(sc$projection)) names(mt) else setdiff(names(mt), PROJECTION_COLS)
  wr(mt[mt$scenario == s, keep, drop = FALSE], sc$mde_file)
  wr(dt[dt$scenario == s, ], sc$draws_file)
  written <- c(written, sc$mde_file, sc$draws_file)
}
wr(ct, "power_curve"); wr(stt, "model_status"); wr(settings, "power_settings")
written <- c(written, "power_curve", "model_status", "power_settings")

note("\n== settings"); note_df(settings)
for (s in names(SCENARIOS)) {
  note("\n== scenario ", s, ": ", SCENARIOS[[s]]$label)
  note_df(mt[mt$scenario == s, setdiff(names(mt), "projection_basis"), drop = FALSE])
}
note("\n== placebo distribution, deciles")
for (k in unique(paste(dt$scenario, dt$gap))) {
  v <- dt$att[paste(dt$scenario, dt$gap) == k & is.finite(dt$att)]
  note(k, ": ", paste(sprintf("%.3f", stats::quantile(v, seq(0, 1, 0.1))), collapse = " "))
}
note("\n== power against effect size"); note_df(ct)
note("\n== model status"); note_df(stt)

# The MDEs are the product of this step and say nothing about which state reformed when,
# so they go to the console. The projection does summarise the event table's cohort
# years, so it stays in the files and the log (CLAUDE.md rule 7).
say("\n== Minimum detectable effect, ", POWER_TARGET * 100, "% power, ", (1 - POWER_LEVEL) * 100,
    "% two-sided test (V units, that is SD)")
pick_col <- function(s, col) {
  x <- mt[mt$scenario == s, ]
  x[[col]][match(GAPS, x$gap)]
}
sbs <- data.frame(gap = GAPS,
                  mde_observed = round(pick_col("observed", "mde"), 4),
                  mde_six_state = round(pick_col("six_state", "mde"), 4),
                  mde_ten_state = round(pick_col("ten_state", "mde"), 4),
                  mde_twelve_state = round(pick_col("twelve_state", "mde"), 4),
                  ratio_reg_to_observed = round(pick_col(REGISTERED, "mde") /
                                                  pick_col("observed", "mde"), 3),
                  over_ceiling = ifelse(pick_col(REGISTERED, "underpowered") == 1L, "yes", "no"),
                  stringsAsFactors = FALSE)
say(paste(utils::capture.output(print(sbs, row.names = FALSE)), collapse = "\n"))
regr <- mt[mt$scenario == REGISTERED, ]
under <- nrow(regr) == length(GAPS) && all(regr$underpowered == 1L)
say("Section 10's ", POWER_CEILING, " SD rule is applied to the ", REGISTERED,
    " scenario (", SCENARIOS[[REGISTERED]]$n_treated,
    " placebo-treated states, the registered power calculation): it is exceeded for ",
    sum(regr$underpowered), " of ", nrow(regr), " primary gaps -> ",
    if (under) "UNDERPOWERED, the study proceeds as a bounds analysis"
    else "not underpowered on this criterion")
say("The ", paste(setdiff(names(SCENARIOS), REGISTERED), collapse = ", "),
    " runs are sensitivity runs and the rule is not applied to them; the ten- and twelve-state ",
    "runs were made while the end year was still assumed to be 2025.")
say("The projection columns of ",
    paste0(vapply(SCENARIOS[DRAWN], function(x) x$mde_file, character(1)), ".csv", collapse = ", "),
    " are supplementary and are not printed here: they summarise the event table's cohort years.")

say("\nWrote ", paste0(out_dir, "/", written, ".csv", collapse = ", "))
if (quick) say("NOTE: --quick run. The registered count is ", POWER_REPS, " placebo runs per gap.")
say("Log: ", log_file)

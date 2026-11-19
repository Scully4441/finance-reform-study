for (f in list.files("R/functions", full.names = TRUE)) source(f)

stage <- read_stage()
if (!identical(stage, 1L))
  stop("R/08_power.R is the power simulation on the stage 1 files (end years 2010-2013). ",
       "It is run before the registration, while data/stage.txt reads 1.")

GAPS       <- c("a_poverty", "b_black_white", "c_hispanic_white")
EVENT_SET  <- "primary"
WEIGHTING  <- "unweighted"
PANEL      <- "unbalanced"
WORKERS    <- 12L
QUICK_REPS <- 200L
SEED_STEP  <- "power"
PLACEBO_YEARS <- 2011:2013
FEDERAL_END <- max(ACH_WINDOW)

quick <- "--quick" %in% commandArgs(trailingOnly = TRUE)
reps  <- if (quick) QUICK_REPS else POWER_REPS

stamp   <- format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ")
out_dir <- "outputs/08_power"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/logs", recursive = TRUE, showWarnings = FALSE)
log_file <- file.path("outputs", "logs", paste0("08_power_", stamp, ".log"))
say <- function(...) {
  txt <- paste0(...)
  cat(txt, "\n", sep = "")
  cat(txt, "\n", sep = "", file = log_file, append = TRUE)
}
note <- function(...) cat(paste0(...), "\n", sep = "", file = log_file, append = TRUE)
note_df <- function(x) note(paste(utils::capture.output(print(x, row.names = FALSE)), collapse = "\n"))

say("Step 8 power, run ", stamp, "; stage ", stage, "; blinding ",
    readLines("data/reference/blinding_status.txt", n = 1, warn = FALSE),
    "; did ", utils::packageVersion("did"))
say("Placebo runs per gap: ", reps,
    if (quick) "  (--quick: a test run, not the registered count)" else "  (the registered count)")

rds <- file.path("outputs", "05_primary", "cs_models.rds")
if (!file.exists(rds)) stop("outputs/05_primary/cs_models.rds not found. Run R/05_primary.R first.")
models <- readRDS(rds)
ov5 <- utils::read.csv(file.path("outputs", "05_primary", "overall_estimates.csv"),
                       stringsAsFactors = FALSE, na.strings = "")
pc5 <- utils::read.csv(file.path("outputs", "05_primary", "panel_counts.csv"), stringsAsFactors = FALSE)

evt <- utils::read.csv(file.path("data", "reference", "event_table.csv"), stringsAsFactors = FALSE)
N_PLACEBO <- placebo_state_count(evt, min(ACH_WINDOW), FEDERAL_END)
if (N_PLACEBO < 1L) stop("the primary event table has no treated state with a post-reform year in the federal files")
say("Placebo-treated states per draw: ", N_PLACEBO, " (treated states of the primary event set with a post-reform year ",
    "in the federal files, end year ", FEDERAL_END, "); cohort years drawn uniformly from ", min(PLACEBO_YEARS), "-",
    max(PLACEBO_YEARS))
say("Minimum detectable effect at ", POWER_TARGET * 100, "% power, ", (1 - POWER_LEVEL) * 100,
    "% two-sided test; the study is registered as underpowered if any gap exceeds ", POWER_CEILING, " SD")

panels <- list(); usable <- character()
say("\n== Step 5 panels the placebo runs are built on")
for (gap in GAPS) {
  fit <- models[[paste(gap, EVENT_SET, WEIGHTING, PANEL, sep = ".")]]
  if (is.null(fit)) next
  cp <- cs_panel(fit)
  states <- sort(unique(cp$panel$state))
  if (length(states) <= N_PLACEBO) next
  k5 <- which(pc5$gap == gap & pc5$event_set == EVENT_SET & pc5$panel == PANEL)
  o5 <- which(ov5$gap == gap & ov5$event_set == EVENT_SET & ov5$weighting == WEIGHTING & ov5$panel == PANEL)
  stopifnot(length(k5) == 1L, length(o5) == 1L,
            length(unique(cp$panel$id)) == pc5$units_in_model[k5],
            length(states) == pc5$states_in_model[k5],
            abs(fit$aggte$overall.att - ov5$att[o5]) < 1e-10)
  panels[[gap]] <- cp
  usable <- c(usable, gap)
  say(sprintf("%-16s %5d %s in %2d states, %s panel", gap, length(unique(cp$panel$id)),
              if (gap == "a_poverty") "states   " else "districts", length(states), PANEL))
}
say("Panels and estimates agree with outputs/05_primary/panel_counts.csv and overall_estimates.csv")

set.seed(seed_for(SEED_STEP))
picks <- list(); years <- list()
for (gap in usable) {
  states <- sort(unique(panels[[gap]]$panel$state))
  picks[[gap]] <- placebo_state_draws(states, N_PLACEBO, reps)
  years[[gap]] <- placebo_year_draws(PLACEBO_YEARS, N_PLACEBO, reps)
}

say("\n== Placebo runs: ", reps, " per gap on ", WORKERS, " workers")
future::plan(future::multisession, workers = WORKERS)
on.exit(future::plan(future::sequential), add = TRUE)
status <- list(); mde <- list(); draws <- list(); curve <- list()
for (gap in GAPS) {
  st <- data.frame(gap = gap, event_set = EVENT_SET, weighting = WEIGHTING, panel = PANEL,
                   status = "ok", notes = "", stringsAsFactors = FALSE)
  if (!gap %in% usable) {
    st$status <- "no placebo assignment possible"
    status[[gap]] <- st
    say(sprintf("  %-16s skipped: %s", gap, st$status))
    next
  }
  t0 <- Sys.time()
  v <- placebo_estimates(panels[[gap]], years[[gap]], picks[[gap]], seed = seed_for(SEED_STEP))
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  m <- mde_from_placebo(v)
  ok <- is.finite(v)
  states <- sort(unique(panels[[gap]]$panel$state))
  o5 <- which(ov5$gap == gap & ov5$event_set == EVENT_SET & ov5$weighting == WEIGHTING & ov5$panel == PANEL)
  mde[[gap]] <- data.frame(
    gap = gap, event_set = EVENT_SET, weighting = WEIGHTING, panel = PANEL,
    reps = as.integer(reps), draws_ok = as.integer(m$draws),
    treated_states = as.integer(N_PLACEBO), eligible_states = length(states),
    placebo_mean = if (any(ok)) mean(v[ok]) else NA_real_,
    placebo_sd = if (m$draws > 1L) stats::sd(v[ok]) else NA_real_,
    placebo_q05 = if (any(ok)) unname(stats::quantile(v[ok], 0.05)) else NA_real_,
    placebo_q95 = if (any(ok)) unname(stats::quantile(v[ok], 0.95)) else NA_real_,
    level = POWER_LEVEL, power_target = POWER_TARGET, crit_value = m$crit,
    mde = m$mde, power_at_mde = m$power_at_mde, mde_normal = m$mde_normal,
    model_se = ov5$se[o5], mde_over_model_se = m$mde / ov5$se[o5],
    ceiling = POWER_CEILING, underpowered = as.integer(!is.finite(m$mde) | m$mde > POWER_CEILING),
    seconds = secs, stringsAsFactors = FALSE)
  draws[[gap]] <- data.frame(gap = gap, event_set = EVENT_SET, weighting = WEIGHTING, panel = PANEL,
                             draw = seq_along(v), att = v, stringsAsFactors = FALSE)
  top <- if (is.finite(m$mde)) 1.5 * m$mde else 4 * m$crit
  d <- seq(0, top, length.out = 61)
  curve[[gap]] <- data.frame(gap = gap, event_set = EVENT_SET, weighting = WEIGHTING, panel = PANEL, effect = d,
                             power = power_at(v, m$crit, d), stringsAsFactors = FALSE)
  if (!any(ok)) st$status <- "every placebo run failed"
  else if (sum(ok) < reps)
    st$notes <- sprintf("%d of %d placebo runs had no estimable cell", reps - sum(ok), reps)
  if (!is.finite(m$mde))
    st$notes <- trimws(paste(st$notes, "| no shift on the placebo draws reaches the power target"))
  st$notes <- trimws(sub("^\\| ", "", st$notes))
  status[[gap]] <- st
  say(sprintf("  %-16s %4d/%4d runs estimated, %6.1f s", gap, sum(ok), reps, secs))
}

bind <- function(x) { y <- do.call(rbind, x); if (!is.null(y)) rownames(y) <- NULL; y }
mt <- bind(mde); dt <- bind(draws); ct <- bind(curve); stt <- bind(status)
decision <- power_decision(mt, GAPS, POWER_CEILING)

settings <- data.frame(
  setting = c("run", "stage", "blinding", "quick_run", "placebo_reps", "event_set", "weighting", "panel",
              "test_level", "power_target", "mde_ceiling", "decision_rule", "seed_step", "placebo_treated_states",
              "placebo_cohort_years", "federal_end_year", "master_seed", "workers", "r_version", "did", "future", "furrr"),
  value = c(stamp, stage, readLines("data/reference/blinding_status.txt", n = 1, warn = FALSE),
            tolower(as.character(quick)), reps, EVENT_SET, WEIGHTING, PANEL, POWER_LEVEL, POWER_TARGET, POWER_CEILING,
            decision$rule, SEED_STEP, N_PLACEBO, paste0(min(PLACEBO_YEARS), "-", max(PLACEBO_YEARS)), FEDERAL_END,
            MASTER_SEED, WORKERS, R.version.string, as.character(utils::packageVersion("did")),
            as.character(utils::packageVersion("future")), as.character(utils::packageVersion("furrr"))),
  stringsAsFactors = FALSE)

wr <- function(x, fn) utils::write.csv(x, file.path(out_dir, paste0(fn, ".csv")), row.names = FALSE, na = "")
written <- c("mde", "placebo_draws", "power_curve", "model_status", "power_decision", "power_settings")
wr(mt, "mde"); wr(dt, "placebo_draws"); wr(ct, "power_curve"); wr(stt, "model_status")
wr(decision, "power_decision"); wr(settings, "power_settings")

note("\n== settings"); note_df(settings)
note("\n== minimum detectable effects"); note_df(mt)
note("\n== placebo distribution, deciles")
for (g in unique(dt$gap)) {
  v <- dt$att[dt$gap == g & is.finite(dt$att)]
  note(g, ": ", paste(sprintf("%.3f", stats::quantile(v, seq(0, 1, 0.1))), collapse = " "))
}
note("\n== power against effect size"); note_df(ct)
note("\n== model status"); note_df(stt)

say("\n== Minimum detectable effect, ", POWER_TARGET * 100, "% power, ", (1 - POWER_LEVEL) * 100,
    "% two-sided test (V units, that is SD)")
if (!is.null(mt))
  say(paste(utils::capture.output(print(data.frame(gap = mt$gap, mde = round(mt$mde, 4), mde_normal = round(mt$mde_normal, 4),
                                                   over_ceiling = ifelse(mt$underpowered == 1L, "yes", "no")),
                                        row.names = FALSE)), collapse = "\n"))
say("The ", POWER_CEILING, " SD ceiling is exceeded for ", decision$gaps_over_ceiling, " of ", decision$gaps,
    " gaps (", decision$gaps_without_mde, " without an MDE) -> ", decision$classification)

say("\nWrote ", paste0(out_dir, "/", written, ".csv", collapse = ", "))
if (quick) say("NOTE: --quick run. The registered count is ", POWER_REPS, " placebo runs per gap.")
say("Log: ", log_file)

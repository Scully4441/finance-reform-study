# Step 14 (Run 2). Full run and reporting (docs/design_extension.md, Sections 7, 8, 10 and 12).
# Run from the repository folder:
#   Rscript R/14_run_all_run2.R            a fresh full run: steps 5-7 on both Run 2 outcome families, the
#                                          variants and splits, Lee bounds, dose scaling, the SEDA MDE and
#                                          the report
#   Rscript R/14_run_all_run2.R --resume   continue an interrupted run: finished parts are skipped, and
#                                          model-level results already saved (step 5 fits, step 6 models,
#                                          randomization inference, variant fits and randomization) are reused
#   Rscript R/14_run_all_run2.R --report   rebuild outputs/run2/13_report/ from the saved outputs
#
# Outcome families (R/functions/run_all_run2.R):
#   seda  data/derived/seda_gaps.csv (step 11): gaps (a), (b), (c) in national SD units, end years
#         2009-2019 and 2022-2025, unbalanced by construction
#   hs    data/derived/hs_gaps_run2.csv (step 12): Run 1's gaps with the report-card years, end years
#         2010-2019 and 2021-2025
# What runs, per family, through the Run 1 functions (primary.R, secondary.R, inference.R, run_all.R):
#   1. Step 5: Callaway-Sant'Anna, 3 gaps x 3 event sets x weightings x both panel rules (30 models).
#      High school: no source covariate (post-freeze correction 2026-09-17, docs/deviations_run2.md;
#      rc_first is recorded in the panel counts but never enters).
#   2. Step 6: Sun-Abraham, imputation, synthdid, stacked, TWFE, all three event sets, on the unbalanced
#      panel (main) and the balanced panel (appendix/). Controls: high school test_replaced, cep and the
#      source indicator rc; SEDA cep; gaps (b) and (c) also the 2009 covariates by year.
#   3. Step 7: Webb wild cluster bootstrap (9,999, one draw set per event set), Romano-Wolf over the
#      three gaps (per event set, panel rule and weighting family), HonestDiD at M-bar 0..2 with the
#      widened grid and, for models whose event times are not consecutive, the reduced-block rule, and
#      randomization inference at 10,000 reassignments on every step 5 model.
#   4. Variants (Run 1 step 10) and the Section 10 splits, one departure each, all three event sets and
#      both weightings, CS only: bootstrap and Romano-Wolf 9,999, HonestDiD with the block rule,
#      randomization 1,000. High school: 5-point and exact-only samples, end years 2013 on, cohort drop,
#      anticipation = 1, EDFacts years alone, the seventeen confirmed states. SEDA: cohort drop,
#      anticipation = 1, 2009-2019 alone, 2022-2025 alone.
#   5. Lee bounds, high school gaps (b) and (c) (Run 1 step 10; tested counts exact only).
#   6. Dose scaling, every gap and event set of both families, revenue per pupil in thousands of 2025
#      dollars under Run 1's floor, percentile intervals from this run's step 7 Webb draws.
#   7. SEDA placebo-based MDE from the step 7 randomization draws of the primary models: descriptive.
#   8. The Section 12 report per family and gap, honest-DiD bound sets first, then the event study, the
#      bootstrap and randomization p-values, dose, Lee, estimator agreement, weighted comparison,
#      narrower event sets, Run 1's robustness checks, the Run 2 splits, and the continuous-treatment
#      estimates of step 13 (outputs/run2/13_continuous/, read, not refitted) with their caveat.
# Kept from R/10_run_all.R: per-model resume, RENV_CONFIG_SANDBOX_ENABLED = FALSE for every process
# started from here, the report's status in place of numbers for a missing model, HonestDiD's widened
# grid (honest_rm()) and the reduced-block rule (honest_block(), applied here as bound sets are made).
# Author decisions 2026-09-16: docs/deviations_run2.md and R/functions/run_all_run2.R.
#
# Outputs
#   outputs/run2/14_run_all/<family>/05_primary, 06_secondary (+ appendix), 07_inference, variants, dose;
#   outputs/run2/14_run_all/hs/lee; outputs/run2/14_run_all/seda/mde; run_times.csv; run_state.rds;
#   cache/ccd_grade9_district.csv (CCD counts, kept across fresh runs)
#   outputs/run2/13_report/report.md, plots/, tables/
#   data/derived/run2_14_fits/<family>/   model objects and randomization draws, for resume. The SEDA
#   fits hold district-level SEDA values, so they stay with the derived files and are never deposited
#   (Section 4, data use agreement); every CSV under outputs/ carries estimates and counts only.
#   outputs/logs/14_run_all_run2_<stamp>.log

for (f in list.files("R/functions", full.names = TRUE)) source(f)

# Every process started from here (the future workers) inherits this (R/10_run_all.R, 2026-09-13).
Sys.setenv(RENV_CONFIG_SANDBOX_ENABLED = "FALSE")

args <- commandArgs(trailingOnly = TRUE)
RESUME <- "--resume" %in% args
REPORT_ONLY <- "--report" %in% args
stage2 <- as.integer(readLines("data/stage_run2.txt", n = 1, warn = FALSE))
if (!identical(stage2, 2L)) stop("R/14_run_all_run2.R reads Run 2 outcome files, which needs data/stage_run2.txt = 2.")
BLINDING <- readLines("data/reference/blinding_status.txt", n = 1, warn = FALSE)
WORKERS <- 12L
OUT <- "outputs/run2/14_run_all"
REP <- "outputs/run2/13_report"
FITS <- "data/derived/run2_14_fits"
CDID_DIR <- "outputs/run2/13_continuous"
SETS <- names(EVENT_FILES)
KEYS <- c("gap", "event_set", "weighting", "panel")
ESTIMATORS6 <- c("sun_abraham", "imputation", "synthdid", "stacked", "twfe", "twfe_static")

stamp <- format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/logs", recursive = TRUE, showWarnings = FALSE)
log_file <- file.path("outputs", "logs", paste0("14_run_all_run2_", stamp, ".log"))
say <- function(...) {
  txt <- paste0(format(Sys.time(), "%H:%M:%S"), "  ", ...)
  cat(txt, "\n", sep = "")
  cat(txt, "\n", sep = "", file = log_file, append = TRUE)
}
wcsv <- function(x, f) { dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, f, row.names = FALSE, na = "") }
rcsv <- function(f) utils::read.csv(f, stringsAsFactors = FALSE, na.strings = "")
bind <- function(x) { y <- do.call(rbind, x); if (!is.null(y)) rownames(y) <- NULL; y }
odir <- function(family, ...) file.path(OUT, family, ...)
fdir <- function(family, ...) { d <- file.path(FITS, family, ...); dir.create(d, recursive = TRUE, showWarnings = FALSE); d }

# ---- run state: which parts are finished, for --resume -------------------------------------------
state_file <- file.path(OUT, "run_state.rds")
if (RESUME || REPORT_ONLY) {
  if (!file.exists(state_file)) stop("no run to resume: ", state_file, " not found")
  run <- readRDS(state_file)
} else {
  unlink(c(FITS, file.path(OUT, RUN2_FAMILIES)), recursive = TRUE)
  run <- list(run_id = stamp, started = Sys.time(), done = character(), times = data.frame(
    part = character(), seconds = numeric(), finished_utc = character(), stringsAsFactors = FALSE))
}
save_state <- function() saveRDS(run, state_file)
save_state()
part <- function(id, expr_fun) {
  if (id %in% run$done && !REPORT_ONLY) { say("skip ", id, " (finished in run ", run$run_id, ")"); return(invisible()) }
  say("start ", id)
  t0 <- Sys.time()
  expr_fun()
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  run$done <<- union(run$done, id)
  run$times <<- rbind(run$times[run$times$part != id, ], data.frame(part = id, seconds = secs,
    finished_utc = format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"), stringsAsFactors = FALSE))
  save_state()
  wcsv(run$times, file.path(OUT, "run_times.csv"))
  say(sprintf("done  %s  %.1f min", id, secs / 60))
}

say("Step 14 run-all (Run 2), run ", run$run_id, if (RESUME) " (resumed)" else "", "; stage_run2 ", stage2, "; blinding ", BLINDING)
say("Console: parts, model and unit counts, timings. Estimates: ", OUT, " and ", REP, "; model objects: ", FITS)

# ---- inputs -----------------------------------------------------------------------------------------
load_family <- function(family, weights = TRUE) {
  if (family == "seda" && weights) {
    ex <- read_seda_run2_extras()
    inp <- run2_load_inputs("seda", seda_tested_weights(ex))
    inp$extras <- ex
    inp
  } else run2_load_inputs(family)
}

# The step 5 model grid of a family: 3 gaps x 3 event sets x weightings x 2 panel rules.
grid5 <- function() {
  g <- bind(lapply(SETS, function(s) bind(lapply(RUN2_GAPS, function(gp) bind(lapply(run2_weightings(gp), function(w)
    data.frame(gap = gp, event_set = s, weighting = w, panel = names(PANEL_TYPES), stringsAsFactors = FALSE)))))))
  g$key <- do.call(paste, c(g[KEYS], sep = "."))
  g
}
tagk <- function(meta, x) if (!is.null(x) && nrow(x)) data.frame(meta, x, row.names = NULL, stringsAsFactors = FALSE)
panel_size <- function(mp) data.frame(units_in_model = mp$units, states_in_model = mp$states,
  states_dropped_few_pre = mp$states_dropped_few_pre, unit_years = nrow(mp$panel),
  first_year = if (nrow(mp$panel)) min(mp$panel$sy_end) else NA_integer_,
  last_year = if (nrow(mp$panel)) max(mp$panel$sy_end) else NA_integer_,
  report_card_unit_years = if ("rc" %in% names(mp$panel)) sum(mp$panel$rc == 1) else NA_integer_,
  source_covariate = mp$source_covariate, stringsAsFactors = FALSE)
no_panel <- function(msg) list(status = paste("panel error:", msg), notes = "", event = NULL, overall = NULL, cells = NULL,
                               fit = NULL, size = NULL)

# One Callaway-Sant'Anna model from a model-panel call, a status in place of a stop.
fit_cs <- function(panel_call, seed_step, allow_unbalanced, anticipation = 0L) {
  mp <- tryCatch(panel_call(), error = function(e) e)
  if (inherits(mp, "error")) return(no_panel(conditionMessage(mp)))
  fit <- tryCatch(run_cs(mp$panel, xformla = mp$xformla, weightsname = mp$weightsname, seed_step = seed_step,
                         allow_unbalanced_panel = allow_unbalanced, anticipation = anticipation), error = function(e) e)
  if (inherits(fit, "error")) return(list(status = paste("error:", conditionMessage(fit)), notes = "", event = NULL, overall = NULL,
                                          cells = NULL, fit = NULL, size = panel_size(mp)))
  list(status = fit$status, notes = paste(unique(fit$notes), collapse = " | "), event = fit$event, overall = fit$overall,
       cells = fit$cells, fit = fit$fit, size = panel_size(mp))
}

# ---- 1. step 5 ------------------------------------------------------------------------------------------
load_step5 <- function(family) {
  g <- grid5()
  stats::setNames(lapply(g$key, function(k) { f <- file.path(FITS, family, "05_primary", paste0(k, ".rds"))
    if (file.exists(f)) readRDS(f) else NULL }), g$key)
}

run_step5 <- function(family) {
  fd <- fdir(family, "05_primary")
  inp <- load_family(family)
  g <- grid5()
  res <- list()
  for (i in seq_len(nrow(g))) {
    k <- g$key[i]; f <- file.path(fd, paste0(k, ".rds"))
    if (file.exists(f)) { res[[k]] <- readRDS(f); next }
    r <- fit_cs(function() run2_model_panel(inp, g$gap[i], g$event_set[i], balanced = g$panel[i] == "balanced",
                                           weighting = g$weighting[i]),
                paste("14_run_all", family, "05_primary", k), PANEL_TYPES[[g$panel[i]]])
    r <- c(as.list(g[i, KEYS]), r)
    saveRDS(r, f)
    res[[k]] <- r
    say(sprintf("  %s fit %-17s %-7s %-15s %-10s %6s units %2s states  %s", family, g$gap[i], g$event_set[i], g$weighting[i],
                g$panel[i], if (is.null(r$size)) "-" else r$size$units_in_model, if (is.null(r$size)) "-" else r$size$states_in_model,
                if (r$status == "ok") "ok" else "not ok (status in files)"))
  }
  meta <- function(r) as.data.frame(r[KEYS], stringsAsFactors = FALSE)
  od <- odir(family, "05_primary")
  wcsv(bind(lapply(res, function(r) tagk(meta(r), r[["event"]]))), file.path(od, "event_time_estimates.csv"))
  wcsv(bind(lapply(res, function(r) tagk(meta(r), r$overall))), file.path(od, "overall_estimates.csv"))
  wcsv(bind(lapply(res, function(r) tagk(meta(r), r$cells))), file.path(od, "group_time_estimates.csv"))
  wcsv(bind(lapply(res, function(r) data.frame(meta(r), status = r$status, notes = r$notes, stringsAsFactors = FALSE))),
       file.path(od, "model_status.csv"))
  wcsv(bind(lapply(res, function(r) tagk(meta(r), r$size))), file.path(od, "panel_counts.csv"))
}

# ---- 2. step 6 ------------------------------------------------------------------------------------------
family_controls <- function(family, inp) {
  if (family == "seda") {
    dist <- run2_seda_districts(unique(inp$extras$leaid))
    return(run2_seda_controls(inp$race, dist, seda_all_both(inp$extras)))
  }
  cc <- as.vector(outer(c("cell_", "w_", "part_ok_"), c("math_all", "rla_all"), paste0))
  rows <- data.table::fread("data/derived/hs_panel_run2.csv", select = c("leaid", "state", "sy_end", "retained", "retained_r1", "retained_r2",
                                                                        "pov_quintile_2009", "test_replaced", "cep", cc),
                            colClasses = c(leaid = "character"), data.table = FALSE, showProgress = FALSE, na.strings = "")
  td <- tempfile("ccd"); dir.create(td)
  m09 <- read_ccd_lea(utils::unzip("data/raw/ccd/lea-directory-sy2009-10.zip", exdir = td), 2010L, extra = "MEMBER")
  rows$member_2009 <- ccd_count(m09$member)[match(rows$leaid, m09$leaid)]
  run2_hs_controls(rows)
}

run_step6 <- function(family) {
  fd <- fdir(family, "06_secondary")
  inp <- load_family(family)
  ctrl <- family_controls(family, inp)
  for (pan in names(PANEL_TYPES)) {
    res <- list()
    for (s in SETS) for (gap in RUN2_GAPS) {
      f <- file.path(fd, paste0(paste(pan, gap, s, sep = "."), ".rds"))
      if (file.exists(f)) fits <- readRDS(f) else {
        err <- function(msg) empty_result(paste("error:", msg))
        fits <- tryCatch({
          mp <- run2_model_panel(inp, gap, s, balanced = pan == "balanced")
          ac <- run2_attach_controls(ctrl, mp$panel, gap, s)
          p <- ac$panel
          covs <- if (gap == "a_poverty") character() else CS_COVARIATES
          est <- function(expr) tryCatch(expr, error = function(e) err(conditionMessage(e)))
          tw <- tryCatch(run_twfe(p, ac$controls, covs, mp$window), error = function(e) {
            x <- err(conditionMessage(e)); st <- x; st$event <- NULL; list(dynamic = x, static = st) })
          say(sprintf("  %s secondary %-17s %-7s %-10s %6d units %2d states", family, gap, s, pan, mp$units, mp$states))
          list(sun_abraham = est(run_sunab(p, ac$controls, covs, mp$window)),
               imputation  = est(run_imputation(p, ac$controls, covs, mp$window)),
               synthdid    = est(run_sdid(p, seed_step = paste("14_run_all", family, "06_secondary synthdid", gap, s, pan),
                                          complete_states = pan == "unbalanced")),
               stacked     = est(run_stacked(p, ac$controls, covs)),
               twfe        = tw$dynamic,
               twfe_static = tw$static)
        }, error = function(e) stats::setNames(lapply(ESTIMATORS6, function(x) err(conditionMessage(e))), ESTIMATORS6))
        fits <- lapply(fits, function(x) { x$fit <- NULL; x })      # the estimates are kept, not the model objects
        fits$twfe_static$event <- NULL
        saveRDS(fits, f)
      }
      for (est in ESTIMATORS6)
        res[[paste(est, gap, s)]] <- c(list(estimator = est, gap = gap, event_set = s, weighting = "unweighted", panel = pan,
                                            unit = if (est == "synthdid" || gap == "a_poverty") "state" else "district"), fits[[est]])
    }
    meta <- function(r) as.data.frame(r[c("estimator", KEYS)], stringsAsFactors = FALSE)
    od <- if (pan == "unbalanced") odir(family, "06_secondary") else odir(family, "06_secondary", "appendix")
    wcsv(bind(lapply(res, function(r) tagk(meta(r), r[["event"]]))), file.path(od, "event_time_estimates.csv"))
    wcsv(bind(lapply(res, function(r) tagk(meta(r), r$overall))), file.path(od, "overall_estimates.csv"))
    wcsv(bind(lapply(res, function(r) tagk(meta(r), r$cells))), file.path(od, "group_time_estimates.csv"))
    wcsv(bind(lapply(res, function(r) tagk(meta(r), r$pooled))), file.path(od, "synthdid_pooled.csv"))
    wcsv(bind(lapply(res, function(r) tagk(data.frame(meta(r), unit = r$unit), r$size))), file.path(od, "panel_counts.csv"))
    wcsv(bind(lapply(res, function(r) data.frame(meta(r), status = r$status, notes = paste(r$notes, collapse = " | "),
                                                 stringsAsFactors = FALSE))), file.path(od, "model_status.csv"))
  }
}

# ---- 3. step 7 ------------------------------------------------------------------------------------------
# Section 8 on a named list of results (list(fit, ref, meta)) sharing one event set: Webb bootstrap,
# HonestDiD with the block rule, and the bootstrap t-statistics for Romano-Wolf.
infer_set <- function(res, seed_step) {
  fits <- lapply(res, function(r) list(fit = r$fit, ref = r$ref))
  inf <- infer_fits(fits, seed_step, RUN2_BOOT_REPS)
  hon <- run2_block_rule(inf$honest, inf$infs, lapply(fits, `[[`, "ref"))
  tag_all <- function(x) stats::setNames(lapply(names(x), function(k) tagk(res[[k]]$meta, x[[k]])), names(x))
  list(overall = tag_all(inf$overall), event = tag_all(inf$event), honest = tag_all(hon), t_boot = inf$t_boot)
}

# Romano-Wolf over the gaps of one family of models (Run 1 step 7): keys named by gap.
rw_family <- function(pick, bo, tb, meta) {
  pick <- pick[!is.na(pick) & vapply(pick, function(k) !is.null(tb[[k]]) && !is.null(bo[[k]]), TRUE)]
  if (length(pick) < 2L) return(NULL)
  to <- vapply(pick, function(k) bo[[k]]$t, 0)
  data.frame(meta, gap = names(pick), weighting = vapply(pick, function(k) bo[[k]]$weighting, ""), t = to,
             p_unadjusted = vapply(pick, function(k) bo[[k]]$p_value, 0), p_romano_wolf = rw_stepdown(to, do.call(cbind, tb[pick])),
             rank = rank(-abs(to), ties.method = "first"), hypotheses = length(pick), reps = RUN2_BOOT_REPS,
             row.names = NULL, stringsAsFactors = FALSE)
}

ri_row <- function(meta, att, r) {
  v <- r$values[is.finite(r$values)]
  data.frame(meta, att = att, p_value = r$p_value, reps = as.integer(r$reps), draws_ok = as.integer(r$draws_ok),
             treated_states = as.integer(r$treated_states), eligible_states = as.integer(r$eligible_states),
             placebo_mean = if (length(v)) mean(v) else NA_real_, placebo_sd = if (length(v) > 1) stats::sd(v) else NA_real_,
             placebo_abs_q95 = if (length(v)) unname(stats::quantile(abs(v), 0.95)) else NA_real_, status = r$status,
             row.names = NULL, stringsAsFactors = FALSE)
}

settings_rows <- function(family, ri_reps) data.frame(
  setting = c("run", "family", "stage_run2", "blinding", "bootstrap_reps", "romano_wolf_reps", "randomization_reps", "webb_support",
              "mbar", "honest_grid", "honest_block_rule", "master_seed", "workers", "r_version", "did", "HonestDiD"),
  value = c(run$run_id, family, stage2, BLINDING, RUN2_BOOT_REPS, RUN2_BOOT_REPS, ri_reps, paste(round(WEBB_SUPPORT, 6), collapse = " "),
            paste(MBAR_GRID, collapse = " "), sprintf("start +/-%d sd, %d points; widened by its width per edge side, same step, up to %d times",
                                                      HONEST_GRID_SD, HONEST_GRID_POINTS, HONEST_GRID_MAX_WIDEN),
            "reduced consecutive event-time block where event times are not consecutive (honest_block())", MASTER_SEED, WORKERS,
            R.version.string, as.character(utils::packageVersion("did")), as.character(utils::packageVersion("HonestDiD"))),
  stringsAsFactors = FALSE)

run_step7 <- function(family) {
  g <- grid5()
  res5 <- load_step5(family)
  rdir <- fdir(family, "07_randomization")
  res <- lapply(stats::setNames(g$key, g$key), function(k) list(fit = res5[[k]]$fit, ref = -1L,
    meta = as.data.frame(g[g$key == k, KEYS], stringsAsFactors = FALSE), status = if (is.null(res5[[k]])) "no step 5 result" else res5[[k]]$status))
  bo <- list(); be <- list(); hd <- list(); tb <- list()
  for (s in SETS) {
    ks <- g$key[g$event_set == s]
    x <- infer_set(res[ks], paste("14_run_all", family, "07_inference bootstrap", s))
    bo <- c(bo, x$overall); be <- c(be, x$event); hd <- c(hd, x$honest); tb <- c(tb, x$t_boot)
    say(sprintf("  %s step 7 %-7s bootstrap, Romano-Wolf draws and HonestDiD: %d fitted models", family, s, length(x$overall)))
  }
  rw <- list()
  for (s in SETS) for (pan in names(PANEL_TYPES)) for (fam in c("unweighted", "tested_weighted")) {
    pick <- vapply(RUN2_GAPS, function(gp) { w <- if (gp == "a_poverty") "unweighted" else fam
      k <- paste(gp, s, w, pan, sep = "."); if (!is.null(tb[[k]])) k else NA_character_ }, "")
    rw[[paste(s, pan, fam)]] <- rw_family(pick, bo, tb, data.frame(event_set = s, panel = pan, family = fam, stringsAsFactors = FALSE))
  }
  ri <- list(); rid <- list()
  t0 <- Sys.time()
  for (k in g$key[vapply(g$key, function(k) !is.null(res[[k]]$fit), TRUE)]) {
    r <- ri_cached(res[[k]]$fit, RUN2_RI_REPS, paste("14_run_all", family, "07_inference randomization", k), file.path(rdir, paste0(k, ".rds")))
    ri[[k]] <- ri_row(res[[k]]$meta, res[[k]]$fit$aggte$overall.att, r)
    if (length(r$values)) rid[[k]] <- data.frame(res[[k]]$meta, draw = seq_along(r$values), att = r$values, row.names = NULL)
    say(sprintf("  %s randomization %-45s %5d/%5d reassignments estimated", family, k, r$draws_ok, r$reps))
  }
  say(sprintf("  %s randomization inference: %d models, %.1f min", family, length(ri), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  status <- bind(lapply(g$key, function(k) {
    h <- hd[[k]]; notes <- character()
    if (!is.null(h) && any(h$status != "ok")) notes <- c(notes, paste("HonestDiD:", unique(h$status[h$status != "ok"])))
    if (!is.null(ri[[k]]) && ri[[k]]$status != "ok") notes <- c(notes, paste("randomization:", ri[[k]]$status))
    data.frame(res[[k]]$meta, status = if (is.null(res[[k]]$fit)) paste("not fitted:", res[[k]]$status) else "ok",
               notes = paste(notes, collapse = " | "), stringsAsFactors = FALSE)
  }))
  od <- odir(family, "07_inference")
  wcsv(bind(bo), file.path(od, "bootstrap_overall.csv")); wcsv(bind(be), file.path(od, "bootstrap_event_time.csv"))
  wcsv(bind(hd), file.path(od, "honestdid_overall.csv")); wcsv(bind(rw), file.path(od, "romano_wolf.csv"))
  wcsv(bind(ri), file.path(od, "randomization_overall.csv")); wcsv(bind(rid), file.path(od, "randomization_draws.csv"))
  wcsv(status, file.path(od, "model_status.csv"))
  wcsv(settings_rows(family, RUN2_RI_REPS), file.path(od, "inference_settings.csv"))
}

# ---- 4. variants and splits -----------------------------------------------------------------------------
run_variants <- function(family) {
  vfd <- fdir(family, "variants", "fits"); vrd <- fdir(family, "variants", "randomization")
  inp <- load_family(family)
  vs_all <- run2_variants_for(family)
  grid <- bind(lapply(vs_all, function(v) bind(lapply(SETS, function(s) bind(lapply(RUN2_GAPS, function(gp)
    data.frame(variant = v, gap = gp, event_set = s, weighting = run2_weightings(gp), panel = "unbalanced", stringsAsFactors = FALSE)))))))
  grid$key <- paste(grid$gap, grid$event_set, grid$weighting, grid$variant, sep = ".")
  say(family, " variants: ", nrow(grid), " models (", length(vs_all), " variants and splits x 3 event sets x gaps and weightings)")
  vk <- c("variant", KEYS)
  res <- list()
  for (i in seq_len(nrow(grid))) {
    k <- grid$key[i]; f <- file.path(vfd, paste0(k, ".rds"))
    if (file.exists(f)) { res[[k]] <- readRDS(f); next }
    vs <- RUN2_VARIANTS[[grid$variant[i]]]
    r <- fit_cs(function() run2_model_panel(inp, grid$gap[i], grid$event_set[i], sample = vs$sample, from_year = vs$from_year,
                                           years = vs$years, states = vs$states, drop_few_pre = vs$drop_few_pre,
                                           weighting = grid$weighting[i]),
                paste("14_run_all", family, "variants", k), TRUE, vs$anticipation)
    r <- c(list(meta = as.data.frame(grid[i, vk], stringsAsFactors = FALSE), ref = -1L - vs$anticipation), r)
    saveRDS(r, f)
    res[[k]] <- r
    say(sprintf("  %s variant %-17s %-7s %-15s %-24s %6s units %2s states  %s", family, grid$gap[i], grid$event_set[i],
                grid$weighting[i], grid$variant[i], if (is.null(r$size)) "-" else r$size$units_in_model,
                if (is.null(r$size)) "-" else r$size$states_in_model, if (r$status == "ok") "ok" else "not ok (status in files)"))
  }
  bo <- list(); be <- list(); hd <- list(); tb <- list(); rw <- list()
  for (v in vs_all) for (s in SETS) {
    ks <- grid$key[grid$variant == v & grid$event_set == s]
    x <- infer_set(res[ks], paste("14_run_all", family, v, "bootstrap", s))
    bo <- c(bo, x$overall); be <- c(be, x$event); hd <- c(hd, x$honest); tb <- c(tb, x$t_boot)
    for (fam in c("unweighted", "tested_weighted")) {
      pick <- vapply(RUN2_GAPS, function(gp) { w <- if (gp == "a_poverty") "unweighted" else fam
        k <- paste(gp, s, w, v, sep = "."); if (!is.null(tb[[k]])) k else NA_character_ }, "")
      rw[[paste(v, s, fam)]] <- rw_family(pick, bo, tb, data.frame(variant = v, event_set = s, panel = "unbalanced", family = fam,
                                                                  stringsAsFactors = FALSE))
    }
  }
  say(family, " variants: bootstrap, Romano-Wolf and HonestDiD done for ", length(bo), " fitted models")
  ri <- list(); rid <- list()
  t0 <- Sys.time()
  for (k in names(res)[vapply(res, function(r) !is.null(r$fit), TRUE)]) {
    r <- ri_cached(res[[k]]$fit, RI_REPS_VARIANT, paste("14_run_all", family, "variants randomization", k), file.path(vrd, paste0(k, ".rds")))
    ri[[k]] <- ri_row(res[[k]]$meta, res[[k]]$overall$att, r)
    if (length(r$values)) rid[[k]] <- data.frame(res[[k]]$meta, draw = seq_along(r$values), att = r$values, row.names = NULL)
  }
  say(sprintf("%s variants: randomization inference (%d reassignments) on %d models, %.1f min", family, RI_REPS_VARIANT,
              length(ri), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  od <- odir(family, "variants")
  wcsv(bind(lapply(res, function(r) tagk(r$meta, r$overall))), file.path(od, "overall_estimates.csv"))
  wcsv(bind(lapply(res, function(r) tagk(r$meta, r[["event"]]))), file.path(od, "event_time_estimates.csv"))
  wcsv(bind(lapply(res, function(r) data.frame(r$meta, status = r$status, notes = r$notes, row.names = NULL, stringsAsFactors = FALSE))),
       file.path(od, "model_status.csv"))
  wcsv(bind(lapply(res, function(r) tagk(r$meta, r$size))), file.path(od, "panel_counts.csv"))
  wcsv(bind(bo), file.path(od, "bootstrap_overall.csv")); wcsv(bind(be), file.path(od, "bootstrap_event_time.csv"))
  wcsv(bind(hd), file.path(od, "honestdid_overall.csv")); wcsv(bind(rw), file.path(od, "romano_wolf.csv"))
  wcsv(bind(ri), file.path(od, "randomization_overall.csv")); wcsv(bind(rid), file.path(od, "randomization_draws.csv"))
  wcsv(data.frame(variant = vs_all, label = vapply(RUN2_VARIANTS[vs_all], `[[`, "", "label"),
                  split = vapply(RUN2_VARIANTS[vs_all], `[[`, TRUE, "split"), stringsAsFactors = FALSE), file.path(od, "variants.csv"))
  wcsv(settings_rows(family, RI_REPS_VARIANT), file.path(od, "inference_settings.csv"))
  # The EDFacts-years split reproduces Run 1's window: its estimates beside Run 1's step 5 file, where present.
  r1f <- "outputs/05_primary/overall_estimates.csv"
  if (family == "hs" && file.exists(r1f)) {
    o1 <- rcsv(r1f); o1 <- o1[o1$panel == "unbalanced", , drop = FALSE]
    sp <- bind(lapply(res[grid$key[grid$variant == "hs_edfacts_years"]], function(r) tagk(r$meta, r$overall)))
    if (!is.null(sp)) {
      k1 <- match(paste(sp$gap, sp$event_set, sp$weighting), paste(o1$gap, o1$event_set, o1$weighting))
      wcsv(data.frame(sp[c("gap", "event_set", "weighting")], att_edfacts_split = sp$att, att_run1_step5 = o1$att[k1],
                      difference = sp$att - o1$att[k1], stringsAsFactors = FALSE), file.path(od, "edfacts_split_vs_run1.csv"))
    }
  }
}

# ---- 5. Lee bounds, high school gaps (b) and (c) ------------------------------------------------------------
run_lee <- function() {
  ldir <- odir("hs", "lee")
  window <- RUN2_WINDOWS$hs
  need <- sort(unique(window - LEE_LAG))
  stopifnot(all(need >= LEE_FIRST_CCD))
  g9_file <- file.path(OUT, "cache", "ccd_grade9_district.csv")
  rg9 <- function(f) utils::read.csv(f, colClasses = c(leaid = "character"), stringsAsFactors = FALSE)
  g9 <- if (file.exists(g9_file)) rg9(g9_file) else if (file.exists("outputs/10_run_all/cache/ccd_grade9_district.csv"))
    rg9("outputs/10_run_all/cache/ccd_grade9_district.csv") else NULL      # Run 1's counts from the same CCD files
  todo <- setdiff(need, g9$sy_end)
  if (length(todo)) {
    td <- tempfile("ccdg9"); dir.create(td); on.exit(unlink(td, recursive = TRUE), add = TRUE)
    for (y in todo) {
      t0 <- Sys.time(); p <- ccd_membership_file(y, td)
      x <- ccd_grade9_district(p, y, attr(p, "layout")); unlink(p)
      g9 <- rbind(g9, x)
      wcsv(g9, g9_file)
      say(sprintf("  CCD grade 9 membership, end year %d: %d districts, %.1f min", y, nrow(x), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
    }
  }
  g9 <- g9[g9$sy_end %in% need, , drop = FALSE]
  sg_cols <- as.vector(outer(c("math_", "rla_"), c("all", "wh", "bl", "hi"), paste0))
  smp <- data.table::fread("data/derived/hs_panel_run2.csv", select = c("leaid", "sy_end", paste0("n_", sg_cols), paste0("nbasis_", sg_cols)),
                           colClasses = c(leaid = "character"), data.table = FALSE, showProgress = FALSE, na.strings = "")
  for (v in sg_cols) smp[[paste0("n_", v)]][!smp[[paste0("nbasis_", v)]] %in% "exact"] <- NA_real_   # exact tested counts only
  inp <- run2_load_inputs("hs")
  ov5 <- rcsv(odir("hs", "05_primary", "overall_estimates.csv"))
  rows <- list(); share_rows <- list()
  for (gap in c("b_black_white", "c_hispanic_white")) {
    mp <- run2_model_panel(inp, gap, "primary")
    base <- mp$panel
    sgs <- RACE_GAPS[[race_key("achievement", gap)]]
    xv <- all.vars(mp$xformla)
    effects <- c(); pg <- c()
    for (sg in sgs) {
      sp <- lee_share_panel(base, smp, g9, sg, window)
      for (v in setdiff(xv, names(sp))) sp[[v]] <- base[[v]][match(sp$leaid, base$leaid)]   # the source covariate
      fs <- run_cs(sp, xformla = mp$xformla, seed_step = paste("14_run_all hs lee share", gap, sg), allow_unbalanced_panel = TRUE)
      effects[sg] <- if (fs$status == "ok") fs$overall$att else NA_real_
      lev <- lee_share_levels(fs, sp)
      pg[sg] <- lee_p(lev[["q_T"]], lev[["q_C"]])
      share_rows[[paste(gap, sg)]] <- data.frame(gap = gap, subgroup = sg, status = fs$status, att_share = fs$overall$att,
        se = fs$overall$se, q_T = lev[["q_T"]], q_C = lev[["q_C"]], p = unname(pg[sg]), units = length(unique(sp$id)),
        unit_years = nrow(sp), report_card_unit_years = sum(sp$sy_end >= RUN2_RC_FROM), share_years_from = min(sp$sy_end),
        share_years_to = max(sp$sy_end), fallback_share = mean(sp$fallback), mean_share = mean(sp$y),
        notes = paste(unique(fs$notes), collapse = " | "), stringsAsFactors = FALSE)
      say(sprintf("  Lee share model %-17s %s: %d districts, %s", gap, sg, length(unique(sp$id)), fs$status))
    }
    frac <- lee_differential_fraction(pg[[sgs[1]]], pg[["wh"]])
    prim <- run_cs(base, xformla = mp$xformla, seed_step = paste("14_run_all hs lee primary", gap), allow_unbalanced_panel = TRUE)
    k5 <- ov5$gap == gap & ov5$event_set == "primary" & ov5$weighting == "unweighted" & ov5$panel == "unbalanced"
    if (any(k5) && is.finite(ov5$att[k5])) stopifnot(isTRUE(all.equal(prim$overall$att, ov5$att[k5])))   # the rebuilt panel is step 5's
    trims <- lapply(c(top = "top", bottom = "bottom"), function(side) {
      tr <- lee_trim(base, if (is.na(frac)) 0 else frac, side)
      ft <- run_cs(tr$panel, xformla = mp$xformla, seed_step = paste("14_run_all hs lee trim", gap, side), allow_unbalanced_panel = TRUE)
      list(att = ft$overall$att, status = ft$status, removed = tr$removed, treated_post = tr$treated_post)
    })
    est <- c(trims$top$att, trims$bottom$att)
    rows[[gap]] <- data.frame(gap = gap, event_set = "primary", weighting = "unweighted", panel = "unbalanced",
      att_primary = prim$overall$att, effect_share_minority = unname(effects[sgs[1]]), effect_share_white = unname(effects["wh"]),
      p_minority = unname(pg[sgs[1]]), p_white = unname(pg["wh"]), trim_fraction = frac,
      treated_post_unit_years = trims$top$treated_post, trimmed_unit_years = trims$top$removed,
      att_trim_top = trims$top$att, att_trim_bottom = trims$bottom$att,
      lee_lower = if (all(is.na(est))) NA_real_ else min(est, na.rm = TRUE), lee_upper = if (all(is.na(est))) NA_real_ else max(est, na.rm = TRUE),
      status = if (is.na(frac)) "no share effect estimated" else if (trims$top$status == "ok" && trims$bottom$status == "ok") "ok" else
        paste("trim refit:", trims$top$status, "/", trims$bottom$status), stringsAsFactors = FALSE)
    say(sprintf("  Lee trim %-17s treated post-reform district-years: %d of %d, %s", gap, trims$top$removed,
                trims$top$treated_post, rows[[gap]]$status))
  }
  wcsv(bind(rows), file.path(ldir, "lee_bounds.csv"))
  wcsv(bind(share_rows), file.path(ldir, "lee_share_models.csv"))
  wcsv(data.frame(sy_end = sort(unique(g9$sy_end)), districts = as.vector(table(g9$sy_end)),
                  race_unavailable_bl = as.vector(tapply(is.na(g9$g9_bl), g9$sy_end, sum)),
                  race_unavailable_wh = as.vector(tapply(is.na(g9$g9_wh), g9$sy_end, sum)),
                  race_unavailable_hi = as.vector(tapply(is.na(g9$g9_hi), g9$sy_end, sum))),
       file.path(ldir, "ccd_grade9_coverage.csv"))
}

# ---- 6. dose scaling ----------------------------------------------------------------------------------------
# The step 7 Webb draws of a family, rebuilt from the same seed steps and state lists as infer_fits().
step7_draws_run2 <- function(family, reps) {
  g <- grid5(); res5 <- load_step5(family)
  infs <- lapply(res5, function(r) if (is.null(r)) NULL else cs_influence(r$fit))
  draws <- list()
  for (s in SETS) {
    k <- g$key[g$event_set == s & !vapply(infs[g$key], is.null, TRUE)]
    if (!length(k)) next
    st <- sort(unique(unlist(lapply(infs[k], `[[`, "states"))))
    set.seed(seed_for(paste("14_run_all", family, "07_inference bootstrap", s)))
    draws[[s]] <- list(states = st, w = webb_weights(length(st), reps))
  }
  list(draws = draws, infs = infs)
}

run_dose <- function(family) {
  ddir <- odir(family, "dose")
  window <- RUN2_WINDOWS[[family]]
  years <- window[window %in% CDID_F33_YEARS]
  rev_all <- cdid_real_revenue(f33_revenue(years))
  rev <- rev_all[!rev_all$excluded, , drop = FALSE]
  count_excl <- function(scope, gap, s, lea_sy) {
    k <- paste(rev_all$leaid, rev_all$sy_end) %in% lea_sy
    data.frame(scope = scope, gap = gap, event_set = s, district_years_with_revenue = sum(k),
               excluded_enrollment_below_30 = sum(k & rev_all$v33 < CDID_REV_MIN_ENROLL),
               excluded_revenue_above_100k = sum(k & rev_all$rev_pp_real > CDID_REV_MAX_PP),
               excluded_total = sum(k & rev_all$excluded), stringsAsFactors = FALSE)
  }
  exrows <- list(all = count_excl("all F-33 districts, window years with F-33", NA_character_, NA_character_, paste(rev_all$leaid, rev_all$sy_end)))
  say(sprintf("  revenue exclusions (%s, fiscal years %d-%d): %d of %d F-33 district-years", family, min(years), max(years),
              sum(rev_all$excluded), nrow(rev_all)))
  st7 <- rcsv(odir(family, "07_inference", "inference_settings.csv"))
  reps7 <- as.integer(st7$value[st7$setting == "bootstrap_reps"])
  s7 <- step7_draws_run2(family, reps7)
  inp <- run2_load_inputs(family)
  da <- if (family == "seda") run2_seda_districts(unique(inp$race$leaid)) else run2_hs_gap_a_districts()
  rows <- list(); fs_ev <- list(); fs_ov <- list()
  for (s in SETS) for (gap in RUN2_GAPS) {
    key <- paste(gap, s, "unweighted", "unbalanced", sep = ".")
    inf_y <- s7$infs[[key]]
    mp <- tryCatch(run2_model_panel(inp, gap, s), error = function(e) e)
    if (inherits(mp, "error")) {
      rows[[key]] <- data.frame(gap = gap, event_set = s, weighting = "unweighted", panel = "unbalanced", status = paste("panel error:", conditionMessage(mp)))
      next
    }
    base <- mp$panel
    unit <- mp$unit
    rp <- if (gap == "a_poverty") run2_gap_a_revenue_panel(da, RETAIN_FLAGS[[s]], rev_all, years, base) else dist_revenue_panel(base, rev, years)
    for (v in setdiff(all.vars(mp$xformla), names(rp))) rp[[v]] <- base[[v]][match(rp[[unit]], base[[unit]])]   # the source covariate
    scope <- if (gap == "a_poverty") {
      x <- da[da[[RETAIN_FLAGS[[s]]]] %in% 1L & da$pov_quintile_2009 %in% c(1L, 5L) & !is.na(da$member_2009) & da$member_2009 > 0 &
                da$state %in% base$state, , drop = FALSE]
      as.vector(outer(x$leaid, years, paste))
    } else as.vector(outer(unique(base$leaid), years, paste))
    exrows[[key]] <- count_excl(if (gap == "a_poverty") "quintile 1 and 5 districts of the gap (a) states" else
                                  "districts of the gap's primary model", gap, s, scope)
    fr <- run_cs(rp, xformla = mp$xformla, seed_step = paste("14_run_all", family, "dose", key), allow_unbalanced_panel = TRUE)
    inf_r <- cs_influence(fr$fit)
    say(sprintf("  %s revenue first stage %-17s %-7s %5d units, %s", family, gap, s, length(unique(rp$id)), fr$status))
    fs_ev[[key]] <- data.frame(gap = gap, event_set = s, fr$event, stringsAsFactors = FALSE)
    rb <- if (!is.null(inf_r) && !is.null(s7$draws[[s]]) && all(inf_r$states %in% s7$draws[[s]]$states))
      wcb_test(inf_r$overall_att, inf_r$scores[, "overall"], inf_r$n, s7$draws[[s]]$w[, match(inf_r$states, s7$draws[[s]]$states), drop = FALSE])$row else NULL
    fs_ov[[key]] <- data.frame(gap = gap, event_set = s, status = fr$status, fr$overall,
      boot_p_value = if (is.null(rb)) NA_real_ else rb$p_value, units_in_model = length(unique(rp$id)),
      unit_years = nrow(rp), notes = paste(unique(fr$notes), collapse = " | "), stringsAsFactors = FALSE)
    none <- function(status) data.frame(att_outcome = NA_real_, att_revenue = NA_real_, revenue_ci_lo = NA_real_, revenue_ci_hi = NA_real_,
      dose_scaled = NA_real_, ci_lo = NA_real_, ci_hi = NA_real_, percentile_lo = NA_real_, percentile_hi = NA_real_,
      share_draws_revenue_sign_flip = NA_real_, reps = reps7, status = status, stringsAsFactors = FALSE)
    d <- if (is.null(inf_y)) none("no step 5 influence function") else if (is.null(inf_r)) none(paste("revenue model:", fr$status)) else
      tryCatch(dose_ratio(inf_y, inf_r, s7$draws[[s]]), error = function(e) none(paste("error:", conditionMessage(e))))
    rows[[key]] <- data.frame(gap = gap, event_set = s, weighting = "unweighted", panel = "unbalanced", d,
                              revenue_units = paste0("thousands of ", CDID_BASE_YEAR, " dollars per pupil"), stringsAsFactors = FALSE)
  }
  fill <- function(x) { nm <- unique(unlist(lapply(x, names))); lapply(x, function(r) { for (v in setdiff(nm, names(r))) r[[v]] <- NA; r[nm] }) }
  wcsv(bind(fill(rows)), file.path(ddir, "dose_scaled.csv"))
  wcsv(bind(fs_ov), file.path(ddir, "revenue_first_stage_overall.csv"))
  wcsv(bind(fs_ev), file.path(ddir, "revenue_first_stage_event_time.csv"))
  wcsv(bind(exrows), file.path(ddir, "revenue_exclusions.csv"))
}

# ---- 7. SEDA placebo-based MDE (descriptive) ---------------------------------------------------------------
run_mde <- function() {
  rows <- lapply(RUN2_GAPS, function(gap) {
    key <- paste(gap, "primary", "unweighted", "unbalanced", sep = ".")
    cf <- file.path(FITS, "seda", "07_randomization", paste0(key, ".rds"))
    base <- data.frame(gap = gap, event_set = "primary", weighting = "unweighted", panel = "unbalanced", stringsAsFactors = FALSE)
    if (!file.exists(cf)) return(data.frame(base, status = "no randomization draws for the model", stringsAsFactors = FALSE))
    r <- readRDS(cf)
    m <- mde_from_placebo(r$values)
    v <- r$values[is.finite(r$values)]
    data.frame(base, reassignments = as.integer(r$reps), draws_ok = m$draws, placebo_sd = if (length(v) > 1) stats::sd(v) else NA_real_,
               crit_abs_q95 = m$crit, mde_power_80 = m$mde, power_at_mde = m$power_at_mde, mde_normal = m$mde_normal,
               status = "descriptive", label = "For information only: no power ceiling applies to Run 2 (extension design Section 8)",
               stringsAsFactors = FALSE)
  })
  nm <- unique(unlist(lapply(rows, names)))
  wcsv(bind(lapply(rows, function(r) { for (v in setdiff(nm, names(r))) r[[v]] <- NA; r[nm] })), odir("seda", "mde", "mde_descriptive.csv"))
  say("  SEDA MDE (descriptive) from the step 7 randomization draws of the primary models")
}

if (!REPORT_ONLY) {
  for (fm in RUN2_FAMILIES) {
    part(paste("05_primary", fm), function() run_step5(fm))
    part(paste("06_secondary", fm), function() run_step6(fm))
    future::plan(future::multisession, workers = WORKERS)
    part(paste("07_inference", fm), function() run_step7(fm))
    part(paste("variants", fm), function() run_variants(fm))
    future::plan(future::sequential)
  }
  part("lee hs", run_lee)
  for (fm in RUN2_FAMILIES) part(paste("dose", fm), function() run_dose(fm))
  part("mde seda", run_mde)
}

# ---- 8. report ----------------------------------------------------------------------------------------------
FAMILY_HEADS <- c(seda = "SEDA grades 3–8 gaps (end years 2009–2019 and 2022–2025)",
                  hs = "High school gaps, extended panel (EDFacts 2010–2021, state report cards 2022–2025)")
GAP_TITLES_RUN2 <- list(
  seda = c(a_poverty = "SEDA gap (a): between-district poverty-quintile gap, grades 3–8",
           b_black_white = "SEDA gap (b): within-district Black–White gap, grades 3–8",
           c_hispanic_white = "SEDA gap (c): within-district Hispanic–White gap, grades 3–8"),
  hs = c(a_poverty = "High school gap (a): between-district poverty-quintile gap",
         b_black_white = "High school gap (b): within-district Black–White gap",
         c_hispanic_white = "High school gap (c): within-district Hispanic–White gap"))
UNITS_TEXT <- c(seda = "national standard deviation units (SEDA cohort-standardized scale)",
                hs = "standard deviation units (Run 1's probit gap V)")
WEIGHT_TEXT <- c(seda = "SEDA's tot_asmt of the gap's two groups in 2009-10, summed over grades 3-8, mean of math and RLA, fixed",
                 hs = "students tested in the gap's two groups in 2009-10, mean of math and RLA, fixed")

build_report <- function() {
  unlink(REP, recursive = TRUE)
  dir.create(file.path(REP, "plots"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(REP, "tables"), recursive = TRUE, showWarnings = FALSE)
  empty <- data.frame(gap = character(), event_set = character(), weighting = character(), panel = character(), variant = character(),
                      estimator = character(), family = character(), mbar = numeric(), status = character(), stringsAsFactors = FALSE)
  rd0 <- function(f) if (file.exists(f)) rcsv(f) else empty
  lee <- rd0(odir("hs", "lee", "lee_bounds.csv"))
  cres <- rd0(file.path(CDID_DIR, "results.csv")); cmod <- rd0(file.path(CDID_DIR, "models.csv"))
  md <- c("# Run 2 report (Section 12)", "",
          paste0("Run ", run$run_id, "; blinding status **", BLINDING, "**. Run 2 is the registered extension (docs/design_extension.md); Run 1 is the registered study and is reported first."),
          "",
          "Run 1 Section 13 applies to each Run 2 outcome family. For each gap the honest-DiD bound sets come first; the headline is the bound set at M̄ = 1, and all five M̄ values are shown. Point estimates, p-values and intervals are reported as quantities, and no result is described as statistically significant.",
          "",
          "Primary specification: Callaway–Sant'Anna, not-yet-treated controls, doubly robust, unbalanced panel, primary suppression sample (high school), reference period −1, primary event set, unweighted; high school models add the source covariate where it varies (Section 7). Event-time and overall intervals are Webb wild cluster bootstrap intervals (9,999 draws, state clusters).",
          "")
  n_head <- length(md)
  ans <- list()
  missing_models <- character()
  gone <- function(st, id) {
    missing_models <<- union(missing_models, id)
    st <- st[!is.na(st)]
    if (!length(st)) "not estimable: no status recorded" else
      if (st[1] == "ok") "no result row (model status: ok)" else paste0("not estimable: ", st[1])
  }
  val <- function(d, x, st, id) if (nrow(d)) x else gone(st, id)
  st1 <- function(st) if (length(st)) st[1] else "no status recorded"
  blk <- function(r) if ("event_block" %in% names(r) && !is.na(r$event_block[1])) paste0(" (event times ", r$event_block[1], ")") else ""
  ci <- function(lo, hi) ifelse(is.na(lo), "–", paste0("[", fmt(lo), ", ", fmt(hi), "]"))
  for (family in RUN2_FAMILIES) {
    s5 <- odir(family, "05_primary"); s6 <- odir(family, "06_secondary"); s7 <- odir(family, "07_inference"); vd <- odir(family, "variants")
    ev5 <- rd0(file.path(s5, "event_time_estimates.csv")); ov5 <- rd0(file.path(s5, "overall_estimates.csv"))
    ms5 <- rd0(file.path(s5, "model_status.csv"))
    bo7 <- rd0(file.path(s7, "bootstrap_overall.csv")); be7 <- rd0(file.path(s7, "bootstrap_event_time.csv"))
    ri7 <- rd0(file.path(s7, "randomization_overall.csv")); rw7 <- rd0(file.path(s7, "romano_wolf.csv"))
    hd7 <- rd0(file.path(s7, "honestdid_overall.csv"))
    ov6 <- rd0(file.path(s6, "overall_estimates.csv")); ms6 <- rd0(file.path(s6, "model_status.csv"))
    vov <- rd0(file.path(vd, "overall_estimates.csv")); vbo <- rd0(file.path(vd, "bootstrap_overall.csv"))
    vri <- rd0(file.path(vd, "randomization_overall.csv")); vhd <- rd0(file.path(vd, "honestdid_overall.csv"))
    vms <- rd0(file.path(vd, "model_status.csv"))
    dose <- rd0(odir(family, "dose", "dose_scaled.csv")); ex_all <- rd0(odir(family, "dose", "revenue_exclusions.csv"))
    md <- c(md, paste0("# ", FAMILY_HEADS[[family]]), "", paste0("Outcome units: ", UNITS_TEXT[[family]], "."), "")
    sel <- function(d, g, s = "primary", w = "unweighted", p = "unbalanced")
      d[d$gap %in% g & d$event_set %in% s & d$weighting %in% w & d$panel %in% p, , drop = FALSE]
    m1 <- function(h, st, id) { r <- h[!is.na(h$mbar) & h$mbar == HEADLINE_MBAR, , drop = FALSE]
      if (!nrow(r)) return(if (nrow(h)) paste0("no bound (", h$status[1], ")") else gone(st, id))
      if (r$status[1] != "ok") return(paste0("no bound (", r$status[1], ")"))
      paste0("[", fmt(r$lb[1]), ", ", fmt(r$ub[1]), "]", blk(r)) }
    for (gap in RUN2_GAPS) {
      title <- GAP_TITLES_RUN2[[family]][[gap]]
      tf <- function(n, name) file.path(REP, "tables", paste0(family, "_", gap, "_", n, "_", name, ".csv"))
      md <- c(md, paste0("## ", title), "")
      mid <- function(s, w, p, v = "primary_specification") paste(family, gap, s, w, p, v, sep = ".")
      id0 <- mid("primary", "unweighted", "unbalanced"); st0 <- sel(ms5, gap)$status
      h <- sel(hd7, gap)
      # 1. honest-DiD bound sets
      ht <- if (!nrow(h)) data.frame(`M̄` = "all", status = gone(st0, id0), check.names = FALSE) else
        data.frame(`M̄` = ifelse(!is.na(h$mbar), formatC(h$mbar, format = "g"), ifelse(h$method %in% "original", "original CS (no restriction)", "–")),
                   lower = fmt(h$lb), upper = fmt(h$ub), width = fmt(h$ub - h$lb), status = h$status,
                   grid = ifelse(is.na(h$grid_points), "–", paste0("[", fmt(h$grid_lb), ", ", fmt(h$grid_ub), "], ", h$grid_points, " points")),
                   headline = ifelse(!is.na(h$mbar) & h$mbar == HEADLINE_MBAR, "**headline**", ""), check.names = FALSE)
      if (nrow(h) && "event_block_note" %in% names(h) && any(!is.na(h$event_block_note)))
        ht$event_block <- ifelse(is.na(h$event_block_note), "–", h$event_block_note)
      wcsv(h, tf(1, "honestdid"))
      md <- c(md, "### 1. Honest-DiD bound sets (relative magnitudes, overall post-reform average)", "",
              "Each M̄ starts on HonestDiD's default grid (±20 standard deviations of the overall estimate, 1,000 points), widened on a side its bound set reaches. Where the estimated event times are not consecutive around the reference period, the bound sets are computed on the largest consecutive block through the reference period and event time 0 (the block rule), named in the event_block column.", "",
              md_table(ht))
      # 2. event study
      ev <- sel(be7, gap); e5 <- sel(ev5, gap)
      md <- c(md, "### 2. Event study with honest-DiD bounds and cohorts per coefficient", "")
      if (nrow(ev)) {
        ev$cohorts <- e5$cohorts[match(ev$e, e5$e)]; ev$treated_states <- e5$treated_states[match(ev$e, e5$e)]
        ev$treated_units <- e5$treated_units[match(ev$e, e5$e)]
        ev$att[is.na(ev$att)] <- e5$att[match(ev$e[is.na(ev$att)], e5$e)]
        o <- sel(ov5, gap)
        png_name <- paste0(family, "_", gap, "_event_study.png")
        plot_event_study(file.path(REP, "plots", png_name), ev, if (nrow(o)) o$att else NA_real_, h, title)
        et <- data.frame(event_time = ev$e, estimate = fmt(ev$att), boot_ci = ci(ev$ci_lo, ev$ci_hi), boot_p = fmt_p(ev$p_value),
                         cohorts = ev$cohorts, treated_states = ev$treated_states, treated_units = ev$treated_units,
                         reference = ifelse(ev$reference, "ref", ""))
        md <- c(md, paste0("![event study](plots/", png_name, ")"), "", md_table(et))
      } else md <- c(md, md_table(data.frame(event_time = "all", status = gone(st0, id0))))
      names(ev)[names(ev) == "t"] <- "t_stat"
      wcsv(ev, tf(2, "event_study"))
      # 3. overall
      o <- sel(ov5, gap); b <- sel(bo7, gap); r <- sel(ri7, gap)
      rw <- rw7[rw7$gap %in% gap & rw7$event_set %in% "primary" & rw7$panel %in% "unbalanced" & rw7$family %in% "unweighted", , drop = FALSE]
      ot <- data.frame(estimate = val(o, fmt(o$att), st0, id0), clustered_se = val(b, fmt(b$se), st0, id0),
                       boot_ci = val(b, ci(b$ci_lo, b$ci_hi), st0, id0), boot_p = val(b, fmt_p(b$p_value), st0, id0),
                       randomization_p = val(r, fmt_p(r$p_value), st0, id0), randomization_reps = val(r, r$reps, st0, id0),
                       romano_wolf_p = fmt_p(if (nrow(rw)) rw$p_romano_wolf else NA), cohorts = val(o, o$cohorts, st0, id0),
                       treated_states = val(o, o$treated_states, st0, id0), model_status = st1(st0))
      wcsv(ot, tf(3, "overall"))
      md <- c(md, "### 3. Overall post-reform average", "", md_table(ot))
      # 4. dose-scaled
      d <- dose[dose$gap %in% gap & dose$event_set %in% "primary", , drop = FALSE]
      ex <- ex_all[!is.na(ex_all$gap) & ex_all$gap == gap & ex_all$event_set %in% "primary", , drop = FALSE]
      dt <- if (!nrow(d)) data.frame(status = "no dose row") else
        data.frame(effect_sd = fmt(d$att_outcome), revenue_effect = fmt(d$att_revenue), revenue_boot_ci = ci(d$revenue_ci_lo, d$revenue_ci_hi),
                   sd_per_1000 = fmt(d$dose_scaled), interval_per_1000 = ifelse(is.na(d$ci_lo), "unbounded or none", ci(d$ci_lo, d$ci_hi)),
                   status = d$status)
      wcsv(d, tf(4, "dose"))
      md <- c(md, paste0("### 4. Dose-scaled estimate (per $1,000 of per-pupil state-plus-local revenue, ", CDID_BASE_YEAR, " dollars)"), "",
        paste0("Revenue effect: the same Callaway–Sant'Anna model with F-33 (TSTREV + TLOCREV) / V33 in thousands of ", CDID_BASE_YEAR,
               " dollars as the outcome, fiscal years 2010–2024",
               if (gap == "a_poverty") " (quintile 5 minus quintile 1 membership-weighted revenue per pupil over a district set fixed across fiscal years, as step 13's gap (a) treatment)" else " (district revenue per pupil)",
               ". District-years with F-33 enrollment below 30 or revenue above $100,000 per pupil are excluded",
               if (nrow(ex)) sprintf(": %d of the %d district-years in scope (%d below 30 enrolled, %d above $100,000)", ex$excluded_total,
                                     ex$district_years_with_revenue, ex$excluded_enrollment_below_30, ex$excluded_revenue_above_100k) else "",
               ". The dose-scaled estimate is the ratio of the two overall effects, with a percentile interval from this run's step 7 Webb draws applied to both. **Assumption:** the reform affects the gap only through revenue (exclusion restriction). The assumption is stated, not tested."),
        "", md_table(dt))
      # 5. Lee bounds
      if (family == "hs" && gap %in% lee$gap) {
        l <- lee[lee$gap == gap, ]
        lt <- data.frame(p_minority = fmt(l$p_minority, 4), p_white = fmt(l$p_white, 4), trim_fraction = fmt(l$trim_fraction, 4),
          trimmed_treated_post_district_years = paste0(l$trimmed_unit_years, " of ", l$treated_post_unit_years),
          estimate_trim_top = fmt(l$att_trim_top), estimate_trim_bottom = fmt(l$att_trim_bottom),
          lee_bracket = paste0("[", fmt(l$lee_lower), ", ", fmt(l$lee_upper), "]"), status = l$status)
        wcsv(l, tf(5, "lee"))
        md <- c(md, "### 5. Lee bounds", "", "Tested share = the subgroup's exact tested count (mean of math and RLA) over its CCD grade 9 membership three years earlier, all-students counts where the race count is unavailable; report-card cells without an exact count give no share. q_T is the treated post-reform share, q_C = q_T minus the Callaway–Sant'Anna effect on the share, p = 1 − q_C / q_T, and the trimming fraction is |p_minority − p_white|, bounded to [0, 1]. The treated post-reform district-years lose that share from the top and, separately, from the bottom of the outcome distribution, and the primary model is refitted each way. The bracket assumes monotone selection.", "", md_table(lt))
      } else md <- c(md, "### 5. Lee bounds", "", if (family == "hs" && gap != "a_poverty")
        paste0("No Lee bounds row for this gap in ", odir("hs", "lee", "lee_bounds.csv"), " (the Lee part has not finished).") else
        if (family == "hs") "Not computed for gap (a) (Run 1, author decision 2026-09-13)." else
        "Not computed for the SEDA gaps: step 14 computes Lee bounds for the high school gaps (b) and (c).", "")
      # 6. estimator agreement
      a6 <- ov6[ov6$gap %in% gap & ov6$event_set %in% "primary", , drop = FALSE]
      st6 <- ms6$status[match(paste(a6$estimator, a6$gap, a6$event_set), paste(ms6$estimator, ms6$gap, ms6$event_set))]
      at <- rbind(data.frame(estimator = "callaway_santanna (primary)", estimate = val(o, fmt(o$att), st0, id0), se = val(b, fmt(b$se), st0, id0),
                             ci = val(b, ci(b$ci_lo, b$ci_hi), st0, id0), status = st1(st0)),
                  if (nrow(a6)) data.frame(estimator = a6$estimator, estimate = fmt(a6$att), se = fmt(a6$se), ci = ci(a6$ci_lo, a6$ci_hi), status = st6))
      wcsv(at, tf(6, "agreement"))
      md <- c(md, "### 6. Estimator agreement (unbalanced panel, primary event set)", "",
              paste0("Secondary intervals are each estimator's own state-clustered or placebo interval; the stacked regression averages event times 0..+5; two-way fixed effects rows are for comparison only. Controls: ",
                     if (family == "hs") "test replacement, CEP and the report-card source indicator (absorbed by the year effects)" else "CEP",
                     if (gap == "a_poverty") "" else ", and the 2009 covariates by year", "."), "", md_table(at))
      # 7. weighted comparison
      if (gap != "a_poverty") {
        wt <- bind(lapply(c("unweighted", "tested_weighted"), function(w) {
          st <- sel(ms5, gap, w = w)$status; id <- mid("primary", w, "unbalanced")
          oo <- sel(ov5, gap, w = w); bb <- sel(bo7, gap, w = w); rr <- sel(ri7, gap, w = w)
          data.frame(weighting = w, estimate = val(oo, fmt(oo$att), st, id), boot_p = val(bb, fmt_p(bb$p_value), st, id),
                     randomization_p = val(rr, fmt_p(rr$p_value), st, id), bound_mbar1 = m1(sel(hd7, gap, w = w), st, id),
                     units = val(oo, oo$treated_units, st, id), status = st1(st)) }))
        wcsv(wt, tf(7, "weighted"))
        md <- c(md, "### 7. Weighted comparison", "", paste0("tested_weighted: ", WEIGHT_TEXT[[family]], ". units = treated units behind the overall average."), "", md_table(wt))
      } else md <- c(md, "### 7. Weighted comparison", "", "Gap (a) is a state-level outcome and has no weighted version (Run 1 Section 7).", "")
      # 8. narrower event definitions
      nt <- bind(lapply(SETS, function(s) { dd <- dose[dose$gap %in% gap & dose$event_set %in% s, , drop = FALSE]
        st <- sel(ms5, gap, s)$status; id <- mid(s, "unweighted", "unbalanced")
        oo <- sel(ov5, gap, s); bb <- sel(bo7, gap, s); rr <- sel(ri7, gap, s)
        data.frame(event_set = s, estimate = val(oo, fmt(oo$att), st, id), boot_ci = val(bb, ci(bb$ci_lo, bb$ci_hi), st, id),
                   boot_p = val(bb, fmt_p(bb$p_value), st, id), randomization_p = val(rr, fmt_p(rr$p_value), st, id),
                   bound_mbar1 = m1(sel(hd7, gap, s), st, id), sd_per_1000 = if (nrow(dd)) fmt(dd$dose_scaled) else "–", status = st1(st)) }))
      wcsv(nt, tf(8, "event_sets"))
      md <- c(md, "### 8. Narrower event definitions", "", "r1 = LRS list plus final state supreme court rulings; r2 = court rulings only.", "", md_table(nt))
      # 9 and 10. variants: Run 1's robustness checks, then the Run 2 splits
      vrow <- function(v) { f <- function(x) x[x$variant %in% v, , drop = FALSE]
        st <- sel(f(vms), gap)$status; id <- mid("primary", "unweighted", "unbalanced", v)
        oo <- sel(f(vov), gap); bb <- sel(f(vbo), gap); rr <- sel(f(vri), gap)
        data.frame(check = RUN2_VARIANTS[[v]]$label, estimate = val(oo, fmt(oo$att), st, id), boot_p = val(bb, fmt_p(bb$p_value), st, id),
                   randomization_p = val(rr, fmt_p(rr$p_value), st, id), randomization_reps = val(rr, rr$reps[1], st, id),
                   bound_mbar1 = m1(sel(f(vhd), gap), st, id), status = st1(st)) }
      stb <- sel(ms5, gap, p = "balanced")$status; idb <- mid("primary", "unweighted", "balanced")
      ob <- sel(ov5, gap, p = "balanced"); bb <- sel(bo7, gap, p = "balanced"); rb <- sel(ri7, gap, p = "balanced")
      bal <- data.frame(check = "Balanced panel (Run 1 Section 7)", estimate = val(ob, fmt(ob$att), stb, idb),
                        boot_p = val(bb, fmt_p(bb$p_value), stb, idb), randomization_p = val(rb, fmt_p(rb$p_value), stb, idb),
                        randomization_reps = val(rb, rb$reps[1], stb, idb), bound_mbar1 = m1(sel(hd7, gap, p = "balanced"), stb, idb),
                        status = st1(stb))
      rt <- rbind(bal, bind(lapply(run2_variants_for(family, split = FALSE), vrow)))
      wcsv(rt, tf(9, "robustness"))
      md <- c(md, "### 9. Run 1 robustness checks (primary event set, unweighted)", "",
              paste0("Variants on all three event sets and both weightings, with event times, Romano–Wolf families and every M̄: ", vd,
                     ". Randomization inference uses 1,000 reassignments on the variants (Section 8)",
                     if (family == "seda") "; the suppression samples and the end-years-2013 variant do not apply to SEDA (Section 10)" else "", "."),
              "", md_table(rt))
      prim <- data.frame(check = if (family == "hs") "Extended panel with the report-card years, 2010–2025 (primary specification)" else
                           "Full SEDA window, 2009–2019 and 2022–2025 (primary specification)",
                         estimate = val(o, fmt(o$att), st0, id0), boot_p = val(b, fmt_p(b$p_value), st0, id0),
                         randomization_p = val(r, fmt_p(r$p_value), st0, id0), randomization_reps = val(r, r$reps[1], st0, id0),
                         bound_mbar1 = m1(h, st0, id0), status = st1(st0))
      sp <- rbind(prim, bind(lapply(run2_variants_for(family, split = TRUE), vrow)))
      wcsv(sp, tf(10, "splits"))
      md <- c(md, "### 10. Run 2 splits (Section 10; primary event set, unweighted)", "",
              if (family == "hs") "The EDFacts-years split is Run 1's window; beside the extended panel it shows the contribution of the report-card years. The coverage split keeps the seventeen states confirmed from the file description in every year." else
                "SEDA's 2022–2025 estimates come from public suppressed state data rather than the restricted-use counts behind 2009–2019; each span is rerun alone, with cohorts coded over its own years.",
              "", md_table(sp))
      # 11. continuous treatment
      cr <- cres[cres$family %in% family & cres$gap %in% gap, , drop = FALSE]
      cm <- cmod[cmod$family %in% family & cmod$gap %in% gap, , drop = FALSE]
      md <- c(md, "### 11. Continuous-treatment estimates (exploratory; step 13, DIDmultiplegtDYN)", "")
      if (nrow(cr)) {
        cr <- cr[order(cr$bin, cr$event_time), , drop = FALSE]
        ct <- data.frame(bin = cr$bin, type = cr$row_type, package_label = cr$package_label, event_time = cr$event_time,
                         estimate = fmt(cr$estimate), se = fmt(cr$se), ci = ci(cr$ci_lo, cr$ci_hi), switchers = cr$switchers,
                         stayers = cr$stayers, stayer_states = cr$stayer_states, status = cr$status)
        wcsv(cr[setdiff(names(cr), "se_caveat")], tf(11, "continuous"))
        mt <- if (nrow(cm)) data.frame(bin = cm$bin, units_with_outcome = cm$units_with_outcome, switchers_used = cm$switchers_used,
                                       switchers_dropped_no_stayer_in_bin = cm$switchers_dropped_no_stayer_in_bin, estimation = cm$estimation) else NULL
        md <- c(md, paste0("Treatment: binned real revenue per pupil (bin_1000 primary, bin_2000 sensitivity), a discrete treatment; effects at event times 0..+8 and placebos at −2..−6, reference −1; an effect or placebo with fewer than 20 stayers or stayers in fewer than 3 states is not estimable. **Caveat:** ",
                            if ("se_caveat" %in% names(cr) && !is.na(cr$se_caveat[1])) cr$se_caveat[1] else CDID_SE_CAVEAT),
                "", if (!is.null(mt)) md_table(mt) else "", md_table(ct))
      } else md <- c(md, paste0("No continuous-treatment rows for this gap in ", file.path(CDID_DIR, "results.csv"), "."), "")
      # the answer as intervals
      hb <- h[!is.na(h$mbar) & h$mbar == HEADLINE_MBAR, , drop = FALSE]
      ans[[paste(family, gap)]] <- data.frame(family = family, gap = gap,
        sd_interval_mbar1 = if (nrow(hb) && hb$status[1] == "ok") paste0("[", fmt(hb$lb), ", ", fmt(hb$ub), "]", blk(hb)) else
          if (!nrow(h)) gone(st0, id0) else paste0("none (", if (nrow(hb)) hb$status[1] else h$status[1], ")"),
        per_1000_interval = if (nrow(d) && !is.na(d$ci_lo)) paste0("[", fmt(d$ci_lo), ", ", fmt(d$ci_hi), "]") else
          if (nrow(d) && startsWith(d$status, "unbounded")) "unbounded (the revenue effect's bootstrap interval includes zero)" else
          paste0("none (", if (nrow(d)) d$status else "no dose row", ")"), stringsAsFactors = FALSE)
      md <- c(md, "### Answer, stated as intervals", "",
              paste0("SD units: honest-DiD bound set at M̄ = 1, ", ans[[paste(family, gap)]]$sd_interval_mbar1,
                     ". Per $1,000 of per-pupil revenue (", CDID_BASE_YEAR, " dollars): ", ans[[paste(family, gap)]]$per_1000_interval,
                     " (percentile interval of the dose-scaled ratio; the first interval rests on bounded departures from parallel trends, the second on parallel trends and the exclusion restriction)."), "")
    }
    if (family == "seda") {
      mde <- rd0(odir("seda", "mde", "mde_descriptive.csv"))
      mt <- if (nrow(mde) && "mde_power_80" %in% names(mde)) data.frame(gap = mde$gap, reassignments = mde$reassignments, draws_ok = mde$draws_ok,
        placebo_sd = fmt(mde$placebo_sd), mde_power_80 = fmt(mde$mde_power_80), mde_normal = fmt(mde$mde_normal), status = mde$status) else
        data.frame(status = "no MDE rows")
      wcsv(mde, file.path(REP, "tables", "seda_mde_descriptive.csv"))
      md <- c(md, "## SEDA design: placebo-based minimum detectable effect (descriptive)", "",
              "For information only (Section 8): no power ceiling applies to Run 2, and this is not a power calculation for a registered test. Placebo distribution: the randomization-inference reassignments of the primary models (primary event set, unweighted, unbalanced), the observed cohort years reassigned among the panel's states. MDE = the smallest shift of the placebo distribution that a test at the 95th percentile of the absolute placebo estimates rejects with probability 0.80; the normal approximation (2.8016 × sd) beside it.",
              "", md_table(mt))
    }
  }
  at <- bind(ans)
  wcsv(at, file.path(REP, "tables", "answer_intervals.csv"))
  md <- c(md[seq_len(n_head)], "## Answer to the research question, by family and gap", "", md_table(at), md[-seq_len(n_head)])
  writeLines(enc2utf8(md), file.path(REP, "report.md"), useBytes = TRUE)
  say("Report: ", file.path(REP, "report.md"), " (", length(list.files(file.path(REP, "plots"))), " plots, ",
      length(list.files(file.path(REP, "tables"))), " tables)")
  say("Report: ", length(missing_models), " models shown with their recorded status in place of numbers",
      if (length(missing_models)) paste0(": ", paste(sort(missing_models), collapse = ", ")) else "")
}
part("report", build_report)

total <- sum(run$times$seconds)
say(sprintf("Run %s finished. Total run time over parts: %.2f h (wall clock since start: %.2f h)", run$run_id, total / 3600,
            as.numeric(difftime(Sys.time(), run$started, units = "hours"))))
say("Run times per part: ", file.path(OUT, "run_times.csv"), "; log: ", log_file)

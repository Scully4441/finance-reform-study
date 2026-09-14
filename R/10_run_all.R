# Step 10. Full run and reporting (design document, Section 13).
# Run from the repository folder:
#   Rscript R/10_run_all.R             a fresh full run: steps 3-7, the robustness variants,
#                                      Lee bounds, dose scaling and the report
#   Rscript R/10_run_all.R --resume    continue an interrupted run: finished steps and
#                                      parts are skipped, and model-level results already
#                                      saved (step 7 randomization, variant fits and
#                                      randomization) are reused
#   Rscript R/10_run_all.R --report    rebuild outputs/13_report/ from the saved outputs
#
# What runs (author decisions 2026-09-13, docs/deviations.md; R/functions/run_all.R):
#   1. Steps 3, 4, 3g, 4g, 5 and 6 (both outcomes), and 7 (both outcomes, registered counts:
#      9,999 bootstrap and Romano-Wolf draws, 10,000 reassignments), each as its own
#      Rscript process; their console output goes to outputs/logs/10_run_all_<step>_<stamp>.txt.
#      Steps 5-7 cover the three event sets; step 5 fits both panel rules and weightings.
#   2. Robustness variants (Sections 5 and 7), one departure each from the primary
#      specification, on all three event sets and both weightings: 5-point and exact-only
#      suppression samples, end years 2013 on (achievement only), cohorts with fewer than
#      three pre-reform years dropped, and did's anticipation = 1 (reference -2; replaces
#      the lawsuit-filing-date version). Section 8 on each: Webb bootstrap and Romano-Wolf
#      at 9,999 draws, HonestDiD at M-bar 0..2, randomization inference at 1,000
#      reassignments (compute deviation). outputs/10_run_all/variants/<outcome>/.
#   3. Lee bounds for gaps (b) and (c) (Section 9). outputs/10_run_all/lee/.
#   4. Dose-scaled estimates, every gap and event set (Section 7). outputs/10_run_all/dose/.
#   5. The Section 13 report for each gap, achievement then graduation, honest-DiD bound
#      sets first (M-bar = 1 the headline): outputs/13_report/report.md, plots/ and tables/.
# Run times per part: outputs/10_run_all/run_times.csv.
# Blinding (CLAUDE.md rule 7): the console shows parts, model counts, unit counts and
# timings. Estimates go to the files; no file written here carries a treatment year.

for (f in list.files("R/functions", full.names = TRUE)) source(f)

# Every process started from here (the step scripts and the 12 future workers of steps 7 and
# 10) inherits this. With renv active, R processes started together queue on renv's sandbox
# lock, 11 of 12 workers missed future's 125-second connect timeout, and the lock was left
# stale for every later R process (2026-09-13 and 2026-09-14). The sandbox only hides the
# packages of R's system library; the renv project library still comes first, so the
# package versions are those of renv.lock.
Sys.setenv(RENV_CONFIG_SANDBOX_ENABLED = "FALSE")

args <- commandArgs(trailingOnly = TRUE)
RESUME <- "--resume" %in% args
REPORT_ONLY <- "--report" %in% args
stage <- as.integer(readLines("data/stage.txt", n = 1, warn = FALSE))
if (!identical(stage, 2L)) stop("step 10 reads the full window, which needs stage 2")
BLINDING <- readLines("data/reference/blinding_status.txt", n = 1, warn = FALSE)
WORKERS <- 12L
OUT <- "outputs/10_run_all"
REP <- "outputs/13_report"
OUTCOMES <- c("achievement", "graduation")
BOOT_REPS <- 9999L

stamp <- format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/logs", recursive = TRUE, showWarnings = FALSE)
log_file <- file.path("outputs", "logs", paste0("10_run_all_", stamp, ".log"))
say <- function(...) {
  txt <- paste0(format(Sys.time(), "%H:%M:%S"), "  ", ...)
  cat(txt, "\n", sep = "")
  cat(txt, "\n", sep = "", file = log_file, append = TRUE)
}
wcsv <- function(x, f) { dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, f, row.names = FALSE, na = "") }
rcsv <- function(f) utils::read.csv(f, stringsAsFactors = FALSE, na.strings = "")
bind <- function(x) { y <- do.call(rbind, x); if (!is.null(y)) rownames(y) <- NULL; y }

# ---- run state: which parts are finished, for --resume -------------------------------------
state_file <- file.path(OUT, "run_state.rds")
if (RESUME || REPORT_ONLY) {
  if (!file.exists(state_file)) stop("no run to resume: ", state_file, " not found")
  run <- readRDS(state_file)
} else {
  unlink(c(file.path(OUT, "cache"), file.path(OUT, "variants"), file.path(OUT, "lee"), file.path(OUT, "dose")),
         recursive = TRUE)
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

say("Step 10 run-all, run ", run$run_id, if (RESUME) " (resumed)" else "", "; stage ", stage, "; blinding ", BLINDING)
say("Console: parts, model and unit counts, timings. Estimates: ", OUT, " and ", REP)

# ---- 1. steps 3-7 ------------------------------------------------------------------------------
STEPS <- list(
  "03_sample"              = "R/03_sample.R",
  "04_outcomes"            = "R/04_outcomes.R",
  "03g_graduation_sample"  = "R/03g_graduation_sample.R",
  "04g_graduation_outcomes"= "R/04g_graduation_outcomes.R",
  "05_primary"             = "R/05_primary.R",
  "05_primary_graduation"  = c("R/05_primary.R", "--outcome", "graduation"),
  "06_secondary"           = "R/06_secondary.R",
  "06_secondary_graduation"= c("R/06_secondary.R", "--outcome", "graduation"),
  "07_inference"           = c("R/07_inference.R", "--cache-dir", file.path(OUT, "cache", "07_inference")),
  "07_inference_graduation"= c("R/07_inference.R", "--outcome", "graduation", "--cache-dir",
                               file.path(OUT, "cache", "07_inference_graduation")))
if (!REPORT_ONLY) for (id in names(STEPS)) part(paste0("step ", id), function() {
  con <- file.path("outputs", "logs", paste0("10_run_all_", id, "_", stamp, ".txt"))
  status <- system2("Rscript", STEPS[[id]], stdout = con, stderr = con)
  if (!identical(as.integer(status), 0L)) stop(id, " failed (exit ", status, "); console output in ", con)
})

# ---- 2. robustness variants ------------------------------------------------------------------
run_variants <- function(outcome) {
  vdir <- file.path(OUT, "variants", outcome)
  fdir <- file.path(vdir, "fits"); rdir <- file.path(vdir, "ri")
  dir.create(fdir, recursive = TRUE, showWarnings = FALSE); dir.create(rdir, recursive = TRUE, showWarnings = FALSE)
  inp <- load_cs_inputs(outcome)
  gaps <- outcome_gaps(outcome)
  grid <- do.call(rbind, lapply(variants_for(outcome), function(v) do.call(rbind, lapply(names(EVENT_FILES), function(s)
    do.call(rbind, lapply(gaps, function(g) data.frame(variant = v, gap = g, event_set = s,
      weighting = if (g == "a_poverty") "unweighted" else c("unweighted", "tested_weighted"), stringsAsFactors = FALSE)))))))
  grid$key <- paste(grid$gap, grid$event_set, grid$weighting, grid$variant, sep = ".")
  say(outcome, " variants: ", nrow(grid), " models (", length(variants_for(outcome)), " variants x 3 event sets x gaps and weightings)")

  res <- list()
  for (i in seq_len(nrow(grid))) {
    k <- grid$key[i]; f <- file.path(fdir, paste0(k, ".rds"))
    if (file.exists(f)) { res[[k]] <- readRDS(f); next }
    vs <- VARIANTS[[grid$variant[i]]]
    mp <- cs_model_panel(inp, grid$gap[i], grid$event_set[i], sample = vs$sample, from_year = vs$from_year,
                         drop_few_pre = vs$drop_few_pre, weighting = grid$weighting[i])
    fit <- run_cs(mp$panel, xformla = mp$xformla, weightsname = mp$weightsname,
                  seed_step = paste("10_run_all", outcome, k), allow_unbalanced_panel = TRUE, anticipation = vs$anticipation)
    r <- c(as.list(grid[i, c("variant", "gap", "event_set", "weighting")]),
           list(panel = "unbalanced", ref = -1L - vs$anticipation, status = fit$status, notes = paste(unique(fit$notes), collapse = " | "),
                event = fit$event, overall = fit$overall, fit = fit$fit,
                size = data.frame(units_in_model = mp$units, states_in_model = mp$states,
                                  states_dropped_few_pre = mp$states_dropped_few_pre, unit_years = nrow(mp$panel))))
    saveRDS(r, f)
    res[[k]] <- r
    say(sprintf("  fit %-19s %-7s %-15s %-24s %5d units %2d states  %s", grid$gap[i], grid$event_set[i],
                grid$weighting[i], grid$variant[i], mp$units, mp$states, if (fit$status == "ok") "ok" else "not ok (status in files)"))
  }
  tag <- function(k, x) if (!is.null(x) && nrow(x)) data.frame(variant = res[[k]]$variant, gap = res[[k]]$gap,
    event_set = res[[k]]$event_set, weighting = res[[k]]$weighting, panel = "unbalanced", x, row.names = NULL, stringsAsFactors = FALSE)

  bo <- list(); be <- list(); hd <- list(); rw <- list(); tb <- list()
  for (v in variants_for(outcome)) for (s in names(EVENT_FILES)) {
    ks <- grid$key[grid$variant == v & grid$event_set == s]
    fits <- lapply(res[ks], function(r) list(fit = r$fit, ref = r$ref))
    inf <- infer_fits(fits, paste("10_run_all", outcome, v, "bootstrap", s), BOOT_REPS)
    for (k in names(inf$overall)) {
      bo[[k]] <- tag(k, inf$overall[[k]]); be[[k]] <- tag(k, inf$event[[k]]); hd[[k]] <- tag(k, inf$honest[[k]])
      tb[[k]] <- inf$t_boot[[k]]
    }
    for (fam in c("unweighted", "tested_weighted")) {
      pick <- vapply(gaps, function(g) { w <- if (g == "a_poverty") "unweighted" else fam
        k <- paste(g, s, w, v, sep = "."); if (!is.null(tb[[k]])) k else NA_character_ }, "")
      pick <- pick[!is.na(pick)]
      if (length(pick) < 2L) next
      to <- vapply(pick, function(k) bo[[k]]$t, 0)
      pa <- rw_stepdown(to, do.call(cbind, tb[pick]))
      rw[[paste(v, s, fam)]] <- data.frame(variant = v, event_set = s, panel = "unbalanced", family = fam,
        gap = vapply(pick, function(k) res[[k]]$gap, ""), weighting = vapply(pick, function(k) res[[k]]$weighting, ""),
        t = to, p_unadjusted = vapply(pick, function(k) bo[[k]]$p_value, 0), p_romano_wolf = pa,
        hypotheses = length(pick), reps = BOOT_REPS, row.names = NULL, stringsAsFactors = FALSE)
    }
  }
  say(outcome, " variants: bootstrap, Romano-Wolf and HonestDiD done for ", length(bo), " fitted models")

  ri <- list(); rid <- list()
  ok <- names(res)[vapply(res, function(r) !is.null(r$fit), TRUE)]
  t0 <- Sys.time()
  for (k in ok) {
    r <- ri_cached(res[[k]]$fit, RI_REPS_VARIANT, paste("10_run_all", outcome, "randomization", k), file.path(rdir, paste0(k, ".rds")))
    v <- r$values[is.finite(r$values)]
    ri[[k]] <- tag(k, data.frame(att = res[[k]]$overall$att, p_value = r$p_value, reps = as.integer(r$reps),
      draws_ok = as.integer(r$draws_ok), treated_states = as.integer(r$treated_states), eligible_states = as.integer(r$eligible_states),
      placebo_sd = if (length(v) > 1) stats::sd(v) else NA_real_, status = r$status, stringsAsFactors = FALSE))
    if (length(r$values)) rid[[k]] <- tag(k, data.frame(draw = seq_along(r$values), att = r$values))
  }
  say(sprintf("%s variants: randomization inference (%d reassignments) on %d models, %.1f min", outcome, RI_REPS_VARIANT,
              length(ok), as.numeric(difftime(Sys.time(), t0, units = "mins"))))

  wcsv(bind(lapply(names(res), function(k) tag(k, res[[k]]$overall))), file.path(vdir, "overall_estimates.csv"))
  wcsv(bind(lapply(names(res), function(k) tag(k, res[[k]]$event))), file.path(vdir, "event_time_estimates.csv"))
  wcsv(bind(lapply(names(res), function(k) tag(k, data.frame(status = res[[k]]$status, notes = res[[k]]$notes)))),
       file.path(vdir, "model_status.csv"))
  wcsv(bind(lapply(names(res), function(k) tag(k, res[[k]]$size))), file.path(vdir, "panel_counts.csv"))
  wcsv(bind(bo), file.path(vdir, "bootstrap_overall.csv")); wcsv(bind(be), file.path(vdir, "bootstrap_event_time.csv"))
  wcsv(bind(hd), file.path(vdir, "honestdid_overall.csv")); wcsv(bind(rw), file.path(vdir, "romano_wolf.csv"))
  wcsv(bind(ri), file.path(vdir, "randomization_overall.csv")); wcsv(bind(rid), file.path(vdir, "randomization_draws.csv"))
  wcsv(data.frame(setting = c("run", "outcome", "blinding", "bootstrap_reps", "romano_wolf_reps", "randomization_reps", "mbar", "workers"),
                  value = c(run$run_id, outcome, BLINDING, BOOT_REPS, BOOT_REPS, RI_REPS_VARIANT, paste(MBAR_GRID, collapse = " "), WORKERS)),
       file.path(vdir, "inference_settings.csv"))
}

# ---- 3. Lee bounds -------------------------------------------------------------------------------
run_lee <- function() {
  ldir <- file.path(OUT, "lee"); dir.create(ldir, recursive = TRUE, showWarnings = FALSE)
  g9_file <- file.path(OUT, "cache", "ccd_grade9_district.csv")
  share_years <- ACH_WINDOW[ACH_WINDOW - LEE_LAG >= 2010L]
  if (file.exists(g9_file)) g9 <- utils::read.csv(g9_file, colClasses = c(leaid = "character"), stringsAsFactors = FALSE) else {
    td <- tempfile("ccdg9"); dir.create(td); on.exit(unlink(td, recursive = TRUE), add = TRUE)
    g9 <- bind(lapply(share_years - LEE_LAG, function(y) {
      t0 <- Sys.time(); p <- ccd_membership_file(y, td)
      x <- ccd_grade9_district(p, y); unlink(p)
      say(sprintf("  CCD grade 9 membership, end year %d: %d districts, %.1f min", y, nrow(x),
                  as.numeric(difftime(Sys.time(), t0, units = "mins")))); x }))
    wcsv(g9, g9_file)
  }
  cols <- c("leaid", "sy_end", as.vector(outer(c("n_math_", "n_rla_"), c("all", "wh", "bl", "hi"), paste0)))
  smp <- data.table::fread("data/derived/sample_district_year.csv", select = cols, colClasses = c(leaid = "character"),
                           data.table = FALSE, showProgress = FALSE)
  inp <- load_cs_inputs("achievement")
  ov5 <- rcsv("outputs/05_primary/overall_estimates.csv")
  rows <- list(); share_rows <- list()
  for (gap in c("b_black_white", "c_hispanic_white")) {
    mp <- cs_model_panel(inp, gap, "primary")
    base <- mp$panel
    sgs <- RACE_GAPS[[race_key("achievement", gap)]]
    effects <- c()
    for (sg in sgs) {
      sp <- lee_share_panel(base, smp, g9, sg, share_years)
      fs <- run_cs(sp, xformla = mp$xformla, seed_step = paste("10_run_all lee share", gap, sg), allow_unbalanced_panel = TRUE)
      effects[sg] <- if (fs$status == "ok") fs$overall$att else NA_real_
      share_rows[[paste(gap, sg)]] <- data.frame(gap = gap, subgroup = sg, status = fs$status, att_share = fs$overall$att,
        se = fs$overall$se, units = length(unique(sp$id)), unit_years = nrow(sp), share_years_from = min(sp$sy_end),
        fallback_share = mean(sp$fallback), mean_share = mean(sp$y), notes = paste(unique(fs$notes), collapse = " | "),
        stringsAsFactors = FALSE)
      say(sprintf("  Lee share model %-17s %s: %d districts, %s", gap, sg, length(unique(sp$id)), fs$status))
    }
    frac <- if (all(is.na(effects))) NA_real_ else min(max(abs(effects), na.rm = TRUE), 1)
    prim <- run_cs(base, xformla = mp$xformla, seed_step = paste("10_run_all lee primary", gap), allow_unbalanced_panel = TRUE)
    k5 <- ov5$gap == gap & ov5$event_set == "primary" & ov5$weighting == "unweighted" & ov5$panel == "unbalanced"
    stopifnot(isTRUE(all.equal(prim$overall$att, ov5$att[k5])))   # the rebuilt panel is step 5's
    trims <- lapply(c(top = "top", bottom = "bottom"), function(side) {
      tr <- lee_trim(base, if (is.na(frac)) 0 else frac, side)
      ft <- run_cs(tr$panel, xformla = mp$xformla, seed_step = paste("10_run_all lee trim", gap, side), allow_unbalanced_panel = TRUE)
      list(att = ft$overall$att, status = ft$status, removed = tr$removed, treated_post = tr$treated_post)
    })
    est <- c(trims$top$att, trims$bottom$att)
    rows[[gap]] <- data.frame(gap = gap, event_set = "primary", weighting = "unweighted", panel = "unbalanced",
      att_primary = prim$overall$att, effect_share_minority = unname(effects[sgs[1]]), effect_share_white = unname(effects["wh"]),
      trim_fraction = frac, treated_post_unit_years = trims$top$treated_post, trimmed_unit_years = trims$top$removed,
      att_trim_top = trims$top$att, att_trim_bottom = trims$bottom$att,
      lee_lower = if (all(is.na(est))) NA_real_ else min(est, na.rm = TRUE), lee_upper = if (all(is.na(est))) NA_real_ else max(est, na.rm = TRUE),
      status = if (is.na(frac)) "no share effect estimated" else if (trims$top$status == "ok" && trims$bottom$status == "ok") "ok" else
        paste("trim refit:", trims$top$status, "/", trims$bottom$status), stringsAsFactors = FALSE)
  }
  wcsv(bind(rows), file.path(ldir, "lee_bounds.csv"))
  wcsv(bind(share_rows), file.path(ldir, "lee_share_models.csv"))
  wcsv(data.frame(sy_end = sort(unique(g9$sy_end)), districts = as.vector(table(g9$sy_end)),
                  race_unavailable_bl = as.vector(tapply(is.na(g9$g9_bl), g9$sy_end, sum)),
                  race_unavailable_wh = as.vector(tapply(is.na(g9$g9_wh), g9$sy_end, sum)),
                  race_unavailable_hi = as.vector(tapply(is.na(g9$g9_hi), g9$sy_end, sum))),
       file.path(ldir, "ccd_grade9_coverage.csv"))
}

# ---- 4. dose scaling ------------------------------------------------------------------------------
run_dose <- function(outcome) {
  ddir <- file.path(OUT, "dose", outcome); dir.create(ddir, recursive = TRUE, showWarnings = FALSE)
  window <- outcome_window(outcome)
  rev <- real_revenue(read_f33_revenue(window))
  sdir <- if (outcome == "achievement") "outputs/07_inference" else "outputs/07_inference/graduation"
  st7 <- rcsv(file.path(sdir, "inference_settings.csv"))
  reps7 <- as.integer(st7$value[st7$setting == "bootstrap_reps"])
  s7 <- step7_draws(outcome, reps7)
  inp <- load_cs_inputs(outcome)
  if (outcome == "achievement") {
    smp <- data.table::fread("data/derived/sample_district_year.csv",
      select = c("leaid", "state", "sy_end", "retained", "retained_r1", "retained_r2", "pov_quintile_2009"),
      colClasses = c(leaid = "character"), data.table = FALSE, showProgress = FALSE)
    td <- tempfile("ccd"); dir.create(td)
    m09 <- read_ccd_lea(utils::unzip("data/raw/ccd/lea-directory-sy2009-10.zip", exdir = td), 2010L, extra = "MEMBER")
    smp$member_2009 <- ccd_count(m09$member)[match(smp$leaid, m09$leaid)]
  }
  rows <- list(); fs_ev <- list(); fs_ov <- list()
  for (s in names(EVENT_FILES)) for (gap in outcome_gaps(outcome)) {
    key <- paste(gap, s, "unweighted", "unbalanced", sep = ".")
    inf_y <- s7$infs[[key]]
    mp <- cs_model_panel(inp, gap, s)
    rp <- if (gap == "a_poverty") pov_revenue_panel(smp, RETAIN_FLAGS[[s]], rev, window, mp$panel) else
      dist_revenue_panel(mp$panel, rev, window)
    fr <- run_cs(rp, xformla = mp$xformla, seed_step = paste("10_run_all dose", outcome, key), allow_unbalanced_panel = TRUE)
    inf_r <- cs_influence(fr$fit)
    say(sprintf("  revenue first stage %-19s %-7s %5d units, %s", gap, s, length(unique(rp$id)), fr$status))
    fs_ev[[key]] <- data.frame(gap = gap, event_set = s, fr$event, stringsAsFactors = FALSE)
    rb <- if (!is.null(inf_r) && !is.null(s7$draws[[s]])) wcb_test(inf_r$overall_att, inf_r$scores[, "overall"], inf_r$n,
            s7$draws[[s]]$w[, match(inf_r$states, s7$draws[[s]]$states), drop = FALSE])$row else NULL
    fs_ov[[key]] <- data.frame(gap = gap, event_set = s, status = fr$status, fr$overall,
      boot_p_value = if (is.null(rb)) NA_real_ else rb$p_value, units_in_model = length(unique(rp$id)),
      unit_years = nrow(rp), notes = paste(unique(fr$notes), collapse = " | "), stringsAsFactors = FALSE)
    d <- if (is.null(inf_y) || is.null(inf_r)) data.frame(att_outcome = NA_real_, att_revenue = NA_real_,
           revenue_ci_lo = NA_real_, revenue_ci_hi = NA_real_, dose_scaled = NA_real_, ci_lo = NA_real_, ci_hi = NA_real_,
           percentile_lo = NA_real_, percentile_hi = NA_real_, share_draws_revenue_sign_flip = NA_real_, reps = reps7,
           status = if (is.null(inf_y)) "no step 5 influence function" else paste("revenue model:", fr$status)) else
         dose_ratio(inf_y, inf_r, s7$draws[[s]])
    rows[[key]] <- data.frame(gap = gap, event_set = s, weighting = "unweighted", panel = "unbalanced", d,
                              revenue_units = "thousands of 2021 dollars per pupil", stringsAsFactors = FALSE)
  }
  wcsv(bind(rows), file.path(ddir, "dose_scaled.csv"))
  wcsv(bind(fs_ov), file.path(ddir, "revenue_first_stage_overall.csv"))
  wcsv(bind(fs_ev), file.path(ddir, "revenue_first_stage_event_time.csv"))
}

if (!REPORT_ONLY) {
  future::plan(future::multisession, workers = WORKERS)
  for (o in OUTCOMES) part(paste("variants", o), function() run_variants(o))
  future::plan(future::sequential)
  part("lee bounds", run_lee)
  for (o in OUTCOMES) part(paste("dose", o), function() run_dose(o))
}

# ---- 5. report --------------------------------------------------------------------------------------
GAP_TITLES <- c(a_poverty = "Gap (a): between-district poverty-quintile gap",
                b_black_white = "Gap (b): within-district Black–White gap",
                c_hispanic_white = "Gap (c): within-district Hispanic–White gap",
                grad_black_white = "Graduation: within-district Black–White gap in the four-year graduation rate",
                grad_hispanic_white = "Graduation: within-district Hispanic–White gap in the four-year graduation rate")

build_report <- function() {
  unlink(REP, recursive = TRUE)
  dir.create(file.path(REP, "plots"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(REP, "tables"), recursive = TRUE, showWarnings = FALSE)
  lee <- rcsv(file.path(OUT, "lee", "lee_bounds.csv"))
  md <- c("# Section 13 report", "",
          paste0("Run ", run$run_id, "; blinding status **", BLINDING, "**",
                 if (BLINDING != "REAL") " — the event tables are permuted, so every estimate below is a rehearsal and carries no information about the reforms." else "."),
          "",
          "The study is registered as a bounds analysis (Section 10). For each gap the honest-DiD bound sets come first; the headline is the bound set at M̄ = 1, and all five M̄ values are shown. Point estimates, p-values and intervals are reported as quantities, and no result is described as statistically significant.",
          "",
          "Primary specification: Callaway–Sant'Anna, not-yet-treated controls, doubly robust, unbalanced panel, primary suppression sample, reference period −1, primary event set, unweighted. Event-time and overall intervals are Webb wild cluster bootstrap intervals (9,999 draws, state clusters).",
          "")
  ans <- list()
  for (outcome in OUTCOMES) {
    s5 <- if (outcome == "achievement") "outputs/05_primary" else "outputs/05_primary/graduation"
    s6 <- if (outcome == "achievement") "outputs/06_secondary" else "outputs/06_secondary/graduation"
    s7 <- if (outcome == "achievement") "outputs/07_inference" else "outputs/07_inference/graduation"
    vd <- file.path(OUT, "variants", outcome)
    ev5 <- rcsv(file.path(s5, "event_time_estimates.csv")); ov5 <- rcsv(file.path(s5, "overall_estimates.csv"))
    ms5 <- rcsv(file.path(s5, "model_status.csv"))
    bo7 <- rcsv(file.path(s7, "bootstrap_overall.csv")); be7 <- rcsv(file.path(s7, "bootstrap_event_time.csv"))
    ri7 <- rcsv(file.path(s7, "randomization_overall.csv")); rw7 <- rcsv(file.path(s7, "romano_wolf.csv"))
    hd7 <- rcsv(file.path(s7, "honestdid_overall.csv"))
    ov6 <- rcsv(file.path(s6, "overall_estimates.csv")); ms6 <- rcsv(file.path(s6, "model_status.csv"))
    vov <- rcsv(file.path(vd, "overall_estimates.csv")); vbo <- rcsv(file.path(vd, "bootstrap_overall.csv"))
    vri <- rcsv(file.path(vd, "randomization_overall.csv")); vhd <- rcsv(file.path(vd, "honestdid_overall.csv"))
    vms <- rcsv(file.path(vd, "model_status.csv")); vrw <- rcsv(file.path(vd, "romano_wolf.csv"))
    dose <- rcsv(file.path(OUT, "dose", outcome, "dose_scaled.csv"))
    md <- c(md, paste0("# ", if (outcome == "achievement") "Primary achievement gaps" else
      "Secondary outcome: graduation-rate gaps (reported after the primary gaps)"), "")
    sel <- function(d, g, s = "primary", w = "unweighted", p = "unbalanced")
      d[d$gap == g & d$event_set == s & d$weighting == w & d$panel == p, , drop = FALSE]
    m1 <- function(h) { r <- h[!is.na(h$mbar) & h$mbar == HEADLINE_MBAR, , drop = FALSE]
      if (!nrow(r)) return(if (nrow(h)) paste0("no bound (", h$status[1], ")") else "no bound (no HonestDiD row)")
      if (r$status[1] != "ok") return(paste0("no bound (", r$status[1], ")"))
      paste0("[", fmt(r$lb[1]), ", ", fmt(r$ub[1]), "]") }
    for (gap in outcome_gaps(outcome)) {
      md <- c(md, paste0("## ", GAP_TITLES[[gap]]), "")
      h <- sel(hd7, gap)
      # 1. honest-DiD bound sets
      ht <- data.frame(`M̄` = ifelse(!is.na(h$mbar), formatC(h$mbar, format = "g"),
                                    ifelse(h$method %in% "original", "original CS (no restriction)", "–")),
                       lower = fmt(h$lb), upper = fmt(h$ub), status = h$status,
                       headline = ifelse(!is.na(h$mbar) & h$mbar == HEADLINE_MBAR, "**headline**", ""), check.names = FALSE)
      wcsv(h, file.path(REP, "tables", paste0(gap, "_1_honestdid.csv")))
      md <- c(md, "### 1. Honest-DiD bound sets (relative magnitudes, overall post-reform average)", "", md_table(ht))
      # 2. event-study plot
      ev <- sel(be7, gap); e5 <- sel(ev5, gap)
      ev$cohorts <- e5$cohorts[match(ev$e, e5$e)]; ev$treated_states <- e5$treated_states[match(ev$e, e5$e)]
      ev$treated_units <- e5$treated_units[match(ev$e, e5$e)]
      ev$att[is.na(ev$att)] <- e5$att[match(ev$e[is.na(ev$att)], e5$e)]
      o <- sel(ov5, gap)
      png_name <- paste0(gap, "_event_study.png")
      plot_event_study(file.path(REP, "plots", png_name), ev, if (nrow(o)) o$att else NA_real_, h, GAP_TITLES[[gap]])
      et <- data.frame(event_time = ev$e, estimate = fmt(ev$att), boot_ci = ifelse(is.na(ev$ci_lo), "–",
        paste0("[", fmt(ev$ci_lo), ", ", fmt(ev$ci_hi), "]")), boot_p = fmt_p(ev$p_value), cohorts = ev$cohorts,
        treated_states = ev$treated_states, treated_units = ev$treated_units, reference = ifelse(ev$reference, "ref", ""))
      names(ev)[names(ev) == "t"] <- "t_stat"      # the bootstrap t-statistic, not a time
      wcsv(ev, file.path(REP, "tables", paste0(gap, "_2_event_study.csv")))
      md <- c(md, "### 2. Event study with honest-DiD bounds and cohorts per coefficient", "",
              paste0("![event study](plots/", png_name, ")"), "", md_table(et))
      # 3. overall with bootstrap and RI p-values
      b <- sel(bo7, gap); r <- sel(ri7, gap); rw <- rw7[rw7$gap == gap & rw7$event_set == "primary" &
                                                   rw7$panel == "unbalanced" & rw7$family == "unweighted", , drop = FALSE]
      ot <- data.frame(estimate = fmt(o$att), clustered_se = fmt(b$se), boot_ci = paste0("[", fmt(b$ci_lo), ", ", fmt(b$ci_hi), "]"),
                       boot_p = fmt_p(b$p_value), randomization_p = fmt_p(r$p_value), randomization_reps = r$reps,
                       romano_wolf_p = fmt_p(if (nrow(rw)) rw$p_romano_wolf else NA), cohorts = o$cohorts,
                       treated_states = o$treated_states, model_status = sel(ms5, gap)$status)
      wcsv(ot, file.path(REP, "tables", paste0(gap, "_3_overall.csv")))
      md <- c(md, "### 3. Overall post-reform average", "", md_table(ot))
      # 4. dose-scaled
      d <- dose[dose$gap == gap & dose$event_set == "primary", , drop = FALSE]
      dt <- data.frame(effect_sd = fmt(d$att_outcome), revenue_effect = fmt(d$att_revenue),
        revenue_boot_ci = paste0("[", fmt(d$revenue_ci_lo), ", ", fmt(d$revenue_ci_hi), "]"),
        sd_per_1000 = fmt(d$dose_scaled), interval_per_1000 = ifelse(is.na(d$ci_lo), "unbounded", paste0("[", fmt(d$ci_lo), ", ", fmt(d$ci_hi), "]")),
        status = d$status)
      wcsv(d, file.path(REP, "tables", paste0(gap, "_4_dose.csv")))
      md <- c(md, "### 4. Dose-scaled estimate (per $1,000 of per-pupil state-plus-local revenue, 2021 dollars)", "",
        paste0("Revenue effect: the same Callaway–Sant'Anna model with F-33 (TSTREV + TLOCREV) / V33 in thousands of 2021 dollars as the outcome",
               if (gap == "a_poverty") " (the 2009-10 membership-weighted top-minus-bottom poverty-quintile gap in revenue per pupil)" else " (district revenue per pupil)",
               ". The dose-scaled estimate is the ratio of the two overall effects (the Wald form of the two-stage estimate), with a percentile interval from the step 7 Webb draws applied to both. **Assumption:** the reform affects the gap only through revenue (exclusion restriction); accountability or other provisions enacted with a reform would violate it. The assumption is stated, not tested."),
        "", md_table(dt))
      # 5. Lee bounds
      if (gap %in% lee$gap) {
        l <- lee[lee$gap == gap, ]
        lt <- data.frame(effect_on_tested_share_minority = fmt(l$effect_share_minority, 4), effect_on_tested_share_white = fmt(l$effect_share_white, 4),
          trim_fraction = fmt(l$trim_fraction, 4), trimmed_of_treated_post = paste0(l$trimmed_unit_years, " of ", l$treated_post_unit_years),
          estimate_trim_top = fmt(l$att_trim_top), estimate_trim_bottom = fmt(l$att_trim_bottom),
          lee_bracket = paste0("[", fmt(l$lee_lower), ", ", fmt(l$lee_upper), "]"), status = l$status)
        wcsv(l, file.path(REP, "tables", paste0(gap, "_5_lee.csv")))
        md <- c(md, "### 5. Lee bounds", "", "Tested share = the subgroup's tested count (mean of math and RLA) over its CCD grade 9 membership three years earlier, all-students counts where race-by-grade membership is unavailable; end years 2013 on (the CCD files begin with 2009-10). Trim fraction = the larger absolute effect on the two shares; the treated post-reform district-years are trimmed from the top and from the bottom and the primary model refitted. The bracket assumes monotone selection.", "", md_table(lt))
      } else md <- c(md, "### 5. Lee bounds", "", if (outcome == "graduation") "Not computed for the graduation gaps: dropout is part of the outcome itself (author decision 2026-09-13)." else
        "Not computed for gap (a) (author decision 2026-09-13).", "")
      # 6. estimator agreement
      a6 <- ov6[ov6$gap == gap & ov6$event_set == "primary", , drop = FALSE]
      st6 <- ms6$status[match(paste(a6$estimator, a6$gap, a6$event_set), paste(ms6$estimator, ms6$gap, ms6$event_set))]
      at <- rbind(data.frame(estimator = "callaway_santanna (primary)", estimate = fmt(o$att), se = fmt(b$se),
                             ci = paste0("[", fmt(b$ci_lo), ", ", fmt(b$ci_hi), "]"), status = sel(ms5, gap)$status),
                  data.frame(estimator = a6$estimator, estimate = fmt(a6$att), se = fmt(a6$se),
                             ci = paste0("[", fmt(a6$ci_lo), ", ", fmt(a6$ci_hi), "]"), status = st6))
      wcsv(at, file.path(REP, "tables", paste0(gap, "_6_agreement.csv")))
      md <- c(md, "### 6. Estimator agreement (unbalanced panel, primary event set)", "",
              "Secondary intervals are each estimator's own state-clustered or placebo interval; the stacked regression averages event times 0..+5; two-way fixed effects rows are for comparison only.", "", md_table(at))
      # 7. weighted comparison
      if (gap != "a_poverty") {
        wt <- do.call(rbind, lapply(c("unweighted", "tested_weighted"), function(w) data.frame(weighting = w,
          estimate = fmt(sel(ov5, gap, w = w)$att), boot_p = fmt_p(sel(bo7, gap, w = w)$p_value),
          randomization_p = fmt_p(sel(ri7, gap, w = w)$p_value), bound_mbar1 = m1(sel(hd7, gap, w = w)),
          units = sel(ov5, gap, w = w)$treated_units, status = sel(ms5, gap, w = w)$status)))
        wcsv(wt, file.path(REP, "tables", paste0(gap, "_7_weighted.csv")))
        md <- c(md, "### 7. Weighted comparison", "", paste0("tested_weighted: ", if (outcome == "achievement")
          "students tested in the gap's two groups in 2009-10, mean of math and RLA" else "2010-11 cohort count in the gap's two groups", ", fixed. units = treated units behind the overall average."), "", md_table(wt))
      } else md <- c(md, "### 7. Weighted comparison", "", "Gap (a) is a state-level outcome and has no weighted version (Section 7).", "")
      # 8. narrower event definitions
      nt <- do.call(rbind, lapply(names(EVENT_FILES), function(s) { dd <- dose[dose$gap == gap & dose$event_set == s, ]
        data.frame(event_set = s, estimate = fmt(sel(ov5, gap, s)$att),
          boot_ci = paste0("[", fmt(sel(bo7, gap, s)$ci_lo), ", ", fmt(sel(bo7, gap, s)$ci_hi), "]"),
          boot_p = fmt_p(sel(bo7, gap, s)$p_value), randomization_p = fmt_p(sel(ri7, gap, s)$p_value),
          bound_mbar1 = m1(sel(hd7, gap, s)), sd_per_1000 = fmt(dd$dose_scaled), status = sel(ms5, gap, s)$status) }))
      wcsv(nt, file.path(REP, "tables", paste0(gap, "_8_event_sets.csv")))
      md <- c(md, "### 8. Narrower event definitions", "", "r1 = LRS list plus final state supreme court rulings; r2 = court rulings only.", "", md_table(nt))
      # 9. robustness variants
      bal <- data.frame(check = "Balanced panel (Section 7)", estimate = fmt(sel(ov5, gap, p = "balanced")$att),
        boot_p = fmt_p(sel(bo7, gap, p = "balanced")$p_value), randomization_p = fmt_p(sel(ri7, gap, p = "balanced")$p_value),
        randomization_reps = sel(ri7, gap, p = "balanced")$reps[1], bound_mbar1 = m1(sel(hd7, gap, p = "balanced")),
        status = sel(ms5, gap, p = "balanced")$status)
      vt <- do.call(rbind, lapply(variants_for(outcome), function(v) { f <- function(x) x[x$variant == v, , drop = FALSE]
        data.frame(check = VARIANTS[[v]]$label, estimate = fmt(sel(f(vov), gap)$att), boot_p = fmt_p(sel(f(vbo), gap)$p_value),
          randomization_p = fmt_p(sel(f(vri), gap)$p_value), randomization_reps = sel(f(vri), gap)$reps[1],
          bound_mbar1 = m1(sel(f(vhd), gap)), status = sel(f(vms), gap)$status) }))
      rt <- rbind(bal, vt)
      rt$randomization_reps[is.na(rt$randomization_reps)] <- "–"
      wcsv(rt, file.path(REP, "tables", paste0(gap, "_9_robustness.csv")))
      md <- c(md, "### 9. Registered robustness checks (primary event set, unweighted)", "",
              "Variants on all three event sets and both weightings, with event times, Romano–Wolf families and every M̄: outputs/10_run_all/variants/. Randomization inference uses 1,000 reassignments on the variants (compute deviation, 2026-09-13).", "", md_table(rt))
      # the answer as intervals
      hb <- h[!is.na(h$mbar) & h$mbar == HEADLINE_MBAR, , drop = FALSE]
      ans[[gap]] <- data.frame(gap = gap, outcome = outcome,
        sd_interval_mbar1 = if (nrow(hb) && hb$status[1] == "ok") paste0("[", fmt(hb$lb), ", ", fmt(hb$ub), "]") else
          paste0("none (", if (nrow(hb)) hb$status[1] else "no bound", ")"),
        per_1000_interval = if (nrow(d) && !is.na(d$ci_lo)) paste0("[", fmt(d$ci_lo), ", ", fmt(d$ci_hi), "]") else
          if (nrow(d) && startsWith(d$status, "unbounded")) "unbounded (the revenue effect's bootstrap interval includes zero)" else
          paste0("none (", if (nrow(d)) d$status else "no dose row", ")"), stringsAsFactors = FALSE)
      md <- c(md, "### Answer, stated as intervals", "",
              paste0("SD units: honest-DiD bound set at M̄ = 1, ", ans[[gap]]$sd_interval_mbar1,
                     ". Per $1,000 of per-pupil revenue: ", ans[[gap]]$per_1000_interval,
                     " (percentile interval of the dose-scaled ratio; the two intervals rest on different assumptions: the first on bounded departures from parallel trends, the second on parallel trends and the exclusion restriction)."), "")
    }
  }
  at <- bind(ans)
  wcsv(at, file.path(REP, "tables", "answer_intervals.csv"))
  md <- c(md[1:8], "## Answer to the research question, by gap", "", md_table(at), md[-(1:8)])
  writeLines(md, file.path(REP, "report.md"), useBytes = TRUE)
  say("Report: ", file.path(REP, "report.md"), " (", length(list.files(file.path(REP, "plots"))), " plots, ",
      length(list.files(file.path(REP, "tables"))), " tables)")
}
part("report", build_report)

total <- sum(run$times$seconds)
say(sprintf("Run %s finished. Total run time over parts: %.2f h (wall clock since start: %.2f h)", run$run_id, total / 3600,
            as.numeric(difftime(Sys.time(), run$started, units = "hours"))))
say("Run times per part: ", file.path(OUT, "run_times.csv"), "; log: ", log_file)

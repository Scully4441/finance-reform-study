for (f in list.files("R/functions", full.names = TRUE)) source(f)

Sys.setenv(RENV_CONFIG_SANDBOX_ENABLED = "FALSE")

args <- commandArgs(trailingOnly = TRUE)
RESUME <- "--resume" %in% args
REPORT_ONLY <- "--report" %in% args
stage <- read_stage()
if (!identical(stage, 2L)) stop("R/13_run_all.R reads the full window, which needs data/stage.txt = 2.")
BLINDING <- readLines("data/reference/blinding_status.txt", n = 1, warn = FALSE)
WORKERS <- 12L
OUT <- "outputs/13_run_all"
REP <- "outputs/13_report"
FITS <- "data/derived/run_all_fits"
CDID_DIR <- "outputs/11_continuous_did"
REPORT_ORDER <- c("hs", "graduation", "seda")
SETS <- names(EVENT_FILES)
KEYS <- c("gap", "event_set", "weighting", "panel")
ESTIMATORS6 <- c("sun_abraham", "imputation", "synthdid", "stacked", "twfe", "twfe_static")
RSCRIPT <- file.path(R.home("bin"), "Rscript")
SEED <- "13_run_all"

stamp <- format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/logs", recursive = TRUE, showWarnings = FALSE)
log_file <- file.path("outputs", "logs", paste0("13_run_all_", stamp, ".log"))
say <- function(...) {
  txt <- paste0(format(Sys.time(), "%H:%M:%S"), "  ", ...)
  cat(txt, "\n", sep = "")
  cat(txt, "\n", sep = "", file = log_file, append = TRUE)
}
wcsv <- function(x, f) { dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, f, row.names = FALSE, na = "") }
rcsv <- function(f) utils::read.csv(f, stringsAsFactors = FALSE, na.strings = "")
bind <- function(x) { y <- do.call(rbind, x); if (!is.null(y)) rownames(y) <- NULL; y }
odir <- function(name, ...) file.path(OUT, name, ...)
fdir <- function(name, ...) { d <- file.path(FITS, name, ...); dir.create(d, recursive = TRUE, showWarnings = FALSE); d }
is_family <- function(name) name %in% FAMILIES

state_file <- file.path(OUT, "run_state.rds")
if (RESUME || REPORT_ONLY) {
  if (!file.exists(state_file)) stop("no run to resume: ", state_file, " not found")
  run <- readRDS(state_file)
} else {
  unlink(c(FITS, file.path(OUT, REPORT_ORDER), file.path(OUT, "cache", "07_inference_graduation")),
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

say("Step 13 run-all, run ", run$run_id, if (RESUME) " (resumed)" else "", "; stage ", stage, "; blinding ", BLINDING)
say("Console: parts, model and unit counts, timings. Estimates: ", OUT, " and ", REP, "; model objects: ", FITS)

STEPS <- list(
  "03_sample"                 = "R/03_sample.R",
  "04_outcomes"               = "R/04_outcomes.R",
  "03g_graduation_sample"     = "R/03g_graduation_sample.R",
  "04g_graduation_outcomes"   = "R/04g_graduation_outcomes.R",
  "05_primary_graduation"     = c("R/05_primary.R", "--outcome", "graduation"),
  "06_secondary_graduation"   = c("R/06_secondary.R", "--outcome", "graduation"),
  "07_inference_graduation"   = c("R/07_inference.R", "--outcome", "graduation", "--cache-dir",
                                  file.path(OUT, "cache", "07_inference_graduation")),
  "09_seda_outcomes"          = "R/09_seda_outcomes.R",
  "10_hs_reportcard_outcomes" = "R/10_hs_reportcard_outcomes.R",
  "11_continuous_did"         = "R/11_continuous_did.R")
if (!REPORT_ONLY) for (id in names(STEPS)) part(paste0("step ", id), function() {
  con <- file.path("outputs", "logs", paste0("13_run_all_", id, "_", stamp, ".txt"))
  status <- system2(RSCRIPT, STEPS[[id]], stdout = con, stderr = con)
  if (!identical(as.integer(status), 0L)) stop(id, " failed (exit ", status, "); console output in ", con)
})

load_family <- function(family, weights = TRUE) {
  if (family == "seda" && weights) {
    ex <- read_seda_extras()
    inp <- family_load_inputs("seda", seda_tested_weights(ex))
    inp$extras <- ex
    inp
  } else family_load_inputs(family)
}

grid5 <- function(family) family_grid(family)
primary_key <- function(meta) paste(meta$gap, "primary", "unweighted", "unbalanced", sep = ".")
tagk <- function(meta, x) if (!is.null(x) && nrow(x)) data.frame(meta, x, row.names = NULL, stringsAsFactors = FALSE)
panel_size <- function(mp) data.frame(units_in_model = mp$units, states_in_model = mp$states,
  states_dropped_few_pre = mp$states_dropped_few_pre, unit_years = nrow(mp$panel),
  first_year = if (nrow(mp$panel)) min(mp$panel$sy_end) else NA_integer_,
  last_year = if (nrow(mp$panel)) max(mp$panel$sy_end) else NA_integer_,
  report_card_unit_years = if ("rc" %in% names(mp$panel)) sum(mp$panel$rc == 1) else NA_integer_,
  source_covariate = mp$source_covariate,
  cohorts_removed_by_floor = if (nrow(mp$floor_removed)) paste(sprintf("%d (%s; %d treated units at the base period)", mp$floor_removed$cohort,
    mp$floor_removed$states, mp$floor_removed$treated_units_base), collapse = "; ") else "none",
  mp$left_out, units_left_out = mp$left_out$units_with_outcome - mp$units, stringsAsFactors = FALSE)
no_panel <- function(msg) list(status = paste("panel error:", msg), notes = "", event = NULL, overall = NULL, cells = NULL,
                               fit = NULL, size = NULL)

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

load_step5 <- function(family) {
  g <- grid5(family)
  stats::setNames(lapply(g$key, function(k) { f <- file.path(FITS, family, "05_primary", paste0(k, ".rds"))
    if (file.exists(f)) readRDS(f) else NULL }), g$key)
}

run_step5 <- function(family) {
  fd <- fdir(family, "05_primary")
  inp <- load_family(family)
  g <- grid5(family)
  res <- list()
  for (i in seq_len(nrow(g))) {
    k <- g$key[i]; f <- file.path(fd, paste0(k, ".rds"))
    if (file.exists(f)) { res[[k]] <- readRDS(f); next }
    r <- fit_cs(function() family_model_panel(inp, g$gap[i], g$event_set[i], balanced = g$panel[i] == "balanced",
                                              weighting = g$weighting[i], cohort_floor = TRUE),
                paste(SEED, family, "05_primary", k), PANEL_TYPES[[g$panel[i]]])
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
  run_thin_cohorts(family, inp)
}

run_thin_cohorts <- function(family, inp) {
  fd <- fdir(family, "05_primary_thin")
  floor_rows <- list(); rows <- list()
  for (s in SETS) for (gap in setdiff(FAMILY_GAPS, "a_poverty")) {
    fl <- family_cohort_floor(inp, gap, s)
    floor_rows[[paste(gap, s)]] <- fl
    thin <- fl[fl$below_floor, , drop = FALSE]
    if (!nrow(thin)) next
    f <- file.path(fd, paste0(gap, ".", s, ".rds"))
    fit <- if (file.exists(f)) readRDS(f) else {
      mp <- family_model_panel(inp, gap, s)
      step <- paste(SEED, family, "05_primary thin cohorts", gap, s)
      r <- run_cs(mp$panel, xformla = ~1, seed_step = step, allow_unbalanced_panel = TRUE)
      grp <- NULL
      if (!is.null(r$fit)) {
        set.seed(seed_for(paste(step, "group")))
        grp <- tryCatch(suppressWarnings(did::aggte(r$fit$att_gt, type = "group", na.rm = TRUE)), error = function(e) NULL)
      }
      x <- list(status = r$status, cells = r$cells,
                group = if (is.null(grp)) NULL else data.frame(g = as.integer(grp$egt), att = grp$att.egt, se = grp$se.egt))
      saveRDS(x, f)
      x
    }
    for (i in seq_len(nrow(thin))) {
      cg <- thin$cohort[i]
      id <- data.frame(family = family, gap = gap, event_set = s, weighting = "unweighted", panel = "unbalanced", cohort = cg,
                       states = thin$states[i], base_year = thin$base_year[i], treated_units_base = thin$treated_units_base[i],
                       treated_units = thin$treated_units[i], stringsAsFactors = FALSE)
      ce <- fit$cells[fit$cells$g == cg, , drop = FALSE]
      gr <- if (is.null(fit$group)) NULL else fit$group[fit$group$g == cg, , drop = FALSE]
      est <- sum(!is.na(ce$att) & ce$t != thin$base_year[i])
      rows[[paste(gap, s, cg)]] <- rbind(
        data.frame(id, row = "cohort post-reform average (did aggte, group)", year = NA_integer_, event_time = NA_integer_,
                   att = if (!is.null(gr) && nrow(gr)) gr$att else NA_real_, se = if (!is.null(gr) && nrow(gr)) gr$se else NA_real_,
                   status = if (fit$status != "ok") fit$status else if (est == 0L) "no estimable cell (no treated unit at the base period)" else "ok",
                   stringsAsFactors = FALSE),
        if (nrow(ce)) data.frame(id, row = "group-time cell", year = ce$t, event_time = ce$e, att = ce$att, se = ce$se,
                                 status = ifelse(ce$t == thin$base_year[i], "reference (base period)", ifelse(is.na(ce$att), "not estimable", "ok")),
                                 stringsAsFactors = FALSE))
    }
    say(sprintf("  %s floor %-17s %-7s cohorts removed: %d", family, gap, s, nrow(thin)))
  }
  od <- odir(family, "05_primary")
  wcsv(bind(floor_rows), file.path(od, "cohort_floor.csv"))
  if (length(rows)) wcsv(bind(rows), file.path(od, "thin_cohorts.csv")) else unlink(file.path(od, "thin_cohorts.csv"))
}

family_controls <- function(family, inp) {
  if (family == "seda") {
    dist <- seda_districts_all_sets(unique(inp$extras$leaid))
    return(seda_controls(inp$race, dist, seda_all_both(inp$extras)))
  }
  cc <- as.vector(outer(c("cell_", "w_", "part_ok_"), c("math_all", "rla_all"), paste0))
  rows <- data.table::fread("data/derived/hs_panel.csv", select = c("leaid", "state", "sy_end", "retained", "retained_r1", "retained_r2",
                                                                   "pov_quintile_2009", "test_replaced", "cep", cc),
                            colClasses = c(leaid = "character"), data.table = FALSE, showProgress = FALSE, na.strings = "")
  td <- tempfile("ccd"); dir.create(td)
  m09 <- read_ccd_lea(utils::unzip("data/raw/ccd/lea-directory-sy2009-10.zip", exdir = td), 2010L, extra = "MEMBER")
  rows$member_2009 <- ccd_count(m09$member)[match(rows$leaid, m09$leaid)]
  hs_controls(rows)
}

run_step6 <- function(family) {
  fd <- fdir(family, "06_secondary")
  inp <- load_family(family)
  ctrl <- family_controls(family, inp)
  for (pan in family_panels(family)) {
    res <- list()
    for (s in SETS) for (gap in FAMILY_GAPS) {
      f <- file.path(fd, paste0(paste(pan, gap, s, sep = "."), ".rds"))
      if (file.exists(f)) fits <- readRDS(f) else {
        err <- function(msg) empty_result(paste("error:", msg))
        fits <- tryCatch({
          mp <- family_model_panel(inp, gap, s, balanced = pan == "balanced")
          ac <- family_attach_controls(ctrl, mp$panel, gap, s)
          p <- ac$panel
          covs <- if (gap == "a_poverty") character() else CS_COVARIATES
          est <- function(expr) tryCatch(expr, error = function(e) err(conditionMessage(e)))
          tw <- tryCatch(run_twfe(p, ac$controls, covs, mp$window), error = function(e) {
            x <- err(conditionMessage(e)); st <- x; st$event <- NULL; list(dynamic = x, static = st) })
          say(sprintf("  %s secondary %-17s %-7s %-10s %6d units %2d states", family, gap, s, pan, mp$units, mp$states))
          list(sun_abraham = est(run_sunab(p, ac$controls, covs, mp$window)),
               imputation  = est(run_imputation(p, ac$controls, covs, mp$window)),
               synthdid    = est(run_sdid(p, seed_step = paste(SEED, family, "06_secondary synthdid", gap, s, pan),
                                          complete_states = pan == "unbalanced")),
               stacked     = est(run_stacked(p, ac$controls, covs)),
               twfe        = tw$dynamic,
               twfe_static = tw$static,
               input       = list(units = mp$units, states = mp$states))
        }, error = function(e) stats::setNames(lapply(ESTIMATORS6, function(x) err(conditionMessage(e))), ESTIMATORS6))
        fits <- lapply(fits, function(x) { x$fit <- NULL; x })
        fits$twfe_static$event <- NULL
        saveRDS(fits, f)
      }
      for (est in ESTIMATORS6) {
        unit_e <- if (est == "synthdid" || gap == "a_poverty") "state" else "district"
        n_in <- if (is.null(fits$input)) NA_integer_ else if (unit_e == "state") fits$input$states else fits$input$units
        res[[paste(est, gap, s)]] <- c(list(estimator = est, gap = gap, event_set = s, weighting = "unweighted", panel = pan,
                                            unit = unit_e, units_in_panel = n_in), fits[[est]])
      }
    }
    meta <- function(r) as.data.frame(r[c("estimator", KEYS)], stringsAsFactors = FALSE)
    od <- if (pan == "unbalanced") odir(family, "06_secondary") else odir(family, "06_secondary", "appendix")
    wcsv(bind(lapply(res, function(r) tagk(meta(r), r[["event"]]))), file.path(od, "event_time_estimates.csv"))
    wcsv(bind(lapply(res, function(r) tagk(meta(r), r$overall))), file.path(od, "overall_estimates.csv"))
    wcsv(bind(lapply(res, function(r) tagk(meta(r), r$cells))), file.path(od, "group_time_estimates.csv"))
    wcsv(bind(lapply(res, function(r) tagk(meta(r), r$pooled))), file.path(od, "synthdid_pooled.csv"))
    wcsv(bind(lapply(res, function(r) if (!is.null(r$size)) { x <- tagk(data.frame(meta(r), unit = r$unit), r$size)
      x$units_in_panel <- r$units_in_panel
      x$units_left_out <- r$units_in_panel - if (r$unit == "state") x$states_in_model else x$units_in_model
      x })), file.path(od, "panel_counts.csv"))
    wcsv(bind(lapply(res, function(r) data.frame(meta(r), status = r$status, notes = paste(r$notes, collapse = " | "),
                                                 stringsAsFactors = FALSE))), file.path(od, "model_status.csv"))
  }
}

infer_set <- function(res, seed_step, growth = FALSE) {
  fits <- lapply(res, function(r) list(fit = r$fit, ref = r$ref))
  inf <- infer_fits(fits, seed_step, BOOT_REPS)
  hon <- honest_block_rule(inf$honest, inf$infs, lapply(fits, `[[`, "ref"))
  tag_all <- function(x) stats::setNames(lapply(names(x), function(k) tagk(res[[k]]$meta, x[[k]])), names(x))
  out <- list(overall = tag_all(inf$overall), event = tag_all(inf$event), honest = tag_all(hon), t_boot = inf$t_boot)
  if (growth) {
    gr <- if (is.null(inf$wm)) list(rows = list(), t_boot = list(), honest = list()) else growth_infer(fits, inf$wm, inf$st)
    out$growth <- tag_all(gr$rows); out$growth_t_boot <- gr$t_boot; out$growth_honest <- tag_all(gr$honest)
  }
  out
}

missing_event_times <- function(res) bind(lapply(names(res), function(k) {
  r <- res[[k]]
  if (is.null(r$fit)) return(NULL)
  eg <- tryCatch(event_time_gaps(r$fit, sort(unique(cs_panel(r$fit)$panel$sy_end)), r$ref), error = function(e) NULL)
  if (is.null(eg)) NULL else tagk(r$meta, eg)
}))

rw_family <- function(pick, bo, tb, meta) {
  pick <- pick[!is.na(pick) & vapply(pick, function(k) !is.null(tb[[k]]) && !is.null(bo[[k]]), TRUE)]
  if (length(pick) < 2L) return(NULL)
  to <- vapply(pick, function(k) bo[[k]]$t, 0)
  data.frame(meta, gap = names(pick), weighting = vapply(pick, function(k) bo[[k]]$weighting, ""), t = to,
             p_unadjusted = vapply(pick, function(k) bo[[k]]$p_value, 0), p_romano_wolf = rw_stepdown(to, do.call(cbind, tb[pick])),
             rank = rank(-abs(to), ties.method = "first"), hypotheses = length(pick), reps = BOOT_REPS,
             row.names = NULL, stringsAsFactors = FALSE)
}

ri_row <- function(meta, att, r) {
  v <- r$values[is.finite(r$values)]
  data.frame(meta, att = att, p_value = r$p_value, reps = as.integer(r$reps), requested = as.integer(r$requested),
             method = r$method, assignments_possible = r$assignments_possible, draws_ok = as.integer(r$draws_ok),
             treated_states = as.integer(r$treated_states), eligible_states = as.integer(r$eligible_states),
             placebo_mean = if (length(v)) mean(v) else NA_real_, placebo_sd = if (length(v) > 1) stats::sd(v) else NA_real_,
             placebo_abs_q95 = if (length(v)) unname(stats::quantile(abs(v), 0.95)) else NA_real_, status = r$status,
             row.names = NULL, stringsAsFactors = FALSE)
}

settings_rows <- function(name, ri_reps) data.frame(
  setting = c("run", "family", "stage", "blinding", "bootstrap_reps", "romano_wolf_reps", "randomization_reps", "webb_support",
              "mbar", "honest_grid", "honest_block_rule", "master_seed", "workers", "r_version", "did", "HonestDiD"),
  value = c(run$run_id, name, stage, BLINDING, BOOT_REPS, BOOT_REPS, ri_reps, paste(round(WEBB_SUPPORT, 6), collapse = " "),
            paste(MBAR_GRID, collapse = " "), sprintf("start +/-%d sd, %d points; widened by its width per edge side, same step, up to %d times",
                                                      HONEST_GRID_SD, HONEST_GRID_POINTS, HONEST_GRID_MAX_WIDEN),
            "reduced consecutive event-time block where event times are not consecutive (honest_block())", MASTER_SEED, WORKERS,
            R.version.string, as.character(utils::packageVersion("did")), as.character(utils::packageVersion("HonestDiD"))),
  stringsAsFactors = FALSE)

run_step7 <- function(family) {
  g <- grid5(family)
  res5 <- load_step5(family)
  rdir <- fdir(family, "07_randomization")
  res <- lapply(stats::setNames(g$key, g$key), function(k) list(fit = res5[[k]]$fit, ref = -1L,
    meta = as.data.frame(g[g$key == k, KEYS], stringsAsFactors = FALSE), status = if (is.null(res5[[k]])) "no step 5 result" else res5[[k]]$status))
  bo <- list(); be <- list(); hd <- list(); tb <- list(); gro <- list(); gtb <- list(); ghd <- list()
  for (s in SETS) {
    ks <- g$key[g$event_set == s]
    x <- infer_set(res[ks], paste(SEED, family, "07_inference bootstrap", s), growth = TRUE)
    bo <- c(bo, x$overall); be <- c(be, x$event); hd <- c(hd, x$honest); tb <- c(tb, x$t_boot)
    gro <- c(gro, x$growth); gtb <- c(gtb, x$growth_t_boot); ghd <- c(ghd, x$growth_honest)
    say(sprintf("  %s step 7 %-7s bootstrap, Romano-Wolf draws, HonestDiD and the growth contrast: %d fitted models", family, s, length(x$overall)))
  }
  rw <- list(); grw <- list()
  for (s in SETS) for (pan in family_panels(family)) for (fam in c("unweighted", "tested_weighted")) {
    pick <- vapply(FAMILY_GAPS, function(gp) { w <- if (gp == "a_poverty") "unweighted" else fam
      k <- paste(gp, s, w, pan, sep = "."); if (!is.null(tb[[k]])) k else NA_character_ }, "")
    rw[[paste(s, pan, fam)]] <- rw_family(pick, bo, tb, data.frame(event_set = s, panel = pan, family = fam, stringsAsFactors = FALSE))
    gpick <- vapply(FAMILY_GAPS, function(gp) { w <- if (gp == "a_poverty") "unweighted" else fam
      k <- paste(gp, s, w, pan, sep = "."); if (!is.null(gtb[[k]])) k else NA_character_ }, "")
    grw[[paste(s, pan, fam)]] <- rw_family(gpick, gro, gtb, data.frame(event_set = s, panel = pan, family = fam, stringsAsFactors = FALSE))
  }
  ri <- list(); rid <- list()
  t0 <- Sys.time()
  for (k in g$key[vapply(g$key, function(k) !is.null(res[[k]]$fit), TRUE)]) {
    r_reps <- if (identical(k, primary_key(res[[k]]$meta))) RI_REPS else RI_REPS_VARIANT
    r <- ri_cached(res[[k]]$fit, r_reps, paste(SEED, family, "07_inference randomization", k), file.path(rdir, paste0(k, ".rds")))
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
  wcsv(bind(gro), file.path(od, "growth_contrast.csv")); wcsv(bind(grw), file.path(od, "growth_romano_wolf.csv"))
  wcsv(bind(ghd), file.path(od, "growth_honestdid.csv"))
  wcsv(missing_event_times(res), file.path(od, "event_time_gaps.csv"))
  wcsv(settings_rows(family, paste(RI_REPS, "primary models;", RI_REPS_VARIANT, "other models")), file.path(od, "inference_settings.csv"))
}

run_variants <- function(name) {
  fam <- is_family(name)
  vfd <- fdir(name, "variants", "fits"); vrd <- fdir(name, "variants", "randomization")
  inp <- if (fam) load_family(name) else load_cs_inputs(name)
  defs <- if (fam) FAMILY_VARIANTS else VARIANTS
  vs_all <- if (fam) family_variants_for(name) else variants_for(name)
  gaps <- if (fam) FAMILY_GAPS else outcome_gaps(name)
  grid <- bind(lapply(vs_all, function(v) bind(lapply(SETS, function(s) bind(lapply(gaps, function(gp)
    data.frame(variant = v, gap = gp, event_set = s, weighting = family_weightings(gp), panel = "unbalanced", stringsAsFactors = FALSE)))))))
  grid$key <- paste(grid$gap, grid$event_set, grid$weighting, grid$variant, sep = ".")
  say(name, " variants: ", nrow(grid), " models (", length(vs_all), " variants x 3 event sets x gaps and weightings)")
  vk <- c("variant", KEYS)
  res <- list()
  for (i in seq_len(nrow(grid))) {
    k <- grid$key[i]; f <- file.path(vfd, paste0(k, ".rds"))
    if (file.exists(f)) { res[[k]] <- readRDS(f); next }
    vs <- defs[[grid$variant[i]]]
    seed_step <- paste(SEED, name, "variants", k)
    r <- if (fam) {
      fit_cs(function() family_model_panel(inp, grid$gap[i], grid$event_set[i], sample = vs$sample, from_year = vs$from_year,
                                           years = vs$years, states = vs$states, drop_few_pre = vs$drop_few_pre,
                                           weighting = grid$weighting[i], cohort_floor = TRUE),
             seed_step, TRUE, vs$anticipation)
    } else {
      mp <- cs_model_panel(inp, grid$gap[i], grid$event_set[i], sample = vs$sample, from_year = vs$from_year,
                           drop_few_pre = vs$drop_few_pre, weighting = grid$weighting[i])
      fit <- run_cs(mp$panel, xformla = mp$xformla, weightsname = mp$weightsname, seed_step = seed_step,
                    allow_unbalanced_panel = TRUE, anticipation = vs$anticipation)
      list(status = fit$status, notes = paste(unique(fit$notes), collapse = " | "), event = fit$event, overall = fit$overall,
           cells = fit$cells, fit = fit$fit, size = data.frame(units_in_model = mp$units, states_in_model = mp$states,
                                                               states_dropped_few_pre = mp$states_dropped_few_pre, unit_years = nrow(mp$panel)))
    }
    r <- c(list(meta = as.data.frame(grid[i, vk], stringsAsFactors = FALSE), ref = -1L - vs$anticipation), r)
    saveRDS(r, f)
    res[[k]] <- r
    say(sprintf("  %s variant %-19s %-7s %-15s %-24s %6s units %2s states  %s", name, grid$gap[i], grid$event_set[i],
                grid$weighting[i], grid$variant[i], if (is.null(r$size)) "-" else r$size$units_in_model,
                if (is.null(r$size)) "-" else r$size$states_in_model, if (r$status == "ok") "ok" else "not ok (status in files)"))
  }
  bo <- list(); be <- list(); hd <- list(); tb <- list(); rw <- list()
  for (v in vs_all) for (s in SETS) {
    ks <- grid$key[grid$variant == v & grid$event_set == s]
    x <- infer_set(res[ks], paste(SEED, name, v, "bootstrap", s))
    bo <- c(bo, x$overall); be <- c(be, x$event); hd <- c(hd, x$honest); tb <- c(tb, x$t_boot)
    for (fm in c("unweighted", "tested_weighted")) {
      pick <- vapply(gaps, function(gp) { w <- if (gp == "a_poverty") "unweighted" else fm
        k <- paste(gp, s, w, v, sep = "."); if (!is.null(tb[[k]])) k else NA_character_ }, "")
      rw[[paste(v, s, fm)]] <- rw_family(pick, bo, tb, data.frame(variant = v, event_set = s, panel = "unbalanced", family = fm,
                                                                 stringsAsFactors = FALSE))
    }
  }
  say(name, " variants: bootstrap, Romano-Wolf and HonestDiD done for ", length(bo), " fitted models")
  ri <- list(); rid <- list()
  t0 <- Sys.time()
  for (k in names(res)[vapply(res, function(r) !is.null(r$fit), TRUE)]) {
    r <- ri_cached(res[[k]]$fit, RI_REPS_VARIANT, paste(SEED, name, "variants randomization", k), file.path(vrd, paste0(k, ".rds")))
    ri[[k]] <- ri_row(res[[k]]$meta, res[[k]]$overall$att, r)
    if (length(r$values)) rid[[k]] <- data.frame(res[[k]]$meta, draw = seq_along(r$values), att = r$values, row.names = NULL)
  }
  say(sprintf("%s variants: randomization inference (%d reassignments) on %d models, %.1f min", name, RI_REPS_VARIANT,
              length(ri), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  od <- odir(name, "variants")
  wcsv(bind(lapply(res, function(r) tagk(r$meta, r$overall))), file.path(od, "overall_estimates.csv"))
  wcsv(bind(lapply(res, function(r) tagk(r$meta, r[["event"]]))), file.path(od, "event_time_estimates.csv"))
  wcsv(bind(lapply(res, function(r) data.frame(r$meta, status = r$status, notes = r$notes, row.names = NULL, stringsAsFactors = FALSE))),
       file.path(od, "model_status.csv"))
  wcsv(bind(lapply(res, function(r) tagk(r$meta, r$size))), file.path(od, "panel_counts.csv"))
  wcsv(bind(bo), file.path(od, "bootstrap_overall.csv")); wcsv(bind(be), file.path(od, "bootstrap_event_time.csv"))
  wcsv(bind(hd), file.path(od, "honestdid_overall.csv")); wcsv(bind(rw), file.path(od, "romano_wolf.csv"))
  wcsv(bind(ri), file.path(od, "randomization_overall.csv")); wcsv(bind(rid), file.path(od, "randomization_draws.csv"))
  wcsv(data.frame(variant = vs_all, label = vapply(defs[vs_all], `[[`, "", "label"),
                  split = vapply(defs[vs_all], function(x) isTRUE(x$split), TRUE), stringsAsFactors = FALSE), file.path(od, "variants.csv"))
  wcsv(settings_rows(name, RI_REPS_VARIANT), file.path(od, "inference_settings.csv"))
  wcsv(missing_event_times(res), file.path(od, "event_time_gaps.csv"))
}

grade9_counts <- function(need) {
  g9_file <- file.path(OUT, "cache", "ccd_grade9_district.csv")
  g9 <- if (file.exists(g9_file)) utils::read.csv(g9_file, colClasses = c(leaid = "character"), stringsAsFactors = FALSE) else NULL
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
  g9[g9$sy_end %in% need, , drop = FALSE]
}

lee_gap <- function(gap, mp, smp, g9, years, seed_prefix, ov5, high_school) {
  base <- mp$panel
  sgs <- RACE_GAPS[[race_key("achievement", gap)]]
  xv <- all.vars(mp$xformla)
  effects <- c(); pg <- c(); share_rows <- list()
  for (sg in sgs) {
    sp <- lee_share_panel(base, smp, g9, sg, years)
    for (v in setdiff(xv, names(sp))) sp[[v]] <- base[[v]][match(sp$leaid, base$leaid)]
    fs <- run_cs(sp, xformla = mp$xformla, seed_step = paste(seed_prefix, "lee share", gap, sg), allow_unbalanced_panel = TRUE)
    effects[sg] <- if (fs$status == "ok") fs$overall$att else NA_real_
    lev <- lee_share_levels(fs, sp)
    pg[sg] <- lee_p(lev[["q_T"]], lev[["q_C"]])
    share_rows[[sg]] <- data.frame(gap = gap, subgroup = sg, status = fs$status, att_share = fs$overall$att,
      se = fs$overall$se, q_T = lev[["q_T"]], q_C = lev[["q_C"]], p = unname(pg[sg]), units = length(unique(sp$id)),
      unit_years = nrow(sp), report_card_unit_years = if (high_school) sum(sp$sy_end >= RC_FROM) else 0L,
      share_years_from = min(sp$sy_end), share_years_to = max(sp$sy_end), fallback_share = mean(sp$fallback),
      mean_share = mean(sp$y), notes = paste(unique(fs$notes), collapse = " | "), stringsAsFactors = FALSE)
    say(sprintf("  Lee share model %-17s %s: %d districts, %s", gap, sg, length(unique(sp$id)), fs$status))
  }
  frac <- lee_differential_fraction(pg[[sgs[1]]], pg[["wh"]])
  prim <- run_cs(base, xformla = mp$xformla, seed_step = paste(seed_prefix, "lee primary", gap), allow_unbalanced_panel = TRUE)
  k5 <- ov5$gap == gap & ov5$event_set == "primary" & ov5$weighting == "unweighted" & ov5$panel == "unbalanced"
  if (high_school) {
    if (any(k5) && is.finite(ov5$att[k5])) stopifnot(isTRUE(all.equal(prim$overall$att, ov5$att[k5])))
  } else stopifnot(isTRUE(all.equal(prim$overall$att, ov5$att[k5])))
  trims <- lapply(c(top = "top", bottom = "bottom"), function(side) {
    tr <- lee_trim(base, if (is.na(frac)) 0 else frac, side)
    ft <- run_cs(tr$panel, xformla = mp$xformla, seed_step = paste(seed_prefix, "lee trim", gap, side), allow_unbalanced_panel = TRUE)
    list(att = ft$overall$att, status = ft$status, removed = tr$removed, treated_post = tr$treated_post)
  })
  est <- c(trims$top$att, trims$bottom$att)
  row <- data.frame(gap = gap, event_set = "primary", weighting = "unweighted", panel = "unbalanced",
    att_primary = prim$overall$att, effect_share_minority = unname(effects[sgs[1]]), effect_share_white = unname(effects["wh"]),
    p_minority = unname(pg[sgs[1]]), p_white = unname(pg["wh"]), trim_fraction = frac,
    treated_post_unit_years = trims$top$treated_post, trimmed_unit_years = trims$top$removed,
    att_trim_top = trims$top$att, att_trim_bottom = trims$bottom$att,
    lee_lower = if (all(is.na(est))) NA_real_ else min(est, na.rm = TRUE), lee_upper = if (all(is.na(est))) NA_real_ else max(est, na.rm = TRUE),
    status = if (is.na(frac)) "no share effect estimated" else if (trims$top$status == "ok" && trims$bottom$status == "ok") "ok" else
      paste("trim refit:", trims$top$status, "/", trims$bottom$status), stringsAsFactors = FALSE)
  say(sprintf("  Lee trim %-17s treated post-reform district-years: %d of %d, %s", gap, trims$top$removed,
              trims$top$treated_post, row$status))
  list(row = row, share = bind(share_rows))
}

write_lee <- function(name, out, g9) {
  ldir <- odir(name, "lee")
  wcsv(bind(lapply(out, `[[`, "row")), file.path(ldir, "lee_bounds.csv"))
  wcsv(bind(lapply(out, `[[`, "share")), file.path(ldir, "lee_share_models.csv"))
  wcsv(data.frame(sy_end = sort(unique(g9$sy_end)), districts = as.vector(table(g9$sy_end)),
                  race_unavailable_bl = as.vector(tapply(is.na(g9$g9_bl), g9$sy_end, sum)),
                  race_unavailable_wh = as.vector(tapply(is.na(g9$g9_wh), g9$sy_end, sum)),
                  race_unavailable_hi = as.vector(tapply(is.na(g9$g9_hi), g9$sy_end, sum))),
       file.path(ldir, "ccd_grade9_coverage.csv"))
}

run_lee_hs <- function() {
  window <- FAMILY_WINDOWS$hs
  need <- sort(unique(window - LEE_LAG))
  stopifnot(all(need >= LEE_FIRST_CCD))
  g9 <- grade9_counts(need)
  sg_cols <- as.vector(outer(c("math_", "rla_"), c("all", "wh", "bl", "hi"), paste0))
  smp <- data.table::fread("data/derived/hs_panel.csv", select = c("leaid", "sy_end", paste0("n_", sg_cols), paste0("nbasis_", sg_cols)),
                           colClasses = c(leaid = "character"), data.table = FALSE, showProgress = FALSE, na.strings = "")
  for (v in sg_cols) smp[[paste0("n_", v)]][!smp[[paste0("nbasis_", v)]] %in% "exact"] <- NA_real_
  inp <- family_load_inputs("hs")
  ov5 <- rcsv(odir("hs", "05_primary", "overall_estimates.csv"))
  out <- lapply(c(b_black_white = "b_black_white", c_hispanic_white = "c_hispanic_white"), function(gap)
    lee_gap(gap, family_model_panel(inp, gap, "primary", cohort_floor = TRUE), smp, g9, window, paste(SEED, "hs"), ov5, TRUE))
  write_lee("hs", out, g9)
}

dose_none <- function(status, reps) data.frame(att_outcome = NA_real_, att_revenue = NA_real_, revenue_ci_lo = NA_real_,
  revenue_ci_hi = NA_real_, dose_scaled = NA_real_, ci_lo = NA_real_, ci_hi = NA_real_, percentile_lo = NA_real_,
  percentile_hi = NA_real_, share_draws_revenue_sign_flip = NA_real_, reps = reps, status = status, stringsAsFactors = FALSE)

family_step7_draws <- function(family, reps) {
  g <- grid5(family); res5 <- load_step5(family)
  infs <- lapply(res5, function(r) if (is.null(r)) NULL else cs_influence(r$fit))
  draws <- list()
  for (s in SETS) {
    k <- g$key[g$event_set == s & !vapply(infs[g$key], is.null, TRUE)]
    if (!length(k)) next
    st <- sort(unique(unlist(lapply(infs[k], `[[`, "states"))))
    set.seed(seed_for(paste(SEED, family, "07_inference bootstrap", s)))
    draws[[s]] <- list(states = st, w = webb_weights(length(st), reps))
  }
  list(draws = draws, infs = infs)
}

run_dose <- function(name) {
  fam <- is_family(name)
  ddir <- odir(name, "dose")
  window <- if (fam) FAMILY_WINDOWS[[name]] else outcome_window(name)
  years <- window[window %in% CDID_F33_YEARS]
  rev_all <- cdid_real_revenue(f33_revenue(years))
  if (!is.null(attr(rev_all, "sources"))) wcsv(attr(rev_all, "sources"), file.path(ddir, "f33_sources.csv"))
  rev <- rev_all[!rev_all$excluded, , drop = FALSE]
  count_excl <- function(scope, gap, s, lea_sy) {
    k <- paste(rev_all$leaid, rev_all$sy_end) %in% lea_sy
    data.frame(scope = scope, gap = gap, event_set = s, district_years_with_revenue = sum(k),
               excluded_enrollment_below_30 = sum(k & rev_all$v33 < CDID_REV_MIN_ENROLL),
               excluded_revenue_above_100k = sum(k & rev_all$rev_pp_real > CDID_REV_MAX_PP),
               excluded_total = sum(k & rev_all$excluded), stringsAsFactors = FALSE)
  }
  exrows <- list(all = count_excl("all F-33 districts, window years with F-33", NA_character_, NA_character_, paste(rev_all$leaid, rev_all$sy_end)))
  say(sprintf("  revenue exclusions (%s, fiscal years %d-%d): %d of %d F-33 district-years", name, min(years), max(years),
              sum(rev_all$excluded), nrow(rev_all)))
  st7 <- rcsv(if (fam) odir(name, "07_inference", "inference_settings.csv") else
    file.path("outputs", "07_inference", name, "inference_settings.csv"))
  reps7 <- as.integer(st7$value[st7$setting == "bootstrap_reps"])
  s7 <- if (fam) family_step7_draws(name, reps7) else step7_draws(name, reps7)
  inp <- if (fam) family_load_inputs(name) else load_cs_inputs(name)
  da <- if (name == "seda") seda_districts_all_sets(unique(inp$race$leaid)) else if (name == "hs") hs_gap_a_districts_all_sets() else NULL
  gaps <- if (fam) FAMILY_GAPS else outcome_gaps(name)
  rows <- list(); fs_ev <- list(); fs_ov <- list()
  for (s in SETS) for (gap in gaps) {
    key <- paste(gap, s, "unweighted", "unbalanced", sep = ".")
    mp <- tryCatch(if (fam) family_model_panel(inp, gap, s, years = years, cohort_floor = TRUE) else cs_model_panel(inp, gap, s),
                   error = function(e) e)
    if (inherits(mp, "error")) {
      rows[[key]] <- data.frame(gap = gap, event_set = s, weighting = "unweighted", panel = "unbalanced", status = paste("panel error:", conditionMessage(mp)))
      next
    }
    base <- mp$panel
    unit <- mp$unit
    rp <- if (gap == "a_poverty") family_gap_a_revenue_panel(da, RETAIN_FLAGS[[s]], rev_all, years, base) else dist_revenue_panel(base, rev, years)
    for (v in setdiff(all.vars(mp$xformla), names(rp))) rp[[v]] <- base[[v]][match(rp[[unit]], base[[unit]])]
    scope <- if (gap == "a_poverty") {
      x <- da[da[[RETAIN_FLAGS[[s]]]] %in% 1L & da$pov_quintile_2009 %in% c(1L, 5L) & !is.na(da$member_2009) & da$member_2009 > 0 &
                da$state %in% base$state, , drop = FALSE]
      as.vector(outer(x$leaid, years, paste))
    } else as.vector(outer(unique(base$leaid), years, paste))
    exrows[[key]] <- count_excl(if (gap == "a_poverty") "quintile 1 and 5 districts of the gap (a) states" else
                                  "districts of the gap's primary model", gap, s, scope)
    base <- base[base$sy_end %in% years, , drop = FALSE]
    fy <- run_cs(base, xformla = mp$xformla, seed_step = paste(SEED, name, "dose outcome", key), allow_unbalanced_panel = TRUE)
    fr <- run_cs(rp, xformla = mp$xformla, seed_step = paste(SEED, name, "dose", key), allow_unbalanced_panel = TRUE)
    cmn <- common_overall(cs_influence(fy$fit), cs_influence(fr$fit))
    inf_y <- cmn$y; inf_r <- cmn$r
    say(sprintf("  %s revenue first stage %-19s %-7s %5d units, %s", name, gap, s, length(unique(rp$id)), fr$status))
    fs_ev[[key]] <- data.frame(gap = gap, event_set = s, fr$event, stringsAsFactors = FALSE)
    rb <- if (!is.null(inf_r) && !is.null(s7$draws[[s]]) && all(inf_r$states %in% s7$draws[[s]]$states))
      wcb_test(inf_r$overall_att, inf_r$scores[, "overall"], inf_r$n, s7$draws[[s]]$w[, match(inf_r$states, s7$draws[[s]]$states), drop = FALSE])$row else NULL
    fs_ov[[key]] <- data.frame(gap = gap, event_set = s, status = fr$status, fr$overall,
      boot_p_value = if (is.null(rb)) NA_real_ else rb$p_value, units_in_model = length(unique(rp$id)),
      unit_years = nrow(rp), notes = paste(unique(fr$notes), collapse = " | "), stringsAsFactors = FALSE)
    d <- if (is.null(fy$fit)) dose_none(paste("outcome model:", fy$status), reps7) else if (is.null(fr$fit)) dose_none(paste("revenue model:", fr$status), reps7) else
      if (is.null(cmn)) dose_none("no post-reform event time estimated in both stages", reps7) else
      tryCatch(dose_ratio(inf_y, inf_r, s7$draws[[s]]), error = function(e) dose_none(paste("error:", conditionMessage(e)), reps7))
    d$event_times <- if (is.null(cmn)) NA_character_ else paste(cmn$event_times, collapse = " ")
    d$end_years <- paste0(min(years), "-", max(years))
    rows[[key]] <- data.frame(gap = gap, event_set = s, weighting = "unweighted", panel = "unbalanced", d,
                              revenue_units = paste0("thousands of ", CDID_BASE_YEAR, " dollars per pupil"), stringsAsFactors = FALSE)
  }
  fill <- function(x) { nm <- unique(unlist(lapply(x, names))); lapply(x, function(r) { for (v in setdiff(nm, names(r))) r[[v]] <- NA; r[nm] }) }
  wcsv(bind(fill(rows)), file.path(ddir, "dose_scaled.csv"))
  wcsv(bind(fs_ov), file.path(ddir, "revenue_first_stage_overall.csv"))
  wcsv(bind(fs_ev), file.path(ddir, "revenue_first_stage_event_time.csv"))
  wcsv(bind(exrows), file.path(ddir, "revenue_exclusions.csv"))
}

if (!REPORT_ONLY) {
  for (fm in FAMILIES) {
    part(paste("05_primary", fm), function() run_step5(fm))
    part(paste("06_secondary", fm), function() run_step6(fm))
    future::plan(future::multisession, workers = WORKERS)
    part(paste("07_inference", fm), function() run_step7(fm))
    future::plan(future::sequential)
  }
  future::plan(future::multisession, workers = WORKERS)
  for (nm in REPORT_ORDER) part(paste("variants", nm), function() run_variants(nm))
  future::plan(future::sequential)
  part("lee hs", run_lee_hs)
  for (nm in REPORT_ORDER) part(paste("dose", nm), function() run_dose(nm))
}

FAMILY_HEADS <- c(
  hs = "High school achievement gaps (primary; EDFacts end years 2010–2021, state report cards 2022–2025)",
  graduation = "Graduation-rate gaps (secondary; end years 2011–2021)",
  seda = "SEDA grades 3–8 gaps (supplementary; end years 2009–2019 and 2022–2025)")
GAP_TITLES <- list(
  hs = c(a_poverty = "High school gap (a): between-district poverty-quintile gap",
         b_black_white = "High school gap (b): within-district Black–White gap",
         c_hispanic_white = "High school gap (c): within-district Hispanic–White gap"),
  graduation = c(grad_black_white = "Graduation: within-district Black–White gap in the four-year graduation rate",
                 grad_hispanic_white = "Graduation: within-district Hispanic–White gap in the four-year graduation rate"),
  seda = c(a_poverty = "SEDA gap (a): between-district poverty-quintile gap, grades 3–8",
           b_black_white = "SEDA gap (b): within-district Black–White gap, grades 3–8",
           c_hispanic_white = "SEDA gap (c): within-district Hispanic–White gap, grades 3–8"))
UNITS_TEXT <- c(hs = "standard deviation units (probit gap V)",
                graduation = "standard deviation units (probit gap V of the four-year graduation rate)",
                seda = "national standard deviation units (SEDA cohort-standardized scale)")
WEIGHT_TEXT <- c(hs = "students tested in the gap's two groups in 2009-10, mean of math and RLA, fixed",
                 graduation = "2010-11 cohort count in the gap's two groups, fixed",
                 seda = "SEDA's tot_asmt of the gap's two groups in 2009-10, summed over grades 3-8, mean of math and RLA, fixed")
CONTROLS_TEXT <- c(hs = "test replacement and CEP", graduation = "CEP", seda = "CEP")
HYPOTHESES <- c(
  "- H1. A reform narrows the between-district achievement gap by child-poverty quintile (gap a).",
  "- H2. A reform narrows the within-district Black–White gap (gap b).",
  "- H3. A reform narrows the within-district Hispanic–White gap (gap c).",
  "- H4. The effect grows with years since reform.",
  "- H5. The effect per $1,000 of reform-induced per-pupil revenue is positive.")

report_dirs <- function(name) {
  if (is_family(name)) return(list(s5 = odir(name, "05_primary"), s6 = odir(name, "06_secondary"), s7 = odir(name, "07_inference")))
  list(s5 = file.path("outputs/05_primary", name), s6 = file.path("outputs/06_secondary", name), s7 = file.path("outputs/07_inference", name))
}

read_or_empty <- function(f) {
  if (file.exists(f)) {
    x <- tryCatch(rcsv(f), error = function(e) if (grepl("empty|no lines available", conditionMessage(e))) NULL else stop(e))
    if (!is.null(x) && (ncol(x) > 1L || nrow(x))) return(x)
  }
  data.frame(gap = character(), event_set = character(), weighting = character(), panel = character(), variant = character(),
             estimator = character(), family = character(), mbar = numeric(), lb = numeric(), ub = numeric(), e = integer(),
             att = numeric(), ci_lo = numeric(), ci_hi = numeric(), status = character(), stringsAsFactors = FALSE)
}

verdict_rows <- function(name) {
  fam <- is_family(name)
  dr <- report_dirs(name)
  rd <- read_or_empty
  ov5 <- rd(file.path(dr$s5, "overall_estimates.csv")); ms5 <- rd(file.path(dr$s5, "model_status.csv"))
  bo7 <- rd(file.path(dr$s7, "bootstrap_overall.csv")); hd7 <- rd(file.path(dr$s7, "honestdid_overall.csv"))
  gro7 <- rd(file.path(dr$s7, "growth_contrast.csv")); ghd7 <- rd(file.path(dr$s7, "growth_honestdid.csv"))
  ov6 <- rd(file.path(dr$s6, "overall_estimates.csv")); ms6 <- rd(file.path(dr$s6, "model_status.csv"))
  ev6 <- rd(file.path(dr$s6, "event_time_estimates.csv"))
  vov <- rd(odir(name, "variants", "overall_estimates.csv")); vms <- rd(odir(name, "variants", "model_status.csv"))
  dose <- rd(odir(name, "dose", "dose_scaled.csv"))
  sel <- function(d, g, s = "primary", w = "unweighted", p = "unbalanced")
    d[d$gap %in% g & d$event_set %in% s & d$weighting %in% w & d$panel %in% p, , drop = FALSE]
  first <- function(x, col) if (nrow(x) && col %in% names(x)) x[[col]][1] else NA
  vlist <- if (fam) family_variants_for(name, split = FALSE) else variants_for(name)
  gaps <- if (fam) FAMILY_GAPS else outcome_gaps(name)
  bind(lapply(gaps, function(gap) {
    o <- sel(ov5, gap); b <- sel(bo7, gap); h <- sel(hd7, gap)
    att <- as.numeric(first(o, "att"))
    sec <- data.frame(name = SECONDARY4, att = vapply(SECONDARY4, function(es)
      as.numeric(first(ov6[ov6$estimator %in% es & ov6$gap %in% gap & ov6$event_set %in% "primary", , drop = FALSE], "att")), 0),
      status = vapply(SECONDARY4, function(es) as.character(first(ms6[ms6$estimator %in% es & ms6$gap %in% gap &
                                                                         ms6$event_set %in% "primary", , drop = FALSE], "status")), ""),
      stringsAsFactors = FALSE)
    vrow <- function(v) { x <- vov[vov$variant %in% v & vov$gap %in% gap & vov$event_set %in% "primary" & vov$weighting %in% "unweighted", , drop = FALSE]
      st <- vms[vms$variant %in% v & vms$gap %in% gap & vms$event_set %in% "primary" & vms$weighting %in% "unweighted", , drop = FALSE]
      data.frame(name = v, att = as.numeric(first(x, "att")), status = as.character(first(st, "status")), stringsAsFactors = FALSE) }
    var <- bind(lapply(intersect(c("sample_r5", "sample_exact", "participation_from_2013"), vlist), vrow))
    if (name != "seda") var <- rbind(var, data.frame(name = "balanced_panel", att = as.numeric(first(sel(ov5, gap, p = "balanced"), "att")),
      status = as.character(first(sel(ms5, gap, p = "balanced"), "status")), stringsAsFactors = FALSE))
    if (gap != "a_poverty") var <- rbind(var, data.frame(name = "tested_weighted", att = as.numeric(first(sel(ov5, gap, w = "tested_weighted"), "att")),
      status = as.character(first(sel(ms5, gap, w = "tested_weighted"), "status")), stringsAsFactors = FALSE))
    if (is.null(var)) var <- data.frame(name = character(), att = numeric(), status = character())
    crit <- agreement_criterion(att, as.numeric(first(b, "ci_lo")), as.numeric(first(b, "ci_hi")), sec, var)
    b1 <- bound_row(h, HEADLINE_MBAR); b0 <- bound_row(h, 0)
    blk <- if (!is.null(b1) && "event_block_note" %in% names(b1) && !is.na(b1$event_block_note)) b1$event_block_note else ""
    g7 <- sel(gro7, gap); gh <- sel(ghd7, gap)
    gb1 <- bound_row(gh, HEADLINE_MBAR)
    sec_g <- vapply(SECONDARY4, function(es) {
      if (!identical(sec$status[sec$name == es], "ok")) return(NA_real_)
      x <- ev6[ev6$estimator %in% es & ev6$gap %in% gap & ev6$event_set %in% "primary", , drop = FALSE]
      if (!nrow(x)) NA_real_ else growth_from_events(x$e, x$att) }, 0)
    d <- dose[dose$gap %in% gap & dose$event_set %in% "primary", , drop = FALSE]
    base <- data.frame(outcome = name, gap = gap, criterion_estimators = crit$estimators, criterion_variants = crit$variants,
                       robust = crit$holds, secondary_estimable = crit$secondary_estimable, disagreeing = crit$disagreeing,
                       stringsAsFactors = FALSE)
    rbind(
      data.frame(base, hypothesis = HYPOTHESIS_OF_GAP[[gap]], verdict = verdict_overall(b1, crit), headline_interval = bound_text(b1),
                 bound_mbar0 = bound_text(b0), largest_mbar_excluding_zero = largest_mbar_excluding_zero(h), event_block = blk,
                 note = "overall post-reform average", stringsAsFactors = FALSE),
      data.frame(base, hypothesis = "H4", verdict = verdict_growth(if (nrow(g7)) g7[1, , drop = FALSE] else NULL, gb1, att, sec_g),
                 headline_interval = bound_text(gb1), bound_mbar0 = bound_text(bound_row(gh, 0)),
                 largest_mbar_excluding_zero = largest_mbar_excluding_zero(gh),
                 event_block = if (!is.null(gb1) && "event_block_note" %in% names(gb1) && !is.na(gb1$event_block_note)) gb1$event_block_note else "",
                 note = paste0("growth contrast G; secondary G: ", paste(SECONDARY4, ifelse(is.na(sec_g), "not estimable", formatC(sec_g, format = "f", digits = 3)),
                                                                     sep = " ", collapse = "; ")), stringsAsFactors = FALSE),
      data.frame(base, hypothesis = "H5", verdict = verdict_dose(if (nrow(d)) d[1, , drop = FALSE] else NULL),
                 headline_interval = if (nrow(d) && is.finite(d$ci_lo[1])) paste0("[", formatC(d$ci_lo[1], format = "f", digits = 3), ", ",
                                                                                 formatC(d$ci_hi[1], format = "f", digits = 3), "]") else
                   if (nrow(d)) as.character(d$status[1]) else "no dose row",
                 bound_mbar0 = "", largest_mbar_excluding_zero = NA_real_, event_block = "",
                 note = if (nrow(d)) paste0("first-stage revenue interval [", formatC(d$revenue_ci_lo[1], format = "f", digits = 3), ", ",
                                            formatC(d$revenue_ci_hi[1], format = "f", digits = 3), "]") else "no dose row", stringsAsFactors = FALSE))
  }))
}

run_verdicts <- function() for (name in REPORT_ORDER) {
  v <- verdict_rows(name)
  wcsv(v, odir(name, "verdicts.csv"))
  say(sprintf("  verdicts %-10s %d rows", name, if (is.null(v)) 0L else nrow(v)))
}

build_report <- function() {
  unlink(REP, recursive = TRUE)
  dir.create(file.path(REP, "plots"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(REP, "tables"), recursive = TRUE, showWarnings = FALSE)
  empty <- data.frame(gap = character(), event_set = character(), weighting = character(), panel = character(), variant = character(),
                      estimator = character(), family = character(), mbar = numeric(), status = character(), stringsAsFactors = FALSE)
  rd0 <- function(f) if (file.exists(f)) rcsv(f) else empty
  cres <- rd0(file.path(CDID_DIR, "results.csv")); cmod <- rd0(file.path(CDID_DIR, "models.csv"))
  pdec <- rd0("outputs/08_power/power_decision.csv")
  md <- c("# Report", "",
          paste0("Run ", run$run_id, "; blinding status **", BLINDING, "**",
                 if (BLINDING != "REAL") " — the event tables are permuted, so every estimate below is a rehearsal and carries no information about the reforms." else "."),
          "",
          paste0("Power simulation (step 8, Section 14): ", if (nrow(pdec) && "classification" %in% names(pdec)) pdec$classification[1] else
                   "no classification in outputs/08_power/power_decision.csv", ". For each gap the honest-DiD bound sets come first; the headline is the bound set at M̄ = 1, and all five M̄ values are shown. Point estimates, p-values and intervals are reported as quantities, and no result is described as statistically significant."),
          "",
          paste0("Primary specification (Section 7.1): Callaway–Sant'Anna, not-yet-treated controls, doubly robust, unbalanced panel, primary suppression sample (high school and graduation), reference period −1, primary event set, unweighted. No report-card source indicator enters any model. Treated-unit floor (Section 5.4): in gaps (b) and (c) of the high school and SEDA families a cohort with fewer than ", COHORT_FLOOR, " treated units at its base period in the primary model's panel is left out of every Callaway–Sant'Anna model of its gap and event set and fitted without covariates in appendix/thin_cohorts.csv. In the event-study tables, † marks a coefficient resting on a single treated state; ‡ marks a model to which fewer than five treated states contribute, with its randomization p-value shown beside the bootstrap interval. Event-time and overall intervals are Webb wild cluster bootstrap intervals (", BOOT_REPS, " draws, state clusters). Revenue is in ", CDID_BASE_YEAR, " dollars."),
          "", "## Hypotheses", "", HYPOTHESES, "",
          "The rules of Section 12 are applied by code from the saved outputs: H1 to H3 from the bound set at M̄ = 1 of the overall post-reform average and the agreement criterion of Section 12.2, H4 from the growth contrast G, and H5 from the dose-scaled estimate. Each family closes with its verdict table. Each answer is stated as an interval.",
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
  few_mark <- function(d) if (nrow(d) && "treated_states" %in% names(d) && isTRUE(d$treated_states[1] < FEW_TREATED_STATES)) " ‡" else ""
  for (name in REPORT_ORDER) {
    fam <- is_family(name)
    dr <- report_dirs(name)
    s5 <- dr$s5; s6 <- dr$s6; s7 <- dr$s7; vd <- odir(name, "variants")
    ev5 <- rd0(file.path(s5, "event_time_estimates.csv")); ov5 <- rd0(file.path(s5, "overall_estimates.csv"))
    ms5 <- rd0(file.path(s5, "model_status.csv"))
    bo7 <- rd0(file.path(s7, "bootstrap_overall.csv")); be7 <- rd0(file.path(s7, "bootstrap_event_time.csv"))
    ri7 <- rd0(file.path(s7, "randomization_overall.csv")); rw7 <- rd0(file.path(s7, "romano_wolf.csv"))
    hd7 <- rd0(file.path(s7, "honestdid_overall.csv"))
    gro7 <- read_or_empty(file.path(s7, "growth_contrast.csv")); ghd7 <- read_or_empty(file.path(s7, "growth_honestdid.csv"))
    grw7 <- read_or_empty(file.path(s7, "growth_romano_wolf.csv")); etg7 <- read_or_empty(file.path(s7, "event_time_gaps.csv"))
    ov6 <- rd0(file.path(s6, "overall_estimates.csv")); ms6 <- rd0(file.path(s6, "model_status.csv"))
    ev6 <- read_or_empty(file.path(s6, "event_time_estimates.csv"))
    pc5 <- read_or_empty(file.path(s5, "panel_counts.csv")); pc6 <- read_or_empty(file.path(s6, "panel_counts.csv"))
    vpc <- read_or_empty(file.path(vd, "panel_counts.csv"))
    vov <- rd0(file.path(vd, "overall_estimates.csv")); vbo <- rd0(file.path(vd, "bootstrap_overall.csv"))
    vri <- rd0(file.path(vd, "randomization_overall.csv")); vhd <- rd0(file.path(vd, "honestdid_overall.csv"))
    vms <- rd0(file.path(vd, "model_status.csv"))
    dose <- rd0(odir(name, "dose", "dose_scaled.csv")); ex_all <- rd0(odir(name, "dose", "revenue_exclusions.csv"))
    lee <- if (name == "hs") rd0(odir(name, "lee", "lee_bounds.csv")) else empty
    flr <- if (fam) rd0(odir(name, "05_primary", "cohort_floor.csv")) else empty
    defs <- if (fam) FAMILY_VARIANTS else VARIANTS
    v9 <- if (fam) family_variants_for(name, split = FALSE) else variants_for(name)
    v10 <- if (fam) family_variants_for(name, split = TRUE) else character()
    gaps <- if (fam) FAMILY_GAPS else outcome_gaps(name)
    md <- c(md, paste0("# ", FAMILY_HEADS[[name]]), "", paste0("Outcome units: ", UNITS_TEXT[[name]], "."), "")
    sel <- function(d, g, s = "primary", w = "unweighted", p = "unbalanced")
      d[d$gap %in% g & d$event_set %in% s & d$weighting %in% w & d$panel %in% p, , drop = FALSE]
    m1 <- function(h, st, id) { r <- h[!is.na(h$mbar) & h$mbar == HEADLINE_MBAR, , drop = FALSE]
      if (!nrow(r)) return(if (nrow(h)) paste0("no bound (", h$status[1], ")") else gone(st, id))
      if (r$status[1] != "ok") return(paste0("no bound (", r$status[1], ")"))
      paste0("[", fmt(r$lb[1]), ", ", fmt(r$ub[1]), "]", blk(r)) }
    for (gap in gaps) {
      title <- GAP_TITLES[[name]][[gap]]
      tf <- function(n, nm) file.path(REP, "tables", paste0(name, "_", gap, "_", n, "_", nm, ".csv"))
      md <- c(md, paste0("## ", title), "")
      mid <- function(s, w, p, v = "primary_specification") paste(name, gap, s, w, p, v, sep = ".")
      id0 <- mid("primary", "unweighted", "unbalanced"); st0 <- sel(ms5, gap)$status
      h <- sel(hd7, gap)
      ht <- if (!nrow(h)) data.frame(`M̄` = "all", status = gone(st0, id0), check.names = FALSE) else
        data.frame(`M̄` = ifelse(!is.na(h$mbar), formatC(h$mbar, format = "g"), ifelse(h$method %in% "original", "original CS (no restriction)", "–")),
                   lower = fmt(h$lb), upper = fmt(h$ub), width = fmt(h$ub - h$lb), status = h$status,
                   grid = ifelse(is.na(h$grid_points), "–", paste0("[", fmt(h$grid_lb), ", ", fmt(h$grid_ub), "], ", h$grid_points, " points")),
                   headline = ifelse(!is.na(h$mbar) & h$mbar == HEADLINE_MBAR, "**headline**", ""), check.names = FALSE)
      if (nrow(h) && "event_block_note" %in% names(h) && any(!is.na(h$event_block_note)))
        ht$event_block <- ifelse(is.na(h$event_block_note), "–", h$event_block_note)
      hx <- h[!is.na(h$mbar) & h$status %in% "ok" & ((h$lb > 0) | (h$ub < 0)), , drop = FALSE]
      wcsv(h, tf(1, "honestdid"))
      md <- c(md, "### 1. Honest-DiD bound sets (relative magnitudes, overall post-reform average)", "",
              "Each M̄ starts on HonestDiD's default grid (±20 standard deviations of the overall estimate, 1,000 points), widened on a side its bound set reaches. Where the estimated event times are not consecutive around the reference period, the bound sets are computed on the largest consecutive block through the reference period and event time 0 (the block rule, Section 8.5), named in the event_block column. The row 'original CS' is the unadjusted confidence set.", "",
              md_table(ht),
              paste0("Largest M̄ at which the bound set excludes zero: ", if (nrow(hx)) formatC(max(hx$mbar), format = "g") else "none", "."), "")
      mg <- sel(etg7, gap)
      if (nrow(mg) && "reason" %in% names(mg))
        md <- c(md, "Event times with no estimate in this model, and why:", "", md_table(data.frame(event_time = mg$event_time, reason = mg$reason)), "")
      ev <- sel(be7, gap); e5 <- sel(ev5, gap)
      md <- c(md, "### 2. Event study with cohorts, treated states and units per coefficient", "")
      if (nrow(ev)) {
        ev$cohorts <- e5$cohorts[match(ev$e, e5$e)]; ev$treated_states <- e5$treated_states[match(ev$e, e5$e)]
        ev$treated_units <- e5$treated_units[match(ev$e, e5$e)]
        ev$att[is.na(ev$att)] <- e5$att[match(ev$e[is.na(ev$att)], e5$e)]
        o <- sel(ov5, gap)
        png_name <- paste0(name, "_", gap, "_event_study.png")
        plot_event_study(file.path(REP, "plots", png_name), ev, if (nrow(o)) o$att else NA_real_, h, title)
        ev$single_treated_state <- !ev$reference & ev$treated_states %in% 1L
        et <- data.frame(event_time = ev$e, estimate = paste0(fmt(ev$att), ifelse(ev$single_treated_state, " †", "")),
                         boot_ci = ci(ev$ci_lo, ev$ci_hi), boot_p = fmt_p(ev$p_value),
                         cohorts = ev$cohorts, treated_states = ev$treated_states, treated_units = ev$treated_units,
                         reference = ifelse(ev$reference, "ref", ""))
        md <- c(md, paste0("![event study](plots/", png_name, ")"), "", md_table(et),
                if (any(ev$single_treated_state)) c("", "† The coefficient rests on a single treated state.") else character())
      } else md <- c(md, md_table(data.frame(event_time = "all", status = gone(st0, id0))))
      names(ev)[names(ev) == "t"] <- "t_stat"
      wcsv(ev, tf(2, "event_study"))
      o <- sel(ov5, gap); b <- sel(bo7, gap); r <- sel(ri7, gap)
      rw <- rw7[rw7$gap %in% gap & rw7$event_set %in% "primary" & rw7$panel %in% "unbalanced" & rw7$family %in% "unweighted", , drop = FALSE]
      few0 <- few_mark(o)
      e5c <- e5[e5$e >= 0 & !is.na(e5$att), , drop = FALSE]
      ot <- data.frame(estimate = paste0(val(o, fmt(o$att), st0, id0), few0), clustered_se = val(b, fmt(b$se), st0, id0),
                       boot_ci = paste0(val(b, ci(b$ci_lo, b$ci_hi), st0, id0),
                                        if (nzchar(few0) && nrow(r)) paste0(" (randomization p = ", fmt_p(r$p_value), ")") else ""),
                       boot_p = val(b, fmt_p(b$p_value), st0, id0),
                       randomization_p = val(r, fmt_p(r$p_value), st0, id0), randomization_reps = val(r, r$reps, st0, id0),
                       romano_wolf_p = fmt_p(if (nrow(rw)) rw$p_romano_wolf else NA), cohorts = val(o, o$cohorts, st0, id0),
                       treated_states = val(o, o$treated_states, st0, id0),
                       cohorts_by_event_time = if (nrow(e5c)) paste(paste0(e5c$e, ":", e5c$cohorts), collapse = " ") else "–",
                       model_status = st1(st0))
      wcsv(ot, tf(3, "overall"))
      md <- c(md, "### 3. Overall post-reform average", "", md_table(ot),
              "cohorts_by_event_time lists event time:cohorts behind each post-reform coefficient of the overall average.", "")
      g7 <- sel(gro7, gap); gh <- sel(ghd7, gap)
      grw <- grw7[grw7$gap %in% gap & grw7$event_set %in% "primary" & grw7$panel %in% "unbalanced" & grw7$family %in% "unweighted", , drop = FALSE]
      sec_g <- vapply(SECONDARY4, function(es) {
        st <- ms6$status[ms6$estimator %in% es & ms6$gap %in% gap & ms6$event_set %in% "primary"]
        x <- ev6[ev6$estimator %in% es & ev6$gap %in% gap & ev6$event_set %in% "primary", , drop = FALSE]
        if (!nrow(x) || !length(st) || !identical(st[1], "ok")) NA_real_ else growth_from_events(x$e, x$att) }, 0)
      gt <- if (!nrow(g7)) data.frame(status = gone(st0, id0)) else
        data.frame(estimate = fmt(g7$att), boot_ci = ci(g7$ci_lo, g7$ci_hi), boot_p = fmt_p(g7$p_value),
                   romano_wolf_p = fmt_p(if (nrow(grw)) grw$p_romano_wolf else NA), early_event_times = g7$early_event_times,
                   late_event_times = g7$late_event_times, cohorts_early = g7$cohorts_early, cohorts_late = g7$cohorts_late,
                   treated_states_early = g7$treated_states_early, treated_states_late = g7$treated_states_late, status = g7$status)
      ght <- if (!nrow(gh)) data.frame(status = "no bound sets for G") else
        data.frame(`M̄` = ifelse(!is.na(gh$mbar), formatC(gh$mbar, format = "g"), ifelse(gh$method %in% "original", "original CS (no restriction)", "–")),
                   lower = fmt(gh$lb), upper = fmt(gh$ub), status = gh$status,
                   event_block = if ("event_block_note" %in% names(gh)) ifelse(is.na(gh$event_block_note), "–", gh$event_block_note) else "–",
                   headline = ifelse(!is.na(gh$mbar) & gh$mbar == HEADLINE_MBAR, "**headline**", ""), check.names = FALSE)
      wcsv(g7, tf(4, "growth")); wcsv(gh, tf(4, "growth_honestdid"))
      md <- c(md, "### 4. Growth contrast G (H4)", "",
              "G = mean of the estimated event-time effects +4 to +8 minus the mean of those 0 to +3 (Section 12.3), with its Webb bootstrap interval from the same draws, the Romano–Wolf p-value across the gaps of the family, the relative-magnitudes bound sets with l_vec set to the contrast weights, the cohorts and treated states behind each window, and the same contrast from each secondary estimator (the stacked regression's late window is +4 and +5).", "",
              md_table(gt), md_table(ght), md_table(data.frame(estimator = SECONDARY4, G = fmt(sec_g)))) 
      d <- dose[dose$gap %in% gap & dose$event_set %in% "primary", , drop = FALSE]
      ex <- ex_all[!is.na(ex_all$gap) & ex_all$gap == gap & ex_all$event_set %in% "primary", , drop = FALSE]
      dt <- if (!nrow(d)) data.frame(status = "no dose row") else
        data.frame(effect_sd = fmt(d$att_outcome), revenue_effect = fmt(d$att_revenue), revenue_boot_ci = ci(d$revenue_ci_lo, d$revenue_ci_hi),
                   sd_per_1000 = fmt(d$dose_scaled), interval_per_1000 = ifelse(is.na(d$ci_lo), "unbounded or none", ci(d$ci_lo, d$ci_hi)),
                   status = d$status)
      wcsv(d, tf(5, "dose"))
      md <- c(md, paste0("### 5. Dose-scaled estimate (per $1,000 of per-pupil state-plus-local revenue, ", CDID_BASE_YEAR, " dollars)"), "",
        paste0("Revenue effect (Section 9): the same Callaway–Sant'Anna model with F-33 (TSTREV + TLOCREV) / V33 in thousands of ", CDID_BASE_YEAR,
               " dollars as the outcome, fiscal years through 2024",
               if (gap == "a_poverty") " (within each state-year, the 2009-10 membership-weighted revenue per pupil of quintile 5 districts minus that of quintile 1 districts)" else " (district revenue per pupil)",
               ". District-years with F-33 enrollment below 30 or revenue above $100,000 per pupil are excluded",
               if (nrow(ex)) sprintf(": %d of the %d district-years in scope (%d below 30 enrolled, %d above $100,000)", ex$excluded_total,
                                     ex$district_years_with_revenue, ex$excluded_enrollment_below_30, ex$excluded_revenue_above_100k) else "",
               ". Both stages are fitted on end years 2010-2024 and averaged over the same post-reform event times; the dose-scaled estimate is the overall average of the outcome over the overall average of revenue, with a percentile interval from the step 7 Webb draws applied to both. **Assumption:** the reform affects the gap only through revenue (exclusion restriction); accountability or other provisions enacted with a reform would violate it. The assumption is stated, not tested."),
        "", md_table(dt))
      if (nrow(lee) && gap %in% lee$gap) {
        l <- lee[lee$gap == gap, ]
        lt <- data.frame(p_minority = fmt(l$p_minority, 4), p_white = fmt(l$p_white, 4), trim_fraction = fmt(l$trim_fraction, 4),
          trimmed_treated_post_district_years = paste0(l$trimmed_unit_years, " of ", l$treated_post_unit_years),
          estimate_trim_top = fmt(l$att_trim_top), estimate_trim_bottom = fmt(l$att_trim_bottom),
          lee_bracket = paste0("[", fmt(l$lee_lower), ", ", fmt(l$lee_upper), "]"), status = l$status)
        wcsv(l, tf(6, "lee"))
        md <- c(md, "### 6. Lee bounds", "", "Tested share (Section 10) = the subgroup's exact tested count (mean of math and RLA) over its CCD grade 9 membership three years earlier, all-students counts where the race count is unavailable; report-card cells without an exact count give no share. For each of the gap's two groups, q_T is the treated post-reform share (aggregated as the overall effect), q_C = q_T minus the Callaway–Sant'Anna effect on the share, and p = 1 − q_C / q_T. The trimming fraction is |p_minority − p_white|, bounded to [0, 1]. The treated post-reform district-years lose that share from the top and, separately, from the bottom of the outcome distribution, and the primary model is refitted each way. The bracket assumes monotone selection.", "", md_table(lt))
      } else md <- c(md, "### 6. Lee bounds", "",
        if (name == "hs" && gap != "a_poverty") paste0("No Lee bounds row for this gap in ", odir(name, "lee", "lee_bounds.csv"), " (the Lee part has not finished).") else
        if (gap == "a_poverty") "Not computed for gap (a)." else
        if (name == "graduation") "Not computed for the graduation gaps: dropout is part of the outcome itself." else
        "Not computed for the SEDA gaps: Lee bounds are computed for the high school gaps (b) and (c).", "")
      a6 <- ov6[ov6$gap %in% gap & ov6$event_set %in% "primary", , drop = FALSE]
      st6 <- ms6$status[match(paste(a6$estimator, a6$gap, a6$event_set), paste(ms6$estimator, ms6$gap, ms6$event_set))]
      p5 <- pc5[pc5$gap %in% gap & pc5$event_set %in% "primary" & pc5$panel %in% "unbalanced" &
                  (if ("weighting" %in% names(pc5)) pc5$weighting %in% "unweighted" else TRUE), , drop = FALSE]
      cs_left <- if (!nrow(p5)) NA else if ("units_left_out" %in% names(p5)) p5$units_left_out[1] else
        if (all(c("units_with_outcome", "units_in_model") %in% names(p5))) p5$units_with_outcome[1] - p5$units_in_model[1] else NA
      ets <- function(e, att) { k <- e >= 0 & is.finite(att); if (any(k)) paste(sort(e[k]), collapse = " ") else "–" }
      et6 <- vapply(seq_len(nrow(a6)), function(i) { x <- ev6[ev6$estimator %in% a6$estimator[i] & ev6$gap %in% gap & ev6$event_set %in% "primary", , drop = FALSE]
        if (nrow(x)) ets(x$e, x$att) else "–" }, "")
      pl6 <- read_or_empty(file.path(s6, "synthdid_pooled.csv"))
      pl6 <- pl6[pl6$estimator %in% "synthdid" & pl6$gap %in% gap & pl6$event_set %in% "primary", , drop = FALSE]
      left6 <- if (nrow(a6) && "units_left_out" %in% names(pc6))
        pc6$units_left_out[match(paste(a6$estimator, a6$gap, a6$event_set), paste(pc6$estimator, pc6$gap, pc6$event_set))] else rep(NA, nrow(a6))
      lab6 <- ifelse(a6$estimator == "synthdid", "synthdid (overall average of event times)", a6$estimator)
      at <- rbind(data.frame(estimator = "callaway_santanna (primary)", estimate = val(o, fmt(o$att), st0, id0), se = val(b, fmt(b$se), st0, id0),
                             ci = val(b, ci(b$ci_lo, b$ci_hi), st0, id0), event_times = ets(e5$e, e5$att), units_left_out = cs_left, status = st1(st0)),
                  if (nrow(a6)) data.frame(estimator = lab6, estimate = fmt(a6$att), se = fmt(a6$se), ci = ci(a6$ci_lo, a6$ci_hi),
                                           event_times = et6, units_left_out = left6, status = st6),
                  if (nrow(pl6)) data.frame(estimator = "synthdid (pooled cohort average)", estimate = fmt(pl6$att[1]), se = fmt(pl6$se[1]),
                                            ci = ci(pl6$ci_lo[1], pl6$ci_hi[1]), event_times = "post-reform years of each cohort",
                                            units_left_out = NA, status = "ok"))
      wcsv(at, tf(7, "agreement"))
      md <- c(md, "### 7. Estimator agreement (unbalanced panel, primary event set)", "",
              paste0("Secondary intervals are each estimator's own state-clustered or placebo interval; the stacked regression averages event times 0..+5; two-way fixed effects rows are for comparison only (Section 7.3). event_times = the post-reform event times each estimator's overall average covers; units_left_out = units of the gap's panel the estimator does not use (Section 16.1). synthdid's overall average of event times enters the agreement criterion; its pooled cohort average is shown for reference. Controls: ",
                     CONTROLS_TEXT[[name]], if (gap == "a_poverty") "" else ", and the 2009 covariates by year", "."), "", md_table(at))
      if (gap != "a_poverty") {
        wt <- bind(lapply(c("unweighted", "tested_weighted"), function(w) {
          st <- sel(ms5, gap, w = w)$status; id <- mid("primary", w, "unbalanced")
          oo <- sel(ov5, gap, w = w); bb <- sel(bo7, gap, w = w); rr <- sel(ri7, gap, w = w)
          data.frame(weighting = w, estimate = paste0(val(oo, fmt(oo$att), st, id), few_mark(oo)), boot_p = val(bb, fmt_p(bb$p_value), st, id),
                     randomization_p = val(rr, fmt_p(rr$p_value), st, id), bound_mbar1 = m1(sel(hd7, gap, w = w), st, id),
                     units = val(oo, oo$treated_units, st, id), status = st1(st)) }))
        wcsv(wt, tf(8, "weighted"))
        md <- c(md, "### 8. Weighted comparison", "", paste0("tested_weighted (Section 7.2): ", WEIGHT_TEXT[[name]], ". units = treated units behind the overall average."), "", md_table(wt))
      } else md <- c(md, "### 8. Weighted comparison", "", "Gap (a) is a state-level outcome and has no weighted version.", "")
      nt <- bind(lapply(SETS, function(s) { dd <- dose[dose$gap %in% gap & dose$event_set %in% s, , drop = FALSE]
        st <- sel(ms5, gap, s)$status; id <- mid(s, "unweighted", "unbalanced")
        oo <- sel(ov5, gap, s); bb <- sel(bo7, gap, s); rr <- sel(ri7, gap, s)
        data.frame(event_set = s, estimate = paste0(val(oo, fmt(oo$att), st, id), few_mark(oo)), boot_ci = val(bb, ci(bb$ci_lo, bb$ci_hi), st, id),
                   boot_p = val(bb, fmt_p(bb$p_value), st, id), randomization_p = val(rr, fmt_p(rr$p_value), st, id),
                   bound_mbar1 = m1(sel(hd7, gap, s), st, id), sd_per_1000 = if (nrow(dd)) fmt(dd$dose_scaled) else "–", status = st1(st)) }))
      wcsv(nt, tf(9, "event_sets"))
      md <- c(md, "### 9. Narrower event definitions", "", "r1 = LRS list plus final state supreme court rulings; r2 = court rulings only (Section 3).", "", md_table(nt))
      vrow <- function(v) { f <- function(x) x[x$variant %in% v, , drop = FALSE]
        st <- sel(f(vms), gap)$status; id <- mid("primary", "unweighted", "unbalanced", v)
        oo <- sel(f(vov), gap); bb <- sel(f(vbo), gap); rr <- sel(f(vri), gap)
        data.frame(check = defs[[v]]$label, estimate = paste0(val(oo, fmt(oo$att), st, id), few_mark(oo)), boot_p = val(bb, fmt_p(bb$p_value), st, id),
                   randomization_p = val(rr, fmt_p(rr$p_value), st, id), randomization_reps = val(rr, rr$reps[1], st, id),
                   bound_mbar1 = m1(sel(f(vhd), gap), st, id), status = st1(st)) }
      bal <- NULL
      if (name != "seda") {
        stb <- sel(ms5, gap, p = "balanced")$status; idb <- mid("primary", "unweighted", "balanced")
        ob <- sel(ov5, gap, p = "balanced"); bb <- sel(bo7, gap, p = "balanced"); rb <- sel(ri7, gap, p = "balanced")
        bal <- data.frame(check = "Balanced panel (Section 5.3)", estimate = paste0(val(ob, fmt(ob$att), stb, idb), few_mark(ob)),
                          boot_p = val(bb, fmt_p(bb$p_value), stb, idb), randomization_p = val(rb, fmt_p(rb$p_value), stb, idb),
                          randomization_reps = val(rb, rb$reps[1], stb, idb), bound_mbar1 = m1(sel(hd7, gap, p = "balanced"), stb, idb),
                          status = st1(stb))
      }
      rt <- rbind(bal, bind(lapply(v9, vrow)))
      wcsv(rt, tf(10, "robustness"))
      md <- c(md, "### 10. Registered robustness checks: sample variants, then timing variants (primary event set, unweighted)", "",
              paste0("Section 11. Variants on all three event sets and both weightings, with event times, Romano–Wolf families and every M̄: ", vd,
                     ". Randomization inference uses ", RI_REPS_VARIANT, " reassignments on the variants",
                     if (name == "seda") "; the suppression samples, the 2013 start and the balanced panel do not apply to SEDA" else
                       if (name == "graduation") "; the 2013 start does not apply to the graduation gaps" else "", "."),
              "", md_table(rt))
      md <- c(md, "### 11. Source, coverage and span splits (primary event set, unweighted)", "")
      if (length(v10)) {
        prim <- data.frame(check = if (name == "hs") "Full high school panel, 2010–2025 (primary specification)" else
                             "Full SEDA window, 2009–2019 and 2022–2025 (primary specification)",
                           estimate = paste0(val(o, fmt(o$att), st0, id0), few_mark(o)), boot_p = val(b, fmt_p(b$p_value), st0, id0),
                           randomization_p = val(r, fmt_p(r$p_value), st0, id0), randomization_reps = val(r, r$reps[1], st0, id0),
                           bound_mbar1 = m1(h, st0, id0), status = st1(st0))
        sp <- rbind(prim, bind(lapply(v10, vrow)))
        wcsv(sp, tf(11, "splits"))
        md <- c(md, if (name == "hs") "Section 11. The source split fits the high school models on the federal years 2010–2021 alone; beside the full panel it shows the contribution of the report-card years. The coverage split keeps the states covered in every report-card year, federal years included." else
                  "Section 11. SEDA's 2022–2025 estimates come from public suppressed state data rather than the restricted-use counts behind 2009–2019; each span is rerun alone, with cohorts coded over its own years.",
                "", md_table(sp))
      } else md <- c(md, "No split applies to the graduation gaps.", "")
      md <- c(md, "### 12. Treated-unit floor and panel counts", "")
      cnt <- bind(c(list(
        if (nrow(sel(pc5, gap))) data.frame(panel = "primary (unbalanced)", units = sel(pc5, gap)$units_in_model[1], states = sel(pc5, gap)$states_in_model[1]) else
          if (nrow(p5)) data.frame(panel = "primary (unbalanced)", units = p5$units_in_model[1], states = p5$states_in_model[1]),
        if (name != "seda") { pb <- pc5[pc5$gap %in% gap & pc5$event_set %in% "primary" & pc5$panel %in% "balanced" &
                                          (if ("weighting" %in% names(pc5)) pc5$weighting %in% "unweighted" else TRUE), , drop = FALSE]
          if (nrow(pb)) data.frame(panel = "balanced", units = pb$units_in_model[1], states = pb$states_in_model[1]) }),
        lapply(c("sample_r5", "sample_exact"), function(v) { x <- vpc[vpc$variant %in% v & vpc$gap %in% gap & vpc$event_set %in% "primary" &
                                                                      vpc$weighting %in% "unweighted", , drop = FALSE]
          if (nrow(x)) data.frame(panel = v, units = x$units_in_model[1], states = x$states_in_model[1]) })))
      md <- c(md, "Units and states behind the primary event set's models (Section 5.3):", "",
              if (is.null(cnt)) "_No rows._\n" else md_table(cnt))
      if (name == "hs") {
        rcy <- read_or_empty("outputs/10_hs_reportcard_outcomes/usable_gaps_by_year.csv")
        rcy <- rcy[rcy$gap %in% gap & "sy_end" %in% names(rcy), , drop = FALSE]
        if (nrow(rcy)) rcy <- rcy[rcy$sy_end >= RC_FROM, c("sy_end", "units"), drop = FALSE]
        md <- c(md, "Unit-years with a usable gap contributed by each report-card year:", "",
                if (nrow(rcy)) md_table(rcy) else "_No rows._\n")
      }
      if (!fam) md <- c(md, "The treated-unit floor does not apply to the graduation gaps.", "") else
        if (gap == "a_poverty") md <- c(md, "Gap (a) has no covariates and no floor.", "") else {
          fg <- flr[flr$gap %in% gap, , drop = FALSE]
          ft <- if (nrow(fg) && "below_floor" %in% names(fg))
            stats::aggregate(list(cohorts = rep(1L, nrow(fg)), removed_by_floor = as.integer(fg$below_floor)), fg["event_set"], sum) else
            data.frame(status = "no cohort_floor.csv rows for this gap")
          md <- c(md, "Cohorts in the primary panel of each event set and those removed by the floor; the removed cohorts are fitted without covariates in the appendix.", "", md_table(ft))
        }
      hb <- h[!is.na(h$mbar) & h$mbar == HEADLINE_MBAR, , drop = FALSE]
      ans[[paste(name, gap)]] <- data.frame(outcome = name, gap = gap,
        sd_interval_mbar1 = if (nrow(hb) && hb$status[1] == "ok") paste0("[", fmt(hb$lb), ", ", fmt(hb$ub), "]", blk(hb)) else
          if (!nrow(h)) gone(st0, id0) else paste0("none (", if (nrow(hb)) hb$status[1] else h$status[1], ")"),
        per_1000_interval = if (nrow(d) && !is.na(d$ci_lo)) paste0("[", fmt(d$ci_lo), ", ", fmt(d$ci_hi), "]") else
          if (nrow(d) && startsWith(d$status, "unbounded")) "unbounded (the revenue effect's bootstrap interval includes zero)" else
          paste0("none (", if (nrow(d)) d$status else "no dose row", ")"), stringsAsFactors = FALSE)
      md <- c(md, "### Answer, stated as intervals", "",
              paste0("SD units: honest-DiD bound set at M̄ = 1, ", ans[[paste(name, gap)]]$sd_interval_mbar1,
                     ". Per $1,000 of per-pupil revenue (", CDID_BASE_YEAR, " dollars): ", ans[[paste(name, gap)]]$per_1000_interval,
                     " (percentile interval of the dose-scaled ratio; the first interval rests on bounded departures from parallel trends, the second on parallel trends and the exclusion restriction)."), "")
    }
    vt <- read_or_empty(odir(name, "verdicts.csv"))
    if (nrow(vt) && "verdict" %in% names(vt)) {
      vt$largest_mbar_excluding_zero <- ifelse(is.na(vt$largest_mbar_excluding_zero), "none", formatC(vt$largest_mbar_excluding_zero, format = "g"))
      for (cc in c("bound_mbar0", "event_block", "headline_interval")) vt[[cc]] <- ifelse(is.na(vt[[cc]]) | !nzchar(vt[[cc]]), "–", vt[[cc]])
    }
    md <- c(md, paste0("## Hypothesis verdicts: ", FAMILY_HEADS[[name]]), "",
            paste0("Section 12, applied by code to the primary model of each gap (primary event set, unweighted, unbalanced panel, primary suppression sample",
                   if (name %in% c("hs", "seda")) ", with the treated-unit floor" else "", ").",
                   if (name != "hs") " Evidence on this outcome; it does not change the high school verdicts." else ""), "",
            if (nrow(vt) && "verdict" %in% names(vt)) md_table(vt[c("gap", "hypothesis", "verdict", "headline_interval", "bound_mbar0",
                                                                   "largest_mbar_excluding_zero", "criterion_estimators", "criterion_variants",
                                                                   "event_block")]) else "_No verdict rows._\n")
  }
  md <- c(md, "# Continuous-treatment estimates (exploratory; step 11, DIDmultiplegtDYN; Section 7.6)", "",
          paste0("Treatment: binned real revenue per pupil (bin_1000 primary, bin_2000 sensitivity), a discrete treatment; effects at event times 0..+8 and placebos at −2..−6, reference −1; an effect or placebo with fewer than 20 stayers or stayers in fewer than 3 states is not estimable. These results are exploratory and are reported after all event-based results. **Caveat:** ",
                 if ("se_caveat" %in% names(cres) && nrow(cres) && !is.na(cres$se_caveat[1])) cres$se_caveat[1] else CDID_SE_CAVEAT), "")
  for (name in REPORT_ORDER) for (gap in (if (is_family(name)) FAMILY_GAPS else outcome_gaps(name))) {
    tf <- function(n, nm) file.path(REP, "tables", paste0(name, "_", gap, "_", n, "_", nm, ".csv"))
    cr <- cres[cres$family %in% name & cres$gap %in% gap, , drop = FALSE]
    cm <- cmod[cmod$family %in% name & cmod$gap %in% gap, , drop = FALSE]
    md <- c(md, paste0("## ", GAP_TITLES[[name]][[gap]], ": continuous treatment"), "")
    if (nrow(cr)) {
      cr <- cr[order(cr$bin, cr$event_time), , drop = FALSE]
      ct <- data.frame(bin = cr$bin, type = cr$row_type, package_label = cr$package_label, event_time = cr$event_time,
                       estimate = fmt(cr$estimate), se = fmt(cr$se), ci = ci(cr$ci_lo, cr$ci_hi), switchers = cr$switchers,
                       stayers = cr$stayers, stayer_states = cr$stayer_states, status = cr$status)
      wcsv(cr[setdiff(names(cr), "se_caveat")], tf(13, "continuous"))
      mt <- if (nrow(cm)) data.frame(bin = cm$bin, units_with_outcome = cm$units_with_outcome, switchers_used = cm$switchers_used,
                                     switchers_dropped_no_stayer_in_bin = cm$switchers_dropped_no_stayer_in_bin, estimation = cm$estimation) else NULL
      md <- c(md, if (!is.null(mt)) md_table(mt) else "", md_table(ct))
    } else md <- c(md, paste0("No continuous-treatment rows for this gap in ", file.path(CDID_DIR, "results.csv"), "."), "")
  }
  fl <- bind(lapply(FAMILIES, function(fm) { x <- rd0(odir(fm, "05_primary", "cohort_floor.csv"))
    if (nrow(x) && "cohort" %in% names(x)) data.frame(family = fm, x, stringsAsFactors = FALSE) }))
  thin <- bind(lapply(FAMILIES, function(fm) { f <- odir(fm, "05_primary", "thin_cohorts.csv"); if (file.exists(f)) rcsv(f) }))
  dir.create(file.path(REP, "appendix"), showWarnings = FALSE)
  md <- c(md, "# Appendix: cohorts below the treated-unit floor", "",
          paste0("Section 5.4. A cohort with fewer than ", COHORT_FLOOR,
                 " treated units at its base period (the last window year before the cohort year) in the primary model's panel of its gap and event set (primary suppression sample, unbalanced, unweighted) is left out of every covariate-adjusted Callaway–Sant'Anna model of that gap and event set in the high school and SEDA families: step 5 under both weightings and panel rules, the variants and splits, and the Lee and dose refits. Each removed cohort is fitted without covariates on its gap's primary panel, all cohorts present; its group-time cells and did's group aggregate are in appendix/thin_cohorts.csv, with the cohort's treated units at the base period and in any year. Gap (a) has no covariates and no floor."), "")
  if (!is.null(fl) && nrow(fl)) {
    wcsv(fl, file.path(REP, "appendix", "cohort_floor.csv"))
    rmv <- fl[fl$below_floor, , drop = FALSE]
    kept <- stats::aggregate(list(cohorts_kept = !fl$below_floor), fl[c("family", "gap", "event_set")], sum)
    rmt <- if (nrow(rmv)) data.frame(family = rmv$family, gap = rmv$gap, event_set = rmv$event_set, cohort = rmv$cohort, states = rmv$states,
                                    base_year = rmv$base_year, treated_units_base = rmv$treated_units_base, treated_units = rmv$treated_units) else
      data.frame(status = "no cohort below the floor")
    md <- c(md, "Removed cohorts:", "", md_table(rmt), "", "Cohorts remaining in the primary panel of each gap and event set:", "",
            md_table(kept[order(kept$family, kept$gap, kept$event_set), ]), "")
  } else md <- c(md, "No cohort_floor.csv in the step 5 outputs.", "")
  if (!is.null(thin) && nrow(thin)) wcsv(thin, file.path(REP, "appendix", "thin_cohorts.csv"))
  at <- bind(ans)
  wcsv(at, file.path(REP, "tables", "answer_intervals.csv"))
  md <- c(md[seq_len(n_head)], "## Answer to the research question, by outcome and gap", "", md_table(at), md[-seq_len(n_head)])
  writeLines(enc2utf8(md), file.path(REP, "report.md"), useBytes = TRUE)
  say("Report: ", file.path(REP, "report.md"), " (", length(list.files(file.path(REP, "plots"))), " plots, ",
      length(list.files(file.path(REP, "tables"))), " tables)")
  say("Report: ", length(missing_models), " models shown with their recorded status in place of numbers",
      if (length(missing_models)) paste0(": ", paste(sort(missing_models), collapse = ", ")) else "")
}
part("verdicts", run_verdicts)
part("report", build_report)

total <- sum(run$times$seconds)
say(sprintf("Run %s finished. Total run time over parts: %.2f h (wall clock since start: %.2f h)", run$run_id, total / 3600,
            as.numeric(difftime(Sys.time(), run$started, units = "hours"))))
say("Run times per part: ", file.path(OUT, "run_times.csv"), "; log: ", log_file)

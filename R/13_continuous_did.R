# Step 13 (Run 2). Continuous-treatment estimator (docs/design_extension.md, Sections 3 and 7).
# Run from the repository folder:
#   Rscript R/13_continuous_did.R                 treatment, panels, counts, and did_multiplegt_dyn() on every model
#   Rscript R/13_continuous_did.R --counts-only   the same without estimation
# Each model is fitted in a child R process (`--fit-rds <in> <out>`, internal), so that an abort inside
# polars' Rust code ends that fit, not the run; the child reads its panel from, and writes the package's
# rows to, the session's temporary folder.
#
# Inputs
#   data/raw/f33/f33-fy2010.csv ... f33-fy2024.csv (fy2022 .xlsx)   revenue per pupil (TSTREV + TLOCREV) / V33
#   data/raw/cpi/cuur0000sa0.csv                                     CPI-U, July-June, 2025 dollars
#   data/derived/hs_gaps_run2.csv          extended high school gaps (step 12), primary suppression sample
#   data/derived/seda_gaps.csv             SEDA gaps (step 11); never deposited, only estimates and counts are written
#   data/derived/gaps_graduation_district_year.csv   Run 1 graduation gaps, primary sample
#   data/derived/sample_district_year.csv  Run 1 gap (a) districts (high school)
#   data/raw/ccd/*.zip, data/raw/saipe/saipe-district-2009.txt       SEDA gap (a) districts, 2009-10 membership
#   data/reference/event_table.csv         rule 6 (each state's group) for the SEDA gap (a) districts only
# Outputs (outputs/run2/13_continuous/; no district-level value)
#   settings.csv                 estimator settings, package and polars versions
#   revenue_exclusions.csv       F-33 district-years by fiscal year and Run 1 floor
#   gap_a_revenue_states.csv     state-years with a gap (a) revenue treatment, by family
#   models.csv                   one row per model: units, switchers used and dropped, estimation status
#   switch_status.csv            units by first switch year and direction, per model
#   counts.csv                   switchers and stayers per effect and placebo, package label and event time,
#                                estimability
#   results.csv                  counts joined to the package's estimates (blank where not estimable), the caveat
#   package_rows.csv             every row the package returned, including the average total effect
#   log: outputs/logs/13_continuous_did_<stamp>.log
#
# Author decisions 2026-09-16 (docs/deviations_run2.md): see R/functions/continuous_did.R. Models: three
# outcome families (hs, seda, graduation) x their gaps x two bin widths (1,000 primary, 2,000 sensitivity);
# primary suppression sample, unweighted, the primary event set's retained flag, no event-set runs.
#
# Memory. On the study machine (Windows 11, R 4.6.1, polars 1.9000.9000.9000 at commit 08ba079) the
# package's commit charge exceeded the machine's limit (about 119 GB) in two cases. With continuous = 1 it
# grows roughly linearly in effects + placebos and quadratically in controls: 57 GB for 5 effects and
# 113 GB for 8 effects with no user controls on a synthetic 200-unit, 15-year panel; 9 effects abort.
# On the binned treatment as a discrete variable, 9 effects and 5 placebos on a synthetic 2,000-unit
# panel take 20 GB with no controls, but one covariate interacted with the window years (13 controls)
# already aborts at 2 effects. The models therefore run discrete and without controls.

for (f in list.files("R/functions", full.names = TRUE)) source(f)
args <- commandArgs(trailingOnly = TRUE)

# ---- child process: one fit ---------------------------------------------------------------------
if (length(args) == 3L && args[1] == "--fit-rds") {
  suppressMessages(library(polars))
  job <- readRDS(args[2])
  fr <- run_cdid(job$panel, job$controls)
  saveRDS(list(rows = cdid_package_rows(fr$fit), messages = fr$messages, status = fr$status, seconds = fr$seconds), args[3])
  quit(save = "no", status = 0)
}

ESTIMATE <- !"--counts-only" %in% args
stage2 <- as.integer(readLines("data/stage_run2.txt", n = 1, warn = FALSE))
if (!identical(stage2, 2L)) stop("R/13_continuous_did.R reads Run 2 outcome files, which needs data/stage_run2.txt = 2.")

stamp   <- format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ")
out_dir <- "outputs/run2/13_continuous"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/logs", recursive = TRUE, showWarnings = FALSE)
log_file <- file.path("outputs", "logs", paste0("13_continuous_did_", stamp, ".log"))
say <- function(...) {
  txt <- paste0(...)
  cat(txt, "\n", sep = "")
  cat(txt, "\n", sep = "", file = log_file, append = TRUE)
}
show <- function(x) say(paste(utils::capture.output(print(x, row.names = FALSE)), collapse = "\n"))
wcsv <- function(x, name) utils::write.csv(x, file.path(out_dir, name), row.names = FALSE, na = "")

say("Step 13 continuous treatment, run ", stamp, "; stage_run2 ", stage2, "; estimation ", if (ESTIMATE) "on" else "off")
say("DIDmultiplegtDYN ", as.character(utils::packageVersion("DIDmultiplegtDYN")), "; polars ",
    as.character(utils::packageVersion("polars")), " (RemoteSha ", utils::packageDescription("polars")$RemoteSha, ")")
stopifnot(as.character(utils::packageVersion("DIDmultiplegtDYN")) == CDID_PACKAGE_VERSION,
          identical(utils::packageDescription("polars")$RemoteSha, CDID_POLARS_SHA))
unlink(file.path(out_dir, c("results.csv", "package_rows.csv")))

wcsv(data.frame(setting = c("package", "polars_remote_sha", "treatment", "continuous", "effects", "placebo", "event_times_effects",
                            "event_times_placebos", "cluster", "standard_errors", "bootstrap", "controls", "weights",
                            "suppression_sample", "retained_flag", "bin_widths_thousands", "dollars", "revenue_floor", "f33_years",
                            "window_hs", "window_seda", "window_graduation", "min_stayers", "min_stayer_states", "estimation_run"),
                value = c(paste("DIDmultiplegtDYN", CDID_PACKAGE_VERSION), CDID_POLARS_SHA,
                          "binned revenue as a discrete variable; switchers compared with stayers of the same baseline bin",
                          "not set", CDID_EFFECTS, CDID_PLACEBO,
                          "0..+8 (Effect_l = l - 1)", "-2..-6 (Placebo_l = -(l + 1)); reference -1", "state", "analytical, clustered",
                          "none", "none (covariate-by-year controls exceed memory)", "none (unweighted)", "primary",
                          "retained (primary event set)", paste(CDID_BIN_WIDTHS, collapse = " "), paste("CPI-U July-June,", CDID_BASE_YEAR),
                          sprintf("V33 >= %d and revenue <= %d thousand per pupil", CDID_REV_MIN_ENROLL, CDID_REV_MAX_PP),
                          paste(range(CDID_F33_YEARS), collapse = "-"),
                          vapply(CDID_WINDOWS, function(w) paste(w, collapse = " "), ""),
                          CDID_MIN_STAYERS, CDID_MIN_STAYER_STATES, ESTIMATE)), "settings.csv")

# ---- revenue ------------------------------------------------------------------------------------
rev_all <- cdid_real_revenue(f33_revenue())
ex <- data.frame(sy_end = sort(unique(rev_all$sy_end)))
ex$district_years <- as.vector(table(rev_all$sy_end))
ex$enrollment_below_30 <- as.vector(tapply(rev_all$v33 < CDID_REV_MIN_ENROLL, rev_all$sy_end, sum))
ex$revenue_above_100k <- as.vector(tapply(rev_all$rev_pp_real > CDID_REV_MAX_PP, rev_all$sy_end, sum))
ex$excluded <- as.vector(tapply(rev_all$excluded, rev_all$sy_end, sum))
ex$median_revenue_pp_thousands <- round(as.vector(tapply(rev_all$rev_pp_real[!rev_all$excluded], rev_all$sy_end[!rev_all$excluded], stats::median)), 2)
wcsv(ex, "revenue_exclusions.csv")
say("\n== F-33 revenue per pupil, thousands of ", CDID_BASE_YEAR, " dollars (Run 1 floor)")
show(ex)
rev <- rev_all[!rev_all$excluded, c("leaid", "sy_end", "rev_pp_real", "excluded")]

# ---- outcomes -------------------------------------------------------------------------------------
rd <- function(f, ...) data.table::fread(f, colClasses = c(leaid = "character"), data.table = FALSE, showProgress = FALSE, ...)

hs <- rd("data/derived/hs_gaps_run2.csv", select = c("gap", "state", "leaid", "sy_end", "subject", "sample", "retained", "v"))
hs <- hs[hs$sample == "primary" & hs$retained == 1L & !is.na(hs$v), ]
say("\nHigh school: end year 2025 left out (F-33 ends at fiscal year 2024): ", sum(hs$sy_end == 2025L),
    " retained gap-subject rows, primary sample")
hs <- hs[hs$sy_end %in% CDID_WINDOWS$hs, ]
seda <- rd("data/derived/seda_gaps.csv", select = c("gap", "state", "leaid", "sy_end", "retained", "v"))
seda <- seda[seda$retained == 1L & !is.na(seda$v), ]
say("SEDA: end years 2009 and 2025 left out (no F-33 year): ", sum(seda$sy_end %in% c(2009L, 2025L)), " retained gap rows")
seda <- seda[seda$sy_end %in% CDID_WINDOWS$seda, ]
grad <- rd("data/derived/gaps_graduation_district_year.csv")

outcome_panel <- function(family, gap) {
  if (family == "hs") {
    x <- hs[hs$gap == gap, ]
    unit <- if (gap == "a_poverty") "state" else "leaid"
    p <- both_subjects(x, unit, "v", CDID_WINDOWS$hs, balanced = FALSE)
  } else if (family == "seda") {
    x <- seda[seda$gap == gap, ]
    unit <- if (gap == "a_poverty") "state" else "leaid"
    p <- x[c(unit, "state", "sy_end")[!duplicated(c(unit, "state", "sy_end"))]]
    p$y <- x$v
  } else {
    unit <- "leaid"
    p <- grad_panel(grad, GRAD_GAPS[[gap]], "retained", CDID_WINDOWS$graduation, "primary", balanced = FALSE)
  }
  data.frame(unit = p[[unit]], state = p$state, sy_end = p$sy_end, y = p$y, stringsAsFactors = FALSE)
}

# ---- gap (a) treatment: Run 1's dose measure --------------------------------------------------------
gap_a_treat <- list()
d_hs <- hs_gap_a_districts()
gap_a_treat$hs <- quintile_revenue_gap(gap_a_district_years(d_hs, CDID_F33_YEARS), rev)
d_seda <- seda_gap_a_districts(unique(seda$leaid[!is.na(seda$leaid)]))
say("SEDA gap (a) quintile set rebuilt: ", sum(d_seda$in_quintile_set & d_seda$retained == 1L),
    " districts (primary set; step 11 log: 8533), with 2009-10 membership > 0: ",
    sum(d_seda$in_quintile_set & d_seda$retained == 1L & !is.na(d_seda$member_2009) & d_seda$member_2009 > 0), " (8532)")
gap_a_treat$seda <- quintile_revenue_gap(gap_a_district_years(d_seda, CDID_F33_YEARS), rev)
ga <- do.call(rbind, lapply(names(gap_a_treat), function(fm) {
  z <- gap_a_treat[[fm]]
  data.frame(family = fm, sy_end = sort(unique(z$sy_end)), states = as.vector(table(z$sy_end)), stringsAsFactors = FALSE)
}))
wcsv(ga, "gap_a_revenue_states.csv")

# ---- fits ---------------------------------------------------------------------------------------------
fit_in_child <- function(panel, key) {
  inp <- tempfile(paste0("cdid_in_", key, "_"), fileext = ".rds")
  outp <- tempfile(paste0("cdid_out_", key, "_"), fileext = ".rds")
  errf <- tempfile(paste0("cdid_err_", key, "_"), fileext = ".txt")
  saveRDS(list(panel = panel, controls = character()), inp)
  on.exit(unlink(c(inp, outp, errf)))
  t0 <- proc.time()[["elapsed"]]
  code <- system2(file.path(R.home("bin"), "Rscript"), c("R/13_continuous_did.R", "--fit-rds", shQuote(inp), shQuote(outp)),
                  stdout = errf, stderr = errf)
  if (file.exists(outp)) return(readRDS(outp))
  txt <- if (file.exists(errf)) grep("renv|out-of-sync", readLines(errf, warn = FALSE), value = TRUE, invert = TRUE) else character()
  list(rows = NULL, messages = character(), status = sprintf("aborted (exit code %s): %s", code, paste(utils::tail(txt, 3), collapse = " ")),
       seconds = proc.time()[["elapsed"]] - t0)
}

# ---- models -----------------------------------------------------------------------------------------
models <- list(); counts <- list(); switch_rows <- list(); results <- list(); pkg_rows <- list()
for (family in names(CDID_GAPS)) for (gap in CDID_GAPS[[family]]) {
  window <- CDID_WINDOWS[[family]]
  y <- outcome_panel(family, gap)
  treat_real <- if (gap == "a_poverty") data.frame(unit = gap_a_treat[[family]]$state, sy_end = gap_a_treat[[family]]$sy_end,
                                                   x = gap_a_treat[[family]]$rev_gap, stringsAsFactors = FALSE) else
    data.frame(unit = rev$leaid, sy_end = rev$sy_end, x = rev$rev_pp_real, stringsAsFactors = FALSE)
  treat_real <- treat_real[treat_real$unit %in% y$unit, , drop = FALSE]
  for (bw in names(CDID_BIN_WIDTHS)) {
    key <- paste(family, gap, bw, sep = ".")
    treat <- data.frame(unit = treat_real$unit, sy_end = treat_real$sy_end, d = revenue_bin(treat_real$x, CDID_BIN_WIDTHS[[bw]]),
                        stringsAsFactors = FALSE)
    p <- cdid_panel(y, treat, window)
    cnt <- cdid_counts(p)
    su <- attr(cnt, "switcher_units")
    sd <- cdid_switch_dates(p)
    sw <- as.data.frame(table(first_switch = ifelse(is.finite(sd$first_switch), sd$first_switch, "never"),
                              direction = sd$direction, useNA = "no"), responseName = "units", stringsAsFactors = FALSE)
    sw <- sw[sw$units > 0, , drop = FALSE]
    switch_rows[[key]] <- data.frame(family = family, gap = gap, bin = bw, sw, stringsAsFactors = FALSE)
    cnt$estimable <- cdid_estimable(cnt$stayers, cnt$stayer_states)
    cnt$status <- ifelse(cnt$estimable, "estimable",
                         sprintf("not estimable: %d stayers in %d states (need %d in %d)", cnt$stayers, cnt$stayer_states,
                                 CDID_MIN_STAYERS, CDID_MIN_STAYER_STATES))
    counts[[key]] <- data.frame(family = family, gap = gap, bin = bw, bin_width_dollars = 1000 * CDID_BIN_WIDTHS[[bw]], cnt,
                                stringsAsFactors = FALSE)
    models[[key]] <- data.frame(family = family, gap = gap, bin = bw, unit = if (gap == "a_poverty") "state" else "district",
      units_with_outcome = length(unique(p$unit[!is.na(p$y)])), unit_years_with_outcome = sum(!is.na(p$y)),
      units_no_treatment = sum(is.na(sd$baseline_year)), states = length(unique(p$state)),
      first_year = min(p$sy_end), last_year = max(p$sy_end), placeholder_years = paste(sort(unique(p$sy_end[p$placeholder])), collapse = " "),
      baseline_bins = length(unique(sd$baseline_d[!is.na(sd$baseline_d)])),
      controls = 0L, controls_specified = if (gap == "a_poverty") 0L else length(CS_COVARIATES) * (length(window) - 1L),
      stayers_never_switching = sum(sd$direction %in% "stayer"), switcher_units = nrow(su), switchers_used = sum(su$used),
      switchers_dropped_no_stayer_in_bin = sum(su$no_stayer), switchers_bin_with_one_switch_date = sum(su$level_dropped),
      switchers_unused_other = sum(!su$used & !su$no_stayer),
      effects_estimable = sum(cnt$estimable & cnt$row_type == "effect"), placebos_estimable = sum(cnt$estimable & cnt$row_type == "placebo"),
      estimation = if (ESTIMATE) "pending" else "not run (--counts-only)", seconds = NA_real_, stringsAsFactors = FALSE)
    say(sprintf("\n== %s: %d units with an outcome, %d baseline bins; switchers %d, used %d, dropped for no stayer in their bin %d",
                key, models[[key]]$units_with_outcome, models[[key]]$baseline_bins, nrow(su), sum(su$used), sum(su$no_stayer)))
    show(counts[[key]][c("package_label", "event_time", "switchers", "stayers", "stayer_states", "status")])

    if (ESTIMATE) {
      fr <- fit_in_child(p, key)
      models[[key]]$estimation <- fr$status; models[[key]]$seconds <- round(fr$seconds, 1)
      res <- cdid_results(cnt[setdiff(names(cnt), c("estimable", "status"))], fr$rows)
      results[[key]] <- data.frame(family = family, gap = gap, bin = bw, res, stringsAsFactors = FALSE)
      if (!is.null(fr$rows)) pkg_rows[[key]] <- data.frame(family = family, gap = gap, bin = bw, fr$rows, se_caveat = CDID_SE_CAVEAT,
                                                           stringsAsFactors = FALSE)
      say(sprintf("  fit: %s (%.0f s)%s", fr$status, fr$seconds,
                  if (length(fr$messages)) paste0("; package messages: ", paste(fr$messages, collapse = " | ")) else ""))
      if (!is.null(fr$rows) && !all(res$switchers_match_package[!is.na(res$switchers_package)]))
        say("  WARNING: switcher counts differ from the package's for ", key)
      if (!is.null(fr$rows) && !all(res$n_match_package %in% c(TRUE, NA)))
        say("  WARNING: switchers + stayer years differ from the package's N for ", key)
      wcsv(do.call(rbind, results), "results.csv")
      if (length(pkg_rows)) wcsv(do.call(rbind, pkg_rows), "package_rows.csv")
    }
  }
}

wcsv(do.call(rbind, models), "models.csv")
wcsv(do.call(rbind, counts), "counts.csv")
wcsv(do.call(rbind, switch_rows), "switch_status.csv")
say("\n== Models")
show(do.call(rbind, models)[c("family", "gap", "bin", "units_with_outcome", "switcher_units", "switchers_used",
                              "switchers_dropped_no_stayer_in_bin", "effects_estimable", "placebos_estimable", "estimation")])
say("\nWrote ", out_dir, "; log ", log_file)

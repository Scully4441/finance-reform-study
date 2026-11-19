for (f in list.files("R/functions", full.names = TRUE)) source(f)

OUTCOME <- outcome_arg()
stage <- as.integer(readLines("data/stage.txt", n = 1, warn = FALSE))
if (OUTCOME == "achievement") {
  if (!identical(stage, 2L)) stop("the achievement pass reads the full window, which needs stage 2")
  WINDOW <- ACH_WINDOW
  GAPS   <- c("a_poverty", "b_black_white", "c_hispanic_white")
  WCOL   <- "tested_2010"
} else {
  if (!identical(stage, 2L)) stop("the graduation pass needs stage 2 (graduation files after 2012-13)")
  WINDOW <- GRAD_WINDOW
  GAPS   <- names(GRAD_GAPS)
  WCOL   <- GRAD_WEIGHT
}
SAMPLE <- "primary"
EVENT_SETS <- c(primary = "event_table.csv", r1 = "event_table_r1.csv", r2 = "event_table_r2.csv")
FLAGS      <- c(primary = "retained", r1 = "retained_r1", r2 = "retained_r2")
STATUS_LEVELS <- c("estimable", "after_window", "never", "first_year", "excluded")

stamp   <- format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ")
out_dir <- if (OUTCOME == "achievement") "outputs/05_primary" else "outputs/05_primary/graduation"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/logs", recursive = TRUE, showWarnings = FALSE)
log_file <- file.path("outputs", "logs", paste0(if (OUTCOME == "achievement") "05_primary_" else "05_primary_graduation_", stamp, ".log"))
say <- function(...) {
  txt <- paste0(...)
  cat(txt, "\n", sep = "")
  cat(txt, "\n", sep = "", file = log_file, append = TRUE)
}
note <- function(...) cat(paste0(...), "\n", sep = "", file = log_file, append = TRUE)
note_df <- function(x) note(paste(utils::capture.output(print(x, row.names = FALSE)), collapse = "\n"))

say("Step 5 primary estimator (", OUTCOME, "), run ", stamp, "; stage ", stage, "; blinding ",
    readLines("data/reference/blinding_status.txt", n = 1, warn = FALSE), "; did ", utils::packageVersion("did"))
say("Console: panel sizes only. Cohort counts, estimates and model status: ", out_dir, " and ", log_file)

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

cov <- cs_covariates(race$leaid, smp, 2010L)
say("Covariates for the ", nrow(cov), " districts in the district gap file; missing: ",
    paste(CS_COVARIATES, colSums(is.na(cov[CS_COVARIATES])), collapse = ", "))

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
      bal <- !PANEL_TYPES[[pan]]
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
      stopifnot(ac$dropped[["excluded"]] == 0L)
      p <- ac$panel
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

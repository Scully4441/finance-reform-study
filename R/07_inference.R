# Step 7. Inference (design document, Section 8).
# Run from the repository folder:
#   Rscript R/07_inference.R            the registered replication counts
#   Rscript R/07_inference.R --quick    reduced counts, for a test run only
#
# Inputs
#   outputs/05_primary/cs_models.rds       R/05_primary.R: the 15 att_gt and aggte fits
#                                          (3 gaps x 3 event sets x weighting)
#   outputs/05_primary/overall_estimates.csv  cross-check on the extracted estimates
# The four procedures of Section 8, each on every step 5 model:
#   wild cluster bootstrap  Webb weights, state clusters, 9,999 replications. The
#                           primary inference. Run on the overall post-reform average
#                           and on every event-time estimate.
#   randomization inference 10,000 reassignments of the cohort years across states,
#                           the estimator rerun on each, on the overall average.
#   Romano-Wolf             step-down over the three gaps within an event set, 9,999
#                           draws, on the overall average.
#   HonestDiD               relative-magnitudes bounds on the overall average,
#                           M-bar in 0, 0.5, 1, 1.5, 2.
# Author decisions 2026-09-11 (docs/decision_log.md, and R/functions/inference.R):
# the bootstrap and Romano-Wolf run on did's influence function with Webb weights
# rather than through fwildclusterboot and wildrwolf, which take an lm or fixest
# object; the reassignments draw from every state in the panel; the Romano-Wolf family
# is the three gaps within an event set.
# Every stochastic step takes its seed from seed_for() (CLAUDE.md rule 4). The
# bootstrap weights and the reassignments are drawn in this process, so the results do
# not depend on how many workers run them.
# Outputs (outputs/07_inference/)
#   bootstrap_overall.csv      Webb bootstrap on the overall post-reform average
#   bootstrap_event_time.csv   the same for each event time -5..+8
#   randomization_overall.csv  reassignment p-values and the placebo distribution
#   randomization_draws.csv    every placebo estimate, so the p-values can be rebuilt
#   romano_wolf.csv            unadjusted and step-down adjusted p-values by family
#   honestdid_overall.csv      bound set per model and M-bar, with the unadjusted set
#   model_status.csv           status and notes per model
#   inference_settings.csv     replication counts, seeds and versions of this run
#   outputs/logs/07_inference_<stamp>.log
# Blinding (CLAUDE.md rule 7): the console shows model names, cluster counts and
# timings. Estimates and p-values go to the files and the log.

for (f in list.files("R/functions", full.names = TRUE)) source(f)

stage <- as.integer(readLines("data/stage.txt", n = 1, warn = FALSE))
if (!identical(stage, 1L))
  stop("R/07_inference.R covers stage 1 (end years 2010-2013). Rerun steps 3 to 5 for stage 2 first.")

GAPS       <- c("a_poverty", "b_black_white", "c_hispanic_white")
EVENT_SETS <- c("primary", "r1", "r2")
MBARVEC    <- c(0, 0.5, 1, 1.5, 2)      # design Section 8
WORKERS    <- 12L                       # CLAUDE.md conventions: 14 cores, no forking
# Registered replication counts (Section 8); --quick is for a test run only and is
# recorded in inference_settings.csv and in the log.
FULL  <- list(bootstrap = 9999L, randomization = 10000L)
QUICK <- list(bootstrap = 999L, randomization = 200L)
quick <- "--quick" %in% commandArgs(trailingOnly = TRUE)
reps  <- if (quick) QUICK else FULL
# The Romano-Wolf step-down reuses the bootstrap draws, so its draw count is the
# bootstrap's; Section 8 puts both at 9,999.
reps$romano_wolf <- reps$bootstrap

stamp   <- format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ")
out_dir <- "outputs/07_inference"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/logs", recursive = TRUE, showWarnings = FALSE)
log_file <- file.path("outputs", "logs", paste0("07_inference_", stamp, ".log"))
say <- function(...) {                      # console and log
  txt <- paste0(...)
  cat(txt, "\n", sep = "")
  cat(txt, "\n", sep = "", file = log_file, append = TRUE)
}
note <- function(...) cat(paste0(...), "\n", sep = "", file = log_file, append = TRUE)   # log only
note_df <- function(x) note(paste(utils::capture.output(print(x, row.names = FALSE)), collapse = "\n"))

say("Step 7 inference, run ", stamp, "; stage ", stage, "; blinding ",
    readLines("data/reference/blinding_status.txt", n = 1, warn = FALSE),
    "; did ", utils::packageVersion("did"), ", HonestDiD ", utils::packageVersion("HonestDiD"))
say("Replication counts: bootstrap ", reps$bootstrap, ", Romano-Wolf ", reps$romano_wolf,
    ", randomization ", reps$randomization, if (quick) "  (--quick: a test run, not the registered counts)" else
      "  (the registered counts)")
say("Console: model names, cluster counts and timings. Estimates and p-values: ", out_dir, " and ", log_file)

# ---- inputs ------------------------------------------------------------------------
rds <- file.path("outputs", "05_primary", "cs_models.rds")
if (!file.exists(rds)) stop("outputs/05_primary/cs_models.rds not found. Run R/05_primary.R first.")
models <- readRDS(rds)
keys <- names(models)
parts <- do.call(rbind, lapply(strsplit(keys, ".", fixed = TRUE), function(z)
  data.frame(gap = z[1], event_set = z[2], weighting = z[3], stringsAsFactors = FALSE)))
parts$key <- keys
stopifnot(all(parts$gap %in% GAPS), all(parts$event_set %in% EVENT_SETS), !anyDuplicated(keys))
say("\n", length(keys), " step 5 models: ", sum(!vapply(models, is.null, TRUE)), " fitted")

# Result rows carry the model's key. The key columns are scalars so that a one-row
# slice of parts does not push its row names onto a longer table.
tag <- function(i, x) data.frame(gap = parts$gap[i], event_set = parts$event_set[i],
                                 weighting = parts$weighting[i], x, row.names = NULL,
                                 stringsAsFactors = FALSE)

infs <- lapply(models, cs_influence)
status <- data.frame(parts[c("gap", "event_set", "weighting")], status = "ok", notes = "",
                     stringsAsFactors = FALSE)
for (i in seq_along(keys)) {
  if (is.null(models[[i]])) status$status[i] <- "no step 5 fit"
  else if (is.null(infs[[i]])) status$status[i] <- "no influence function"
}
usable <- status$status == "ok"

# The extracted overall estimates must match the step 5 file.
ov5 <- utils::read.csv(file.path("outputs", "05_primary", "overall_estimates.csv"),
                       stringsAsFactors = FALSE, na.strings = "")
k5 <- match(paste(parts$gap, parts$event_set, parts$weighting),
            paste(ov5$gap, ov5$event_set, ov5$weighting))
got <- vapply(infs, function(x) if (is.null(x)) NA_real_ else as.numeric(x$overall_att), numeric(1))
d5 <- abs(got - ov5$att[k5])
if (any(is.finite(d5) & d5 > 1e-10)) stop("the overall estimates do not match outputs/05_primary/overall_estimates.csv")
say("Overall estimates agree with outputs/05_primary/overall_estimates.csv")

# ---- Webb bootstrap draws, one set per event set -------------------------------------
# Every model of an event set draws from the same state-level weights, so the
# Romano-Wolf step-down over the gaps carries the dependence between them.
set_states <- list(); wmat <- list()
for (s in EVENT_SETS) {
  k <- which(usable & parts$event_set == s)
  if (!length(k)) next
  st <- sort(unique(unlist(lapply(infs[k], `[[`, "states"))))
  set.seed(seed_for(paste("07_inference bootstrap", s)))
  set_states[[s]] <- st
  wmat[[s]] <- webb_weights(length(st), reps$bootstrap)
  say(sprintf("Webb draws for event set %-7s %d states x %d replications", s, length(st), reps$bootstrap))
}

# ---- wild cluster bootstrap ----------------------------------------------------------
t0 <- Sys.time()
boot_overall <- list(); boot_event <- list(); t_boot <- list()
for (i in which(usable)) {
  inf <- infs[[i]]; s <- parts$event_set[i]
  w <- wmat[[s]][, match(inf$states, set_states[[s]]), drop = FALSE]
  b <- wcb_test(inf$overall_att, inf$scores[, "overall"], inf$n, w)
  boot_overall[[keys[i]]] <- tag(i, b$row)
  t_boot[[keys[i]]] <- b$t_boot
  ev <- tag(i, data.frame(e = EVENT_MIN:EVENT_MAX, att = NA_real_, se = NA_real_, boot_se = NA_real_,
                          t = NA_real_, crit_val = NA_real_, ci_lo = NA_real_, ci_hi = NA_real_,
                          p_value = NA_real_, reps = reps$bootstrap, clusters = length(inf$states),
                          reference = (EVENT_MIN:EVENT_MAX) == -1L, stringsAsFactors = FALSE))
  for (j in seq_along(inf$egt)) {
    e <- inf$egt[j]
    if (e == -1L || !is.finite(inf$se_egt[j]) || !is.finite(inf$att_egt[j])) next
    r <- wcb_test(inf$att_egt[j], inf$scores[, j], inf$n, w)$row
    ev[ev$e == e, names(r)] <- r
  }
  boot_event[[keys[i]]] <- ev
}
say(sprintf("Wild cluster bootstrap: %d models, %.1f s", length(boot_overall),
            as.numeric(difftime(Sys.time(), t0, units = "secs"))))

# ---- Romano-Wolf over the three gaps -------------------------------------------------
# One family per event set and weighting: the three gaps. The tested-count-weighted
# family takes the weighted models of gaps (b) and (c); gap (a) is a state-level
# outcome and is unweighted in both families.
rw <- list()
for (s in EVENT_SETS) {
  for (fam in c("unweighted", "tested_weighted")) {
    pick <- vapply(GAPS, function(g) {
      w <- if (g == "a_poverty") "unweighted" else fam
      k <- which(parts$gap == g & parts$event_set == s & parts$weighting == w)
      if (length(k) == 1L && usable[k] && !is.null(t_boot[[keys[k]]])) k else NA_integer_
    }, integer(1))
    k <- pick[!is.na(pick)]
    if (length(k) < 2L) next
    tb <- do.call(cbind, t_boot[keys[k]])
    to <- vapply(keys[k], function(x) boot_overall[[x]]$t, numeric(1))
    pu <- vapply(keys[k], function(x) boot_overall[[x]]$p_value, numeric(1))
    pa <- rw_stepdown(to, tb)
    rw[[paste(s, fam)]] <- data.frame(
      event_set = s, family = fam, gap = parts$gap[k], weighting = parts$weighting[k],
      t = to, p_unadjusted = pu, p_romano_wolf = pa,
      rank = rank(-abs(to), ties.method = "first"), hypotheses = length(k),
      reps = reps$romano_wolf, stringsAsFactors = FALSE)
  }
}
say("Romano-Wolf: ", length(rw), " families of ", length(GAPS), " gaps")

# ---- HonestDiD -----------------------------------------------------------------------
t0 <- Sys.time()
honest <- list()
for (i in which(usable)) {
  h <- honest_rm(infs[[i]], MBARVEC)
  honest[[keys[i]]] <- tag(i, h)
  bad <- h$status != "ok"
  if (any(bad)) status$notes[i] <- paste(c(status$notes[i], paste("HonestDiD:", unique(h$status[bad]))),
                                         collapse = " | ")
}
say(sprintf("HonestDiD relative magnitudes: %d models x %d M-bar values, %.1f s",
            length(honest), length(MBARVEC), as.numeric(difftime(Sys.time(), t0, units = "secs"))))

# ---- randomization inference ---------------------------------------------------------
say("\nRandomization inference: ", reps$randomization, " reassignments per model on ", WORKERS, " workers")
future::plan(future::multisession, workers = WORKERS)
on.exit(future::plan(future::sequential), add = TRUE)
ri <- list(); ri_draws <- list()
for (i in which(usable)) {
  t0 <- Sys.time()
  r <- ri_overall(models[[i]], reps$randomization, paste("07_inference randomization", keys[i]))
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  att <- infs[[i]]$overall_att
  v <- r$values[is.finite(r$values)]
  ri[[keys[i]]] <- tag(i, data.frame(
    att = att, p_value = r$p_value,
    reps = as.integer(r$reps), draws_ok = as.integer(r$draws_ok),
    treated_states = as.integer(r$treated_states), eligible_states = as.integer(r$eligible_states),
    placebo_mean = if (length(v)) mean(v) else NA_real_, placebo_sd = if (length(v)) stats::sd(v) else NA_real_,
    placebo_abs_q95 = if (length(v)) unname(stats::quantile(abs(v), 0.95)) else NA_real_,
    seconds = secs, stringsAsFactors = FALSE))
  if (length(r$values))
    ri_draws[[keys[i]]] <- tag(i, data.frame(draw = seq_along(r$values), att = r$values,
                                             stringsAsFactors = FALSE))
  if (r$status != "ok")
    status$notes[i] <- paste(c(status$notes[i], paste("randomization:", r$status)), collapse = " | ")
  else if (r$draws_ok < r$reps)   # a reassignment can leave no estimable group-time cell
    status$notes[i] <- paste(c(status$notes[i],
                               sprintf("randomization: %d of %d reassignments had no estimable cell",
                                       r$reps - r$draws_ok, r$reps)), collapse = " | ")
  say(sprintf("  %-16s %-7s %-15s %4d/%4d reassignments estimated, %5.1f s", parts$gap[i], parts$event_set[i],
              parts$weighting[i], r$draws_ok, r$reps, secs))
}

# ---- outputs -------------------------------------------------------------------------
bind <- function(x) { y <- do.call(rbind, x); if (!is.null(y)) rownames(y) <- NULL; y }
bo <- bind(boot_overall); be <- bind(boot_event); rwt <- bind(rw); hd <- bind(honest)
rit <- bind(ri); rid <- bind(ri_draws)
status$notes <- trimws(sub("^ \\| ", "", status$notes))

settings <- data.frame(setting = c("run", "stage", "blinding", "quick_run", "bootstrap_reps",
                                   "romano_wolf_reps", "randomization_reps", "webb_support", "mbar",
                                   "master_seed", "workers", "boot_level", "r_version", "did", "HonestDiD",
                                   "fwildclusterboot", "wildrwolf"),
                       value = c(stamp, stage, readLines("data/reference/blinding_status.txt", n = 1, warn = FALSE),
                                 tolower(as.character(quick)), reps$bootstrap, reps$romano_wolf,
                                 reps$randomization, paste(round(WEBB_SUPPORT, 6), collapse = " "),
                                 paste(MBARVEC, collapse = " "), MASTER_SEED, WORKERS, BOOT_LEVEL,
                                 R.version.string, as.character(utils::packageVersion("did")),
                                 as.character(utils::packageVersion("HonestDiD")),
                                 as.character(utils::packageVersion("fwildclusterboot")),
                                 as.character(utils::packageVersion("wildrwolf"))),
                       stringsAsFactors = FALSE)

files <- list(bootstrap_overall = bo, bootstrap_event_time = be, randomization_overall = rit,
              randomization_draws = rid, romano_wolf = rwt, honestdid_overall = hd,
              model_status = status, inference_settings = settings)
for (fn in names(files))
  utils::write.csv(files[[fn]], file.path(out_dir, paste0(fn, ".csv")), row.names = FALSE, na = "")

note("\n== settings"); note_df(settings)
note("\n== wild cluster bootstrap, overall post-reform average"); note_df(bo)
note("\n== wild cluster bootstrap, event times"); note_df(be[!is.na(be$att), ])
note("\n== Romano-Wolf over the three gaps"); note_df(rwt)
note("\n== HonestDiD relative magnitudes"); note_df(hd)
note("\n== randomization inference"); note_df(rit)
note("\n== model status"); note_df(status)

say("\nWrote ", paste0(out_dir, "/", names(files), ".csv", collapse = ", "))
say(sum(usable), " of ", length(keys), " models carried through all four procedures. Status per model: ",
    file.path(out_dir, "model_status.csv"))
if (quick) say("NOTE: --quick run. The registered counts are ", FULL$bootstrap, " bootstrap and Romano-Wolf draws and ",
               FULL$randomization, " reassignments.")
say("Log: ", log_file)

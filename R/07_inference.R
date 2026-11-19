for (f in list.files("R/functions", full.names = TRUE)) source(f)

OUTCOME <- outcome_arg()
stage <- read_stage()
if (OUTCOME == "achievement") {
  GAPS <- c("a_poverty", "b_black_white", "c_hispanic_white")
  in_dir <- file.path("outputs", "05_primary")
} else {
  if (!identical(stage, 2L)) stop("the graduation pass needs stage 2 (graduation files after 2012-13)")
  GAPS <- names(GRAD_GAPS)
  in_dir <- file.path("outputs", "05_primary", "graduation")
}
seed_tag <- if (OUTCOME == "achievement") "07_inference" else "07_inference graduation"

EVENT_SETS <- c("primary", "r1", "r2")
PANELS     <- names(PANEL_TYPES)
MBARVEC    <- c(0, 0.5, 1, 1.5, 2)
WORKERS    <- 12L
FULL  <- list(bootstrap = 9999L, randomization = 10000L)
QUICK <- list(bootstrap = 999L, randomization = 200L)
quick <- "--quick" %in% commandArgs(trailingOnly = TRUE)
reps  <- if (quick) QUICK else FULL
reps$romano_wolf <- reps$bootstrap

stamp   <- format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ")
out_dir <- if (OUTCOME == "achievement") "outputs/07_inference" else "outputs/07_inference/graduation"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/logs", recursive = TRUE, showWarnings = FALSE)
log_file <- file.path("outputs", "logs", paste0(if (OUTCOME == "achievement") "07_inference_" else "07_inference_graduation_", stamp, ".log"))
say <- function(...) {
  txt <- paste0(...)
  cat(txt, "\n", sep = "")
  cat(txt, "\n", sep = "", file = log_file, append = TRUE)
}
note <- function(...) cat(paste0(...), "\n", sep = "", file = log_file, append = TRUE)
note_df <- function(x) note(paste(utils::capture.output(print(x, row.names = FALSE)), collapse = "\n"))

say("Step 7 inference (", OUTCOME, "), run ", stamp, "; stage ", stage, "; blinding ",
    readLines("data/reference/blinding_status.txt", n = 1, warn = FALSE),
    "; did ", utils::packageVersion("did"), ", HonestDiD ", utils::packageVersion("HonestDiD"))
say("Replication counts: bootstrap ", reps$bootstrap, ", Romano-Wolf ", reps$romano_wolf,
    ", randomization ", reps$randomization, if (quick) "  (--quick: a test run, not the registered counts)" else
      "  (the registered counts)")
say("Console: model names, cluster counts and timings. Estimates and p-values: ", out_dir, " and ", log_file)

rds <- file.path(in_dir, "cs_models.rds")
if (!file.exists(rds)) stop(rds, " not found. Run R/05_primary.R", if (OUTCOME == "graduation") " --outcome graduation", " first.")
models <- readRDS(rds)
keys <- names(models)
parts <- do.call(rbind, lapply(strsplit(keys, ".", fixed = TRUE), function(z)
  data.frame(gap = z[1], event_set = z[2], weighting = z[3], panel = z[4], stringsAsFactors = FALSE)))
parts$key <- keys
stopifnot(all(parts$gap %in% GAPS), all(parts$event_set %in% EVENT_SETS),
          all(parts$panel %in% PANELS), !anyDuplicated(keys))
say("\n", length(keys), " step 5 models: ", sum(!vapply(models, is.null, TRUE)), " fitted")

tag <- function(i, x) data.frame(gap = parts$gap[i], event_set = parts$event_set[i],
                                 weighting = parts$weighting[i], panel = parts$panel[i], x,
                                 row.names = NULL, stringsAsFactors = FALSE)

infs <- lapply(models, cs_influence)
status <- data.frame(parts[c("gap", "event_set", "weighting", "panel")], status = "ok", notes = "",
                     stringsAsFactors = FALSE)
for (i in seq_along(keys)) {
  if (is.null(models[[i]])) status$status[i] <- "no step 5 fit"
  else if (is.null(infs[[i]])) status$status[i] <- "no influence function"
}
usable <- status$status == "ok"

ov5 <- utils::read.csv(file.path(in_dir, "overall_estimates.csv"),
                       stringsAsFactors = FALSE, na.strings = "")
k5 <- match(paste(parts$gap, parts$event_set, parts$weighting, parts$panel),
            paste(ov5$gap, ov5$event_set, ov5$weighting, ov5$panel))
got <- vapply(infs, function(x) if (is.null(x)) NA_real_ else as.numeric(x$overall_att), numeric(1))
d5 <- abs(got - ov5$att[k5])
if (any(is.finite(d5) & d5 > 1e-10)) stop("the overall estimates do not match ", file.path(in_dir, "overall_estimates.csv"))
say("Overall estimates agree with ", file.path(in_dir, "overall_estimates.csv"))

set_states <- list(); wmat <- list()
for (s in EVENT_SETS) {
  k <- which(usable & parts$event_set == s)
  if (!length(k)) next
  st <- sort(unique(unlist(lapply(infs[k], `[[`, "states"))))
  set.seed(seed_for(paste(seed_tag, "bootstrap", s)))
  set_states[[s]] <- st
  wmat[[s]] <- webb_weights(length(st), reps$bootstrap)
  say(sprintf("Webb draws for event set %-7s %d states x %d replications", s, length(st), reps$bootstrap))
}

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

rw <- list()
for (s in EVENT_SETS) {
  for (pan in PANELS) {
    for (fam in c("unweighted", "tested_weighted")) {
      pick <- vapply(GAPS, function(g) {
        w <- if (g == "a_poverty") "unweighted" else fam
        k <- which(parts$gap == g & parts$event_set == s & parts$weighting == w & parts$panel == pan)
        if (length(k) == 1L && usable[k] && !is.null(t_boot[[keys[k]]])) k else NA_integer_
      }, integer(1))
      k <- pick[!is.na(pick)]
      if (length(k) < 2L) next
      tb <- do.call(cbind, t_boot[keys[k]])
      to <- vapply(keys[k], function(x) boot_overall[[x]]$t, numeric(1))
      pu <- vapply(keys[k], function(x) boot_overall[[x]]$p_value, numeric(1))
      pa <- rw_stepdown(to, tb)
      rw[[paste(s, pan, fam)]] <- data.frame(
        event_set = s, panel = pan, family = fam, gap = parts$gap[k], weighting = parts$weighting[k],
        t = to, p_unadjusted = pu, p_romano_wolf = pa,
        rank = rank(-abs(to), ties.method = "first"), hypotheses = length(k),
        reps = reps$romano_wolf, stringsAsFactors = FALSE)
    }
  }
}
say("Romano-Wolf: ", length(rw), " families of ", length(GAPS), " gaps")

t0 <- Sys.time()
future::plan(future::multisession, workers = WORKERS)
on.exit(future::plan(future::sequential), add = TRUE)
hs <- furrr::future_map(which(usable), function(i) suppressWarnings(honest_rm(infs[[i]], MBARVEC)),
                        .options = furrr::furrr_options(seed = NULL))
names(hs) <- keys[which(usable)]
n_block <- sum(vapply(hs, function(h) any(h$status %in% HONEST_NOT_CONSEC), TRUE))
hs <- honest_block_rule(hs, infs[names(hs)], stats::setNames(as.list(rep(-1L, length(hs))), names(hs)), MBARVEC)
honest <- list()
for (j in seq_along(hs)) {
  i <- which(usable)[j]; h <- hs[[j]]
  honest[[keys[i]]] <- tag(i, h)
  bad <- h$status != "ok"
  if (any(bad)) status$notes[i] <- paste(c(status$notes[i], paste("HonestDiD:", unique(h$status[bad]))),
                                         collapse = " | ")
}
hd_new <- do.call(rbind, honest); rownames(hd_new) <- NULL
say(sprintf("HonestDiD relative magnitudes: %d models x %d M-bar values, %.1f s; grid widened for %d M-bar rows; reduced event-time block for %d models",
            length(honest), length(MBARVEC), as.numeric(difftime(Sys.time(), t0, units = "secs")),
            sum(hd_new$grid_points > HONEST_GRID_POINTS, na.rm = TRUE), n_block))

say("\nRandomization inference: ", reps$randomization, " reassignments per model on ", WORKERS, " workers")
ri <- list(); ri_draws <- list()
cache_dir <- local({ a <- commandArgs(trailingOnly = TRUE); k <- which(a == "--cache-dir")
  if (length(k) && k[1] < length(a)) a[k[1] + 1L] else NULL })
if (!is.null(cache_dir)) { dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  say("Randomization results cached per model in ", cache_dir) }
for (i in which(usable)) {
  t0 <- Sys.time()
  seed_step <- paste(seed_tag, "randomization", keys[i])
  cf <- if (!is.null(cache_dir)) file.path(cache_dir, paste0(keys[i], ".rds"))
  r <- if (!is.null(cf) && file.exists(cf)) readRDS(cf)
  if (!is.null(r) && !(identical(r$seed_step, seed_step) && identical(r$reps, reps$randomization) &&
                       identical(r$att, infs[[i]]$overall_att))) r <- NULL
  if (is.null(r)) {
    r <- ri_overall(models[[i]], reps$randomization, seed_step)
    r$seed_step <- seed_step; r$att <- infs[[i]]$overall_att
    if (!is.null(cf)) saveRDS(r, cf)
  }
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
  else if (r$draws_ok < r$reps)
    status$notes[i] <- paste(c(status$notes[i],
                               sprintf("randomization: %d of %d reassignments had no estimable cell",
                                       r$reps - r$draws_ok, r$reps)), collapse = " | ")
  say(sprintf("  %-19s %-7s %-15s %-10s %5d/%5d reassignments estimated, %6.1f s", parts$gap[i],
              parts$event_set[i], parts$weighting[i], parts$panel[i], r$draws_ok, r$reps, secs))
}

bind <- function(x) { y <- do.call(rbind, x); if (!is.null(y)) rownames(y) <- NULL; y }
pkg_version_or_none <- function(p)
  if (requireNamespace(p, quietly = TRUE)) as.character(utils::packageVersion(p)) else "not installed"
bo <- bind(boot_overall); be <- bind(boot_event); rwt <- bind(rw); hd <- bind(honest)
rit <- bind(ri); rid <- bind(ri_draws)
status$notes <- trimws(sub("^ \\| ", "", status$notes))

settings <- data.frame(setting = c("run", "outcome", "stage", "blinding", "quick_run", "bootstrap_reps",
                                   "romano_wolf_reps", "randomization_reps", "webb_support", "mbar",
                                   "master_seed", "workers", "boot_level", "r_version", "did", "HonestDiD",
                                   "fwildclusterboot", "wildrwolf"),
                       value = c(stamp, OUTCOME, stage, readLines("data/reference/blinding_status.txt", n = 1, warn = FALSE),
                                 tolower(as.character(quick)), reps$bootstrap, reps$romano_wolf,
                                 reps$randomization, paste(round(WEBB_SUPPORT, 6), collapse = " "),
                                 paste(MBARVEC, collapse = " "), MASTER_SEED, WORKERS, BOOT_LEVEL,
                                 R.version.string, as.character(utils::packageVersion("did")),
                                 as.character(utils::packageVersion("HonestDiD")),
                                 pkg_version_or_none("fwildclusterboot"), pkg_version_or_none("wildrwolf")),
                       stringsAsFactors = FALSE)
settings <- rbind(settings, data.frame(setting = c("honest_grid", "honest_block_rule"), value = c(sprintf(
  "start +/-%d sd, %d points; widened by its width per edge side, same step, up to %d times",
  HONEST_GRID_SD, HONEST_GRID_POINTS, HONEST_GRID_MAX_WIDEN),
  "reduced consecutive event-time block where event times are not consecutive (honest_block())")))

files <- list(bootstrap_overall = bo, bootstrap_event_time = be, randomization_overall = rit,
              randomization_draws = rid, romano_wolf = rwt, honestdid_overall = hd,
              model_status = status, inference_settings = settings)
for (fn in names(files))
  utils::write.csv(files[[fn]], file.path(out_dir, paste0(fn, ".csv")), row.names = FALSE, na = "")

note("\n== settings"); note_df(settings)
note("\n== wild cluster bootstrap, overall post-reform average"); note_df(bo)
note("\n== wild cluster bootstrap, event times"); note_df(be[!is.na(be$att), ])
note("\n== Romano-Wolf over the gaps"); note_df(rwt)
note("\n== HonestDiD relative magnitudes"); note_df(hd)
note("\n== randomization inference"); note_df(rit)
note("\n== model status"); note_df(status)

say("\nWrote ", paste0(out_dir, "/", names(files), ".csv", collapse = ", "))
say(sum(usable), " of ", length(keys), " models carried through all four procedures. Status per model: ",
    file.path(out_dir, "model_status.csv"))
if (quick) say("NOTE: --quick run. The registered counts are ", FULL$bootstrap, " bootstrap and Romano-Wolf draws and ",
               FULL$randomization, " reassignments.")
say("Log: ", log_file)

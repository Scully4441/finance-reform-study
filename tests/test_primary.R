# Checks for R/functions/primary.R and the step 5 outputs (design Section 7).
# Sourced by tests/run_tests.R after the shared functions are loaded.
W <- 2010:2013

# cohort coding: after-window states are not-yet-treated controls, first-year states cannot enter
ev <- data.frame(state = c("A", "B", "C", "D", "E", "F"), treat_year = c(2011L, 2013L, 2016L, 2010L, NA, NA),
                 group = c("treated", "treated", "treated", "treated", "never", "excluded"), stringsAsFactors = FALSE)
cc <- cohort_coding(ev, W)
stopifnot(identical(cc$cohort_status, c("estimable", "estimable", "after_window", "first_year", "never", "excluded")),
          identical(cc$g, c(2011L, 2013L, 0L, NA, 0L, NA)))

# gaps (b) and (c): both subjects, every year, one event set, one sample
rg <- function(leaid, sy_end, subject, v, n_bl = 40, n_wh = 100, sample = "primary", retained = 1L)
  data.frame(leaid = leaid, state = "X", sy_end = sy_end, subject = subject, sample = sample, retained = retained,
             retained_r1 = retained, retained_r2 = 1L, v_bw = v, se_bw = 0.1, v_hw = NA_real_, se_hw = NA_real_,
             n_wh = n_wh, n_bl = n_bl, n_hi = NA_real_, stringsAsFactors = FALSE)
full <- function(leaid, ...) do.call(rbind, lapply(W, function(y)
  rbind(rg(leaid, y, "math", -0.4, ...), rg(leaid, y, "rla", -0.6, ...))))
g <- rbind(full("D1"), full("D2"), full("D3", retained = 0L), full("D4", sample = "r5"))
g$n_bl[g$leaid == "D1" & g$sy_end == 2010 & g$subject == "rla"] <- 60
g$v_bw[g$leaid == "D2" & g$sy_end == 2012 & g$subject == "rla"] <- NA       # one subject missing in one year
rp <- race_panel(g, "bw", "retained", W)
stopifnot(identical(unique(rp$leaid), "D1"), identical(rp$sy_end, W), near(rp$y, rep(-0.5, 4)),
          near(rp$tested_2010, rep((140 + 160) / 2, 4)))                      # fixed 2009-10 weight, mean of subjects
stopifnot(identical(unique(race_panel(g, "bw", "retained_r2", W)$leaid), c("D1", "D3")),
          nrow(race_panel(g, "hw", "retained", W)) == 0)

# gap (a): a state missing a year leaves the balanced panel
pv <- data.frame(state = rep(c("P", "Q"), each = 8), sy_end = rep(rep(W, each = 2), 2), subject = c("math", "rla"),
                 sample = "primary", retained = 1L, retained_r1 = 1L, retained_r2 = 1L, v_pov = -0.3, stringsAsFactors = FALSE)
pv$v_pov[pv$state == "Q" & pv$sy_end == 2011 & pv$subject == "math"] <- NA
pp <- pov_panel(pv, "retained", W)
stopifnot(identical(unique(pp$state), "P"), nrow(pp) == 4, near(pp$y, rep(-0.3, 4)))

# racial composition from a CCD school file: invalid or zero totals are left out
tmp <- tempfile(fileext = ".txt")
writeLines(c("NCESSCH\tLEAID\tSCHNAM09\tBLACK09\tHISP09\tTOTETH09",
             "1\t0100001\t\"A\tschool\"\t10\t20\t100", "2\t0100001\tB\t5\t5\t50", "3\t0100001\tC\t-9\t1\t10",
             "4\t0100002\tD\t0\t0\t0"), tmp)
rs <- read_ccd_race_shares(tmp, 2010L)
stopifnot(identical(rs$leaid, "0100001"), near(rs$black_share, 15 / 150), near(rs$hisp_share, 25 / 150), rs$schools == 2)

# synthetic panel: cohorts 2011, 2012 (two states), 2013; one state treated after the
# window, one in the first window year, three never treated; true effect 0.5
sim <- function(n = 30, effect = 0.5) {
  ty <- c(2011L, 2012L, 2012L, 2013L, 2016L, 2010L, NA, NA, NA)
  ev <- data.frame(state = sprintf("S%02d", seq_along(ty)), treat_year = ty,
                   group = ifelse(is.na(ty), "never", "treated"), stringsAsFactors = FALSE)
  set.seed(seed_for("test primary sim"))
  d <- expand.grid(k = seq_len(n), state = ev$state, sy_end = W, stringsAsFactors = FALSE)
  d$unit <- paste(d$state, d$k)
  u <- sort(unique(d$unit)); x <- stats::rnorm(length(u)); w <- 50 + 10 * (seq_along(u) %% 7)
  d$x1 <- x[match(d$unit, u)]; d$w <- w[match(d$unit, u)]
  tyd <- ev$treat_year[match(d$state, ev$state)]
  d$y <- 0.3 * d$x1 + 0.05 * (d$sy_end - 2010) + effect * (!is.na(tyd) & d$sy_end >= tyd) +
    stats::rnorm(nrow(d), sd = 0.02)
  ac <- attach_cohorts(d[order(d$unit, d$sy_end), ], cohort_coding(ev, W), "unit")
  ac
}
ac <- sim(); p <- ac$panel
stopifnot(ac$dropped[["first_year"]] == 30, ac$dropped[["excluded"]] == 0, !"S06" %in% p$state,
          all(p$g[p$state == "S05"] == 0), p$cohort_status[p$state == "S05"][1] == "after_window",
          is.integer(p$id), length(unique(p$id)) == 8 * 30)

fit <- run_cs(p, ~x1, seed_step = "test primary run")
e <- fit$event
stopifnot(fit$status == "ok", identical(e$e, -5:8), e$att[e$e == -1] == 0, e$reference[e$e == -1])
stopifnot(all(abs(e$att[e$e %in% 0:2] - 0.5) < 0.05), all(abs(e$att[e$e %in% -3:-2]) < 0.05),
          all(is.na(e$att[e$e < -3 | e$e > 2])))
stopifnot(identical(e$cohorts, c(0L, 0L, 1L, 2L, 3L, 3L, 2L, 1L, rep(0L, 6))),      # cohorts per event time
          identical(e$treated_states, c(0L, 0L, 1L, 3L, 4L, 4L, 3L, 1L, rep(0L, 6))),
          identical(e$treated_units, 30L * e$treated_states))
stopifnot(abs(fit$overall$att - 0.5) < 0.05, fit$overall$cohorts == 3, fit$overall$treated_units == 120,
          all(fit$overall$ci_lo < fit$overall$att), all(e$ci_lo[e$e == 0] < e$att[e$e == 0]))
stopifnot(inherits(fit$fit$att_gt, "MP"), inherits(fit$fit$aggte, "AGGTEobj"),
          identical(sort(unique(fit$cells$g)), c(2011L, 2012L, 2013L)))
stopifnot(identical(run_cs(p, ~x1, seed_step = "test primary run")$event$se, e$se))   # seeded bootstrap
fw <- run_cs(p, ~x1, weightsname = "w", seed_step = "test primary weighted")
stopifnot(fw$status == "ok", abs(fw$overall$att - 0.5) < 0.05)
bad <- p; bad$w[1] <- bad$w[1] + 1                                                    # weights must be fixed within unit
stopifnot(inherits(try(run_cs(bad, ~x1, weightsname = "w", seed_step = "x"), silent = TRUE), "try-error"))

# state-level model (gap (a)): one row per state-year, no covariates
ps <- stats::aggregate(y ~ state + sy_end + g, p, mean)
ps$id <- as.integer(factor(ps$state))
fs <- run_cs(ps, ~1, seed_step = "test primary state")
stopifnot(fs$status == "ok", identical(fs$event$cohorts, e$cohorts), identical(fs$event$treated_units, fs$event$treated_states))

# no estimable cohort (every treated state after the window): a status, not an error
p0 <- p; p0$g <- 0L
f0 <- run_cs(p0, ~x1, seed_step = "test primary none")
stopifnot(f0$status == "no estimable cohort", all(is.na(f0$event$att)), all(f0$event$cohorts == 0L),
          identical(f0$event$e, -5:8), is.na(f0$overall$att), nrow(f0$cells) == 0, is.null(f0$fit))
# did failing is recorded, not raised
fe <- run_cs(p, ~no_such_covariate, seed_step = "test primary error")
stopifnot(startsWith(fe$status, "error:"), all(is.na(fe$event$att)))

# no step uses set.seed() with a literal (CLAUDE.md rule 4)
src <- unlist(lapply(c(list.files("R", pattern = "\\.R$", full.names = TRUE), list.files("R/functions", full.names = TRUE)),
                     readLines, warn = FALSE))
stopifnot(!any(grepl("set\\.seed\\(\\s*[0-9]", src)))

# step 5 outputs, when they have been built
of <- file.path("outputs", "05_primary", c("event_time_estimates.csv", "overall_estimates.csv", "model_status.csv",
                                         "panel_counts.csv", "group_time_estimates.csv"))
if (all(file.exists(of))) {
  rd <- function(f) utils::read.csv(f, stringsAsFactors = FALSE, na.strings = "")
  ee <- rd(of[1]); oo <- rd(of[2]); ms <- rd(of[3]); pc <- rd(of[4])
  mw <- c("a_poverty unweighted", "b_black_white unweighted", "b_black_white tested_weighted",
          "c_hispanic_white unweighted", "c_hispanic_white tested_weighted")
  models <- unlist(lapply(c("primary", "r1", "r2"), function(s) sub(" ", paste0(" ", s, " "), mw)))
  key <- function(x) paste(x$gap, x$event_set, x$weighting)
  stopifnot(nrow(ms) == 15, setequal(key(ms), models), !anyDuplicated(key(ms)),
            !any(startsWith(ms$status, "error")), all(ms$status %in% c("ok", "no estimable cohort")))
  stopifnot(nrow(ee) == 15 * 14, all(table(key(ee)) == 14), all(ee$e %in% EVENT_MIN:EVENT_MAX),
            nrow(oo) == 15, setequal(key(oo), models))
  ok <- key(ee) %in% key(ms)[ms$status == "ok"]
  stopifnot(all(ee$att[ok & ee$e == -1] == 0), all(ee$cohorts[ok & ee$e == -1] >= 1),
            all(is.na(ee$att[!ok])), all(ee$cohorts[!ok] == 0))
  stopifnot(all(ee$cohorts >= 0), all(ee$treated_states >= ee$cohorts | ee$cohorts == 0),
            all(ee$treated_units >= ee$treated_states), all(is.na(ee$att) == (ee$cohorts == 0)))
  stopifnot(nrow(pc) == 9, all(pc$units_in_model <= pc$units_balanced - pc$dropped_missing_covariates),
            all(pc$units_balanced <= pc$units_with_outcome),
            all(pc$units_in_model == pc$units_estimable + pc$units_after_window + pc$units_never),
            all(pc$dropped_missing_covariates[pc$gap == "a_poverty"] == 0))
}

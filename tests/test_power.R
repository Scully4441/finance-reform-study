# Checks for R/functions/power.R and the step 8 outputs (design Section 10).
# Sourced by tests/run_tests.R after the shared functions are loaded.
PW <- 2010:2013

# the constants Section 10 fixes
stopifnot(POWER_REPS == 2000L, POWER_LEVEL == 0.95, POWER_TARGET == 0.80, POWER_CEILING == 0.10)

# cohort years of a panel: one per state treated within the window, controls left out
ppan <- data.frame(state = rep(c("A", "B", "C", "D"), each = 4), sy_end = PW,
                   g = rep(c(2012, 0, 2011, 0), each = 4), stringsAsFactors = FALSE)
stopifnot(identical(panel_cohort_years(ppan), c(2012, 2011)))
stopifnot(length(panel_cohort_years(within(ppan, g <- 0))) == 0L)

# placebo draws: the right number of distinct states each time, from the whole panel,
# and seeded, so the same seed gives the same assignments
pst <- sprintf("S%02d", 1:36)
set.seed(seed_for("test power draws"))
pd <- placebo_state_draws(pst, 2L, 500L)
stopifnot(length(pd) == 500L, all(lengths(pd) == 2L), all(vapply(pd, anyDuplicated, 0) == 0),
          all(unlist(pd) %in% pst), length(unique(unlist(pd))) == length(pst))
set.seed(seed_for("test power draws"))
stopifnot(identical(pd, placebo_state_draws(pst, 2L, 500L)))
set.seed(seed_for("test power draws other"))
stopifnot(!identical(pd, placebo_state_draws(pst, 2L, 500L)))
stopifnot(inherits(try(placebo_state_draws(pst, 36L, 5L), silent = TRUE), "try-error"),   # nothing left to control
          inherits(try(placebo_state_draws(pst, 0L, 5L), silent = TRUE), "try-error"))

# power against effect size: at no effect the test rejects at its own level, and the
# critical value is the level quantile of the absolute draws
set.seed(seed_for("test power normal"))
pv <- stats::rnorm(20000)
pm <- mde_from_placebo(pv)
stopifnot(pm$draws == 20000L, near(pm$crit, stats::quantile(abs(pv), 0.95, names = FALSE)),
          near(power_at(pv, pm$crit, 0), mean(abs(pv) >= pm$crit)), abs(power_at(pv, pm$crit, 0) - 0.05) < 1e-4)
# on a normal placebo distribution the exact inversion is the textbook (z + z) x sd
stopifnot(abs(pm$mde - (stats::qnorm(0.975) + stats::qnorm(0.8)) * stats::sd(pv)) < 0.05,
          abs(pm$mde - pm$mde_normal) < 0.05, near(pm$mde_normal, 2.8015862 * stats::sd(pv), 1e-6))
# the MDE reaches the target and is the smallest shift that does: just below it the
# test's power is short
stopifnot(pm$mde > 0, pm$power_at_mde >= POWER_TARGET,
          near(pm$power_at_mde, power_at(pv, pm$crit, pm$mde)),
          power_at(pv, pm$crit, pm$mde - 1e-8) < POWER_TARGET)
# the critical value and every candidate shift scale with the draws, so the MDE does too
stopifnot(near(mde_from_placebo(3 * pv)$mde, 3 * pm$mde, 1e-10),
          near(mde_from_placebo(-pv)$crit, pm$crit))
# power rises with the effect size and reaches 1
pg <- power_at(pv, pm$crit, seq(0, 6, 0.25))
stopifnot(all(diff(pg) >= -1e-12), pg[1] < 0.06, pg[length(pg)] > 0.99, all(pg >= 0), all(pg <= 1))
# a distribution with no spread, and too few draws, give no MDE rather than an error
stopifnot(is.na(mde_from_placebo(c(1, NA))$mde), is.na(mde_from_placebo(numeric())$crit),
          near(mde_from_placebo(rep(0, 100))$mde, 0))
pna <- mde_from_placebo(c(pv[1:100], rep(NA_real_, 20)))
stopifnot(pna$draws == 100L, is.finite(pna$mde))

# a small panel, as in test_inference: cohorts 2011 and 2012 among nine states
psim <- function(n = 6L, effect = 0.5) {
  ty <- c(2011L, 2012L, 2012L, rep(NA, 6))
  ev <- data.frame(state = sprintf("V%02d", seq_along(ty)), treat_year = ty,
                   group = ifelse(is.na(ty), "never", "treated"), stringsAsFactors = FALSE)
  set.seed(seed_for("test power sim"))
  d <- expand.grid(k = seq_len(n), state = ev$state, sy_end = PW, stringsAsFactors = FALSE)
  d$unit <- paste(d$state, d$k)
  u <- sort(unique(d$unit))
  d$x1 <- stats::rnorm(length(u))[match(d$unit, u)]
  tyd <- ev$treat_year[match(d$state, ev$state)]
  d$y <- 0.3 * d$x1 + 0.05 * (d$sy_end - 2010) + effect * (!is.na(tyd) & d$sy_end >= tyd) +
    stats::rnorm(nrow(d), sd = 0.02)
  attach_cohorts(d[order(d$unit, d$sy_end), ], cohort_coding(ev, PW), "unit")$panel
}
pp <- psim()
pfit <- run_cs(pp, ~x1, seed_step = "test power fit")
stopifnot(pfit$status == "ok")
pcp <- cs_panel(pfit$fit)
pgs <- panel_cohort_years(pcp$panel)
stopifnot(length(pgs) == 3L, all(pgs > 0))
# the placebo runs refit the step 5 panel on reassigned cohorts: the estimate moves,
# and giving the cohort years back to their own states returns the step 5 estimate
set.seed(seed_for("test power sim draws"))
ppk <- placebo_state_draws(sort(unique(pcp$panel$state)), length(pgs), 5L)
pvals <- placebo_estimates(pcp, pgs, ppk, parallel = FALSE)
stopifnot(length(pvals) == 5L, sum(is.finite(pvals)) >= 1L)
stopifnot(near(placebo_estimates(pcp, panel_cohort_years(pcp$panel), list(names(
            which(vapply(split(pcp$panel$g, pcp$panel$state), function(z) z[1], numeric(1)) > 0))),
            parallel = FALSE), pfit$fit$aggte$overall.att, 1e-8))
stopifnot(identical(placebo_estimates(pcp, pgs, ppk, parallel = FALSE), pvals))   # no RNG in the refit
stopifnot(inherits(try(placebo_estimates(pcp, pgs, list("V01"), parallel = FALSE), silent = TRUE), "try-error"))

# step 8 outputs, when they have been built
of8 <- file.path("outputs", "08_power",
                 c("mde.csv", "placebo_draws.csv", "power_curve.csv", "model_status.csv",
                   "power_settings.csv"))
if (all(file.exists(of8))) {
  rd8 <- function(f) utils::read.csv(f, stringsAsFactors = FALSE, na.strings = "")
  m8 <- rd8(of8[1]); d8 <- rd8(of8[2]); c8 <- rd8(of8[3]); s8 <- rd8(of8[4]); g8 <- rd8(of8[5])
  gaps8 <- c("a_poverty", "b_black_white", "c_hispanic_white")
  rep8 <- as.integer(g8$value[g8$setting == "placebo_reps"])

  # the three primary gaps, on the primary event set, unweighted (design Section 10)
  stopifnot(nrow(s8) == 3L, setequal(s8$gap, gaps8), all(s8$event_set == "primary"),
            all(s8$weighting == "unweighted"), all(s8$status == "ok"))
  stopifnot(setequal(m8$gap, gaps8), !anyDuplicated(m8$gap), all(m8$reps == rep8),
            all(m8$draws_ok <= m8$reps), all(m8$treated_states >= 1),
            all(m8$eligible_states > m8$treated_states))
  stopifnot(all(m8$level == POWER_LEVEL), all(m8$power_target == POWER_TARGET),
            all(m8$ceiling == POWER_CEILING), all(m8$crit_value > 0), all(m8$placebo_sd > 0),
            all(m8$mde > 0), all(m8$mde_normal > 0), all(m8$power_at_mde >= POWER_TARGET),
            all(m8$underpowered == as.integer(m8$mde > POWER_CEILING)),
            all(near(m8$mde_over_model_se, m8$mde / m8$model_se, 1e-8)))
  # the MDE is the one the saved draws give, and the critical value is their quantile
  stopifnot(setequal(d8$gap, gaps8), all(table(d8$gap) == rep8),
            all(tapply(d8$draw, d8$gap, function(z) identical(sort(z), seq_len(rep8)))))
  for (g in gaps8) {
    v <- d8$att[d8$gap == g]
    r <- m8[m8$gap == g, ]
    mm <- mde_from_placebo(v)
    stopifnot(sum(is.finite(v)) == r$draws_ok, near(mm$crit, r$crit_value, 1e-10),
              near(mm$mde, r$mde, 1e-10), near(mm$mde_normal, r$mde_normal, 1e-10),
              near(mm$power_at_mde, r$power_at_mde, 1e-10),
              near(stats::sd(v[is.finite(v)]), r$placebo_sd, 1e-10))
    # the placebo distribution is a null: it sits near zero next to the effect the
    # design would have to detect
    stopifnot(abs(r$placebo_mean) < r$mde)
    # the curve runs from no effect to past the MDE and is the same test as the table
    x <- c8[c8$gap == g, ]
    stopifnot(nrow(x) == 61L, x$effect[1] == 0, all(x$power >= 0), all(x$power <= 1),
              all(diff(x$effect) > 0), near(max(x$effect), 1.5 * r$mde, 1e-8),
              near(x$power, power_at(v, r$crit_value, x$effect), 1e-12),
              x$power[nrow(x)] >= POWER_TARGET, x$power[1] < 0.2)
  }
  # the settings file records the count this run used and the one seed Section 10 needs
  stopifnot(all(c("placebo_reps", "quick_run", "seed_step", "master_seed", "mde_ceiling") %in% g8$setting),
            g8$value[g8$setting == "master_seed"] == as.character(MASTER_SEED),
            g8$value[g8$setting == "seed_step"] == "power",
            g8$value[g8$setting == "event_set"] == "primary")
}

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

# drawn cohort years: one per treated state per draw, with replacement, from the years given
set.seed(seed_for("test power years"))
py <- placebo_year_draws(2011:2013, 10L, 400L)
stopifnot(length(py) == 400L, all(lengths(py) == 10L), all(unlist(py) %in% 2011:2013),
          setequal(unlist(py), 2011:2013))
set.seed(seed_for("test power years"))
stopifnot(identical(py, placebo_year_draws(2011:2013, 10L, 400L)))
# a single year is that year, not sample()'s 1:n shorthand
stopifnot(identical(placebo_year_draws(2012L, 3L, 2L), list(rep(2012L, 3), rep(2012L, 3))))
stopifnot(inherits(try(placebo_year_draws(integer(), 2L, 5L), silent = TRUE), "try-error"))

# post-reform end years a cohort contributes, with the end years the design drops
stopifnot(identical(post_years(2011L, 2013L), 3L), identical(post_years(2013L, 2013L), 1L),
          identical(post_years(c(2011, 2012, 2013), 2013), c(3L, 2L, 1L)),
          identical(post_years(2018, 2025, 2020), 7L),     # 2018-2025 is 8 end years, less 2020
          identical(post_years(2021, 2025, 2020), 5L),     # the dropped year is before the cohort
          identical(post_years(2026, 2025), 0L))           # treated after the window: no post period

# the projection: a square-root-of-state-years rescaling, and nothing more
stopifnot(near(mde_projection(0.2, 20, 80), 0.1), near(mde_projection(0.2, 50, 50), 0.2),
          near(mde_projection(0.3, 9, 4), 0.45),
          inherits(try(mde_projection(0.2, 0, 50), silent = TRUE), "try-error"),
          inherits(try(mde_projection(0.2, 20, -1), silent = TRUE), "try-error"))

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
# the same years handed over as one vector per draw must give the same estimates
stopifnot(identical(placebo_estimates(pcp, rep(list(pgs), length(ppk)), ppk, parallel = FALSE), pvals))
# years that vary from draw to draw, as the ten-state scenario draws them
set.seed(seed_for("test power sim years"))
pyr <- placebo_year_draws(2011:2013, length(pgs), length(ppk))
pv2 <- placebo_estimates(pcp, pyr, ppk, parallel = FALSE)
stopifnot(length(pv2) == length(ppk), sum(is.finite(pv2)) >= 1L)
stopifnot(inherits(try(placebo_estimates(pcp, pgs, list("V01"), parallel = FALSE), silent = TRUE), "try-error"))
stopifnot(inherits(try(placebo_estimates(pcp, lapply(pyr, function(y) y[1:2]), ppk, parallel = FALSE),
                       silent = TRUE), "try-error"))    # a years vector shorter than its pick

# step 8 outputs, when they have been built
of8 <- file.path("outputs", "08_power",
                 c("mde.csv", "placebo_draws.csv", "mde_10states.csv",
                   "placebo_draws_10states.csv", "power_curve.csv", "model_status.csv",
                   "power_settings.csv"))
if (all(file.exists(of8))) {
  rd8 <- function(f) utils::read.csv(f, stringsAsFactors = FALSE, na.strings = "")
  m8 <- rd8(of8[1]); d8 <- rd8(of8[2]); m10 <- rd8(of8[3]); d10 <- rd8(of8[4])
  c8 <- rd8(of8[5]); s8 <- rd8(of8[6]); g8 <- rd8(of8[7])
  gaps8 <- c("a_poverty", "b_black_white", "c_hispanic_white")
  set8 <- function(k) g8$value[g8$setting == k]
  rep8 <- as.integer(set8("placebo_reps"))
  ten8 <- as.integer(set8("ten_state_count"))
  PROJ <- c("placebo_post_state_years", "design_treated_states", "design_mean_post_years",
            "design_post_state_years", "projection_scale", "mde_projection", "projection_basis")

  # two scenarios, three primary gaps each; the projection belongs to the ten-state file
  stopifnot(nrow(s8) == 6L, setequal(s8$scenario, c("observed", "ten_state")),
            all(table(s8$scenario) == 3L), all(s8$status == "ok"),
            all(s8$event_set == "primary"), all(s8$weighting == "unweighted"))
  stopifnot(all(m8$scenario == "observed"), all(m10$scenario == "ten_state"),
            !any(PROJ %in% names(m8)), all(PROJ %in% names(m10)))
  stopifnot(ten8 == 10L, all(m10$treated_states == ten8), all(m8$treated_states >= 1),
            all(m8$treated_states < ten8))

  # each scenario: the MDE is the one its own saved draws give
  for (part in list(list(m = m8, d = d8), list(m = m10, d = d10))) {
    mm8 <- part$m; dd8 <- part$d
    stopifnot(setequal(mm8$gap, gaps8), !anyDuplicated(mm8$gap), all(mm8$reps == rep8),
              all(mm8$draws_ok <= mm8$reps), all(mm8$eligible_states > mm8$treated_states),
              all(mm8$level == POWER_LEVEL), all(mm8$power_target == POWER_TARGET),
              all(mm8$ceiling == POWER_CEILING), all(mm8$crit_value > 0), all(mm8$placebo_sd > 0),
              all(mm8$mde > 0), all(mm8$mde_normal > 0), all(mm8$power_at_mde >= POWER_TARGET),
              all(mm8$underpowered == as.integer(mm8$mde > POWER_CEILING)),
              all(near(mm8$mde_over_model_se, mm8$mde / mm8$model_se, 1e-8)))
    stopifnot(setequal(dd8$gap, gaps8), all(table(dd8$gap) == rep8))
    for (g in gaps8) {
      v <- dd8$att[dd8$gap == g]
      r <- mm8[mm8$gap == g, ]
      mm <- mde_from_placebo(v)
      stopifnot(sum(is.finite(v)) == r$draws_ok, near(mm$crit, r$crit_value, 1e-10),
                near(mm$mde, r$mde, 1e-10), near(mm$mde_normal, r$mde_normal, 1e-10),
                near(mm$power_at_mde, r$power_at_mde, 1e-10),
                near(stats::sd(v[is.finite(v)]), r$placebo_sd, 1e-10),
                abs(r$placebo_mean) < r$mde)
      # the curve runs from no effect to past the MDE and is the same test as the table
      x <- c8[c8$scenario == r$scenario & c8$gap == g, ]
      stopifnot(nrow(x) == 61L, x$effect[1] == 0, all(x$power >= 0), all(x$power <= 1),
                all(diff(x$effect) > 0), near(max(x$effect), 1.5 * r$mde, 1e-8),
                near(x$power, power_at(v, r$crit_value, x$effect), 1e-12),
                x$power[nrow(x)] >= POWER_TARGET, x$power[1] < 0.2)
    }
  }
  # ten placebo-treated states buy a tighter placebo distribution than two
  k10 <- match(m8$gap, m10$gap)
  stopifnot(!anyNA(k10), all(m10$placebo_sd[k10] < m8$placebo_sd), all(m10$mde[k10] < m8$mde))

  # the projection: the ten-state MDE rescaled by the square root of the state-year
  # ratio, labelled as a projection and carrying the inputs it was built from
  stopifnot(all(m10$design_treated_states >= 1), all(m10$design_mean_post_years > 0),
            all(near(m10$design_post_state_years,
                     m10$design_treated_states * m10$design_mean_post_years, 1e-8)),
            all(m10$placebo_post_state_years > 0),
            all(m10$placebo_post_state_years <= ten8 * length(2011:2013)),
            all(near(m10$projection_scale,
                     sqrt(m10$placebo_post_state_years / m10$design_post_state_years), 1e-12)),
            all(near(m10$mde_projection, m10$mde * m10$projection_scale, 1e-12)),
            all(near(m10$mde_projection, mde_projection(m10$mde, m10$placebo_post_state_years,
                                                        m10$design_post_state_years), 1e-12)),
            all(m10$mde_projection < m10$mde),      # the registered window is the longer one
            all(grepl("projection", m10$projection_basis)),
            all(grepl("not a power calculation", m10$projection_basis)))
  # the projection end year is the placeholder, and the dropped end year is out of the count
  stopifnot(set8("projection_end_year") == "2025", set8("projection_dropped_years") == "2020")

  # the settings file records both scenarios' seeds and the counts this run used
  stopifnot(all(c("placebo_reps", "quick_run", "seed_step_observed", "seed_step_ten_state",
                  "ten_state_count", "ten_state_years", "projection_end_year",
                  "projection_dropped_years", "master_seed", "mde_ceiling") %in% g8$setting),
            set8("master_seed") == as.character(MASTER_SEED),
            set8("seed_step_observed") == "power", set8("seed_step_ten_state") == "power_10",
            set8("ten_state_years") == "2011-2013", set8("event_set") == "primary")
}

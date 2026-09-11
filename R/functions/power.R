# Power (design document, Section 10). Helpers used by R/08_power.R on the
# Callaway-Sant'Anna fits of step 5 (outputs/05_primary/cs_models.rds).
#
# Section 10 computes power by simulation on the stage 1 assessment files (end years
# 2010-2013), before any later outcome file is downloaded: placebo reform years are
# assigned to random states, the Callaway-Sant'Anna pipeline is rerun 2,000 times, and
# the spread of those placebo estimates gives the minimum detectable effect at 80
# percent power and a 5 percent two-sided test.
#
# Author decisions 2026-09-11 (docs/decision_log.md):
#   Placebo assignment. The rule Section 8 already fixes for randomization inference:
#   the treated states are drawn at random from every state in the model's panel
#   (never treated, treated after the window, or treated within it) and given the
#   observed cohort years, keeping the number of states per cohort year. Section 10
#   and Section 8 describe the same reassignment, so the two null distributions are
#   the same object and share this code.
#   Minimum detectable effect. The critical value is the POWER_LEVEL quantile of the
#   absolute placebo estimates: the test rejects when the estimate is farther from
#   zero than that share of the placebo draws. The MDE is the smallest constant shift
#   of the placebo distribution that this test rejects with probability POWER_TARGET.
#   The inversion is exact rather than a normal approximation: adding a constant to
#   the treated post-reform outcomes shifts every doubly robust ATT(g, t), and so
#   their average, by exactly that constant, so the shifted placebo draws are the
#   distribution of the estimate under an alternative of that size. The
#   normal-approximation MDE, (z_0.975 + z_0.8) x sd, is reported beside it.
#
# Nothing here prints or returns a treatment year (CLAUDE.md rule 7): the cohort years
# enter placebo_estimates() as values to reassign and never leave it.

POWER_REPS    <- 2000L   # Section 10: 2,000 placebo runs
POWER_LEVEL   <- 0.95    # two-sided level of the placebo critical value
POWER_TARGET  <- 0.80    # power the MDE is reported at
POWER_CEILING <- 0.10    # Section 10: underpowered if every primary gap exceeds this, in SD

# The cohort years of the states treated within the window, one per treated state, in
# the order split() gives (states sorted by name). Values, not states: which state
# carries which year is what the placebo draws replace.
panel_cohort_years <- function(panel) {
  g <- vapply(split(panel$g, panel$state), function(z) z[1], numeric(1))
  unname(g[g > 0])
}

# The treated states of each placebo draw: n_treated of the panel's states, drawn
# without replacement. The caller seeds with seed_for("power") in the parent process,
# so one seed covers every model and the draws do not depend on the worker count.
placebo_state_draws <- function(states, n_treated, reps) {
  stopifnot(n_treated >= 1L, n_treated < length(states), reps >= 1L)
  lapply(seq_len(reps), function(b) states[sample.int(length(states), n_treated)])
}

# The overall post-reform average refit on each placebo assignment.
# cp: cs_panel() of a step 5 fit; gs: the cohort years to reassign, one per treated
# state; picks: the treated states of each draw, from placebo_state_draws(). Returns
# one estimate per draw, NA where did could not fit the reassignment.
placebo_estimates <- function(cp, gs, picks, parallel = TRUE, seed = NULL) {
  panel <- cp$panel
  states <- sort(unique(panel$state))
  stopifnot(length(gs) >= 1L, all(lengths(picks) == length(gs)))
  one <- function(pick) {
    g <- stats::setNames(rep(0, length(states)), states)
    g[pick] <- gs
    p <- panel
    p$g <- unname(g[p$state])
    cs_overall(p, cp$xformla, cp$weightsname, cp$min_e, cp$max_e)
  }
  if (parallel && requireNamespace("furrr", quietly = TRUE))
    furrr::future_map_dbl(picks, one, .options = furrr::furrr_options(seed = seed))
  else vapply(picks, one, numeric(1))
}

# Power of the placebo test against an effect of size d: the share of placebo draws
# that the test rejects once they are shifted by d.
# The shifts the MDE search considers put a draw exactly on the critical value, where
# floating point can leave the shifted draw an ulp short of it, so the comparison keeps
# a relative tolerance. It is nine orders of magnitude below the spacing of the shifts
# the search steps through, so it can only decide draws that sit on the critical value
# itself, and it is what makes the MDE scale exactly with the spread of the draws.
POWER_TOL <- 1e-12

power_at <- function(v, crit, d) {
  v <- v[is.finite(v)]
  cut <- crit * (1 - POWER_TOL)
  vapply(d, function(x) mean(abs(v + x) >= cut), numeric(1))
}

# Minimum detectable effect from a placebo distribution (author decision above).
# Power can only step up where d reaches crit - v for one of the draws v, and the
# steps down (where d reaches -crit - v) never create a crossing, so zero and those
# points are the whole candidate set and the smallest of them reaching POWER_TARGET is
# the exact MDE. Returns NA for the MDE if no shift on the candidate set reaches it.
mde_from_placebo <- function(v, level = POWER_LEVEL, power = POWER_TARGET) {
  v <- v[is.finite(v)]
  out <- list(draws = length(v), crit = NA_real_, mde = NA_real_, power_at_mde = NA_real_,
              mde_normal = NA_real_)
  if (length(v) < 2L) return(out)
  out$crit <- unname(stats::quantile(abs(v), level, names = FALSE))
  out$mde_normal <- (stats::qnorm(1 - (1 - level) / 2) + stats::qnorm(power)) * stats::sd(v)
  up <- out$crit - v
  cand <- sort(unique(c(0, up[up > 0])))
  ok <- which(power_at(v, out$crit, cand) >= power)
  if (length(ok)) {
    out$mde <- cand[ok[1]]
    out$power_at_mde <- power_at(v, out$crit, out$mde)
  }
  out
}

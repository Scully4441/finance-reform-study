POWER_REPS    <- 2000L
POWER_LEVEL   <- 0.95
POWER_TARGET  <- 0.80
POWER_CEILING <- 0.10

panel_cohort_years <- function(panel) {
  g <- vapply(split(panel$g, panel$state), function(z) z[1], numeric(1))
  unname(g[g > 0])
}

placebo_state_draws <- function(states, n_treated, reps) {
  stopifnot(n_treated >= 1L, n_treated < length(states), reps >= 1L)
  lapply(seq_len(reps), function(b) states[sample.int(length(states), n_treated)])
}

placebo_year_draws <- function(years, n_treated, reps) {
  stopifnot(length(years) >= 1L, n_treated >= 1L, reps >= 1L)
  lapply(seq_len(reps), function(b) years[sample.int(length(years), n_treated, replace = TRUE)])
}

placebo_estimates <- function(cp, gs, picks, parallel = TRUE, seed = NULL) {
  panel <- cp$panel
  states <- sort(unique(panel$state))
  gsl <- if (is.list(gs)) gs else rep(list(gs), length(picks))
  stopifnot(length(gsl) == length(picks), all(lengths(gsl) >= 1L),
            all(lengths(picks) == lengths(gsl)))
  one <- function(pick, years) {
    g <- stats::setNames(rep(0, length(states)), states)
    g[pick] <- years
    p <- panel
    p$g <- unname(g[p$state])
    cs_overall(p, cp$xformla, cp$weightsname, cp$min_e, cp$max_e, cp$allow_unbalanced)
  }
  if (parallel && requireNamespace("furrr", quietly = TRUE))
    furrr::future_map2_dbl(picks, gsl, one, .options = furrr::furrr_options(seed = seed))
  else vapply(seq_along(picks), function(i) one(picks[[i]], gsl[[i]]), numeric(1))
}

POWER_TOL <- 1e-12

power_at <- function(v, crit, d) {
  v <- v[is.finite(v)]
  cut <- crit * (1 - POWER_TOL)
  vapply(d, function(x) mean(abs(v + x) >= cut), numeric(1))
}

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

post_years <- function(g, last_year, drop = integer())
  vapply(g, function(x) if (x > last_year) 0L else sum(!(seq.int(x, last_year) %in% drop)),
         integer(1))

mde_projection <- function(mde, placebo_state_years, design_state_years) {
  stopifnot(placebo_state_years > 0, design_state_years > 0)
  mde * sqrt(placebo_state_years / design_state_years)
}

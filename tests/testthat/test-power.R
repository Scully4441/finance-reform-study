withr::local_dir(ROOT)

test_that("power simulation and the step 8 output", {
PW <- 2010:2013

expect_all(POWER_REPS == 2000L, POWER_LEVEL == 0.95, POWER_TARGET == 0.80, POWER_CEILING == 0.10)

ppan <- data.frame(state = rep(c("A", "B", "C", "D"), each = 4), sy_end = PW,
                   g = rep(c(2012, 0, 2011, 0), each = 4), stringsAsFactors = FALSE)
expect_all(identical(panel_cohort_years(ppan), c(2012, 2011)))
expect_all(length(panel_cohort_years(within(ppan, g <- 0))) == 0L)

pst <- sprintf("S%02d", 1:36)
set.seed(seed_for("test power draws"))
pd <- placebo_state_draws(pst, 2L, 500L)
expect_all(length(pd) == 500L, all(lengths(pd) == 2L), all(vapply(pd, anyDuplicated, 0) == 0),
          all(unlist(pd) %in% pst), length(unique(unlist(pd))) == length(pst))
set.seed(seed_for("test power draws"))
expect_all(identical(pd, placebo_state_draws(pst, 2L, 500L)))
set.seed(seed_for("test power draws other"))
expect_all(!identical(pd, placebo_state_draws(pst, 2L, 500L)))
expect_all(inherits(try(placebo_state_draws(pst, 36L, 5L), silent = TRUE), "try-error"),
          inherits(try(placebo_state_draws(pst, 0L, 5L), silent = TRUE), "try-error"))

set.seed(seed_for("test power years"))
py <- placebo_year_draws(2011:2013, 10L, 400L)
expect_all(length(py) == 400L, all(lengths(py) == 10L), all(unlist(py) %in% 2011:2013),
          setequal(unlist(py), 2011:2013))
set.seed(seed_for("test power years"))
expect_all(identical(py, placebo_year_draws(2011:2013, 10L, 400L)))
expect_all(identical(placebo_year_draws(2012L, 3L, 2L), list(rep(2012L, 3), rep(2012L, 3))))
expect_all(inherits(try(placebo_year_draws(integer(), 2L, 5L), silent = TRUE), "try-error"))

expect_all(identical(post_years(2011L, 2013L), 3L), identical(post_years(2013L, 2013L), 1L),
          identical(post_years(c(2011, 2012, 2013), 2013), c(3L, 2L, 1L)),
          identical(post_years(2018, 2025, 2020), 7L),
          identical(post_years(2021, 2025, 2020), 5L),
          identical(post_years(2026, 2025), 0L))

set.seed(seed_for("test power normal"))
pv <- stats::rnorm(20000)
pm <- mde_from_placebo(pv)
expect_all(pm$draws == 20000L, near(pm$crit, stats::quantile(abs(pv), 0.95, names = FALSE)),
          near(power_at(pv, pm$crit, 0), mean(abs(pv) >= pm$crit)), abs(power_at(pv, pm$crit, 0) - 0.05) < 1e-4)
expect_all(abs(pm$mde - (stats::qnorm(0.975) + stats::qnorm(0.8)) * stats::sd(pv)) < 0.05,
          abs(pm$mde - pm$mde_normal) < 0.05, near(pm$mde_normal, 2.8015862 * stats::sd(pv), 1e-6))
expect_all(pm$mde > 0, pm$power_at_mde >= POWER_TARGET,
          near(pm$power_at_mde, power_at(pv, pm$crit, pm$mde)),
          power_at(pv, pm$crit, pm$mde - 1e-8) < POWER_TARGET)
expect_all(near(mde_from_placebo(3 * pv)$mde, 3 * pm$mde, 1e-10),
          near(mde_from_placebo(-pv)$crit, pm$crit))
pg <- power_at(pv, pm$crit, seq(0, 6, 0.25))
expect_all(all(diff(pg) >= -1e-12), pg[1] < 0.06, pg[length(pg)] > 0.99, all(pg >= 0), all(pg <= 1))
expect_all(is.na(mde_from_placebo(c(1, NA))$mde), is.na(mde_from_placebo(numeric())$crit),
          near(mde_from_placebo(rep(0, 100))$mde, 0))
pna <- mde_from_placebo(c(pv[1:100], rep(NA_real_, 20)))
expect_all(pna$draws == 100L, is.finite(pna$mde))

expect_all(length(unique(c(seed_for("power"), seed_for("power_6"), seed_for("power_10"),
                          seed_for("power_12")))) == 4L)

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
expect_all(pfit$status == "ok")
pcp <- cs_panel(pfit$fit)
pgs <- panel_cohort_years(pcp$panel)
expect_all(length(pgs) == 3L, all(pgs > 0))
set.seed(seed_for("test power sim draws"))
ppk <- placebo_state_draws(sort(unique(pcp$panel$state)), length(pgs), 5L)
pvals <- placebo_estimates(pcp, pgs, ppk, parallel = FALSE)
expect_all(length(pvals) == 5L, sum(is.finite(pvals)) >= 1L)
expect_all(near(placebo_estimates(pcp, panel_cohort_years(pcp$panel), list(names(
            which(vapply(split(pcp$panel$g, pcp$panel$state), function(z) z[1], numeric(1)) > 0))),
            parallel = FALSE), pfit$fit$aggte$overall.att, 1e-8))
expect_all(identical(placebo_estimates(pcp, pgs, ppk, parallel = FALSE), pvals))
expect_all(identical(placebo_estimates(pcp, rep(list(pgs), length(ppk)), ppk, parallel = FALSE), pvals))
set.seed(seed_for("test power sim years"))
pyr <- placebo_year_draws(2011:2013, length(pgs), length(ppk))
pv2 <- placebo_estimates(pcp, pyr, ppk, parallel = FALSE)
expect_all(length(pv2) == length(ppk), sum(is.finite(pv2)) >= 1L)
expect_all(inherits(try(placebo_estimates(pcp, pgs, list("V01"), parallel = FALSE), silent = TRUE), "try-error"))
expect_all(inherits(try(placebo_estimates(pcp, lapply(pyr, function(y) y[1:2]), ppk, parallel = FALSE),
                       silent = TRUE), "try-error"))

pev <- data.frame(state = c("A", "B", "C", "D", "E", "F"), treat_year = c(2010L, 2011L, 2019L, 2021L, 2022L, NA),
                  group = c("treated", "treated", "treated", "treated", "treated", "never"), stringsAsFactors = FALSE)
expect_all(placebo_state_count(pev, 2010L, 2021L) == 3L, placebo_state_count(pev, 2010L, 2025L) == 4L,
          placebo_state_count(pev[pev$group == "never", ], 2010L, 2021L) == 0L)
pmt <- data.frame(gap = c("a_poverty", "b_black_white", "c_hispanic_white"), mde = c(0.05, 0.08, 0.11))
pg3 <- c("a_poverty", "b_black_white", "c_hispanic_white")
expect_all(startsWith(power_decision(pmt, pg3)$classification, "UNDERPOWERED"),
          power_decision(pmt, pg3)$gaps_over_ceiling == 1L,
          power_decision(transform(pmt, mde = c(0.05, 0.08, 0.09)), pg3)$classification == "not underpowered",
          startsWith(power_decision(transform(pmt, mde = c(0.05, NA, 0.09)), pg3)$classification, "UNDERPOWERED"),
          startsWith(power_decision(pmt[1:2, ], pg3)$classification, "UNDERPOWERED"),
          startsWith(power_decision(NULL, pg3)$classification, "UNDERPOWERED"))

of8 <- file.path("outputs", "08_power", c("mde.csv", "placebo_draws.csv", "power_curve.csv", "model_status.csv",
                                          "power_decision.csv", "power_settings.csv"))
if (all(file.exists(of8))) {
  rd8 <- function(f) utils::read.csv(f, stringsAsFactors = FALSE, na.strings = "")
  m8 <- rd8(of8[1]); d8 <- rd8(of8[2]); c8 <- rd8(of8[3]); s8 <- rd8(of8[4]); dec8 <- rd8(of8[5]); g8 <- rd8(of8[6])
  gaps8 <- c("a_poverty", "b_black_white", "c_hispanic_white")
  set8 <- function(k) g8$value[g8$setting == k]
  rep8 <- as.integer(set8("placebo_reps"))
  expect_all(nrow(s8) == 3L, all(s8$event_set == "primary"), all(s8$weighting == "unweighted"), all(s8$panel == "unbalanced"),
            set8("seed_step") == "power", set8("master_seed") == as.character(MASTER_SEED),
            set8("placebo_cohort_years") == "2011-2013", set8("event_set") == "primary", set8("panel") == "unbalanced",
            all(m8$treated_states == as.integer(set8("placebo_treated_states"))))
  expect_all(setequal(m8$gap, gaps8), !anyDuplicated(m8$gap), all(m8$reps == rep8), all(m8$draws_ok <= m8$reps),
            all(m8$eligible_states > m8$treated_states), all(m8$level == POWER_LEVEL), all(m8$power_target == POWER_TARGET),
            all(m8$ceiling == POWER_CEILING), all(m8$underpowered == as.integer(!is.finite(m8$mde) | m8$mde > POWER_CEILING)),
            all(near(m8$mde_over_model_se, m8$mde / m8$model_se, 1e-8)))
  expect_all(identical(dec8$classification, power_decision(m8, gaps8)$classification),
            dec8$gaps_over_ceiling == sum(m8$mde > POWER_CEILING, na.rm = TRUE))
  expect_all(setequal(d8$gap, gaps8), all(table(d8$gap) == rep8))
  for (g in gaps8) {
    v <- d8$att[d8$gap == g]
    r <- m8[m8$gap == g, ]
    mm <- mde_from_placebo(v)
    expect_all(sum(is.finite(v)) == r$draws_ok, near(mm$crit, r$crit_value, 1e-10), near(mm$mde, r$mde, 1e-10),
              near(mm$mde_normal, r$mde_normal, 1e-10), near(stats::sd(v[is.finite(v)]), r$placebo_sd, 1e-10))
    x <- c8[c8$gap == g, ]
    expect_all(nrow(x) == 61L, x$effect[1] == 0, all(x$power >= 0), all(x$power <= 1), all(diff(x$effect) > 0),
              near(x$power, power_at(v, r$crit_value, x$effect), 1e-12))
  }
}
})

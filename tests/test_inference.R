# Checks for R/functions/inference.R and the step 7 outputs (design Section 8).
# Sourced by tests/run_tests.R after the shared functions are loaded.
IW <- 2010:2013

# Webb weights: the six-point support, mean 0 and variance 1, and seeded
set.seed(seed_for("test inference webb"))
iw <- webb_weights(5L, 4000L)
stopifnot(identical(dim(iw), c(4000L, 5L)), all(iw %in% WEBB_SUPPORT),
          length(unique(as.vector(iw))) == 6L, near(sort(unique(as.vector(iw))), WEBB_SUPPORT))
stopifnot(abs(mean(iw)) < 0.02, abs(stats::var(as.vector(iw)) - 1) < 0.05)
set.seed(seed_for("test inference webb"))
stopifnot(identical(iw, webb_weights(5L, 4000L)))

# cluster_se() on an influence function reproduces a cluster-robust standard error:
# for least squares the influence function is n (X'X)^-1 x_i e_i, and fixest without
# small-sample corrections is the same CR0 estimator.
set.seed(seed_for("test inference cluster se"))
icl <- data.frame(cl = rep(sprintf("C%02d", 1:12), each = 20), stringsAsFactors = FALSE)
icl$x <- stats::rnorm(nrow(icl))
icl$y <- 0.4 * icl$x + rep(stats::rnorm(12), each = 20) + stats::rnorm(nrow(icl), sd = 0.5)
ilm <- stats::lm(y ~ x, icl)
iX <- stats::model.matrix(ilm)
ipsi <- nrow(icl) * (iX * stats::resid(ilm)) %*% solve(crossprod(iX))
ife <- fixest::feols(y ~ x, icl, cluster = ~cl, ssc = fixest::ssc(adj = FALSE, cluster.adj = FALSE))
stopifnot(near(cluster_se(rowsum(ipsi[, "x"], icl$cl), nrow(icl)),
               unname(sqrt(diag(stats::vcov(ife)))["x"]), 1e-8))

# wild cluster bootstrap: the p-value counts the draws at least as far from zero
set.seed(seed_for("test inference wcb"))
iS <- stats::rnorm(20)
iwb <- webb_weights(20L, 999L)
ise <- cluster_se(iS, 200L)
ib0 <- wcb_test(0, iS, 200L, iwb)                       # t = 0: every draw is at least as far out
ibb <- wcb_test(10 * ise, iS, 200L, iwb)                # far beyond any Webb draw
stopifnot(near(ib0$row$p_value, 1), near(ibb$row$p_value, 1 / 1000), length(ibb$t_boot) == 999L,
          near(ibb$row$se, ise), ibb$row$crit_val > 0, ibb$row$clusters == 20L, ibb$row$reps == 999L,
          ibb$row$ci_lo < ibb$row$att, ibb$row$ci_hi > ibb$row$att)
stopifnot(near(wcb_test(-10 * ise, iS, 200L, iwb)$row$p_value, ibb$row$p_value))   # two-sided
imid <- wcb_test(1.2 * ise, iS, 200L, iwb)$row
stopifnot(imid$p_value > 1 / 1000, imid$p_value < 1, near(imid$t, 1.2))
stopifnot(is.na(wcb_test(NA_real_, iS, 200L, iwb)$row$p_value),
          is.na(wcb_test(1, rep(0, 20), 200L, iwb)$row$p_value))   # no variation: no test

# Romano-Wolf: never below the unadjusted p-value, monotone down the ordering, and
# equal to the unadjusted p-value for a family of one
set.seed(seed_for("test inference rw"))
itb <- matrix(stats::rnorm(999 * 3), 999L, 3L)
ito <- c(3, 1.5, 0.2)
irw <- rw_stepdown(ito, itb)
ipu <- vapply(1:3, function(j) (1 + sum(abs(itb[, j]) >= abs(ito[j]))) / 1000, numeric(1))
stopifnot(all(irw >= ipu - 1e-12), all(irw > 0), all(irw <= 1),
          all(diff(irw[order(abs(ito), decreasing = TRUE)]) >= -1e-12),
          near(rw_stepdown(ito[1], itb[, 1, drop = FALSE]), ipu[1]))

# a small panel: cohorts 2011 and 2012, six never-treated states, true effect 0.5
isim <- function(n = 6L, effect = 0.5) {
  ty <- c(2011L, 2012L, 2012L, rep(NA, 6))
  iev <- data.frame(state = sprintf("U%02d", seq_along(ty)), treat_year = ty,
                    group = ifelse(is.na(ty), "never", "treated"), stringsAsFactors = FALSE)
  set.seed(seed_for("test inference sim"))
  d <- expand.grid(k = seq_len(n), state = iev$state, sy_end = IW, stringsAsFactors = FALSE)
  d$unit <- paste(d$state, d$k)
  u <- sort(unique(d$unit)); x <- stats::rnorm(length(u))
  d$x1 <- x[match(d$unit, u)]
  tyd <- iev$treat_year[match(d$state, iev$state)]
  d$y <- 0.3 * d$x1 + 0.05 * (d$sy_end - 2010) + effect * (!is.na(tyd) & d$sy_end >= tyd) +
    stats::rnorm(nrow(d), sd = 0.02)
  attach_cohorts(d[order(d$unit, d$sy_end), ], cohort_coding(iev, IW), "unit")$panel
}
ip <- isim()
ifit <- run_cs(ip, ~x1, seed_step = "test inference fit")
stopifnot(ifit$status == "ok")

# the influence function: one row per unit summed into states, and did's own standard
# error is the clustered one; the overall column is the mean of the post-reform columns
iinf <- cs_influence(ifit$fit)
stopifnot(!is.null(iinf), iinf$n == length(unique(ip$id)), length(iinf$states) == 9L,
          identical(iinf$states, sort(unique(ip$state))),
          identical(dim(iinf$scores), c(9L, length(iinf$egt) + 1L)),
          identical(colnames(iinf$scores)[ncol(iinf$scores)], "overall"))
stopifnot(cluster_se(iinf$scores[, "overall"], iinf$n) > 0,
          abs(cluster_se(iinf$scores[, "overall"], iinf$n) / iinf$overall_se - 1) < 0.25)
ipost <- which(iinf$egt >= 0)
stopifnot(near(iinf$scores[, "overall"], rowMeans(iinf$scores[, ipost, drop = FALSE]), 1e-10),
          near(iinf$overall_att, mean(iinf$att_egt[ipost]), 1e-10))
stopifnot(is.null(cs_influence(NULL)), is.null(cs_influence(list(att_gt = NULL, aggte = NULL))))

# refitting on did's stored panel reproduces the estimate, which is what randomization
# inference reruns
ipan <- cs_panel(ifit$fit)
stopifnot(is.null(ipan$weightsname), nrow(ipan$panel) == nrow(ip), !ipan$allow_unbalanced,
          near(cs_overall(ipan$panel, ipan$xformla, ipan$weightsname, ipan$min_e, ipan$max_e),
               ifit$fit$aggte$overall.att, 1e-8))
stopifnot(is.na(cs_overall(ipan$panel, ~no_such_covariate, NULL, ipan$min_e, ipan$max_e)))

# the primary panel rule: cs_panel() carries allow_unbalanced_panel back, so the refits
# of randomization inference and of the power simulation are the step 5 model
set.seed(seed_for("test inference holes"))
ipu <- ip[-sample(nrow(ip), round(0.15 * nrow(ip))), ]
ifitu <- run_cs(ipu, ~x1, seed_step = "test inference unbalanced", allow_unbalanced_panel = TRUE)
ipanu <- cs_panel(ifitu$fit)
stopifnot(ifitu$status == "ok", ipanu$allow_unbalanced, is.null(ipanu$panel$.rowid),
          near(cs_overall(ipanu$panel, ipanu$xformla, ipanu$weightsname, ipanu$min_e, ipanu$max_e,
                          ipanu$allow_unbalanced), ifitu$fit$aggte$overall.att, 1e-8))
# refitting the same panel under the balanced rule is a different model, which is why the
# flag has to travel with the panel
stopifnot(!near(cs_overall(ipanu$panel, ipanu$xformla, ipanu$weightsname, ipanu$min_e, ipanu$max_e,
                           FALSE), ifitu$fit$aggte$overall.att, 1e-8))
# the influence function of an unbalanced fit is still one row per unit, summed by state
iinfu <- cs_influence(ifitu$fit)
stopifnot(!is.null(iinfu), iinfu$n == length(unique(ipu$id)),
          identical(iinfu$states, sort(unique(ipu$state))),
          cluster_se(iinfu$scores[, "overall"], iinfu$n) > 0)
iriu <- ri_overall(ifitu$fit, reps = 4L, seed_step = "test inference ri unbalanced", parallel = FALSE)
stopifnot(iriu$status == "ok", length(iriu$values) == 4L, iriu$draws_ok > 0L)
# a placebo draw that reproduces the observed estimate up to floating-point noise is a tie
# and counts as at least as far from zero
stopifnot(near(ri_pvalue(c(0.3 - 1e-15, -0.3 + 1e-14, 0.1, 0.5), 0.3), 4 / 5),
          near(ri_pvalue(c(0.2999, 0.1), -0.3), 1 / 3))
# a weighted model: did reserves .w for its own weights, so they come back under another name
ipw <- ip
ipw$wt <- 1 + as.integer(factor(ipw$state)) %% 3L
ifitw <- run_cs(ipw, ~x1, weightsname = "wt", seed_step = "test inference fit weighted")
ipanw <- cs_panel(ifitw$fit)
stopifnot(ifitw$status == "ok", identical(ipanw$weightsname, "ri_weight"), is.null(ipanw$panel$.w),
          near(cs_overall(ipanw$panel, ipanw$xformla, ipanw$weightsname, ipanw$min_e, ipanw$max_e),
               ifitw$fit$aggte$overall.att, 1e-8))

# randomization inference: the cohort years move to other states, the treated count is
# kept, and the draws are seeded
iri <- ri_overall(ifit$fit, reps = 6L, seed_step = "test inference ri", parallel = FALSE)
stopifnot(iri$status == "ok", length(iri$values) == 6L, iri$treated_states == 3L,
          iri$eligible_states == 9L, iri$draws_ok <= 6L, iri$draws_ok > 0L,
          iri$p_value > 0, iri$p_value <= 1)
stopifnot(identical(ri_overall(ifit$fit, reps = 6L, seed_step = "test inference ri", parallel = FALSE)$values,
                    iri$values))
stopifnot(!identical(ri_overall(ifit$fit, reps = 6L, seed_step = "test inference ri other",
                                parallel = FALSE)$values, iri$values))
ivok <- iri$values[is.finite(iri$values)]
stopifnot(near(iri$p_value, (1 + sum(abs(ivok) >= abs(ifit$fit$aggte$overall.att))) / (length(ivok) + 1)))

# HonestDiD: a row per M-bar plus the unadjusted set, and the bounds widen with M-bar
ihd <- honest_rm(iinf, c(0, 0.5, 1, 1.5, 2))
stopifnot(nrow(ihd) == 6L, sum(is.na(ihd$mbar)) == 1L, ihd$method[1] == "original",
          identical(ihd$mbar[-1], c(0, 0.5, 1, 1.5, 2)),
          all(ihd$num_pre[ihd$status == "ok"] == sum(iinf$egt < 0 & iinf$egt != -1)),
          all(ihd$num_post[ihd$status == "ok"] == sum(iinf$egt >= 0)))
# an M-bar whose grid search accepts nothing is an empty bound set, not a pair of
# infinities; a reported bound is always finite and widens with M-bar
stopifnot(all(ihd$status == "ok" | grepl("^empty bound set", ihd$status)))
iok <- ihd$status == "ok" & !is.na(ihd$mbar)
stopifnot(all(is.finite(ihd$lb[ihd$status == "ok"])), all(is.finite(ihd$ub[ihd$status == "ok"])),
          all(is.na(ihd$lb[ihd$status != "ok"])), all(is.na(ihd$ub[ihd$status != "ok"])),
          all(ihd$lb[iok] <= ihd$ub[iok]),
          all(diff(ihd$lb[iok]) <= 1e-8), all(diff(ihd$ub[iok]) >= -1e-8))   # wider as M-bar grows
# the failure paths carry a status rather than stopping
ipre <- iinf; ipre$egt[ipre$egt < -1L] <- -1L                                # no pre-reform event time
stopifnot(nrow(honest_rm(ipre, 1)) == 1L, grepl("pre-reform", honest_rm(ipre, 1)$status))
igap <- iinf; igap$egt <- igap$egt - c(2L, rep(0L, length(igap$egt) - 1L))    # a hole in the sequence
stopifnot(grepl("consecutive", honest_rm(igap, 1)$status))
stopifnot(grepl("no influence function", honest_rm(NULL, 1)$status))

# step 7 outputs, when they have been built
of7 <- file.path("outputs", "07_inference",
                 c("bootstrap_overall.csv", "bootstrap_event_time.csv", "randomization_overall.csv",
                   "randomization_draws.csv", "romano_wolf.csv", "honestdid_overall.csv",
                   "model_status.csv", "inference_settings.csv"))
if (all(file.exists(of7))) {
  rd7 <- function(f) utils::read.csv(f, stringsAsFactors = FALSE, na.strings = "")
  bo <- rd7(of7[1]); be <- rd7(of7[2]); ro <- rd7(of7[3]); rdw <- rd7(of7[4])
  rwf <- rd7(of7[5]); hdo <- rd7(of7[6]); st7 <- rd7(of7[7]); se7 <- rd7(of7[8])
  key7 <- function(x) paste(x$gap, x$event_set, x$weighting, x$panel)
  mw7 <- c("a_poverty unweighted", "b_black_white unweighted", "b_black_white tested_weighted",
           "c_hispanic_white unweighted", "c_hispanic_white tested_weighted")
  all7 <- unlist(lapply(c("primary", "r1", "r2"), function(s)
    unlist(lapply(names(PANEL_TYPES), function(pn) paste(sub(" ", paste0(" ", s, " "), mw7), pn)))))
  stopifnot(nrow(st7) == 30L, setequal(key7(st7), all7), !anyDuplicated(key7(st7)),
            setequal(st7$panel, names(PANEL_TYPES)), all(table(st7$panel) == 15L))
  used <- key7(st7)[st7$status == "ok"]

  # bootstrap: one row per usable model, a p-value on the (1 + count) / (reps + 1) grid
  stopifnot(setequal(key7(bo), used), !anyDuplicated(key7(bo)), all(bo$se > 0), all(bo$clusters >= 2),
            all(bo$p_value > 0), all(bo$p_value <= 1), all(bo$ci_lo < bo$att), all(bo$ci_hi > bo$att),
            all(near(bo$p_value * (bo$reps + 1), round(bo$p_value * (bo$reps + 1)), 1e-8)),
            all(near(bo$t, bo$att / bo$se, 1e-8)), all(bo$crit_val > 0))
  # event times: the step 5 grid, the reference period empty, a p-value wherever there is an estimate
  stopifnot(all(table(key7(be)) == length(EVENT_MIN:EVENT_MAX)), setequal(key7(be), used),
            all(be$e >= EVENT_MIN), all(be$e <= EVENT_MAX), all(is.na(be$att[be$reference])),
            identical(is.na(be$att), is.na(be$p_value)), all(be$se[!is.na(be$att)] > 0),
            all(be$p_value[!is.na(be$p_value)] > 0), all(be$p_value[!is.na(be$p_value)] <= 1))
  # the overall bootstrap row is the same test as the event-time file's overall counterpart
  stopifnot(all(be$reps == bo$reps[1]), all(bo$reps == se7$value[se7$setting == "bootstrap_reps"]))

  # Romano-Wolf: the unadjusted p-values are the bootstrap's (one set of draws per event
  # set), and the step-down never lowers them
  stopifnot(all(rwf$p_romano_wolf >= rwf$p_unadjusted - 1e-12), all(rwf$hypotheses >= 2),
            all(rwf$family %in% c("unweighted", "tested_weighted")),
            all(rwf$panel %in% names(PANEL_TYPES)))
  # a family is the three gaps within one event set, weighting family and panel rule
  # (a family forms where at least two of its gaps have a step 5 fit; on the full window
  # the balanced r1 and r2 panels do not)
  fams <- as.vector(outer(c("primary", "r1", "r2"),
                          as.vector(outer(names(PANEL_TYPES), c("unweighted", "tested_weighted"), paste)), paste))
  stopifnot(all(paste(rwf$event_set, rwf$panel, rwf$family) %in% fams),
            all(paste("primary", names(PANEL_TYPES), "unweighted") %in% paste(rwf$event_set, rwf$panel, rwf$family)))
  kb <- match(paste(rwf$gap, rwf$event_set, rwf$weighting, rwf$panel), key7(bo))
  stopifnot(!anyNA(kb), all(near(rwf$p_unadjusted, bo$p_value[kb], 1e-12)),
            all(near(rwf$t, bo$t[kb], 1e-10)))
  for (f in unique(paste(rwf$event_set, rwf$panel, rwf$family))) {   # monotone down the ordering
    x <- rwf[paste(rwf$event_set, rwf$panel, rwf$family) == f, ]
    x <- x[order(x$rank), ]
    stopifnot(all(diff(x$p_romano_wolf) >= -1e-12))
  }

  # HonestDiD: the unadjusted set and the five M-bar values per model, bounds widening.
  # A model that cannot be bounded (no estimated pre-reform event time) is one row
  # carrying that status instead.
  stopifnot(setequal(key7(hdo), used), all(hdo$mbar[!is.na(hdo$mbar)] %in% c(0, 0.5, 1, 1.5, 2)))
  for (m in unique(key7(hdo))) {
    x <- hdo[key7(hdo) == m, ]
    if (nrow(x) == 1L) {
      stopifnot(x$status != "ok", is.na(x$mbar), is.na(x$lb), is.na(x$ub))
    } else {
      stopifnot(nrow(x) == 6L, sum(is.na(x$mbar)) == 1L, x$method[1] == "original",
                setequal(x$mbar[!is.na(x$mbar)], c(0, 0.5, 1, 1.5, 2)),
                all(is.finite(x$lb[x$status == "ok"])), all(is.na(x$lb[x$status != "ok"])))
      y <- x[!is.na(x$mbar) & x$status == "ok", ]
      y <- y[order(y$mbar), ]
      if (nrow(y) > 1) stopifnot(all(y$lb <= y$ub), all(diff(y$lb) <= 1e-8), all(diff(y$ub) >= -1e-8))
    }
  }

  # randomization inference: the p-value is the one the saved draws give
  stopifnot(setequal(key7(ro), used), all(ro$draws_ok <= ro$reps), all(ro$p_value > 0),
            all(ro$p_value <= 1), all(ro$treated_states >= 1), all(ro$eligible_states > ro$treated_states),
            all(ro$reps == se7$value[se7$setting == "randomization_reps"]))
  for (m in unique(key7(ro))) {
    v <- rdw$att[key7(rdw) == m]
    v <- v[!is.na(v)]
    r <- ro[key7(ro) == m, ]
    stopifnot(length(v) == r$draws_ok, near(r$p_value, ri_pvalue(v, r$att), 1e-10))
  }
  # the settings file records the counts this run used
  stopifnot(all(c("bootstrap_reps", "randomization_reps", "romano_wolf_reps", "quick_run", "master_seed") %in%
                  se7$setting), se7$value[se7$setting == "master_seed"] == as.character(MASTER_SEED),
            se7$value[se7$setting == "romano_wolf_reps"] == se7$value[se7$setting == "bootstrap_reps"])
}

# Inference (design document, Section 8). Helpers used by R/07_inference.R on the
# Callaway-Sant'Anna fits of step 5 (outputs/05_primary/cs_models.rds).
#
# Author decisions 2026-09-11 (docs/decision_log.md):
#   Wild cluster bootstrap. Section 8 names fwildclusterboot, whose boottest() takes an
#   lm or fixest object. The primary estimate is neither: did::att_gt aggregates
#   group-time effects and is not a regression coefficient. The Webb-weight bootstrap
#   therefore runs on the estimator's own influence function. did returns one
#   influence-function row per unit; the rows are summed within state (the cluster) and
#   each replication multiplies every state's sum by an independent Webb weight. This is
#   did's own multiplier bootstrap with Webb weights in place of Mammen's, and the
#   p-value is read off the draws. The same draws serve every model of an event set, so
#   the Romano-Wolf step-down over the three gaps uses one set of state-level weights,
#   which is how wildrwolf induces the dependence across equations.
#   Randomization inference. The cohort years observed among the treated states are
#   reassigned at random among every state in the model's panel (all are eligible: never
#   treated, treated after the window, or treated within it), keeping the number of
#   states per cohort year. The estimator is rerun on each reassignment.
#   Romano-Wolf. The family is the three gaps within an event set. The primary family
#   takes the unweighted model of each gap; the robustness family takes the
#   tested-count-weighted models of gaps (b) and (c) with gap (a), a state-level
#   outcome, unweighted in both.
#   HonestDiD. Relative magnitudes on the overall post-reform average: l_vec puts equal
#   weight on every estimated post-reform event time, which is did::aggte's overall.
#
# Nothing here prints a treatment year (CLAUDE.md rule 7): the cohort years enter
# ri_overall() as values to permute and are never returned or logged.

# Webb's six-point distribution: mean 0, variance 1 (MacKinnon and Webb 2018).
WEBB_SUPPORT <- sort(c(-sqrt(c(1.5, 1, 0.5)), sqrt(c(1.5, 1, 0.5))))
BOOT_LEVEL   <- 0.95   # two-sided level of the bootstrap critical value

# reps x clusters matrix of Webb weights. The caller seeds with seed_for().
webb_weights <- function(n_clusters, reps)
  matrix(sample(WEBB_SUPPORT, reps * n_clusters, replace = TRUE), nrow = reps, ncol = n_clusters)

# Influence function of one step 5 fit, by cluster.
# did stores one influence-function row per unit (gt$n rows, in the order of
# DIDparams$cluster_vector, which holds each row's state). aggte carries the influence
# function of the dynamic aggregation: dynamic.inf.func.e has one column per event time
# in egt, dynamic.inf.func one column for the overall post-reform average.
# Returns the state sums of each column (states x column matrix), so that the
# estimate's clustered standard error is sqrt(sum(scores^2)) / n.
cs_influence <- function(fit) {
  if (is.null(fit) || is.null(fit$att_gt) || is.null(fit$aggte)) return(NULL)
  gt <- fit$att_gt; es <- fit$aggte
  inf <- es$inf.function
  if (is.null(inf) || is.null(inf$dynamic.inf.func.e) || is.null(inf$dynamic.inf.func)) return(NULL)
  cl <- as.character(gt$DIDparams$cluster_vector)
  n <- as.integer(gt$n)
  dyn <- as.matrix(inf$dynamic.inf.func.e)
  ov <- as.matrix(inf$dynamic.inf.func)[, 1]
  if (length(cl) != n || nrow(dyn) != n || length(ov) != n) return(NULL)
  if (ncol(dyn) != length(es$egt)) return(NULL)
  psi <- cbind(dyn, overall = ov)
  colnames(psi) <- c(paste0("e", es$egt), "overall")
  scores <- rowsum(psi, cl)                       # states x columns, rows named by state
  list(n = n, states = rownames(scores), scores = scores, egt = as.integer(es$egt),
       att_egt = es$att.egt, se_egt = es$se.egt, overall_att = es$overall.att,
       overall_se = es$overall.se, min_e = es$min_e, max_e = es$max_e)
}

# Clustered standard error of an estimate from the state sums of its influence function.
cluster_se <- function(scores, n) sqrt(sum(scores^2)) / n

# One wild cluster bootstrap test of H0: estimate = 0.
# scores: the estimate's influence function summed within state; w: reps x states Webb
# weights in the same state order. The bootstrap recentres on zero, so the draws are the
# distribution of the estimate under the null. The p-value is the share of draws at
# least as far from zero as the estimate, with the usual (1 + count) / (reps + 1)
# correction; the critical value is the BOOT_LEVEL quantile of |t*|.
# Returns the summary row and the bootstrap t-statistics (for the Romano-Wolf step-down).
wcb_test <- function(att, scores, n, w) {
  reps <- nrow(w)
  se <- cluster_se(scores, n)
  empty <- data.frame(att = att, se = NA_real_, boot_se = NA_real_, t = NA_real_, crit_val = NA_real_,
                      ci_lo = NA_real_, ci_hi = NA_real_, p_value = NA_real_, reps = reps,
                      clusters = length(scores))
  if (!is.finite(att) || !is.finite(se) || se <= 0) return(list(row = empty, t_boot = rep(NA_real_, reps)))
  draws <- as.vector(w %*% scores) / n
  t_obs <- att / se
  t_boot <- draws / se
  crit <- unname(stats::quantile(abs(t_boot), BOOT_LEVEL, names = FALSE))
  row <- data.frame(att = att, se = se, boot_se = stats::sd(draws), t = t_obs, crit_val = crit,
                    ci_lo = att - crit * se, ci_hi = att + crit * se,
                    p_value = (1 + sum(abs(t_boot) >= abs(t_obs))) / (reps + 1),
                    reps = reps, clusters = length(scores))
  list(row = row, t_boot = t_boot)
}

# Romano and Wolf (2005) step-down adjustment over a family of hypotheses tested on
# common bootstrap draws. t_obs: one observed t per hypothesis; t_boot: reps x
# hypotheses. Hypotheses are ordered by |t|; at each step the maximum |t*| over the
# hypotheses not yet rejected gives the p-value, and the sequence is made monotone.
rw_stepdown <- function(t_obs, t_boot) {
  k <- length(t_obs)
  stopifnot(ncol(t_boot) == k, k >= 1L)
  reps <- nrow(t_boot)
  a_obs <- abs(t_obs)
  a_boot <- abs(t_boot)
  ord <- order(a_obs, decreasing = TRUE, na.last = TRUE)
  p <- rep(NA_real_, k)
  prev <- 0
  for (i in seq_len(k)) {
    j <- ord[i]
    if (!is.finite(a_obs[j])) next
    rest <- ord[i:k]
    rest <- rest[apply(a_boot[, rest, drop = FALSE], 2, function(z) all(is.finite(z)))]
    if (!length(rest)) next
    mx <- do.call(pmax, as.data.frame(a_boot[, rest, drop = FALSE]))
    prev <- max(prev, (1 + sum(mx >= a_obs[j])) / (reps + 1))
    p[j] <- prev
  }
  p
}

# The panel and estimator settings of a step 5 fit, for refitting under randomization
# inference. did keeps the estimation data (with its normalised weight column .w) and
# the formula in DIDparams, so the reassignments run on exactly the step 5 panel.
# did rewrites the cohort column of that copy: every unit carries a positive value and
# the states not treated within the window are moved to a single value beyond the last
# window year, which is the same thing as g = 0 over this window. Mapping those back to
# 0 restores the step 5 coding; tests/test_inference.R checks the restored panel by
# refitting it and comparing with the step 5 estimate.
# allow_unbalanced: did clears DIDparams$panel when it accepts an unbalanced panel (it
# keeps true_repeated_cross_sections FALSE, which is what separates that case from a
# genuine repeated cross-section), so the refit has to set allow_unbalanced_panel again.
cs_panel <- function(fit) {
  dp <- fit$att_gt$DIDparams
  d <- dp$data
  if (".rowid" %in% names(d)) d$.rowid <- NULL     # did rebuilds its own row id
  allow_unbalanced <- !isTRUE(dp$panel) && !isTRUE(dp$true_repeated_cross_sections)
  d[[dp$gname]] <- ifelse(d[[dp$gname]] > max(d[[dp$tname]]), 0, d[[dp$gname]])
  # did reserves the column name .w for the weights it builds and refuses a panel that
  # already has one, so the stored weights move to a column of our own.
  wn <- NULL
  if (!is.null(d$.w) && any(d$.w != 1)) {
    d$ri_weight <- d$.w
    wn <- "ri_weight"
  }
  d$.w <- NULL
  list(panel = d, xformla = dp$xformla, weightsname = wn, allow_unbalanced = allow_unbalanced,
       min_e = fit$aggte$min_e, max_e = fit$aggte$max_e)
}

# One Callaway-Sant'Anna overall post-reform average, refit on a panel whose cohort
# variable has been replaced. Point estimate only: randomization inference needs no
# standard error, so the multiplier bootstrap is switched off.
cs_overall <- function(panel, xformla, weightsname, min_e, max_e, allow_unbalanced = FALSE) {
  suppressWarnings(suppressMessages(tryCatch({
    gt <- did::att_gt(yname = "y", tname = "sy_end", idname = "id", gname = "g", data = panel,
                      xformla = xformla, weightsname = weightsname, control_group = "notyettreated",
                      est_method = "dr", base_period = "universal", clustervars = "state",
                      bstrap = FALSE, cband = FALSE, allow_unbalanced_panel = allow_unbalanced)
    es <- did::aggte(gt, type = "dynamic", min_e = min_e, max_e = max_e, na.rm = TRUE,
                     bstrap = FALSE, cband = FALSE)
    as.numeric(es$overall.att)
  }, error = function(e) NA_real_)))
}

# Randomization inference on the overall post-reform average.
# The cohort years of the treated states are reassigned among every state in the panel,
# keeping the number of states per cohort year, and the estimator is rerun. The
# reassignments are drawn in this process from seed_for(seed_step) and then handed to
# the workers, so the draws do not depend on how many workers run them.
# Returns the placebo estimates and the two-sided p-value: the share of reassignments
# whose estimate is at least as far from zero as the observed one.
ri_overall <- function(fit, reps, seed_step, parallel = TRUE) {
  cp <- cs_panel(fit)
  panel <- cp$panel
  att <- fit$aggte$overall.att
  states <- sort(unique(panel$state))
  g_state <- vapply(split(panel$g, panel$state), function(z) z[1], numeric(1))
  gs <- unname(g_state[g_state > 0])
  if (!length(gs) || length(states) <= length(gs))
    return(list(status = "no reassignment possible", p_value = NA_real_, values = numeric(),
                reps = reps, draws_ok = 0L, treated_states = length(gs), eligible_states = length(states)))
  set.seed(seed_for(seed_step))
  picks <- lapply(seq_len(reps), function(b) states[sample.int(length(states), length(gs))])
  one <- function(pick) {
    g <- stats::setNames(rep(0, length(states)), states)
    g[pick] <- gs
    p <- panel
    p$g <- unname(g[p$state])
    cs_overall(p, cp$xformla, cp$weightsname, cp$min_e, cp$max_e, cp$allow_unbalanced)
  }
  vals <- if (parallel && requireNamespace("furrr", quietly = TRUE))
    furrr::future_map_dbl(picks, one, .options = furrr::furrr_options(seed = seed_for(paste(seed_step, "workers"))))
  else vapply(picks, one, numeric(1))
  ok <- is.finite(vals)
  p <- if (!any(ok) || !is.finite(att)) NA_real_ else (1 + sum(abs(vals[ok]) >= abs(att))) / (sum(ok) + 1)
  list(status = if (any(ok)) "ok" else "every reassignment failed", p_value = p, values = vals,
       reps = reps, draws_ok = sum(ok), treated_states = length(gs), eligible_states = length(states))
}

# Rambachan and Roth (2023) relative-magnitudes bounds on the overall post-reform
# average. The event-time estimates enter as betahat with the reference period dropped
# and their state-clustered covariance as sigma; l_vec puts equal weight on every
# estimated post-reform event time, so the bounded quantity is the step 5 overall.
# Mbar = 0 allows no post-reform violation of parallel trends and is the tightest bound;
# each Mbar is called on its own so that one failure does not lose the others.
# Returns one row per Mbar plus the unadjusted confidence set (mbar NA, method original).
honest_rm <- function(inf, mbarvec, alpha = 1 - BOOT_LEVEL) {
  fail <- function(status) data.frame(mbar = NA_real_, lb = NA_real_, ub = NA_real_,
                                      method = NA_character_, status = status,
                                      num_pre = NA_integer_, num_post = NA_integer_,
                                      stringsAsFactors = FALSE)
  if (is.null(inf)) return(fail("no influence function"))
  keep <- inf$egt != -1L & is.finite(inf$att_egt) & is.finite(inf$se_egt)
  e <- inf$egt[keep]
  num_pre <- sum(e < 0L); num_post <- sum(e >= 0L)
  if (!num_post) return(fail("no estimated post-reform event time"))
  if (!num_pre) return(fail("no estimated pre-reform event time: relative magnitudes need one"))
  # HonestDiD reads betahat as consecutive periods with the reference period left out,
  # so the pre-reform event times run to -2 and the post-reform ones from 0.
  if (!identical(e, c(seq.int(-num_pre - 1L, -2L), seq.int(0L, num_post - 1L))))
    return(fail("event times are not consecutive around the reference period"))
  betahat <- as.numeric(inf$att_egt[keep])
  sigma <- crossprod(inf$scores[, which(keep), drop = FALSE]) / inf$n^2
  sigma <- (sigma + t(sigma)) / 2                      # symmetric up to rounding
  dimnames(sigma) <- NULL
  l_vec <- matrix(rep(1 / num_post, num_post), ncol = 1)
  row <- function(mbar, lb, ub, method, status)
    data.frame(mbar = mbar, lb = lb, ub = ub, method = method, status = status,
               num_pre = as.integer(num_pre), num_post = as.integer(num_post), stringsAsFactors = FALSE)
  # HonestDiD searches a grid and returns an empty interval (lower bound Inf, upper
  # bound -Inf, with a warning from min() and max() on an empty set) when no value on
  # the grid is accepted. That is an empty bound set, not a bound, so it is recorded as
  # one rather than passed on as a pair of infinities.
  bounded <- function(m, lb, ub, method) {
    if (!is.finite(lb) || !is.finite(ub) || lb > ub)
      return(row(m, NA_real_, NA_real_, method, "empty bound set: no value on the grid was accepted"))
    row(m, lb, ub, method, "ok")
  }
  out <- lapply(mbarvec, function(m) tryCatch({
    r <- HonestDiD::createSensitivityResults_relativeMagnitudes(
      betahat = betahat, sigma = sigma, numPrePeriods = num_pre, numPostPeriods = num_post,
      l_vec = l_vec, Mbarvec = m, alpha = alpha)
    bounded(m, as.numeric(r$lb)[1], as.numeric(r$ub)[1], as.character(r$method)[1])
  }, error = function(e) row(m, NA_real_, NA_real_, NA_character_, paste("error:", conditionMessage(e)))))
  orig <- tryCatch({
    r <- HonestDiD::constructOriginalCS(betahat = betahat, sigma = sigma, numPrePeriods = num_pre,
                                        numPostPeriods = num_post, l_vec = l_vec, alpha = alpha)
    bounded(NA_real_, as.numeric(r$lb)[1], as.numeric(r$ub)[1], "original")
  }, error = function(e) row(NA_real_, NA_real_, NA_real_, "original", paste("error:", conditionMessage(e))))
  res <- do.call(rbind, c(list(orig), out))
  rownames(res) <- NULL
  res
}

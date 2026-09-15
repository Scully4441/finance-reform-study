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
       min_e = fit$aggte$min_e, max_e = fit$aggte$max_e,
       anticipation = if (is.null(dp$anticipation)) 0L else as.integer(dp$anticipation))
}

# One Callaway-Sant'Anna overall post-reform average, refit on a panel whose cohort
# variable has been replaced. Point estimate only: randomization inference needs no
# standard error, so the multiplier bootstrap is switched off.
cs_overall <- function(panel, xformla, weightsname, min_e, max_e, allow_unbalanced = FALSE,
                       anticipation = 0L) {
  suppressWarnings(suppressMessages(tryCatch({
    gt <- did::att_gt(yname = "y", tname = "sy_end", idname = "id", gname = "g", data = panel,
                      xformla = xformla, weightsname = weightsname, control_group = "notyettreated",
                      est_method = "dr", base_period = "universal", clustervars = "state",
                      bstrap = FALSE, cband = FALSE, allow_unbalanced_panel = allow_unbalanced,
                      anticipation = anticipation)
    es <- did::aggte(gt, type = "dynamic", min_e = min_e, max_e = max_e, na.rm = TRUE,
                     bstrap = FALSE, cband = FALSE)
    as.numeric(es$overall.att)
  }, error = function(e) NA_real_)))
}

# Two-sided randomization p-value: (1 + the placebo estimates at least as far from zero as
# the observed one) / (draws + 1). A reassignment that reproduces the observed treated
# states gives the observed estimate again, but a refit can land a floating-point hair
# below it; such ties count as at least as far, so the comparison allows a relative
# tolerance of 1e-9 (far below any estimate's precision). vals: finite placebo estimates.
RI_TIE_TOL <- 1e-9
ri_pvalue <- function(vals, att) {
  (1 + sum(abs(vals) >= abs(att) - RI_TIE_TOL * max(1, abs(att)))) / (length(vals) + 1)
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
    cs_overall(p, cp$xformla, cp$weightsname, cp$min_e, cp$max_e, cp$allow_unbalanced, cp$anticipation)
  }
  vals <- if (parallel && requireNamespace("furrr", quietly = TRUE))
    furrr::future_map_dbl(picks, one, .options = furrr::furrr_options(seed = seed_for(paste(seed_step, "workers"))))
  else vapply(picks, one, numeric(1))
  ok <- is.finite(vals)
  p <- if (!any(ok) || !is.finite(att)) NA_real_ else ri_pvalue(vals[ok], att)
  list(status = if (any(ok)) "ok" else "every reassignment failed", p_value = p, values = vals,
       reps = reps, draws_ok = sum(ok), treated_states = length(gs), eligible_states = length(states))
}

# Rambachan and Roth (2023) relative-magnitudes bounds on the overall post-reform
# average. The event-time estimates enter as betahat with the reference period dropped
# and their state-clustered covariance as sigma; l_vec puts equal weight on every
# estimated post-reform event time, so the bounded quantity is the step 5 overall.
# Mbar = 0 allows no post-reform violation of parallel trends and is the tightest bound;
# each Mbar is called on its own so that one failure does not lose the others.
# ref: the reference event time. -1 in the registered models; -2 under anticipation = 1
# (step 10), where event time -1 enters HonestDiD as a post-reference period with zero
# weight in l_vec, so the bounded quantity is still the mean of event times 0..+8.
# Search grid (code correction 2026-09-14, docs/deviations.md). HonestDiD reports a bound
# set as the lowest and highest accepted point of a grid it builds, by default 1,000 points
# over +/- 20 standard deviations of the bounded quantity, so a set wider than the grid
# comes back cut at the grid edge. Each Mbar therefore starts on that default grid and, while
# its lower (upper) bound sits within half a step of the grid's lower (upper) edge, the grid
# is widened on that side by its current width, with points added to keep the step
# unchanged, up to HONEST_GRID_MAX_WIDEN times. A set still at an edge after that is
# recorded with a status and no bound. Every Mbar row carries the grid it was read from.
HONEST_GRID_SD <- 20
HONEST_GRID_POINTS <- 1000L
HONEST_GRID_MAX_WIDEN <- 6L
# Returns one row per Mbar plus the unadjusted confidence set (mbar NA, method original).
honest_rm <- function(inf, mbarvec, alpha = 1 - BOOT_LEVEL, ref = -1L) {
  fail <- function(status) data.frame(mbar = NA_real_, lb = NA_real_, ub = NA_real_,
                                      method = NA_character_, status = status,
                                      num_pre = NA_integer_, num_post = NA_integer_,
                                      grid_lb = NA_real_, grid_ub = NA_real_, grid_points = NA_integer_,
                                      stringsAsFactors = FALSE)
  if (is.null(inf)) return(fail("no influence function"))
  ref <- as.integer(ref)
  keep <- inf$egt != ref & is.finite(inf$att_egt) & is.finite(inf$se_egt)
  e <- inf$egt[keep]
  num_pre <- sum(e < ref); num_post <- sum(e > ref)
  if (!sum(e >= 0L)) return(fail("no estimated post-reform event time"))
  if (!num_pre) return(fail("no estimated pre-reform event time: relative magnitudes need one"))
  # HonestDiD reads betahat as consecutive periods with the reference period left out,
  # so the pre-reform event times run to ref - 1 and the later ones from ref + 1.
  if (!identical(e, c(seq.int(ref - num_pre, ref - 1L), seq.int(ref + 1L, ref + num_post))))
    return(fail("event times are not consecutive around the reference period"))
  betahat <- as.numeric(inf$att_egt[keep])
  sigma <- crossprod(inf$scores[, which(keep), drop = FALSE]) / inf$n^2
  sigma <- (sigma + t(sigma)) / 2                      # symmetric up to rounding
  dimnames(sigma) <- NULL
  post_e <- e[e > ref]
  l_vec <- matrix(ifelse(post_e >= 0L, 1 / sum(post_e >= 0L), 0), ncol = 1)
  row <- function(mbar, lb, ub, method, status, grid = c(NA_real_, NA_real_, NA_real_))
    data.frame(mbar = mbar, lb = lb, ub = ub, method = method, status = status,
               num_pre = as.integer(num_pre), num_post = as.integer(num_post),
               grid_lb = grid[1], grid_ub = grid[2], grid_points = as.integer(grid[3]), stringsAsFactors = FALSE)
  # HonestDiD searches a grid and returns an empty interval (lower bound Inf, upper
  # bound -Inf, with a warning from min() and max() on an empty set) when no value on
  # the grid is accepted. That is an empty bound set, not a bound, so it is recorded as
  # one rather than passed on as a pair of infinities.
  bounded <- function(m, lb, ub, method, grid = c(NA_real_, NA_real_, NA_real_)) {
    if (!is.finite(lb) || !is.finite(ub) || lb > ub)
      return(row(m, NA_real_, NA_real_, method, "empty bound set: no value on the grid was accepted", grid))
    row(m, lb, ub, method, "ok", grid)
  }
  # HonestDiD's default grid: +/- HONEST_GRID_SD standard deviations of l_vec' betahat_post
  post <- seq.int(num_pre + 1L, num_pre + num_post)
  sd_theta <- sqrt(as.numeric(t(l_vec) %*% sigma[post, post, drop = FALSE] %*% l_vec))
  step <- 2 * HONEST_GRID_SD * sd_theta / (HONEST_GRID_POINTS - 1L)
  out <- lapply(mbarvec, function(m) tryCatch({
    glb <- -HONEST_GRID_SD * sd_theta; gub <- HONEST_GRID_SD * sd_theta
    for (k in 0:HONEST_GRID_MAX_WIDEN) {
      pts <- as.integer(round((gub - glb) / step)) + 1L
      grid <- c(glb, gub, pts)
      r <- HonestDiD::createSensitivityResults_relativeMagnitudes(
        betahat = betahat, sigma = sigma, numPrePeriods = num_pre, numPostPeriods = num_post,
        l_vec = l_vec, Mbarvec = m, alpha = alpha, gridPoints = pts, grid.lb = glb, grid.ub = gub)
      res <- bounded(m, as.numeric(r$lb)[1], as.numeric(r$ub)[1], as.character(r$method)[1], grid)
      if (res$status != "ok") return(res)
      tol <- (gub - glb) / (pts - 1L) / 2
      lo_edge <- res$lb <= glb + tol; hi_edge <- res$ub >= gub - tol
      if (!lo_edge && !hi_edge) return(res)
      if (k == HONEST_GRID_MAX_WIDEN)
        return(row(m, NA_real_, NA_real_, res$method,
                   sprintf("bound set reaches the grid edge after %d widenings (grid %.4g to %.4g)", k, glb, gub), grid))
      w <- gub - glb
      if (lo_edge) glb <- glb - w
      if (hi_edge) gub <- gub + w
    }
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

# ---- reduced event-time block (post-freeze inference correction 2026-09-15, docs/deviations.md) ----
# A model whose estimated event times have a hole around the reference period gets
# "event times are not consecutive around the reference period" from honest_rm(). For such a
# model the bound sets are computed on the largest consecutive block of estimated event times
# that contains the reference period and event time 0, with the post-reform average over the
# block's post-periods (honest_rm() on the influence function restricted to the block; the
# estimates themselves are unchanged). No block with event time 0, or no pre-period in the
# block beyond the reference, leaves the status.

# The block: estimated event times (finite estimate and standard error) plus the reference,
# the maximal run of consecutive integers through the reference. NULL when 0 is not in it.
honest_block_range <- function(inf, ref = -1L) {
  est <- inf$egt[inf$egt != ref & is.finite(inf$att_egt) & is.finite(inf$se_egt)]
  have <- sort(unique(c(as.integer(est), as.integer(ref))))
  lo <- ref; while ((lo - 1L) %in% have) lo <- lo - 1L
  hi <- ref; while ((hi + 1L) %in% have) hi <- hi + 1L
  if (hi < 0L) return(NULL)
  c(lo, hi)
}

# The influence function restricted to the event times lo..hi (the overall column is kept
# but not used by honest_rm()).
honest_block_inf <- function(inf, lo, hi) {
  j <- which(inf$egt >= lo & inf$egt <= hi)
  out <- inf
  out$egt <- inf$egt[j]; out$att_egt <- inf$att_egt[j]; out$se_egt <- inf$se_egt[j]
  out$scores <- inf$scores[, c(j, which(colnames(inf$scores) == "overall")), drop = FALSE]
  out
}

# Bound sets on the block. Returns the honest_rm() rows with the block recorded, or the
# original status row with the block and the reason no bound was computed.
honest_block <- function(inf, mbarvec, ref = -1L,
                         status = "event times are not consecutive around the reference period") {
  keep_status <- function(block, why) data.frame(mbar = NA_real_, lb = NA_real_, ub = NA_real_, method = NA_character_,
    status = status, num_pre = NA_integer_, num_post = NA_integer_, grid_lb = NA_real_, grid_ub = NA_real_,
    grid_points = NA_integer_, event_block = block, event_block_note = why, stringsAsFactors = FALSE)
  if (is.null(inf)) stop("honest_block: no influence function")
  b <- honest_block_range(inf, ref)
  if (is.null(b)) return(keep_status(NA_character_, "no consecutive block through the reference period reaches event time 0"))
  blk <- sprintf("%+d..%+d", b[1], b[2])
  if (b[1] >= ref) return(keep_status(blk, "the block has no pre-reform event time beyond the reference period"))
  h <- honest_rm(honest_block_inf(inf, b[1], b[2]), mbarvec, ref = ref)
  h$event_block <- blk
  h$event_block_note <- sprintf("bound on event times %s; post-reform average over event times 0..%+d", blk, b[2])
  h
}

# Why each event time inside the estimated span (and not estimated) is missing. fit: a step 5
# or step 10 did fit; window: the outcome's window end years; ref: the reference period.
# For event time e: the model's treated cohorts g with g + e inside the window's calendar span;
# "no cohort" when none; "no district-year" when those cohorts have no row in the estimation
# panel at year g + e (a year outside the window, such as 2020 for achievement, counts here);
# otherwise the group-time cells exist but are not estimable (the base-period year g - 1 - anticipation
# has no row, or no comparison units), recorded with the cohort cells.
event_time_gaps <- function(fit, window, ref = -1L) {
  inf <- cs_influence(fit)
  if (is.null(inf)) return(NULL)
  est <- sort(unique(c(inf$egt[is.finite(inf$att_egt) & is.finite(inf$se_egt)], ref)))
  span <- seq.int(max(EVENT_MIN, min(est)), min(EVENT_MAX, max(est)))
  miss <- setdiff(span, est)
  if (!length(miss)) return(NULL)
  cp <- cs_panel(fit); p <- cp$panel
  unit_word <- if (length(unique(p$id)) == length(unique(p$state))) "state-year" else "district-year"
  cohorts <- sort(unique(p$g[p$g > 0]))
  gt <- fit$att_gt
  do.call(rbind, lapply(miss, function(e) {
    cg <- cohorts[(cohorts + e) >= min(window) & (cohorts + e) <= max(window)]
    if (!length(cg)) return(data.frame(event_time = e, reason = "no cohort",
      detail = "no treated cohort reaches this event time within the window", stringsAsFactors = FALSE))
    rows <- vapply(cg, function(g) sum(p$g == g & p$sy_end == g + e), 0)
    if (!any(rows > 0)) return(data.frame(event_time = e, reason = paste("no", unit_word),
      detail = paste0("cohort-years with no ", unit_word, " in the panel: ",
                      paste0(cg, " at ", cg + e, ifelse((cg + e) %in% window, "", " (outside the window)"), collapse = "; ")),
      stringsAsFactors = FALSE))
    base <- cg - 1L - cp$anticipation
    base_rows <- vapply(seq_along(cg), function(i) sum(p$g == cg[i] & p$sy_end == base[i]), 0)
    data.frame(event_time = e, reason = "not estimable",
      detail = paste0(unit_word, "s present but no estimable group-time cell: ",
        paste0("cohort ", cg, " at ", cg + e, " (", rows, " rows; base year ", base, ": ", base_rows, " rows)", collapse = "; ")),
      stringsAsFactors = FALSE)
  }))
}

WEBB_SUPPORT <- sort(c(-sqrt(c(1.5, 1, 0.5)), sqrt(c(1.5, 1, 0.5))))
BOOT_LEVEL   <- 0.95

webb_weights <- function(n_clusters, reps)
  matrix(sample(WEBB_SUPPORT, reps * n_clusters, replace = TRUE), nrow = reps, ncol = n_clusters)

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
  scores <- rowsum(psi, cl)
  list(n = n, states = rownames(scores), scores = scores, egt = as.integer(es$egt),
       att_egt = es$att.egt, se_egt = es$se.egt, overall_att = es$overall.att,
       overall_se = es$overall.se, min_e = es$min_e, max_e = es$max_e)
}

cluster_se <- function(scores, n) sqrt(sum(scores^2)) / n

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

cs_panel <- function(fit) {
  dp <- fit$att_gt$DIDparams
  d <- dp$data
  if (".rowid" %in% names(d)) d$.rowid <- NULL
  allow_unbalanced <- !isTRUE(dp$panel) && !isTRUE(dp$true_repeated_cross_sections)
  d[[dp$gname]] <- ifelse(d[[dp$gname]] > max(d[[dp$tname]]), 0, d[[dp$gname]])
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

RI_TIE_TOL <- 1e-9
ri_pvalue <- function(vals, att) {
  (1 + sum(abs(vals) >= abs(att) - RI_TIE_TOL * max(1, abs(att)))) / (length(vals) + 1)
}

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

HONEST_GRID_SD <- 20
HONEST_GRID_POINTS <- 1000L
HONEST_GRID_MAX_WIDEN <- 6L
honest_rm <- function(inf, mbarvec, alpha = 1 - BOOT_LEVEL, ref = -1L, weights = NULL) {
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
  if (!identical(e, c(seq.int(ref - num_pre, ref - 1L), seq.int(ref + 1L, ref + num_post))))
    return(fail("event times are not consecutive around the reference period"))
  betahat <- as.numeric(inf$att_egt[keep])
  sigma <- crossprod(inf$scores[, which(keep), drop = FALSE]) / inf$n^2
  sigma <- (sigma + t(sigma)) / 2
  dimnames(sigma) <- NULL
  post_e <- e[e > ref]
  lw <- if (is.null(weights)) ifelse(post_e >= 0L, 1 / sum(post_e >= 0L), 0) else weights(post_e)
  if (is.null(lw)) return(fail("growth contrast: no estimated event time in one of the two windows"))
  l_vec <- matrix(lw, ncol = 1)
  row <- function(mbar, lb, ub, method, status, grid = c(NA_real_, NA_real_, NA_real_))
    data.frame(mbar = mbar, lb = lb, ub = ub, method = method, status = status,
               num_pre = as.integer(num_pre), num_post = as.integer(num_post),
               grid_lb = grid[1], grid_ub = grid[2], grid_points = as.integer(grid[3]), stringsAsFactors = FALSE)
  bounded <- function(m, lb, ub, method, grid = c(NA_real_, NA_real_, NA_real_)) {
    if (!is.finite(lb) || !is.finite(ub) || lb > ub)
      return(row(m, NA_real_, NA_real_, method, "empty bound set: no value on the grid was accepted", grid))
    row(m, lb, ub, method, "ok", grid)
  }
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


honest_block_range <- function(inf, ref = -1L) {
  est <- inf$egt[inf$egt != ref & is.finite(inf$att_egt) & is.finite(inf$se_egt)]
  have <- sort(unique(c(as.integer(est), as.integer(ref))))
  lo <- ref; while ((lo - 1L) %in% have) lo <- lo - 1L
  hi <- ref; while ((hi + 1L) %in% have) hi <- hi + 1L
  if (hi < 0L) return(NULL)
  c(lo, hi)
}

honest_block_inf <- function(inf, lo, hi) {
  j <- which(inf$egt >= lo & inf$egt <= hi)
  out <- inf
  out$egt <- inf$egt[j]; out$att_egt <- inf$att_egt[j]; out$se_egt <- inf$se_egt[j]
  out$scores <- inf$scores[, c(j, which(colnames(inf$scores) == "overall")), drop = FALSE]
  out
}

honest_block <- function(inf, mbarvec, ref = -1L,
                         status = "event times are not consecutive around the reference period", weights = NULL) {
  keep_status <- function(block, why) data.frame(mbar = NA_real_, lb = NA_real_, ub = NA_real_, method = NA_character_,
    status = status, num_pre = NA_integer_, num_post = NA_integer_, grid_lb = NA_real_, grid_ub = NA_real_,
    grid_points = NA_integer_, event_block = block, event_block_note = why, stringsAsFactors = FALSE)
  if (is.null(inf)) stop("honest_block: no influence function")
  b <- honest_block_range(inf, ref)
  if (is.null(b)) return(keep_status(NA_character_, "no consecutive block through the reference period reaches event time 0"))
  blk <- sprintf("%+d..%+d", b[1], b[2])
  if (b[1] >= ref) return(keep_status(blk, "the block has no pre-reform event time beyond the reference period"))
  h <- honest_rm(honest_block_inf(inf, b[1], b[2]), mbarvec, ref = ref, weights = weights)
  h$event_block <- blk
  h$event_block_note <- sprintf("bound on event times %s; post-reform average over event times 0..%+d", blk, b[2])
  h
}

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

GROWTH_EARLY <- 0:3
GROWTH_LATE <- 4:8

growth_weights <- function(e, early = GROWTH_EARLY, late = GROWTH_LATE) {
  ne <- sum(e %in% early); nl <- sum(e %in% late)
  if (!ne || !nl) return(NULL)
  ifelse(e %in% early, -1 / ne, ifelse(e %in% late, 1 / nl, 0))
}

growth_contrast <- function(inf, ref = -1L, early = GROWTH_EARLY, late = GROWTH_LATE) {
  if (is.null(inf)) return(NULL)
  ok <- inf$egt != ref & is.finite(inf$att_egt) & is.finite(inf$se_egt)
  e <- inf$egt[ok]
  w <- growth_weights(e, early, late)
  if (is.null(w)) return(NULL)
  cols <- paste0("e", e)
  list(estimate = sum(w * inf$att_egt[ok]), scores = as.vector(inf$scores[, cols, drop = FALSE] %*% w),
       early = e[e %in% early], late = e[e %in% late], n = inf$n)
}

growth_from_events <- function(e, att, early = GROWTH_EARLY, late = GROWTH_LATE) {
  ok <- is.finite(att)
  ee <- e[ok & e %in% early]; el <- e[ok & e %in% late]
  if (!length(ee) || !length(el)) return(NA_real_)
  mean(att[ok & e %in% late]) - mean(att[ok & e %in% early])
}

growth_cohorts <- function(fit, early = GROWTH_EARLY, late = GROWTH_LATE) {
  out <- data.frame(cohorts_early = NA_integer_, cohorts_late = NA_integer_, treated_states_early = NA_integer_,
                    treated_states_late = NA_integer_)
  if (is.null(fit) || is.null(fit$att_gt)) return(out)
  gt <- fit$att_gt
  e <- gt$t - gt$group
  ok <- is.finite(gt$att) & is.finite(gt$se)
  p <- cs_panel(fit)$panel
  st <- function(gs) length(unique(p$state[p$g %in% gs]))
  ge <- unique(gt$group[ok & e %in% early]); gl <- unique(gt$group[ok & e %in% late])
  data.frame(cohorts_early = length(ge), cohorts_late = length(gl), treated_states_early = st(ge),
             treated_states_late = st(gl))
}

growth_test <- function(inf, w, ref = -1L) {
  g <- growth_contrast(inf, ref)
  if (is.null(g)) return(NULL)
  b <- wcb_test(g$estimate, g$scores, g$n, w)
  b$row$early_event_times <- paste(g$early, collapse = " ")
  b$row$late_event_times <- paste(g$late, collapse = " ")
  b
}

honest_growth <- function(inf, mbarvec, ref = -1L) {
  h <- suppressWarnings(honest_rm(inf, mbarvec, ref = ref, weights = growth_weights))
  if (any(h$status %in% "event times are not consecutive around the reference period"))
    h <- suppressWarnings(honest_block(inf, mbarvec, ref = ref, weights = growth_weights))
  if (!"event_block" %in% names(h)) { h$event_block <- NA_character_; h$event_block_note <- NA_character_ }
  h
}

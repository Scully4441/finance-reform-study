# Secondary estimators (design document, Section 7) and two-way fixed effects for
# comparison only (Section 9). Helpers used by R/06_secondary.R on the step 5 panels
# (R/functions/primary.R: race_panel(), pov_panel(), attach_cohorts(), cs_covariates()).
# Each run_*() takes a panel with id (integer), state, sy_end, y and g (0 = not
# treated within the window) and returns the step 5 layout (run_cs()): status, notes,
# event (event times -5..+8 with the cohorts, treated states and treated units behind
# each coefficient), overall, cells (cohort-by-period estimates where the estimator
# gives them), fit, and size (units, states, cohorts and observations in the model).
# Author decisions 2026-09-11 (docs/decision_log.md):
#   Controls. The regression estimators (Sun-Abraham, imputation, stacked, TWFE) take
#   the test-replacement and CEP flags as time-varying controls for every gap and, for
#   gaps (b) and (c), the four 2009 covariates of step 5 interacted with year (the
#   unit fixed effects absorb their levels).
#   synthdid. State level, cohort by cohort, against the states not treated within the
#   window; gaps (b) and (c) are first averaged to state-year over the step 5 panel's
#   districts, unweighted. Event-time estimates pool the cohorts' effect curves by
#   treated states; the pooled ATT weights cohorts by treated state-years in post
#   periods (Clarke et al. 2023). Standard errors from placebo reassignment among the
#   control states. No controls.
#   Stacked. Each cohort's sub-experiment covers event times -5..+5; clean controls are
#   states untreated through g + 5; corrective weights (Wing, Freedman and
#   Hollingsworth 2024).
#   Overall post-reform average: the equal-weight mean of the event-time estimates from
#   0 to +8, as did::aggte's dynamic overall in step 5. Static TWFE is its own row.
# Standard errors are clustered by state (synthdid: placebo) and describe the
# estimates; inference for the study is step 7.

SEC_FLAGS    <- c("test_replaced", "cep")   # state-year controls from the step 3 sample file
STACK_PRE    <- 5L                          # stacked sub-experiment: event times -5..+5
STACK_POST   <- 5L
SDID_REPS    <- 200L                        # placebo replications (synthdid's default)
SDID_MIN_PRE <- 2L                          # synthdid's noise level needs two pre-reform years

# ---- inputs ------------------------------------------------------------------------

# State-year flags from data/derived/sample_district_year.csv: test_replaced (1 in the
# year either subject's high school test was replaced) and cep (CEP available in the
# state). Both are state-level, so there is one row per state-year.
state_flags <- function(smp, window) {
  x <- unique(smp[smp$sy_end %in% window, c("state", "sy_end", SEC_FLAGS)])
  if (anyDuplicated(x[c("state", "sy_end")])) stop("a flag differs across districts within a state-year")
  if (anyNA(x[SEC_FLAGS])) stop("flags missing for ", sum(!stats::complete.cases(x[SEC_FLAGS])), " state-years")
  rownames(x) <- NULL
  x
}

attach_flags <- function(panel, flags) {
  k <- match(paste(panel$state, panel$sy_end), paste(flags$state, flags$sy_end))
  if (anyNA(k)) stop("state-years without flags: ", paste(unique(paste(panel$state, panel$sy_end)[is.na(k)]), collapse = " "))
  panel[SEC_FLAGS] <- flags[k, SEC_FLAGS]
  panel
}

# Covariate-by-year columns cy_<covariate>_<year> = covariate * 1{sy_end == year} for
# every window year after the first; the unit fixed effects absorb the level.
add_cov_year <- function(panel, covs, window) {
  terms <- character()
  for (x in covs) for (t in sort(window)[-1]) {
    v <- paste0("cy_", x, "_", t)
    panel[[v]] <- panel[[x]] * as.numeric(panel$sy_end == t)
    terms <- c(terms, v)
  }
  list(panel = panel, terms = terms)
}

check_panel <- function(panel, cols = character()) {
  need <- c("id", "state", "sy_end", "y", "g", cols)
  miss <- setdiff(need, names(panel))
  if (length(miss)) stop("panel lacks columns: ", paste(miss, collapse = ", "))
  stopifnot(is.integer(panel$id), !anyNA(panel[need]), !anyDuplicated(panel[c("id", "sy_end")]))
}

# ---- results in the step 5 layout ----------------------------------------------------

event_template <- function(min_e = EVENT_MIN, max_e = EVENT_MAX, ref = TRUE)
  data.frame(e = min_e:max_e, att = NA_real_, se = NA_real_, crit_val = NA_real_, ci_lo = NA_real_,
             ci_hi = NA_real_, cohorts = 0L, treated_states = 0L, treated_units = 0L,
             reference = ref & (min_e:max_e) == -1L)

overall_template <- function()
  data.frame(att = NA_real_, se = NA_real_, ci_lo = NA_real_, ci_hi = NA_real_,
             cohorts = 0L, treated_states = 0L, treated_units = 0L)

empty_cells <- function() data.frame(g = integer(), t = integer(), e = integer(), att = numeric(), se = numeric())

empty_result <- function(status, notes = character(), ref = TRUE, min_e = EVENT_MIN, max_e = EVENT_MAX)
  list(status = status, notes = unique(notes), event = event_template(min_e, max_e, ref),
       overall = overall_template(), cells = empty_cells(), fit = NULL, size = NULL, pooled = NULL)

model_size <- function(d, treated, obs = nrow(d))
  data.frame(units_in_model = length(unique(d$id)), states_in_model = length(unique(d$state)),
             cohorts_in_model = length(unique(d$g[treated])), treated_units = length(unique(d$id[treated])),
             control_units = length(unique(d$id[!treated])), obs = as.integer(obs))

# Evaluate expr; warnings and messages become notes and an error is returned, not raised.
with_notes <- function(expr, drop = character()) {
  notes <- character()
  value <- tryCatch(withCallingHandlers(expr, warning = function(w) {
    notes <<- c(notes, trimws(conditionMessage(w))); invokeRestart("muffleWarning")
  }, message = function(m) {
    notes <<- c(notes, trimws(conditionMessage(m))); invokeRestart("muffleMessage")
  }), error = function(e) e)
  list(value = value, notes = setdiff(unique(notes), drop), failed = inherits(value, "error"))
}

collin_note <- function(fit)
  if (length(fit$collin.var)) paste("removed as collinear:", paste(fit$collin.var, collapse = ", "))

rhs <- function(...) {
  x <- c(...)
  paste(x[nzchar(x)], collapse = " + ")
}

# Cohorts, treated states and treated units with an observation at event times es.
counts_over <- function(d, es) {
  k <- d$g > 0L & (d$sy_end - d$g) %in% es
  c(cohorts = length(unique(d$g[k])), treated_states = length(unique(d$state[k])),
    treated_units = length(unique(d$id[k])))
}

# Equal-weight mean of the event-time estimates from 0 to max_e and its standard
# error from their covariance V.
post_mean <- function(e, b, V, max_e = EVENT_MAX) {
  k <- which(e >= 0L & e <= max_e & !is.na(b))
  if (!length(k)) return(list(att = NA_real_, se = NA_real_))
  a <- rep(1 / length(k), length(k))
  list(att = sum(a * b[k]), se = sqrt(drop(t(a) %*% V[k, k, drop = FALSE] %*% a)))
}

# Event and overall rows from event-time estimates est (e, att, se). counts: the
# treated rows behind the estimates (id, state, sy_end, g). ref: event time -1 is a
# normalised reference (att 0), as in step 5.
finish <- function(est, ov, counts, ref = TRUE, min_e = EVENT_MIN, max_e = EVENT_MAX) {
  ev <- event_template(min_e, max_e, ref)
  est <- est[!is.na(est$att) & est$e %in% ev$e & !(ref & est$e == -1L), , drop = FALSE]
  k <- match(est$e, ev$e)
  ev$att[k] <- est$att
  ev$se[k] <- est$se
  if (ref && counts_over(counts, -1L)[["cohorts"]] > 0) ev$att[ev$e == -1L] <- 0
  has <- !is.na(ev$att)
  cnt <- vapply(ev$e, function(e) counts_over(counts, e), numeric(3))
  ev$cohorts[has] <- as.integer(cnt[1, has])
  ev$treated_states[has] <- as.integer(cnt[2, has])
  ev$treated_units[has] <- as.integer(cnt[3, has])
  z <- stats::qnorm(1 - 0.05 / 2)
  ev$crit_val[!is.na(ev$se)] <- z
  ev$ci_lo <- ev$att - ev$crit_val * ev$se
  ev$ci_hi <- ev$att + ev$crit_val * ev$se
  pc <- counts_over(counts, ev$e[has & ev$e >= 0L])
  overall <- data.frame(att = ov$att, se = ov$se, ci_lo = ov$att - z * ov$se, ci_hi = ov$att + z * ov$se,
                        cohorts = as.integer(pc[["cohorts"]]), treated_states = as.integer(pc[["treated_states"]]),
                        treated_units = as.integer(pc[["treated_units"]]))
  list(event = ev, overall = overall)
}

ok_result <- function(fs, notes, cells, fit, size, pooled = NULL)
  list(status = "ok", notes = unique(notes), event = fs$event, overall = fs$overall, cells = cells,
       fit = fit, size = size, pooled = pooled)

# ---- Sun and Abraham (2021) ------------------------------------------------------------

# Cohort-by-relative-period indicators: the interaction matrix fixest::sunab() builds
# (its own code calls fixest::i() on these columns), constructed here rather than by
# calling sunab(). In fixest 0.14.2 sunab() takes a cohort whose treated units supply a
# single pre-treatment observation for an always-treated cohort: it drops that cohort's
# indicators and sets one unrelated row to NA. Gap (a), where a cohort is one state, is
# that case. The columns are the ones sunab() builds, so the estimator is unchanged;
# tests/test_secondary.R checks the two against each other wherever sunab() is sound and
# fails as a canary when fixest fixes the case.
# Never-treated rows (g = 0) and treated rows at the reference period are zero on every
# indicator, which is how sunab() keeps them in the sample as the comparison group.
sa_terms <- function(panel, ref_p = -1L) {
  rel <- panel$sy_end - panel$g
  k <- panel$g > 0L & rel != ref_p
  cells <- unique(data.frame(g = panel$g[k], e = rel[k]))
  cells <- cells[order(cells$g, cells$e), ]
  cells$term <- sprintf("sa_c%d_e%s", cells$g, sub("-", "m", cells$e))
  for (i in seq_len(nrow(cells)))
    panel[[cells$term[i]]] <- as.numeric(panel$g == cells$g[i] & rel == cells$e[i])
  rownames(cells) <- NULL
  list(panel = panel, cells = cells)
}

# Sun and Abraham (2021): the indicators above, with the never-treated states (g = 0:
# never treated, or treated after the window) as the comparison group and event time -1
# as the reference period. The cohort-by-period coefficients are aggregated with the
# interaction weights (each cohort's share of the treated observations at that event
# time), which also gives the covariance of the event-time estimates for the overall
# mean; fixest's own sunab aggregation gives the same point estimates
# (tests/test_secondary.R).
run_sunab <- function(panel, flags = character(), covs = character(), window,
                      min_e = EVENT_MIN, max_e = EVENT_MAX) {
  check_panel(panel, c(flags, covs))
  if (!any(panel$g > 0L)) return(empty_result("no estimable cohort"))
  cy <- add_cov_year(panel, covs, window)
  sa <- sa_terms(cy$panel)
  d <- sa$panel
  fml <- stats::as.formula(paste("y ~", rhs(sa$cells$term, flags, cy$terms), "| id + sy_end"))
  r <- with_notes(fixest::feols(fml, data = d, cluster = ~state))
  if (r$failed) return(empty_result(paste("error:", conditionMessage(r$value)), r$notes))
  fit <- r$value
  b <- stats::coef(fit); V <- stats::vcov(fit)
  notes <- c(r$notes, collin_note(fit))
  cc <- sa$cells
  idx <- match(cc$term, names(b))
  if (anyNA(idx)) {
    notes <- c(notes, sprintf("%d cohort-by-period term(s) not estimated and left out", sum(is.na(idx))))
    cc <- cc[!is.na(idx), ]
    idx <- idx[!is.na(idx)]
  }
  tr <- d[d$g > 0L, ]
  n_ge <- table(paste(tr$g, tr$sy_end - tr$g))
  cc$n <- as.numeric(n_ge[paste(cc$g, cc$e)])
  es <- sort(unique(cc$e))
  A <- matrix(0, length(es), length(b), dimnames = list(NULL, names(b)))
  for (i in seq_along(es)) {
    j <- cc$e == es[i]
    A[i, idx[j]] <- cc$n[j] / sum(cc$n[j])
  }
  be <- drop(A %*% b); Ve <- A %*% V %*% t(A)
  est <- data.frame(e = es, att = be, se = sqrt(diag(Ve)))
  fs <- finish(est, post_mean(es, be, Ve, max_e), d, ref = TRUE, min_e, max_e)
  cells <- data.frame(g = cc$g, t = cc$g + cc$e, e = cc$e, att = unname(b[idx]),
                      se = unname(sqrt(diag(V))[idx]))
  ok_result(fs, notes, cells, fit, model_size(d, d$g > 0L, stats::nobs(fit)))
}

# ---- Borusyak, Jaravel and Spiess (2024) -----------------------------------------------

# didimputation::did_imputation: unit and year fixed effects plus the controls fitted
# on untreated observations, then imputed for the treated. Estimands through custom
# weights (wtr), all in one call so their standard errors (clustered by state) come
# from the same fit: each event time 0..max_e; the overall mean of those event times
# (equal weight per event time, equal weight per treated observation within it); and
# each cohort-year cell. Pre-reform rows are the package's pre-trend coefficients for
# event times min_e..-2 on the untreated observations, with -1 omitted, so -1 is the
# reference as in step 5.
run_imputation <- function(panel, flags = character(), covs = character(), window,
                           min_e = EVENT_MIN, max_e = EVENT_MAX) {
  check_panel(panel, c(flags, covs))
  if (!any(panel$g > 0L)) return(empty_result("no estimable cohort"))
  cy <- add_cov_year(panel, covs, window)
  d <- cy$panel
  rel <- ifelse(d$g > 0L, d$sy_end - d$g, NA_integer_)
  post <- !is.na(rel) & rel >= 0L
  hs <- sort(unique(rel[post & rel <= max_e]))
  wtr <- paste0("wtr_e", hs)
  for (i in seq_along(hs)) d[[wtr[i]]] <- as.numeric(post & rel == hs[i])
  d$wtr_overall <- 0
  for (h in hs) {
    k <- post & rel == h
    d$wtr_overall[k] <- 1 / (sum(k) * length(hs))
  }
  cl <- unique(data.frame(g = d$g[post], t = d$sy_end[post]))
  cl <- cl[order(cl$g, cl$t), ]
  cl$term <- sprintf("wtr_g%d_t%d", cl$g, cl$t)
  for (i in seq_len(nrow(cl))) d[[cl$term[i]]] <- as.numeric(d$g == cl$g[i] & d$sy_end == cl$t[i])
  leads <- intersect(min_e:-2L, unique(rel[!is.na(rel)]))
  controls <- c(flags, cy$terms)
  first <- paste(if (length(controls)) paste(controls, collapse = " + ") else "0", "| id + sy_end")
  # didimputation sorts its output with as.numeric() on the term names, which warns for
  # the named weights; that warning is not a note.
  r <- with_notes(didimputation::did_imputation(d, yname = "y", gname = "g", tname = "sy_end", idname = "id",
                                                first_stage = first, wtr = c(wtr, "wtr_overall", cl$term),
                                                pretrends = if (length(leads)) leads else NULL,
                                                cluster_var = "state"),
                  drop = "NAs introduced by coercion")
  if (r$failed) return(empty_result(paste("error:", conditionMessage(r$value)), r$notes))
  out <- as.data.frame(r$value)
  pre <- out[out$term %in% as.character(leads), ]
  po <- out[out$term %in% wtr, ]
  est <- rbind(data.frame(e = as.integer(pre$term), att = pre$estimate, se = pre$std.error),
               data.frame(e = as.integer(sub("^wtr_e", "", po$term)), att = po$estimate, se = po$std.error))
  o <- out[out$term == "wtr_overall", ]
  fs <- finish(est, list(att = o$estimate, se = o$std.error), d, ref = TRUE, min_e, max_e)
  cm <- out[match(cl$term, out$term), ]
  cells <- data.frame(g = cl$g, t = cl$t, e = cl$t - cl$g, att = cm$estimate, se = cm$std.error)
  rownames(cells) <- NULL
  ok_result(fs, r$notes, cells, list(estimates = out, first_stage = first, leads = leads),
            model_size(d, d$g > 0L))
}

# ---- stacked regression (Wing, Freedman and Hollingsworth 2024) ------------------------

# One sub-experiment per cohort a: its treated units and the clean controls (units of
# states untreated through a + post: g = 0, or g > a + post) in the window years
# a - pre .. a + post. Sub-experiments are not trimmed to complete event windows:
# Section 5 (rule 6) keeps cohorts with few pre-reform years. A cohort without clean
# controls is left out. Corrective weights: 1 for treated units, and
# (N_D_a / N_D) / (N_C_a / N_C) for controls in sub-experiment a, from unit counts
# (N_D_a, N_C_a treated and control units in a; N_D, N_C their sums over a).
build_stacks <- function(panel, pre = STACK_PRE, post = STACK_POST) {
  st <- lapply(sort(unique(panel$g[panel$g > 0L])), function(a) {
    d <- panel[(panel$g == a | panel$g == 0L | panel$g > a + post) &
                 panel$sy_end >= a - pre & panel$sy_end <= a + post, , drop = FALSE]
    if (!any(d$g != a)) return(NULL)
    d$stack <- a
    d$treat <- as.integer(d$g == a)
    d$rel <- d$sy_end - a
    d
  })
  s <- do.call(rbind, st)
  if (is.null(s)) return(NULL)
  u <- unique(s[c("stack", "id", "treat")])
  nd <- tapply(u$treat == 1L, u$stack, sum)
  nc <- tapply(u$treat == 0L, u$stack, sum)
  k <- as.character(s$stack)
  s$w_stack <- ifelse(s$treat == 1L, 1, (nd[k] / sum(nd)) / (nc[k] / sum(nc)))
  rownames(s) <- NULL
  s
}

# Weighted regression on the stacked data: event-time indicators for the treated units
# (reference -1), the flags, sub-experiment-by-unit and sub-experiment-by-year fixed
# effects, and for gaps (b) and (c) sub-experiment-by-year slopes on the covariates.
run_stacked <- function(panel, flags = character(), covs = character(), pre = STACK_PRE, post = STACK_POST,
                        min_e = EVENT_MIN, max_e = EVENT_MAX) {
  check_panel(panel, c(flags, covs))
  if (!any(panel$g > 0L)) return(empty_result("no estimable cohort"))
  s <- build_stacks(panel, pre, post)
  n_left <- length(unique(panel$g[panel$g > 0L])) - length(unique(s$stack))
  notes <- if (n_left > 0L) sprintf("%d cohort(s) without clean controls left out", n_left)
  if (is.null(s)) return(empty_result("no cohort with clean controls", notes))
  fe <- if (length(covs)) sprintf("stack^id + stack^sy_end[%s]", paste(covs, collapse = ", ")) else "stack^id + stack^sy_end"
  fml <- stats::as.formula(paste("y ~", rhs("i(rel, treat, ref = -1)", flags), "|", fe))
  r <- with_notes(fixest::feols(fml, data = s, weights = ~w_stack, cluster = ~state))
  if (r$failed) return(empty_result(paste("error:", conditionMessage(r$value)), c(notes, r$notes)))
  fit <- r$value
  b <- stats::coef(fit); V <- stats::vcov(fit)
  k <- grep("^rel::-?[0-9]+:treat$", names(b))
  e <- as.integer(sub("^rel::(-?[0-9]+):treat$", "\\1", names(b)[k]))
  est <- data.frame(e = e, att = unname(b[k]), se = unname(sqrt(diag(V))[k]))
  treated <- s[s$treat == 1L, ]
  fs <- finish(est, post_mean(e, unname(b[k]), V[k, k, drop = FALSE], min(max_e, post)), treated, ref = TRUE, min_e, max_e)
  size <- model_size(s, s$treat == 1L, stats::nobs(fit))
  size$cohorts_in_model <- length(unique(s$stack))
  ok_result(fs, c(notes, r$notes, collin_note(fit)), empty_cells(), fit, size)
}

# ---- two-way fixed effects, for comparison only (Section 9) ----------------------------

# Unit and year fixed effects with the same controls as the other regression
# estimators. dynamic: an indicator for every event time of the treated units except
# -1. static: one post-reform indicator, reported as its own overall row.
run_twfe <- function(panel, flags = character(), covs = character(), window,
                     min_e = EVENT_MIN, max_e = EVENT_MAX) {
  check_panel(panel, c(flags, covs))
  if (!any(panel$g > 0L)) {
    none <- empty_result("no estimable cohort")
    st <- none; st$event <- NULL
    return(list(dynamic = none, static = st))
  }
  cy <- add_cov_year(panel, covs, window)
  d <- cy$panel
  d$treat <- as.integer(d$g > 0L)
  d$rel <- ifelse(d$g > 0L, d$sy_end - d$g, -1L)
  d$post <- as.integer(d$g > 0L & d$sy_end >= d$g)
  controls <- c(flags, cy$terms)
  fit_one <- function(first) {
    fml <- stats::as.formula(paste("y ~", rhs(first, controls), "| id + sy_end"))
    with_notes(fixest::feols(fml, data = d, cluster = ~state))
  }
  size <- model_size(d, d$g > 0L)

  r <- fit_one("i(rel, treat, ref = -1)")
  dynamic <- if (r$failed) empty_result(paste("error:", conditionMessage(r$value)), r$notes) else {
    fit <- r$value
    b <- stats::coef(fit); V <- stats::vcov(fit)
    k <- grep("^rel::-?[0-9]+:treat$", names(b))
    e <- as.integer(sub("^rel::(-?[0-9]+):treat$", "\\1", names(b)[k]))
    est <- data.frame(e = e, att = unname(b[k]), se = unname(sqrt(diag(V))[k]))
    fs <- finish(est, post_mean(e, unname(b[k]), V[k, k, drop = FALSE], max_e), d, ref = TRUE, min_e, max_e)
    ok_result(fs, c(r$notes, collin_note(fit)), empty_cells(), fit, size)
  }

  r <- fit_one("post")
  static <- if (r$failed) empty_result(paste("error:", conditionMessage(r$value)), r$notes) else {
    fit <- r$value
    z <- stats::qnorm(1 - 0.05 / 2)
    att <- unname(stats::coef(fit)["post"]); se <- unname(sqrt(diag(stats::vcov(fit)))["post"])
    pc <- counts_over(d, unique(d$sy_end[d$post == 1L] - d$g[d$post == 1L]))
    list(status = "ok", notes = unique(c(r$notes, collin_note(fit))), event = NULL,
         overall = data.frame(att = att, se = se, ci_lo = att - z * se, ci_hi = att + z * se,
                              cohorts = as.integer(pc[["cohorts"]]), treated_states = as.integer(pc[["treated_states"]]),
                              treated_units = as.integer(pc[["treated_units"]])),
         cells = empty_cells(), fit = fit, size = size, pooled = NULL)
  }
  static$event <- NULL
  list(dynamic = dynamic, static = static)
}

# ---- synthetic difference-in-differences (Arkhangelsky et al. 2021) --------------------

# State-year means of y (gaps (b) and (c): unweighted over the panel's districts; gap
# (a) is already one row per state-year). id is re-coded by state.
state_year_means <- function(panel) {
  s <- stats::aggregate(y ~ state + sy_end + g, data = panel, FUN = mean)
  s <- s[order(s$state, s$sy_end), ]
  s$id <- as.integer(factor(s$state))
  rownames(s) <- NULL
  s
}

# synthdid::synthdid_estimate per cohort with at least min_pre pre-reform years, the
# cohort's states against every state not treated within the window, on the state-year
# means. Event time e pools the cohorts' effect curves (synthdid_effect_curve) weighted
# by treated states; the overall is the mean of those from 0 to max_e; the pooled ATT
# weights the cohort estimates by treated states times post periods. Standard errors:
# in each of reps placebo replications the control states are shuffled, as many as
# there are treated states take the cohorts' adoption years, the rest are controls, and
# everything is re-estimated (weights included); SE = sqrt((r - 1) / r) * sd, as in
# synthdid's placebo_se. There is no pre-reform reference row: synthdid weights the
# pre-reform years rather than normalising on -1.
run_sdid <- function(panel, seed_step, reps = SDID_REPS, min_pre = SDID_MIN_PRE,
                     min_e = EVENT_MIN, max_e = EVENT_MAX) {
  check_panel(panel)
  if (!any(panel$g > 0L)) return(empty_result("no estimable cohort", ref = FALSE))
  sp <- state_year_means(panel)
  years <- sort(unique(sp$sy_end))
  if (any(table(sp$state) != length(years))) stop("synthdid needs a balanced state-year panel")
  Y <- tapply(sp$y, list(sp$state, sp$sy_end), mean)
  gs <- tapply(sp$g, sp$state, function(z) z[1])
  controls <- names(gs)[gs == 0L]
  all_c <- sort(unique(gs[gs > 0L]))
  t0_all <- vapply(all_c, function(a) sum(years < a), integer(1))
  cohorts <- all_c[t0_all >= min_pre]
  notes <- character()
  if (length(cohorts) < length(all_c))
    notes <- sprintf("%d of %d cohort(s) left out: fewer than %d pre-reform years (synthdid's noise level needs them)",
                     length(all_c) - length(cohorts), length(all_c), min_pre)
  if (!length(cohorts)) return(empty_result(sprintf("no cohort with %d pre-reform years", min_pre), notes, ref = FALSE))
  treated <- lapply(cohorts, function(a) names(gs)[gs == a])
  n_tr <- lengths(treated)
  t0 <- vapply(cohorts, function(a) sum(years < a), integer(1))
  post_e <- lapply(cohorts, function(a) years[years >= a] - a)
  t1 <- lengths(post_e)
  es <- sort(unique(unlist(post_e)))
  stat <- function(ctrl, tr) {
    fits <- lapply(seq_along(cohorts), function(i)
      synthdid::synthdid_estimate(Y[c(ctrl, tr[[i]]), , drop = FALSE], length(ctrl), t0[i]))
    curves <- lapply(fits, function(f) as.numeric(synthdid::synthdid_effect_curve(f)))
    tau <- vapply(fits, as.numeric, numeric(1))
    att_e <- vapply(es, function(e) {
      k <- vapply(post_e, function(x) e %in% x, logical(1))
      sum(n_tr[k] * mapply(function(cv, pe) cv[pe == e], curves[k], post_e[k])) / sum(n_tr[k])
    }, numeric(1))
    list(fits = fits, values = c(att_e, mean(att_e[es <= max_e]), sum(n_tr * t1 * tau) / sum(n_tr * t1),
                                 unlist(curves)))
  }
  r <- with_notes(stat(controls, treated))
  if (r$failed) return(empty_result(paste("error:", conditionMessage(r$value)), c(notes, r$notes), ref = FALSE))
  main <- r$value; v <- main$values
  notes <- c(notes, r$notes)
  se <- rep(NA_real_, length(v)); draws <- NULL
  n_all <- sum(n_tr)
  if (length(controls) > n_all) {
    set.seed(seed_for(seed_step))
    grp <- rep(seq_along(cohorts), n_tr)
    pr <- with_notes(replicate(reps, {
      perm <- sample(controls)
      tryCatch(stat(perm[-seq_len(n_all)], split(perm[seq_len(n_all)], grp))$values,
               error = function(e) rep(NA_real_, length(v)))
    }))
    notes <- c(notes, pr$notes)
    if (!pr$failed) {
      draws <- pr$value
      ok <- colSums(is.na(draws)) == 0
      if (any(!ok)) notes <- c(notes, sprintf("%d of %d placebo replications failed and are left out", sum(!ok), reps))
      if (sum(ok) > 1) se <- sqrt((sum(ok) - 1) / sum(ok)) * apply(draws[, ok, drop = FALSE], 1, stats::sd)
    }
  } else {
    notes <- c(notes, "placebo standard errors need more control states than treated states; none computed")
  }
  ne <- length(es)
  est <- data.frame(e = es, att = v[seq_len(ne)], se = se[seq_len(ne)])
  used <- sp[sp$g == 0L | sp$g %in% cohorts, ]
  fs <- finish(est, list(att = v[ne + 1L], se = se[ne + 1L]), used, ref = FALSE, min_e, max_e)
  z <- stats::qnorm(1 - 0.05 / 2)
  pooled <- data.frame(att = v[ne + 2L], se = se[ne + 2L], ci_lo = v[ne + 2L] - z * se[ne + 2L],
                       ci_hi = v[ne + 2L] + z * se[ne + 2L], cohorts = length(cohorts), treated_states = n_all)
  ci <- (ne + 3L):length(v)
  cells <- data.frame(g = rep(as.integer(cohorts), t1), e = as.integer(unlist(post_e)), att = v[ci], se = se[ci])
  cells$t <- cells$g + cells$e
  cells <- cells[c("g", "t", "e", "att", "se")]
  ok_result(fs, notes, cells, list(cohort_fits = main$fits, placebo_draws = draws),
            model_size(used, used$g > 0L), pooled)
}

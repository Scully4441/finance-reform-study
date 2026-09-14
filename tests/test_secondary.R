# Checks for R/functions/secondary.R and the step 6 outputs (design Section 7).
# Sourced by tests/run_tests.R after the shared functions are loaded.
W <- 2010:2013

# flags: one row per state-year; a flag that differs within a state-year stops
sm <- data.frame(leaid = c("1", "2", "3", "1", "2", "3"), state = c("A", "A", "B", "A", "A", "B"),
                 sy_end = rep(c(2010L, 2011L), each = 3), test_replaced = c(0L, 0L, 1L, 1L, 1L, 0L), cep = 0L,
                 stringsAsFactors = FALSE)
fl <- state_flags(sm, W)
stopifnot(nrow(fl) == 4, identical(fl$test_replaced[fl$state == "A"], c(0L, 1L)))
sm2 <- sm; sm2$cep[2] <- 1L
stopifnot(inherits(try(state_flags(sm2, W), silent = TRUE), "try-error"))
stopifnot(inherits(try(attach_flags(data.frame(state = "C", sy_end = 2010L), fl), silent = TRUE), "try-error"))

# gap (a) flags (author decision 2026-09-12): cep = share of the state-year's gap (a)
# districts under CEP (quintile 1 or 5, valid 2009-10 membership, retained, all-students
# cell usable in both subjects); other districts do not count
ga <- data.frame(leaid = as.character(1:6), state = "A", sy_end = 2015L, retained = c(1L, 1L, 1L, 1L, 1L, 0L),
                 pov_quintile_2009 = c(1L, 5L, 5L, 3L, 1L, 1L), member_2009 = c(100, 200, 300, 400, NA, 100),
                 test_replaced = 1L, cep = c(1L, 0L, 1L, 1L, 1L, 1L), stringsAsFactors = FALSE)
for (subj in names(SUBJECTS)) {
  ga[[paste0("cell_", subj, "_all")]] <- "usable"; ga[[paste0("w_", subj, "_all")]] <- 0
  ga[[paste0("part_ok_", subj, "_all")]] <- 1L
}
ga$part_ok_rla_all[3] <- 0L                        # district 3 fails rule 4 in RLA
af <- gap_a_flags(ga, "retained", 2015L)
stopifnot(nrow(af) == 1, af$test_replaced == 1L, near(af$cep, 0.5))   # districts 1 and 2 only

# covariate-by-year columns: none for the first window year
cy <- add_cov_year(data.frame(sy_end = W, x = 2), "x", W)
stopifnot(identical(cy$terms, paste0("cy_x_", 2011:2013)), identical(cy$panel$cy_x_2011, c(0, 2, 0, 0)))

# equal-weight mean of event times 0..max_e
pm <- post_mean(c(-1L, 0L, 1L, 9L), c(5, 1, 3, 100), diag(4), max_e = 8L)
stopifnot(near(pm$att, 2), near(pm$se, sqrt(0.5)))

# stacked sub-experiments: clean controls, window, corrective weights
sp <- expand.grid(k = 1:2, state = c("A", "B", "C", "N1", "N2", "N3"), sy_end = 2008:2016, stringsAsFactors = FALSE)
sp$g <- c(A = 2011L, B = 2012L, C = 2013L, N1 = 0L, N2 = 0L, N3 = 0L)[sp$state]
sp$id <- as.integer(factor(paste(sp$state, sp$k)))
st <- build_stacks(sp, pre = 2L, post = 1L)
s11 <- st[st$stack == 2011, ]
stopifnot(setequal(unique(s11$state), c("A", "C", "N1", "N2", "N3")),      # C (2013 > 2011 + 1) is clean, B is not
          all(s11$sy_end %in% 2009:2012), all(s11$treat == (s11$state == "A")), identical(sort(unique(s11$rel)), -2:1),
          setequal(unique(st$state[st$stack == 2012]), c("B", "N1", "N2", "N3")))
wc <- tapply(st$w_stack[st$treat == 0L], st$stack[st$treat == 0L], unique)
stopifnot(near(unlist(wc), c((2 / 6) / (8 / 20), (2 / 6) / (6 / 20), (2 / 6) / (6 / 20))),
          all(st$w_stack[st$treat == 1L] == 1))
stopifnot(identical(unique(build_stacks(sp[sp$g > 0L, ], 2L, 1L)$stack), 2011L),   # no clean controls: left out
          is.null(build_stacks(sp[sp$g %in% c(2012L, 2013L), ], 2L, 5L)))

# synthetic panel: cohorts 2011, 2012 (two states), 2013; one state treated after the
# window, one in the first window year, eight never treated; true effect 0.5. With
# extra = TRUE the outcome also moves with the flags and with a covariate-specific trend.
sim2 <- function(n = 25, effect = 0.5, extra = TRUE) {
  ty <- c(2011L, 2012L, 2012L, 2013L, 2016L, 2010L, rep(NA, 8))
  ev <- data.frame(state = sprintf("S%02d", seq_along(ty)), treat_year = ty,
                   group = ifelse(is.na(ty), "never", "treated"), stringsAsFactors = FALSE)
  set.seed(seed_for("test secondary sim"))
  d <- expand.grid(k = seq_len(n), state = ev$state, sy_end = W, stringsAsFactors = FALSE)
  d$unit <- paste(d$state, d$k)
  u <- sort(unique(d$unit)); x <- stats::rnorm(length(u)); a <- stats::rnorm(length(u))
  d$x1 <- x[match(d$unit, u)]
  sf <- expand.grid(state = ev$state, sy_end = W, stringsAsFactors = FALSE)
  sf$test_replaced <- stats::rbinom(nrow(sf), 1, 0.3)
  first_cep <- sample(2011:2014, nrow(ev), replace = TRUE)
  sf$cep <- as.integer(sf$sy_end >= first_cep[match(sf$state, ev$state)])
  d <- attach_flags(d, sf)
  tyd <- ev$treat_year[match(d$state, ev$state)]
  d$y <- a[match(d$unit, u)] + 0.05 * (d$sy_end - 2010) + effect * (!is.na(tyd) & d$sy_end >= tyd) +
    stats::rnorm(nrow(d), sd = 0.02)
  if (extra) d$y <- d$y + 0.3 * d$x1 * (d$sy_end - 2010) + 0.2 * d$test_replaced - 0.1 * d$cep
  attach_cohorts(d[order(d$unit, d$sy_end), ], cohort_coding(ev, W), "unit")$panel
}
p2 <- sim2()
sa  <- run_sunab(p2, SEC_FLAGS, "x1", W)
bi  <- run_imputation(p2, SEC_FLAGS, "x1", W)
stk <- run_stacked(p2, SEC_FLAGS, "x1")
tw  <- run_twfe(p2, SEC_FLAGS, "x1", W)
# unbalanced input: treated units observed only after reform cannot be imputed; they are
# left out of the weights with a note, and the overall stays the equal-weight mean of
# the event-time estimates
pun <- p2[!(p2$g > 0L & p2$sy_end < p2$g & p2$id %in% unique(p2$id[p2$g > 0L])[1:10]), ]
biu <- run_imputation(pun, SEC_FLAGS, "x1", W)
stopifnot(biu$status == "ok", any(grepl("^10 treated unit\\(s\\) without an untreated observation", biu$notes)),
          near(biu$overall$att, mean(biu$event$att[biu$event$e >= 0 & !is.na(biu$event$att)]), 1e-8))
exp_c <- c(0L, 0L, 1L, 2L, 3L, 3L, 2L, 1L, rep(0L, 6))    # cohorts per event time -5..+8
exp_s <- c(0L, 0L, 1L, 3L, 4L, 4L, 3L, 1L, rep(0L, 6))    # treated states
for (f in list(sa, bi, stk, tw$dynamic)) {
  e <- f$event
  stopifnot(f$status == "ok", identical(e$e, -5:8), e$att[e$e == -1] == 0, e$reference[e$e == -1],
            all(abs(e$att[e$e %in% 0:2] - 0.5) < 0.05), all(abs(e$att[e$e %in% -3:-2]) < 0.05),
            all(is.na(e$att[e$e < -3 | e$e > 2])), all(is.na(e$att) == (e$cohorts == 0L)),
            identical(e$cohorts, exp_c), identical(e$treated_states, exp_s), identical(e$treated_units, 25L * exp_s),
            abs(f$overall$att - 0.5) < 0.05, near(f$overall$att, mean(e$att[e$e %in% 0:2]), 1e-8),
            f$overall$cohorts == 3L, f$overall$treated_units == 100L, all(e$se[e$e %in% 0:2] > 0),
            f$size$units_in_model == 13L * 25L)
}
stopifnot(tw$static$status == "ok", abs(tw$static$overall$att - 0.5) < 0.05, is.null(tw$static$event),
          tw$static$overall$cohorts == 3L)
# Sun-Abraham: the interaction weights here match fixest's own aggregation
env <- new.env(); env$sunab <- utils::getFromNamespace("sunab", "fixest")
cyp <- add_cov_year(p2, "x1", W)
fa <- fixest::feols(stats::as.formula(paste("y ~ sunab(g, sy_end) +", paste(c(SEC_FLAGS, cyp$terms), collapse = " + "),
                                            "| id + sy_end"), env = env), cyp$panel, cluster = ~state, notes = FALSE)
ag <- stats::coef(fa)[grep("^sy_end::", names(stats::coef(fa)))]
stopifnot(near(unname(ag), sa$event$att[match(as.integer(sub("sy_end::", "", names(ag))), sa$event$e)], 1e-8))
stopifnot(nrow(sa$cells) == 9, all(sa$cells$t - sa$cells$g == sa$cells$e))
# the indicators are the ones sunab() builds, column for column, where sunab() is sound
sunab_m <- utils::getFromNamespace("sunab", "fixest")
snp <- sunab_m(p2$g, p2$sy_end, ref.p = -1, no_agg = TRUE)
stp <- sa_terms(p2)
cn <- data.frame(col = colnames(snp), e = as.integer(sub("^(-?[0-9]+):.*$", "\\1", colnames(snp))),
                 g = as.integer(sub("^.*:", "", colnames(snp))), stringsAsFactors = FALSE)
cn$term <- sprintf("sa_c%d_e%s", cn$g, sub("-", "m", cn$e))
stopifnot(sum(!stats::complete.cases(snp)) == 0, nrow(cn) == nrow(stp$cells), setequal(cn$term, stp$cells$term),
          all(vapply(seq_len(nrow(cn)), function(i) all(snp[, cn$col[i]] == stp$panel[[cn$term[i]]]), TRUE)))
# a cohort whose treated units supply one pre-treatment observation: fixest 0.14.2's
# sunab() drops it and NAs an unrelated row, so the indicators are built in sa_terms().
# Canary: the first two checks fail when fixest fixes this, and run_sunab() can then
# call sunab() directly again.
# The panel is laid out like a real state-level one: single-state cohorts scattered
# among the controls, which is where sunab()'s always-treated test misfires.
set.seed(seed_for("test secondary one unit"))
gs <- c(2011L, 2012L, rep(0L, 34))
one <- do.call(rbind, lapply(seq_along(gs), function(s)
  data.frame(id = s, state = sprintf("T%02d", s), sy_end = W, g = gs[s], stringsAsFactors = FALSE)))
one$id <- as.integer(one$id)
one <- one[order(match(one$id, sample(seq_along(gs))), one$sy_end), ]
rownames(one) <- NULL
one$y <- 0.05 * (one$sy_end - 2010) + 0.5 * (one$g > 0L & one$sy_end >= one$g) + stats::rnorm(nrow(one), sd = 0.01)
sn <- sunab_m(one$g, one$sy_end, ref.p = -1, no_agg = TRUE)
stopifnot(ncol(sn) == 3, sum(!stats::complete.cases(sn)) == 1)          # the package drops a cohort here
st1 <- sa_terms(one)
stopifnot(nrow(st1$cells) == 6, all(colSums(st1$panel[st1$cells$term]) == 1))
f1 <- run_sunab(one, window = W)
stopifnot(f1$status == "ok", nrow(f1$cells) == 6, f1$event$cohorts[f1$event$e == 0] == 2L,
          all(abs(f1$event$att[f1$event$e %in% 0:1] - 0.5) < 0.05))
# imputation: cohort-year cells for every treated cell; the overall is the mean of its event times
stopifnot(nrow(bi$cells) == 6, all(abs(bi$cells$att - 0.5) < 0.05), !anyNA(bi$cells$se))
# the controls enter every regression estimator: flags, covariate-by-year terms
# (stacked: sub-experiment-by-year slopes)
ctl <- c(SEC_FLAGS, paste0("cy_x1_", 2011:2013))
stopifnot(all(ctl %in% names(stats::coef(sa$fit))), all(ctl %in% names(stats::coef(tw$dynamic$fit))),
          all(ctl %in% names(stats::coef(tw$static$fit))), identical(bi$fit$first_stage, paste(paste(ctl, collapse = " + "), "| id + sy_end")),
          all(SEC_FLAGS %in% names(stats::coef(stk$fit))),
          grepl("stack^sy_end[[x1]]", deparse1(stk$fit$fml_all$fixef), fixed = TRUE))
stopifnot(!any(SEC_FLAGS %in% names(stats::coef(run_twfe(p2, window = W)$static$fit))))   # none when none given

# synthdid on an outcome without flags or covariate trends (it takes no controls)
p3 <- sim2(extra = FALSE)
sd1 <- run_sdid(p3, seed_step = "test secondary sdid", reps = 50L)
e <- sd1$event
stopifnot(sd1$status == "ok", any(grepl("fewer than 2 pre-reform years", sd1$notes)),     # the 2011 cohort has one
          identical(e$cohorts, c(rep(0L, 5), 2L, 1L, rep(0L, 7))), identical(e$treated_states, c(rep(0L, 5), 3L, 2L, rep(0L, 7))),
          identical(e$treated_units, e$treated_states), all(is.na(e$att[e$e < 0])), !any(e$reference),
          all(abs(e$att[e$e %in% 0:1] - 0.5) < 0.05), near(sd1$overall$att, mean(e$att[e$e %in% 0:1])),
          all(e$se[e$e %in% 0:1] > 0), abs(sd1$pooled$att - 0.5) < 0.05, sd1$pooled$treated_states == 3L,
          nrow(sd1$cells) == 3, near(sd1$pooled$att, sum(c(2, 2, 1) * sd1$cells$att) / 5),   # cohort estimate = mean of its curve
          sd1$size$units_in_model == 12L, sd1$size$cohorts_in_model == 2L)                  # 9 control states + 3 in the two cohorts
stopifnot(identical(run_sdid(p3, seed_step = "test secondary sdid", reps = 50L)$event$se, e$se))   # seeded placebo
sdf <- run_sdid(p3[p3$g %in% c(0L, 2012L, 2013L) & p3$state %in% c("S02", "S03", "S04", "S07", "S08"), ],
                seed_step = "test secondary sdid few", reps = 5L)
stopifnot(sdf$status == "ok", all(is.na(sdf$event$se)), any(grepl("more control states", sdf$notes)))
# unbalanced input (author decision 2026-09-13): a state without a mean in every year stops
# the balanced call; with complete_states it is left out with a note and the rest estimate
pu <- p3[!(p3$state == "S09" & p3$sy_end == min(p3$sy_end)), ]
stopifnot(inherits(try(run_sdid(pu, seed_step = "test secondary sdid", reps = 5L), silent = TRUE), "try-error"))
sdu <- run_sdid(pu, seed_step = "test secondary sdid unbalanced", reps = 5L, complete_states = TRUE)
sdc <- run_sdid(p3[p3$state != "S09", ], seed_step = "test secondary sdid unbalanced", reps = 5L)
stopifnot(sdu$status == "ok", any(grepl("^1 of [0-9]+ state\\(s\\) without", sdu$notes)),
          near(sdu$overall$att, sdc$overall$att), sdu$size$units_in_model == sdc$size$units_in_model)

# no estimable cohort: a status, not an error
p0 <- p2; p0$g <- 0L
t0 <- run_twfe(p0, SEC_FLAGS, "x1", W)
for (f in list(run_sunab(p0, SEC_FLAGS, "x1", W), run_imputation(p0, SEC_FLAGS, "x1", W),
               run_stacked(p0, SEC_FLAGS, "x1"), run_sdid(p0, "x", reps = 5L), t0$dynamic))
  stopifnot(f$status == "no estimable cohort", all(is.na(f$event$att)), all(f$event$cohorts == 0L),
            identical(f$event$e, -5:8), is.na(f$overall$att), nrow(f$cells) == 0)
stopifnot(t0$static$status == "no estimable cohort", is.null(t0$static$event))

# step 6 outputs, when they have been built: the unbalanced panel in the main folder and
# the balanced panel in appendix/ (author decision 2026-09-13)
for (pan6 in c(unbalanced = "outputs/06_secondary", balanced = "outputs/06_secondary/appendix")) {
of6 <- file.path(pan6, c("event_time_estimates.csv", "overall_estimates.csv", "model_status.csv",
                         "panel_counts.csv", "group_time_estimates.csv", "synthdid_pooled.csv"))
if (all(file.exists(of6))) {
  rd <- function(f) utils::read.csv(f, stringsAsFactors = FALSE, na.strings = "")
  ee <- rd(of6[1]); oo <- rd(of6[2]); ms <- rd(of6[3]); pc6 <- rd(of6[4]); gt <- rd(of6[5]); sdp <- rd(of6[6])
  pname <- if (endsWith(pan6, "appendix")) "balanced" else "unbalanced"
  stopifnot(all(ms$panel == pname), all(ee$panel == pname), all(oo$panel == pname), all(pc6$panel == pname))
  ests <- c("sun_abraham", "imputation", "synthdid", "stacked", "twfe", "twfe_static")
  gps <- c("a_poverty", "b_black_white", "c_hispanic_white")
  # all three event sets from step 10 (2026-09-13); a model on a narrower set may stop with
  # a package error on a small panel, every primary-set model must fit
  models <- as.vector(outer(as.vector(outer(ests, gps, paste)), c("primary", "r1", "r2"), paste))
  key <- function(x) paste(x$estimator, x$gap, x$event_set)
  stopifnot(nrow(ms) == 54, setequal(key(ms), models), !anyDuplicated(key(ms)),
            !any(startsWith(ms$status[ms$event_set == "primary"], "error")), all(ms$weighting == "unweighted"))
  stopifnot(nrow(ee) == 3 * 15 * 14, all(table(key(ee)) == 14), !"twfe_static" %in% ee$estimator,
            all(ee$e %in% EVENT_MIN:EVENT_MAX), nrow(oo) == 54, setequal(key(oo), models))
  ok <- key(ee) %in% key(ms)[ms$status == "ok"]
  stopifnot(all(is.na(ee$att) == (ee$cohorts == 0L)), all(ee$treated_units >= ee$treated_states),
            all(ee$att[ok & ee$reference] == 0), !any(ee$reference[ee$estimator == "synthdid"]),
            all(is.na(ee$att[ee$estimator == "synthdid" & ee$e < 0])))
  for (m in setdiff(key(ms)[ms$status == "ok"], key(ms)[ms$estimator == "twfe_static"])) {   # overall = mean of e = 0..+8
    x <- ee[key(ee) == m & ee$e >= 0 & !is.na(ee$att), ]
    stopifnot(near(oo$att[key(oo) == m], mean(x$att), 1e-8))
  }
  s5 <- file.path("outputs", "05_primary", c("event_time_estimates.csv", "overall_estimates.csv", "group_time_estimates.csv"))
  if (all(file.exists(s5)))                                                        # the step 5 layout, estimator first
    stopifnot(identical(names(ee)[-1], names(rd(s5[1]))), identical(names(oo)[-1], names(rd(s5[2]))),
              identical(names(gt)[-1], names(rd(s5[3]))))
  stopifnot(nrow(pc6) <= 54, sum(pc6$event_set == "primary") == 18, all(pc6$units_in_model == pc6$treated_units + pc6$control_units |
                                   pc6$estimator == "stacked"),
            nrow(sdp) == sum(ms$estimator == "synthdid" & ms$status == "ok"))
}
}

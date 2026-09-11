# Outcome construction (design document, Section 6; data acquisition 4, 4.2).
# Functions used by R/04_outcomes.R on district-year rows of
# data/derived/sample_district_year.csv (R/03_sample.R).
# Author decisions 2026-09-11 (docs/decision_log.md):
#   Gaps (b) and (c) are Black minus White and Hispanic minus White, the same
#   orientation as gap (a) (top-poverty minus bottom-poverty quintile): gaps are
#   usually negative and a positive effect means a gap narrowed. Reardon's
#   convention is the reverse.
#   Gap (a) weights each district by its 2009-10 CCD membership, fixed across years.
#   A district without a valid 2009-10 membership is left out of gap (a) and stays
#   in gaps (b) and (c).
# Standard errors cover binomial sampling in each share only, not the error from
# entering a range at its midpoint (rule 3, author decision 2026-09-11).

# Racial gaps: V = probit(first subgroup) - probit(second subgroup).
RACE_GAPS <- list(bw = c("bl", "wh"), hw = c("hi", "wh"))

# CCD counts: negative codes (-1 missing, -2 not applicable, -9 fails NCES
# quality standards) and non-numeric values become NA.
ccd_count <- function(x) {
  v <- suppressWarnings(as.numeric(trimws(as.character(x))))
  v[!is.na(v) & v < 0] <- NA_real_
  v
}

# TRUE where every subgroup in sgs passes rule 3 in the named suppression sample
# and rule 4. part_ok_* is NA before 2012-13 (no participation file: retained
# untested) and 0/1 from 2012-13 on (R/03_sample.R), so NA passes here.
gap_cells_ok <- function(d, subj, sgs, sample = names(MAX_WIDTH)) {
  sample <- match.arg(sample)
  ok <- rep(TRUE, nrow(d))
  for (s in sgs) {
    col <- function(pre) d[[paste0(pre, "_", subj, "_", s)]]
    pk <- col("part_ok")
    ok <- ok & cell_in_sample(col("cell"), col("w"), sample) & (is.na(pk) | pk == 1L)
  }
  ok
}

# Gaps (b) and (c) for one subject and suppression sample: one row per district-year
# with at least one of the two gaps. n_* are valid-test counts, p_* shares (percent
# / 100), w_* range widths in points, as reported for each cell; v_* and se_* are NA
# where the gap's two cells are not both in the sample.
race_gaps <- function(d, subj, sample) {
  col <- function(pre, s) d[[paste0(pre, "_", subj, "_", s)]]
  out <- data.frame(leaid = d$leaid, state = d$state, sy_end = d$sy_end,
                    subject = rep(subj, nrow(d)), sample = rep(sample, nrow(d)),
                    retained = d$retained, retained_r1 = d$retained_r1, retained_r2 = d$retained_r2,
                    stringsAsFactors = FALSE)
  any_ok <- rep(FALSE, nrow(d))
  for (g in names(RACE_GAPS)) {
    a <- RACE_GAPS[[g]][1]; b <- RACE_GAPS[[g]][2]
    ok <- gap_cells_ok(d, subj, c(a, b), sample)
    v <- se <- rep(NA_real_, nrow(d))
    pa <- col("p", a)[ok] / 100; pb <- col("p", b)[ok] / 100
    na <- col("n", a)[ok];       nb <- col("n", b)[ok]
    v[ok]  <- v_gap(pa, pb, na, nb)
    se[ok] <- v_gap_se(pa, pb, na, nb)
    out[[paste0("v_", g)]]  <- v
    out[[paste0("se_", g)]] <- se
    any_ok <- any_ok | ok
  }
  for (pre in c("n", "p", "w")) for (s in c("wh", "bl", "hi")) {
    x <- col(pre, s)
    out[[paste0(pre, "_", s)]] <- if (pre == "p") x / 100 else x
  }
  out <- out[any_ok, ]
  rownames(out) <- NULL
  out
}

# Gap (a) for one subject and suppression sample: one row per state-year with a
# usable district in both quintile 1 (lowest poverty) and quintile 5 (highest).
# d must carry pov_quintile_2009 and member_2009 (the weight). A district's score
# is probit_score(p, n) for all students; each quintile's score is the
# member_2009-weighted mean over its districts with a usable cell that year;
# v_pov = score_q5 - score_q1. Districts without a positive member_2009 are left
# out (author decision 2026-09-11). The retained flags are state-level: they must
# agree across a state's quintile districts.
poverty_gap <- function(d, subj, sample) {
  n_col <- paste0("n_", subj, "_all"); p_col <- paste0("p_", subj, "_all")
  wt_ok <- !is.na(d$member_2009) & d$member_2009 > 0
  x <- d[d$pov_quintile_2009 %in% c(1L, 5L) & wt_ok & gap_cells_ok(d, subj, "all", sample), ]
  x$score <- probit_score(x[[p_col]] / 100, x[[n_col]])
  x$key <- paste(x$state, x$sy_end)
  fl <- unique(x[c("key", "retained", "retained_r1", "retained_r2")])
  if (anyDuplicated(fl$key)) stop("gap (a): retained flags differ within a state-year")
  keys <- sort(unique(x$key))
  by_q <- function(qq) {
    y <- x[x$pov_quintile_2009 == qq, ]
    k <- factor(y$key, levels = keys)
    w <- as.vector(tapply(y$member_2009, k, sum))
    list(score = as.vector(tapply(y$member_2009 * y$score, k, sum)) / w,
         districts = as.vector(table(k)), member = w, tested = as.vector(tapply(y[[n_col]], k, sum)))
  }
  lo <- by_q(1L); hi <- by_q(5L)
  first <- x[match(keys, x$key), c("state", "sy_end", "retained", "retained_r1", "retained_r2")]
  out <- data.frame(state = first$state, sy_end = first$sy_end,
                    subject = rep(subj, length(keys)), sample = rep(sample, length(keys)),
                    retained = first$retained, retained_r1 = first$retained_r1, retained_r2 = first$retained_r2,
                    v_pov = hi$score - lo$score, score_q5 = hi$score, score_q1 = lo$score,
                    districts_q5 = hi$districts, districts_q1 = lo$districts,
                    member_q5 = hi$member, member_q1 = lo$member, tested_q5 = hi$tested, tested_q1 = lo$tested,
                    stringsAsFactors = FALSE)
  out <- out[out$districts_q1 > 0 & out$districts_q5 > 0, ]
  rownames(out) <- NULL
  out
}

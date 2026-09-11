# Step 4. Outcome construction (design document, Section 6; data acquisition 4, 4.2).
# Run from the repository folder: Rscript R/04_outcomes.R
#
# Inputs
#   data/derived/sample_district_year.csv    R/03_sample.R: rules, cells, quintiles
#   data/raw/ccd/lea-directory-sy2009-10.zip 2009-10 CCD membership, the gap (a) weight
# Outputs
#   data/derived/gaps_race_district_year.csv   gaps (b) and (c): one row per
#     district-year-subject-sample with at least one of the two gaps, for districts
#     retained under at least one event set
#       leaid, state, sy_end, subject (math, rla), sample (primary, r5, exact)
#       retained, retained_r1, retained_r2   rules 1, 2 and 6 with each event set
#       v_bw, se_bw   Black minus White:    probit(p_bl) - probit(p_wh)
#       v_hw, se_hw   Hispanic minus White: probit(p_hi) - probit(p_wh)
#       n_<sg>, p_<sg>, w_<sg>   for wh, bl, hi: valid-test count, share proficient
#                     (exact value or range midpoint, divided by 100), range width in points
#   data/derived/gap_poverty_state_year.csv    gap (a): one row per state-year-subject-sample
#     with a usable district in poverty quintile 1 and in quintile 5
#       state, sy_end, subject, sample, retained, retained_r1, retained_r2 (state-level)
#       v_pov = score_q5 - score_q1: membership-weighted mean district probit score,
#               highest-poverty quintile minus lowest-poverty quintile
#       districts_q*, member_q*, tested_q*: districts, 2009-10 membership and valid tests
#   outputs/04_outcomes/*.csv and outputs/logs/04_outcomes_<stamp>.log: the counts below
#
# Rules (author decisions 2026-09-11, docs/decision_log.md, CLAUDE.md):
#   A gap uses a district-year-subject only when every subgroup in it passes rule 3 in
#   the suppression sample and, from 2012-13, rule 4. Suppression samples
#   (MAX_WIDTH): primary = exact or a range of 10 points or less at its midpoint;
#   r5 = 5 points or less; exact = exact values only.
#   Sign: Black minus White and Hispanic minus White, the orientation of gap (a)
#   (top-poverty minus bottom-poverty). Gaps are usually negative; a positive effect
#   means a gap narrowed. Reardon's convention is the reverse.
#   Gap (a) weight: each district's 2009-10 CCD total membership, fixed across years.
#   A district without a valid 2009-10 membership (CCD -1, -2, -9, or 0) is left out
#   of gap (a) and stays in gaps (b) and (c).
#   Poverty quintiles are fixed per state at SAIPE 2009 (R/03_sample.R).
#   Standard errors (delta method) cover binomial sampling in each share only. They do
#   not include the error from entering a range at its midpoint.
# Math and RLA are kept as separate rows; averaging within district-year is left to
# the estimation steps (Section 6). Cohorts per event time are reported by
# R/05_primary.R: this script reads only each state's event-set group.

for (f in list.files("R/functions", full.names = TRUE)) source(f)

stage <- as.integer(readLines("data/stage.txt", n = 1, warn = FALSE))
if (!identical(stage, 1L))
  stop("R/04_outcomes.R covers stage 1 (end years 2010-2013). Rerun R/03_sample.R for stage 2 first.")
WINDOW    <- 2010:2013    # stage 1 end years (data acquisition 1)
PART_FROM <- 2013L        # participation files begin with 2012-13 (design Section 5, v17)

stamp   <- format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ")
out_dir <- "outputs/04_outcomes"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/logs", recursive = TRUE, showWarnings = FALSE)
log_file <- file.path("outputs", "logs", paste0("04_outcomes_", stamp, ".log"))
say <- function(...) {
  txt <- paste0(...)
  cat(txt, "\n", sep = "")
  cat(txt, "\n", sep = "", file = log_file, append = TRUE)
}
show <- function(x) say(paste(utils::capture.output(print(x, row.names = FALSE)), collapse = "\n"))

say("Step 4 outcomes, run ", stamp, "; stage ", stage, "; blinding ",
    readLines("data/reference/blinding_status.txt", n = 1, warn = FALSE))

# ---- inputs ------------------------------------------------------------------------
s <- utils::read.csv("data/derived/sample_district_year.csv", colClasses = c(leaid = "character"),
                     stringsAsFactors = FALSE, na.strings = "")
stopifnot(setequal(unique(s$sy_end), WINDOW), !anyDuplicated(s[c("leaid", "sy_end")]))
for (v in as.vector(outer(names(SUBJECTS), SUBGROUPS, paste, sep = "_"))) {
  pk <- s[[paste0("part_ok_", v)]]        # gap_cells_ok() lets NA pass: only before 2012-13
  stopifnot(all(is.na(pk[s$sy_end < PART_FROM])), all(pk[s$sy_end >= PART_FROM] %in% 0:1))
}

# The retained flags come from the three permuted event tables (R/03_sample.R). Check
# them against each state's group; nothing else is read from the tables.
sets <- c(retained = "event_table.csv", retained_r1 = "event_table_r1.csv", retained_r2 = "event_table_r2.csv")
for (flag in names(sets)) {
  e <- utils::read.csv(file.path("data", "reference", sets[[flag]]), stringsAsFactors = FALSE)[c("state", "group")]
  stopifnot(!any(s[[flag]] == 1L & s$state %in% e$state[e$group == "excluded"]))
}

# Gap (a) weight: 2009-10 CCD total membership (author decision 2026-09-11).
td <- tempfile("ccd"); dir.create(td)
l09 <- read_ccd_lea(utils::unzip("data/raw/ccd/lea-directory-sy2009-10.zip", exdir = td), 2010L, extra = "MEMBER")
s$member_2009 <- ccd_count(l09$member)[match(s$leaid, l09$leaid)]

keep <- s$retained == 1L | s$retained_r1 == 1L | s$retained_r2 == 1L
d <- s[keep, ]
say("District-years retained under at least one event set: ", nrow(d), " (", length(unique(d$leaid)),
    " districts, ", length(unique(d$state)), " states)")
no_wt <- d[d$pov_quintile_2009 %in% c(1L, 5L) & (is.na(d$member_2009) | d$member_2009 <= 0), ]
no_wt <- no_wt[!duplicated(no_wt$leaid), c("leaid", "state", "pov_quintile_2009")]
say("Quintile 1 and 5 districts without a valid 2009-10 membership, left out of gap (a): ", nrow(no_wt),
    if (nrow(no_wt)) paste0(" (", paste(no_wt$state, no_wt$leaid, paste0("q", no_wt$pov_quintile_2009),
                                        collapse = "; "), ")") else "")
utils::write.csv(no_wt, file.path(out_dir, "gap_a_no_2009_membership.csv"), row.names = FALSE)

# ---- gaps (b) and (c) ----------------------------------------------------------------
race <- do.call(rbind, lapply(names(MAX_WIDTH), function(smpl)
  do.call(rbind, lapply(names(SUBJECTS), function(subj) race_gaps(d, subj, smpl)))))
race <- race[order(factor(race$sample, levels = names(MAX_WIDTH)), race$state, race$leaid, race$sy_end,
                   race$subject), ]
stopifnot(!anyDuplicated(race[c("leaid", "sy_end", "subject", "sample")]))
utils::write.csv(race, "data/derived/gaps_race_district_year.csv", row.names = FALSE, na = "")
say("Wrote data/derived/gaps_race_district_year.csv: ", nrow(race), " rows.")

# ---- gap (a) -------------------------------------------------------------------------
pov <- do.call(rbind, lapply(names(MAX_WIDTH), function(smpl)
  do.call(rbind, lapply(names(SUBJECTS), function(subj) poverty_gap(d, subj, smpl)))))
pov <- pov[order(factor(pov$sample, levels = names(MAX_WIDTH)), pov$state, pov$sy_end, pov$subject), ]
stopifnot(!anyDuplicated(pov[c("state", "sy_end", "subject", "sample")]))
utils::write.csv(pov, "data/derived/gap_poverty_state_year.csv", row.names = FALSE, na = "")
say("Wrote data/derived/gap_poverty_state_year.csv: ", nrow(pov), " rows.")

# ---- report 1: gap counts by suppression sample and event set ------------------------
count_by <- function(x, value_col, unit) {
  do.call(rbind, lapply(names(MAX_WIDTH), function(smpl) do.call(rbind, lapply(names(sets), function(flag) {
    y <- x[x$sample == smpl & x[[flag]] == 1L & !is.na(x[[value_col]]), ]
    cnt <- vapply(names(SUBJECTS), function(subj) sum(y$subject == subj), integer(1))
    data.frame(sample = smpl, event_set = sub("retained", "primary", sub("retained_", "", flag)),
               math = cnt[["math"]], rla = cnt[["rla"]], total = sum(cnt), stringsAsFactors = FALSE)
  }))))
}
say("\n== Gap counts by suppression sample and event set (end years ", min(WINDOW), "-", max(WINDOW), ")")
say("Samples: primary = exact or range <= ", MAX_WIDTH[["primary"]], " points; r5 = <= ", MAX_WIDTH[["r5"]],
    " points; exact = exact values only. Event set = districts retained under rules 1, 2 and 6 with that table.")
counts <- list(b_black_white = count_by(race, "v_bw"), c_hispanic_white = count_by(race, "v_hw"),
               a_poverty = count_by(pov, "v_pov"))
labels <- c(b_black_white = "Gap (b) Black-White: district-year-subject gaps",
            c_hispanic_white = "Gap (c) Hispanic-White: district-year-subject gaps",
            a_poverty = "Gap (a) poverty quintile 5 minus 1: state-year-subject gaps")
for (g in names(counts)) { say("\n", labels[[g]]); show(counts[[g]]) }
utils::write.csv(do.call(rbind, lapply(names(counts), function(g) cbind(gap = g, counts[[g]]))),
                 file.path(out_dir, "gap_counts.csv"), row.names = FALSE)

# ---- report 2: by end year, primary event set ------------------------------------------
by_year <- function(x, value_col) {
  y <- x[x$retained == 1L & !is.na(x[[value_col]]), ]
  tb <- table(sample = factor(y$sample, levels = names(MAX_WIDTH)), subject = y$subject,
              sy_end = factor(y$sy_end, levels = WINDOW))
  as.data.frame(tb, responseName = "gaps")
}
yr <- do.call(rbind, list(cbind(gap = "b_black_white", by_year(race, "v_bw")),
                          cbind(gap = "c_hispanic_white", by_year(race, "v_hw")),
                          cbind(gap = "a_poverty", by_year(pov, "v_pov"))))
utils::write.csv(yr, file.path(out_dir, "gap_counts_by_year.csv"), row.names = FALSE)
say("\n== Gaps by end year, primary event set")
wide <- stats::reshape(yr, idvar = c("gap", "sample", "subject"), timevar = "sy_end", direction = "wide")
names(wide) <- sub("^gaps\\.", "sy", names(wide))
show(wide[order(wide$gap, factor(wide$sample, levels = names(MAX_WIDTH)), wide$subject), ])

# ---- report 3: gap (a) coverage ----------------------------------------------------------
qd <- d[!is.na(d$pov_quintile_2009) & d$retained == 1L, ]
q_states <- sort(unique(qd$state))
say("\n== Gap (a) coverage, primary event set, primary sample")
say("States with quintile districts: ", length(q_states))
pp <- pov[pov$sample == "primary" & pov$retained == 1L, ]
miss <- do.call(rbind, lapply(names(SUBJECTS), function(subj) {
  have <- paste(pp$state[pp$subject == subj], pp$sy_end[pp$subject == subj])
  grid <- expand.grid(state = q_states, sy_end = WINDOW, stringsAsFactors = FALSE)
  grid <- grid[!paste(grid$state, grid$sy_end) %in% have, ]
  if (!nrow(grid)) return(NULL)
  ok <- gap_cells_ok(qd, subj, "all", "primary")
  grid$usable_q1 <- mapply(function(st, y) sum(ok & qd$state == st & qd$sy_end == y & qd$pov_quintile_2009 == 1L),
                           grid$state, grid$sy_end)
  grid$usable_q5 <- mapply(function(st, y) sum(ok & qd$state == st & qd$sy_end == y & qd$pov_quintile_2009 == 5L),
                           grid$state, grid$sy_end)
  cbind(subject = subj, grid)
}))
if (is.null(miss)) say("Every state-year-subject has a gap (a) row.") else {
  say("State-year-subjects with no gap (a) row (no usable district in quintile 1 or 5):")
  show(miss[order(miss$subject, miss$state, miss$sy_end), ])
  utils::write.csv(miss, file.path(out_dir, "gap_a_missing_state_years.csv"), row.names = FALSE)
}
say("Districts per quintile-5 and quintile-1 mean (primary sample, primary set): median ",
    stats::median(pp$districts_q5), " and ", stats::median(pp$districts_q1), "; minimum ",
    min(pp$districts_q5), " and ", min(pp$districts_q1), ".")

# ---- report 4: distribution of V (no treatment information) -----------------------------
desc <- function(x, value_col, gap) {
  do.call(rbind, lapply(names(MAX_WIDTH), function(smpl) do.call(rbind, lapply(names(SUBJECTS), function(subj) {
    v <- x[[value_col]][x$sample == smpl & x$subject == subj & x$retained == 1L]
    v <- v[!is.na(v)]
    data.frame(gap = gap, sample = smpl, subject = subj, n = length(v), mean = round(mean(v), 3),
               sd = round(stats::sd(v), 3), p10 = round(stats::quantile(v, 0.1, names = FALSE), 3),
               median = round(stats::median(v), 3), p90 = round(stats::quantile(v, 0.9, names = FALSE), 3))
  }))))
}
ds <- rbind(desc(race, "v_bw", "b_black_white"), desc(race, "v_hw", "c_hispanic_white"), desc(pov, "v_pov", "a_poverty"))
say("\n== Distribution of V, primary event set, pooled over end years (SD units; negative = disadvantaged group lower)")
show(ds)
utils::write.csv(ds, file.path(out_dir, "gap_distribution.csv"), row.names = FALSE)
se_med <- vapply(c("se_bw", "se_hw"), function(v) stats::median(race[[v]][race$sample == "primary"], na.rm = TRUE), numeric(1))
say("Median binomial standard error, primary sample: Black-White ", round(se_med[[1]], 3),
    ", Hispanic-White ", round(se_med[[2]], 3), " (excludes range-midpoint error).")
say("Log: ", log_file)

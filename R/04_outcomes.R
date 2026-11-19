for (f in list.files("R/functions", full.names = TRUE)) source(f)

stage <- read_stage()
WINDOW <- ach_window(stage)

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

s <- utils::read.csv("data/derived/sample_district_year.csv", colClasses = c(leaid = "character"),
                     stringsAsFactors = FALSE, na.strings = "")
stopifnot(setequal(unique(s$sy_end), WINDOW), !anyDuplicated(s[c("leaid", "sy_end")]))
for (v in as.vector(outer(names(SUBJECTS), SUBGROUPS, paste, sep = "_"))) {
  pk <- s[[paste0("part_ok_", v)]]
  stopifnot(all(is.na(pk[s$sy_end < PART_FROM])), all(pk[s$sy_end >= PART_FROM] %in% 0:1))
}

sets <- c(retained = "event_table.csv", retained_r1 = "event_table_r1.csv", retained_r2 = "event_table_r2.csv")
for (flag in names(sets)) {
  e <- utils::read.csv(file.path("data", "reference", sets[[flag]]), stringsAsFactors = FALSE)[c("state", "group")]
  stopifnot(!any(s[[flag]] == 1L & s$state %in% e$state[e$group == "excluded"]))
}

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

race <- do.call(rbind, lapply(names(MAX_WIDTH), function(smpl)
  do.call(rbind, lapply(names(SUBJECTS), function(subj) race_gaps(d, subj, smpl)))))
race <- race[order(factor(race$sample, levels = names(MAX_WIDTH)), race$state, race$leaid, race$sy_end,
                   race$subject), ]
stopifnot(!anyDuplicated(race[c("leaid", "sy_end", "subject", "sample")]))
utils::write.csv(race, "data/derived/gaps_race_district_year.csv", row.names = FALSE, na = "")
say("Wrote data/derived/gaps_race_district_year.csv: ", nrow(race), " rows.")

pov <- do.call(rbind, lapply(names(MAX_WIDTH), function(smpl)
  do.call(rbind, lapply(names(SUBJECTS), function(subj) poverty_gap(d, subj, smpl)))))
pov <- pov[order(factor(pov$sample, levels = names(MAX_WIDTH)), pov$state, pov$sy_end, pov$subject), ]
stopifnot(!anyDuplicated(pov[c("state", "sy_end", "subject", "sample")]))
utils::write.csv(pov, "data/derived/gap_poverty_state_year.csv", row.names = FALSE, na = "")
say("Wrote data/derived/gap_poverty_state_year.csv: ", nrow(pov), " rows.")

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

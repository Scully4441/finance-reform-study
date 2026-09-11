# Step 3. Sample construction (design document, Section 5; data acquisition 2.1-2.6 and 4).
# Run from the repository folder: Rscript R/03_sample.R
#
# Output: data/derived/sample_district_year.csv, one row per district-year for every
# CCD-listed agency in the 50 states and DC, with
#   leaid, state, sy_end
#   retained, reason          rules 1 and 2, a SAIPE 2009 poverty rate, and rule 6 with the
#                             primary event set (event_table.csv)
#   retained_r1, retained_r2  the same with the robustness event sets (Section 3)
#   robust_from_2013          1 for end years 2013 on: the participation robustness sample (v17)
#   agency_type, ccd_bound, boundary_change   CCD TYPE, CCD BOUND code, BOUND 5 or 8
#   saipe_pov_rate_2009, pov_quintile_2009    SAIPE 2009 child poverty; quintile 1 = lowest
#   cep                       state CEP availability (data/reference/cep_phase_in.csv, stage 1)
#   test_replaced, test_replaced_math, test_replaced_rla   data/reference/test_replacement.csv
#   part_<subj>_<sg>, part_ok_<subj>_<sg>     reported HS participation and the 95% rule on
#                                             the exact value or band midpoint, all three
#                                             samples (NA before 2012-13: retained untested)
#   n_<subj>_<sg>, cell_<subj>_<sg>           exact HS valid-test count and rule 3 status
#   w_<subj>_<sg>                             width in points of the reported percent
#                                             proficient (0 exact; NA when suppressed)
#   p_<subj>_<sg>                             percent proficient entering the gap: the exact
#                                             value or range midpoint; NA unless usable
# with subj in math, rla and sg in all, wh, bl, hi, ecd.
#
# Rules 1, 2 and 6 act on districts (retained). Rules 3 and 4 act on
# district-year-subject-subgroup cells (cell_*, part_ok_*); R/04_outcomes.R combines
# them for the subgroups in each gap. Rule 5 is carried as the test_replaced_* flags.
# Rule 3 (author decision 2026-09-11) admits ranges of 10 points or less at their
# midpoint; the robustness samples (exact values only; ranges of 5 points or less)
# are cell_in_sample() on cell_* and w_*.
# Treatment years are never read into this script; only each state's group is used.

for (f in list.files("R/functions", full.names = TRUE)) source(f)

stage <- as.integer(readLines("data/stage.txt", n = 1, warn = FALSE))
if (!identical(stage, 1L))
  stop("R/03_sample.R covers stage 1 (end years 2010-2013). Extend WINDOW and the loaders for stage 2 without changing any rule.")
WINDOW    <- 2010:2013    # stage 1 end years (data acquisition 1)
PART_FROM <- 2013L        # participation files begin with 2012-13 (design Section 5, v17)
stopifnot(max(WINDOW) <= 2013L)   # stage gate: no outcome file after 2013 is read

stamp   <- format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ")
out_dir <- "outputs/03_sample"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/logs", recursive = TRUE, showWarnings = FALSE)
dir.create("data/derived", recursive = TRUE, showWarnings = FALSE)
log_file <- file.path("outputs", "logs", paste0("03_sample_", stamp, ".log"))
say <- function(...) {
  txt <- paste0(...)
  cat(txt, "\n", sep = "")
  cat(txt, "\n", sep = "", file = log_file, append = TRUE)
}
show <- function(x) say(paste(utils::capture.output(print(x, row.names = FALSE)), collapse = "\n"))

say("Step 3 sample, run ", stamp, "; stage ", stage, "; blinding ",
    readLines("data/reference/blinding_status.txt", n = 1, warn = FALSE))

# ---- reference tables ------------------------------------------------------------
ev_files <- c(primary = "event_table.csv", r1 = "event_table_r1.csv", r2 = "event_table_r2.csv")
groups <- lapply(ev_files, function(f) {
  e <- utils::read.csv(file.path("data", "reference", f), stringsAsFactors = FALSE)
  stopifnot(setequal(e$state, names(STATE_FIPS)), !anyDuplicated(e$state),
            all(e$group %in% c("treated", "never", "excluded")))
  e[c("state", "group")]                           # treatment years are dropped here
})

tr <- utils::read.csv("data/reference/test_replacement.csv", stringsAsFactors = FALSE, na.strings = character())
cep <- utils::read.csv("data/reference/cep_phase_in.csv", stringsAsFactors = FALSE, na.strings = character())
stopifnot(all(outer(names(STATE_FIPS), WINDOW, paste) %in% paste(tr$state, tr$sy_end)),
          setequal(cep$state, names(STATE_FIPS)))

# ---- CCD LEA universe: rules 1 and 2 ---------------------------------------------
td <- tempfile("ccd"); dir.create(td)
lea <- do.call(rbind, lapply(WINDOW, function(y) {
  z <- sprintf("data/raw/ccd/lea-directory-sy%d-%02d.zip", y - 1L, y %% 100L)
  read_ccd_lea(utils::unzip(z, exdir = td), y)
}))
lea$state <- fips_to_state(lea$fipst)
n_outside <- length(unique(lea$leaid[is.na(lea$state)]))
lea <- lea[!is.na(lea$state), ]

dr <- district_rules(lea, WINDOW)
dr$state <- fips_to_state(substr(dr$leaid, 1, 2))

# ---- SAIPE 2009 poverty and quintiles --------------------------------------------
# A district passing rules 1 and 2 with no SAIPE 2009 rate (absent from the file, or
# no children 5-17) is dropped before rule 6 (author decision 2026-09-11).
NO_SAIPE <- "no SAIPE 2009 poverty rate"
saipe <- read_saipe("data/raw/saipe/saipe-district-2009.txt")
hs_2009 <- lea$leaid[lea$sy_end == 2010L & lea$gshi == "12"]   # 2009-10 grade span reaches 12
dr$saipe_pov_rate_2009 <- saipe$pov_rate[match(dr$leaid, saipe$leaid)]
dr$in_saipe_file <- dr$leaid %in% saipe$leaid
in_q <- dr$rule12 == "pass" & dr$leaid %in% hs_2009 & !is.na(dr$saipe_pov_rate_2009)
dr$pov_quintile_2009 <- NA_integer_
dr$pov_quintile_2009[in_q] <- poverty_quintile(dr$state[in_q], dr$saipe_pov_rate_2009[in_q], dr$leaid[in_q])

reason_for <- function(set) {
  grp <- groups[[set]]$group[match(dr$state, groups[[set]]$state)]
  ifelse(dr$rule12 != "pass", dr$rule12,
         ifelse(is.na(dr$saipe_pov_rate_2009), NO_SAIPE,
                ifelse(grp == "excluded", "rule 6: state excluded (reform in 2005-2009)", "retained")))
}
for (set in names(groups)) dr[[paste0("reason_", set)]] <- reason_for(set)

# ---- district-year frame -----------------------------------------------------------
smp <- lea[c("leaid", "state", "sy_end", "agency_type", "ccd_bound")]
k <- match(smp$leaid, dr$leaid)
smp$retained    <- as.integer(dr$reason_primary[k] == "retained")
smp$reason      <- dr$reason_primary[k]
smp$retained_r1 <- as.integer(dr$reason_r1[k] == "retained")
smp$retained_r2 <- as.integer(dr$reason_r2[k] == "retained")
smp$robust_from_2013 <- as.integer(smp$sy_end >= PART_FROM)
smp$boundary_change  <- as.integer(smp$ccd_bound %in% BOUND_CHANGE)
smp$saipe_pov_rate_2009 <- dr$saipe_pov_rate_2009[k]
smp$pov_quintile_2009   <- dr$pov_quintile_2009[k]
smp$cep <- as.integer(smp$sy_end >= cep$first_cep_sy_end[match(smp$state, cep$state)])
kt <- match(paste(smp$state, smp$sy_end), paste(tr$state, tr$sy_end))
smp$test_replaced      <- tr$replaced[kt]
smp$test_replaced_math <- tr$replaced_math[kt]
smp$test_replaced_rla  <- tr$replaced_rla[kt]

# ---- EDFacts high school cells: rules 3 and 4 ------------------------------------
edf <- lapply(WINDOW, function(y) {
  yr <- NULL
  for (subj in names(SUBJECTS)) {
    f <- sprintf("data/raw/edfacts/%s-achievement-lea-sy%d-%02d.csv", subj, y - 1L, y %% 100L)
    a <- read_edfacts_hs(f, subj, y, "achievement")
    x <- data.frame(leaid = a$leaid, stringsAsFactors = FALSE)
    for (s in SUBGROUPS) {
      n_raw <- a[[paste0("n_", s)]]
      p_raw <- a[[paste0("p_", s)]]
      st <- cell_status(n_raw, p_raw)
      r  <- edfacts_range(p_raw)
      x[[paste0("n_", subj, "_", s)]]    <- edfacts_exact(n_raw)
      x[[paste0("p_", subj, "_", s)]]    <- ifelse(st == "usable", r$mid, NA_real_)
      x[[paste0("w_", subj, "_", s)]]    <- r$width
      x[[paste0("cell_", subj, "_", s)]] <- st
    }
    if (y >= PART_FROM) {
      pf <- sprintf("data/raw/edfacts/%s-participation-lea-sy%d-%02d.csv", subj, y - 1L, y %% 100L)
      p <- read_edfacts_hs(pf, subj, y, "participation")
      pp <- data.frame(leaid = p$leaid, stringsAsFactors = FALSE)
      for (s in SUBGROUPS) pp[[paste0("part_", subj, "_", s)]] <- trimws(p[[paste0("part_", s)]])
      x <- merge(x, pp, by = "leaid", all.x = TRUE)
    } else {
      for (s in SUBGROUPS) x[[paste0("part_", subj, "_", s)]] <- NA_character_
    }
    yr <- if (is.null(yr)) x else merge(yr, x, by = "leaid", all = TRUE)
  }
  yr$sy_end <- y
  yr
})
edf <- do.call(rbind, edf)

has_hs <- Reduce(`|`, lapply(grep("^n_", names(edf), value = TRUE), function(v) !is.na(edf[[v]])))
edf_unmatched <- unique(edf$leaid[has_hs & !paste(edf$leaid, edf$sy_end) %in% paste(smp$leaid, smp$sy_end)])

smp <- merge(smp, edf, by = c("leaid", "sy_end"), all.x = TRUE, sort = FALSE)
for (subj in names(SUBJECTS)) for (s in SUBGROUPS) {
  cv <- paste0("cell_", subj, "_", s)
  smp[[cv]][is.na(smp[[cv]])] <- "not_reported"
  pv <- paste0("part_", subj, "_", s)
  smp[[paste0("part_ok_", subj, "_", s)]] <-
    ifelse(smp$sy_end >= PART_FROM, as.integer(part_pass(smp[[pv]])), NA_integer_)
  # The exact-only sample keeps exact participation values (author decision 2026-09-11).
  # Its cells report participation exactly or as GE99/LE1 (width 1), where the
  # midpoint test gives the same answer; a wider band there needs an author decision.
  k  <- smp$sy_end >= PART_FROM & cell_in_sample(smp[[cv]], smp[[paste0("w_", subj, "_", s)]], "exact")
  pw <- edfacts_range(smp[[pv]][k])$width
  if (any(!is.na(pw) & pw > 1))
    stop("exact-only sample: participation band wider than 1 point in ", sum(!is.na(pw) & pw > 1),
         " ", subj, " ", s, " cells; the participation rule for that sample needs an author decision")
}

cols <- c("leaid", "state", "sy_end", "retained", "reason", "retained_r1", "retained_r2",
          "robust_from_2013", "agency_type", "ccd_bound", "boundary_change",
          "saipe_pov_rate_2009", "pov_quintile_2009", "cep",
          "test_replaced", "test_replaced_math", "test_replaced_rla",
          as.vector(outer(c("part_", "part_ok_"), outer(names(SUBJECTS), SUBGROUPS, paste, sep = "_"), paste0)),
          as.vector(outer(c("n_", "p_", "w_", "cell_"), outer(names(SUBJECTS), SUBGROUPS, paste, sep = "_"), paste0)))
smp <- smp[order(smp$state, smp$leaid, smp$sy_end), cols]
stopifnot(!anyDuplicated(smp[c("leaid", "sy_end")]))
out_file <- "data/derived/sample_district_year.csv"
utils::write.csv(smp, out_file, row.names = FALSE, na = "")
say("Wrote ", out_file, ": ", nrow(smp), " district-years, ", length(unique(smp$leaid)), " districts, ",
    ncol(smp), " columns.")

# ---- report 1: districts retained by each rule -----------------------------------
say("\n== Districts retained by each rule (end years ", min(WINDOW), "-", max(WINDOW), ")")
say("CCD agencies outside the 50 states and DC, dropped before the rules: ", n_outside)
n0 <- nrow(dr)
n1 <- sum(dr$rule12 != "rule 1: agency type not 1 or 2")
n2 <- sum(!dr$rule12 %in% c("rule 1: agency type not 1 or 2", "rule 2: not operational in every window year"))
n3 <- sum(dr$rule12 == "pass")
n4 <- sum(dr$rule12 == "pass" & !is.na(dr$saipe_pov_rate_2009))
steps <- data.frame(
  rule = c("CCD agencies in the 50 states and DC", "rule 1: agency type 1 or 2 in every year",
           "rule 2: operational in every window year", "rule 2: no boundary change (BOUND 5 or 8)",
           "SAIPE 2009 poverty rate present",
           "rule 6: primary event set", "rule 6: robustness set r1", "rule 6: robustness set r2"),
  districts = c(n0, n1, n2, n3, n4, sum(dr$reason_primary == "retained"),
                sum(dr$reason_r1 == "retained"), sum(dr$reason_r2 == "retained")))
steps$removed <- c(NA, -diff(steps$districts[1:5]), n4 - steps$districts[6:8])
show(steps)
utils::write.csv(steps, file.path(out_dir, "districts_by_rule.csv"), row.names = FALSE, na = "")

bc <- dr$leaid[dr$rule12 == "rule 2: boundary change (BOUND 5 or 8)"]
b5 <- unique(lea$leaid[lea$sy_end %in% WINDOW & lea$ccd_bound == 5L])
say("Boundary-change exclusions: ", length(bc), " (BOUND 5 in a window year: ", sum(bc %in% b5),
    "; BOUND 8 and never 5: ", sum(!bc %in% b5), ")")
ns <- dr[dr$rule12 == "pass" & is.na(dr$saipe_pov_rate_2009), ]
say("Districts passing rules 1 and 2 with no SAIPE 2009 poverty rate, dropped: ", nrow(ns),
    " (absent from the SAIPE file: ", sum(!ns$in_saipe_file), "; no children 5-17: ", sum(ns$in_saipe_file), ")")
kept_by <- vapply(names(groups), function(set)
  sum(groups[[set]]$group[match(ns$state, groups[[set]]$state)] != "excluded"), integer(1))
say("  of which in states that rule 6 keeps: ", paste(names(kept_by), kept_by, collapse = ", "))
utils::write.csv(ns[c("leaid", "state", "in_saipe_file")], file.path(out_dir, "no_saipe_2009.csv"), row.names = FALSE)
ret <- smp[smp$retained == 1L, ]
say("States with retained districts (primary set): ", length(unique(ret$state)))
say("Retained districts in the poverty-quintile set (grade span to 12 in 2009-10, SAIPE 2009 rate): ",
    sum(in_q & dr$reason_primary == "retained"))
few <- tapply(in_q & dr$reason_primary == "retained", dr$state, sum)
few <- few[names(few) %in% unique(ret$state) & few < 5]
if (length(few)) say("States with fewer than five quintile districts (no bottom quintile can form): ",
                     paste(sprintf("%s (%d)", names(few), few), collapse = ", "))
say("EDFacts LEAIDs with HS counts but no CCD row in the 50 states and DC that year: ", length(edf_unmatched))

# ---- report 2: EDFacts range widths by tested-count bracket ----------------------
say("\n== Width in points of the reported HS percent proficient, by tested-count bracket, ", min(WINDOW), "-",
    max(WINDOW))
say("Every LEA in the EDFacts files in the 50 states and DC with an exact valid-test count; subgroups ",
    paste(SUBGROUPS, collapse = " "), "; math and RLA. Width 0 = exact value; none = PS, N/A or blank.")
in_us <- substr(edf$leaid, 1, 2) %in% STATE_FIPS
cw <- do.call(rbind, lapply(names(SUBJECTS), function(subj) do.call(rbind, lapply(SUBGROUPS, function(s)
  data.frame(sy_end = edf$sy_end[in_us], n = edf[[paste0("n_", subj, "_", s)]][in_us],
             w = edf[[paste0("w_", subj, "_", s)]][in_us])))))
cw <- cw[!is.na(cw$n), ]
cw$bracket <- cut(cw$n, c(-Inf, 0, 5, 15, 30, 60, 300, Inf),
                  labels = c("0", "1-5", "6-15", "16-30", "31-60", "61-300", "301+"))
cw$width <- factor(ifelse(is.na(cw$w), "none", as.character(cw$w)),
                   levels = c(as.character(sort(unique(cw$w))), "none"))
for (y in WINDOW) {
  say("End year ", y, ":")
  say(paste(utils::capture.output(print(table(bracket = cw$bracket[cw$sy_end == y],
                                              width = cw$width[cw$sy_end == y]))), collapse = "\n"))
}
rw <- as.data.frame(table(sy_end = cw$sy_end, bracket = cw$bracket, width = cw$width), responseName = "cells")
utils::write.csv(rw[rw$cells > 0, ], file.path(out_dir, "range_widths_by_bracket.csv"), row.names = FALSE)

# ---- report 3: cells lost to suppression (rule 3) --------------------------------
say("\n== HS cells lost to suppression, retained districts (primary set), ", min(WINDOW), "-", max(WINDOW))
say("Each cell is one district-year-subject-subgroup. not_reported: no count in EDFacts (includes districts",
    " without high school grades); below_30: exact count under 30; suppressed: count >= 30, percent",
    " proficient not reported; wide_range: count >= 30, percent proficient a range wider than ",
    MAX_WIDTH[["primary"]], " points; usable: exact or a range of ", MAX_WIDTH[["primary"]],
    " points or less (primary). usable_r5 and usable_exact: the robustness samples.")
status_levels <- c("not_reported", "below_30", "suppressed", "wide_range", "usable")
supp <- do.call(rbind, lapply(names(SUBJECTS), function(subj) do.call(rbind, lapply(SUBGROUPS, function(s) {
  do.call(rbind, lapply(WINDOW, function(y) {
    v  <- ret[[paste0("cell_", subj, "_", s)]][ret$sy_end == y]
    wv <- ret[[paste0("w_", subj, "_", s)]][ret$sy_end == y]
    tb <- table(factor(v, levels = status_levels))
    data.frame(subject = subj, subgroup = s, sy_end = y, cells = length(v), t(as.vector(tb)),
               usable_r5 = sum(cell_in_sample(v, wv, "r5")), usable_exact = sum(cell_in_sample(v, wv, "exact")))
  }))
}))))
names(supp)[5:9] <- status_levels
utils::write.csv(supp, file.path(out_dir, "cells_by_status.csv"), row.names = FALSE)
tot <- aggregate(supp[c("cells", status_levels, "usable_r5", "usable_exact")], supp[c("subject", "subgroup")], sum)
tot$subgroup <- factor(tot$subgroup, levels = SUBGROUPS)
show(tot[order(tot$subject, tot$subgroup), ])

gap_pairs <- list(a_all = "all", b_black_white = c("wh", "bl"), c_hispanic_white = c("wh", "hi"))
usable_gap <- function(d, subj, sgs, with_part, sample = "primary") {
  ok <- Reduce(`&`, lapply(sgs, function(s)
    cell_in_sample(d[[paste0("cell_", subj, "_", s)]], d[[paste0("w_", subj, "_", s)]], sample)))
  if (with_part) {
    pk <- Reduce(`&`, lapply(sgs, function(s) is.na(d[[paste0("part_ok_", subj, "_", s)]]) |
                                               d[[paste0("part_ok_", subj, "_", s)]] == 1L))
    ok <- ok & pk
  }
  ok
}
say("\nUsable district-years, retained districts (primary set): every subgroup of the gap in the sample",
    " under rule 3. sy", PART_FROM, "_part also applies the participation rule.")
say("Samples: primary = exact or range <= ", MAX_WIDTH[["primary"]], " points; r5 = exact or range <= ",
    MAX_WIDTH[["r5"]], " points; exact = exact values only.")
gy <- do.call(rbind, lapply(names(MAX_WIDTH), function(smpl) do.call(rbind, lapply(names(gap_pairs), function(g)
  do.call(rbind, lapply(names(SUBJECTS), function(subj) {
    cnt <- vapply(WINDOW, function(y) sum(usable_gap(ret[ret$sy_end == y, ], subj, gap_pairs[[g]], FALSE, smpl)),
                  integer(1))
    data.frame(sample = smpl, gap = g, subject = subj, t(cnt),
               part = sum(usable_gap(ret[ret$sy_end == PART_FROM, ], subj, gap_pairs[[g]], TRUE, smpl)))
  }))))))
names(gy) <- c("sample", "gap", "subject", paste0("sy", WINDOW), paste0("sy", PART_FROM, "_part"))
show(gy)
utils::write.csv(gy, file.path(out_dir, "usable_gap_district_years.csv"), row.names = FALSE)

# ---- report 4: participation (rule 4) ----------------------------------------------
say("\n== Participation rule, retained districts (primary set)")
say("End years ", min(WINDOW), "-", PART_FROM - 1L, ": no participation file; retained without the test.")
say("From ", PART_FROM, ": the exact value or band midpoint must be at least 95 (GE90 passes, 90-94 fails).")
r13 <- ret[ret$sy_end == PART_FROM, ]
pc <- do.call(rbind, lapply(names(SUBJECTS), function(subj) do.call(rbind, lapply(SUBGROUPS, function(s) {
  u <- r13[[paste0("cell_", subj, "_", s)]] == "usable"
  pv <- part_value(r13[[paste0("part_", subj, "_", s)]])
  data.frame(subject = subj, subgroup = s, usable_cells = sum(u), pass = sum(u & !is.na(pv) & pv >= 95),
             fail_reported_below_95 = sum(u & !is.na(pv) & pv < 95), fail_not_reported = sum(u & is.na(pv)))
}))))
say("Cells usable under rule 3 in ", PART_FROM, ", by participation outcome:")
show(pc)
utils::write.csv(pc, file.path(out_dir, paste0("participation_cells_", PART_FROM, ".csv")), row.names = FALSE)

sy_lost <- do.call(rbind, lapply(names(gap_pairs), function(g) do.call(rbind, lapply(names(SUBJECTS), function(subj) {
  before <- usable_gap(r13, subj, gap_pairs[[g]], FALSE)
  after  <- usable_gap(r13, subj, gap_pairs[[g]], TRUE)
  b <- tapply(before, r13$state, sum); a <- tapply(after, r13$state, sum)
  lost <- names(b)[b > 0 & a == 0]
  data.frame(gap = g, subject = subj, district_cells_before = sum(before), district_cells_after = sum(after),
             states_with_cells_before = sum(b > 0), state_years_lost = length(lost),
             states_lost = paste(lost, collapse = " "))
}))))
say("\nState-years lost to participation in ", PART_FROM, " (state had at least one usable district cell",
    " for the gap before the rule and none after):")
show(sy_lost)
utils::write.csv(sy_lost, file.path(out_dir, paste0("participation_state_years_", PART_FROM, ".csv")), row.names = FALSE)

no_part <- tapply(is.na(part_value(r13$part_math_all)) & is.na(part_value(r13$part_rla_all)),
                  r13$state, all)
if (any(no_part)) say("States reporting no HS all-students participation for any retained district in ",
                      PART_FROM, ": ", paste(names(no_part)[no_part], collapse = " "))

say("\nRobustness sample (end years ", PART_FROM, " on): ", sum(smp$retained == 1L & smp$robust_from_2013 == 1L),
    " retained district-years of ", sum(smp$retained == 1L), ".")
say("Log: ", log_file)

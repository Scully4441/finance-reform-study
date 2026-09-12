# Step 3g. Sample for the secondary graduation outcome (design v18, Sections 5 and 6;
# docs/deviations.md 2026-09-12; data acquisition 5.2).
# Run from the repository folder: Rscript R/03g_graduation_sample.R
#
# Output: data/derived/graduation_sample_district_year.csv, one row per district-year
# for every CCD-listed agency in the 50 states and DC, end years 2011-2021, with
#   leaid, state, sy_end
#   retained, reason          rules 1 and 2 over end years 2010-2021, a SAIPE 2009 poverty
#                             rate, and rule 6 with the primary event set
#   retained_r1, retained_r2  the same with the robustness event sets
#   agency_type, ccd_bound    CCD TYPE and BOUND; LEA_TYPE and UPDATED_STATUS from 2014-15
#   saipe_pov_rate_2009       SAIPE 2009 child poverty (a covariate in steps 5 and 6)
#   cep                       the step 3 CEP indicator (cep_indicator())
#   n_<sg>, cell_<sg>         exact four-year ACGR cohort count and rule 3 status
#   w_<sg>                    width in points of the reported rate (0 exact; NA suppressed)
#   p_<sg>                    rate entering the gap, percent: exact value or range midpoint
# with sg in wh, bl, hi.
#
# Rules (R/functions/graduation.R header; author decisions 2026-09-12):
#   Rule 1 and 2 over end years 2010-2021 (GRAD_RULES_WINDOW), with LEA_TYPE and
#   UPDATED_STATUS standing in for TYPE and BOUND from 2014-15 on. Rule 3 with the cohort
#   count as the count: exact and at least 30, the rate exact or a range of 10 points or
#   less at its midpoint (r5 and exact robustness samples through cell_in_sample()).
#   Rule 4 does not apply. Rule 6 from the event tables' groups, as in step 3. A district
#   passing rules 1 and 2 without a SAIPE 2009 rate is dropped (rule 7).
# The graduation files for end years 2022-2024 were never published at LEA level; the
# loader lists them and the window stops at 2021 (deviation 2026-09-12).
# Treatment years are never read into this script; only each state's group is used.

for (f in list.files("R/functions", full.names = TRUE)) source(f)

stage <- as.integer(readLines("data/stage.txt", n = 1, warn = FALSE))
if (!identical(stage, 2L))
  stop("R/03g_graduation_sample.R reads graduation files after 2012-13, which stage 1 does not allow.")
WINDOW <- GRAD_WINDOW
RULES_WINDOW <- GRAD_RULES_WINDOW

stamp   <- format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ")
out_dir <- "outputs/03g_graduation_sample"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/logs", recursive = TRUE, showWarnings = FALSE)
dir.create("data/derived", recursive = TRUE, showWarnings = FALSE)
log_file <- file.path("outputs", "logs", paste0("03g_graduation_sample_", stamp, ".log"))
say <- function(...) {
  txt <- paste0(...)
  cat(txt, "\n", sep = "")
  cat(txt, "\n", sep = "", file = log_file, append = TRUE)
}
show <- function(x) say(paste(utils::capture.output(print(x, row.names = FALSE)), collapse = "\n"))

say("Step 3g graduation sample, run ", stamp, "; stage ", stage, "; blinding ",
    readLines("data/reference/blinding_status.txt", n = 1, warn = FALSE))

# ---- reference tables ------------------------------------------------------------
ev_files <- c(primary = "event_table.csv", r1 = "event_table_r1.csv", r2 = "event_table_r2.csv")
groups <- lapply(ev_files, function(f) {
  e <- utils::read.csv(file.path("data", "reference", f), stringsAsFactors = FALSE)
  stopifnot(setequal(e$state, names(STATE_FIPS)), !anyDuplicated(e$state),
            all(e$group %in% c("treated", "never", "excluded")))
  e[c("state", "group")]                           # treatment years are dropped here
})

# ---- CCD: rules 1 and 2 over 2010-2021 --------------------------------------------
lea <- do.call(rbind, lapply(RULES_WINDOW, read_ccd_lea_year))
lea$state <- fips_to_state(lea$fipst)
n_outside <- length(unique(lea$leaid[is.na(lea$state)]))
lea <- lea[!is.na(lea$state), ]
dr <- district_rules(lea, RULES_WINDOW)
dr$state <- fips_to_state(substr(dr$leaid, 1, 2))

saipe <- read_saipe("data/raw/saipe/saipe-district-2009.txt")
dr$saipe_pov_rate_2009 <- saipe$pov_rate[match(dr$leaid, saipe$leaid)]
reason_for <- function(set) {
  grp <- groups[[set]]$group[match(dr$state, groups[[set]]$state)]
  ifelse(dr$rule12 != "pass", dr$rule12,
         ifelse(is.na(dr$saipe_pov_rate_2009), "no SAIPE 2009 poverty rate",
                ifelse(grp == "excluded", "rule 6: state excluded (reform in 2005-2009)", "retained")))
}
for (set in names(groups)) dr[[paste0("reason_", set)]] <- reason_for(set)

# ---- ACGR cells: rule 3 ------------------------------------------------------------
acgr <- load_acgr(GRAD_FILE_YEARS)
say("Graduation LEA files read for end years ", paste(acgr$published, collapse = " "),
    "; none published for ", paste(acgr$unpublished, collapse = " "), " (docs/deviations.md, 2026-09-12)")
stopifnot(setequal(acgr$published, WINDOW))
cells <- grad_cells(acgr$data)

smp <- lea[lea$sy_end %in% WINDOW, c("leaid", "state", "sy_end", "agency_type", "ccd_bound")]
k <- match(smp$leaid, dr$leaid)
smp$retained    <- as.integer(dr$reason_primary[k] == "retained")
smp$reason      <- dr$reason_primary[k]
smp$retained_r1 <- as.integer(dr$reason_r1[k] == "retained")
smp$retained_r2 <- as.integer(dr$reason_r2[k] == "retained")
smp$saipe_pov_rate_2009 <- dr$saipe_pov_rate_2009[k]
smp$cep <- cep_indicator(smp$leaid, smp$state, smp$sy_end)

in_us <- substr(cells$leaid, 1, 2) %in% STATE_FIPS
has_n <- Reduce(`|`, lapply(GRAD_SUBGROUPS, function(s) !is.na(cells[[paste0("n_", s)]])))
acgr_unmatched <- unique(cells$leaid[in_us & has_n & !paste(cells$leaid, cells$sy_end) %in% paste(smp$leaid, smp$sy_end)])
smp <- merge(smp, cells, by = c("leaid", "sy_end"), all.x = TRUE, sort = FALSE)
for (s in GRAD_SUBGROUPS) {
  cv <- paste0("cell_", s)
  smp[[cv]][is.na(smp[[cv]])] <- "not_reported"
}

cols <- c("leaid", "state", "sy_end", "retained", "reason", "retained_r1", "retained_r2",
          "agency_type", "ccd_bound", "saipe_pov_rate_2009", "cep",
          as.vector(outer(c("n_", "p_", "w_", "cell_"), GRAD_SUBGROUPS, paste0)))
smp <- smp[order(smp$state, smp$leaid, smp$sy_end), cols]
stopifnot(!anyDuplicated(smp[c("leaid", "sy_end")]), all(smp$cep %in% 0:1))
out_file <- "data/derived/graduation_sample_district_year.csv"
utils::write.csv(smp, out_file, row.names = FALSE, na = "")
say("Wrote ", out_file, ": ", nrow(smp), " district-years, ", length(unique(smp$leaid)), " districts, ",
    ncol(smp), " columns.")

# ---- report 1: districts retained by each rule -------------------------------------
say("\n== Districts retained by each rule (rules 1 and 2 over end years ", min(RULES_WINDOW), "-",
    max(RULES_WINDOW), ")")
say("CCD agencies outside the 50 states and DC, dropped before the rules: ", n_outside)
n0 <- nrow(dr)
n1 <- sum(dr$rule12 != "rule 1: agency type not 1 or 2")
n2 <- sum(!dr$rule12 %in% c("rule 1: agency type not 1 or 2", "rule 2: not operational in every window year"))
n3 <- sum(dr$rule12 == "pass")
n4 <- sum(dr$rule12 == "pass" & !is.na(dr$saipe_pov_rate_2009))
steps <- data.frame(
  rule = c("CCD agencies in the 50 states and DC", "rule 1: agency type 1 or 2 in every year",
           "rule 2: operational in every rules year", "rule 2: no boundary change (code 5 or 8)",
           "SAIPE 2009 poverty rate present",
           "rule 6: primary event set", "rule 6: robustness set r1", "rule 6: robustness set r2"),
  districts = c(n0, n1, n2, n3, n4, sum(dr$reason_primary == "retained"),
                sum(dr$reason_r1 == "retained"), sum(dr$reason_r2 == "retained")))
steps$removed <- c(NA, -diff(steps$districts[1:5]), n4 - steps$districts[6:8])
show(steps)
utils::write.csv(steps, file.path(out_dir, "districts_by_rule.csv"), row.names = FALSE, na = "")
t9 <- unique(lea$leaid[lea$agency_type == 9L])
t9_only <- dr$leaid[dr$rule12 == "rule 1: agency type not 1 or 2" &
                      dr$leaid %in% t9 & dr$leaid %in% lea$leaid[lea$agency_type %in% 1:2]]
say("Rule 1 failures that were type 1 or 2 in some year and LEA_TYPE 9 (specialized district, from 2019-20) in another: ",
    length(t9_only))
say("ACGR LEAIDs with a cohort count but no CCD row in the 50 states and DC that year: ", length(acgr_unmatched))

# ---- report 2: rate widths by cohort bracket -----------------------------------------
say("\n== Width in points of the reported four-year ACGR, by cohort-count bracket")
say("Every LEA in the files in the 50 states and DC with an exact cohort count; subgroups wh bl hi.",
    " Width 0 = exact value; none = PS, S or blank.")
cw <- do.call(rbind, lapply(GRAD_SUBGROUPS, function(s)
  data.frame(sy_end = cells$sy_end[in_us], n = cells[[paste0("n_", s)]][in_us], w = cells[[paste0("w_", s)]][in_us])))
cw <- cw[!is.na(cw$n), ]
cw$bracket <- cut(cw$n, c(-Inf, 0, 5, 15, 30, 60, 300, Inf),
                  labels = c("0", "1-5", "6-15", "16-30", "31-60", "61-300", "301+"))
cw$width <- factor(ifelse(is.na(cw$w), "none", as.character(cw$w)),
                   levels = c(as.character(sort(unique(cw$w))), "none"))
say(paste(utils::capture.output(print(table(bracket = cw$bracket, width = cw$width))), collapse = "\n"))
rw <- as.data.frame(table(sy_end = cw$sy_end, bracket = cw$bracket, width = cw$width), responseName = "cells")
utils::write.csv(rw[rw$cells > 0, ], file.path(out_dir, "range_widths_by_bracket.csv"), row.names = FALSE)

# ---- report 3: cells by rule 3 status, retained districts ------------------------------
ret <- smp[smp$retained == 1L, ]
status_levels <- c("not_reported", "below_30", "suppressed", "wide_range", "usable")
supp <- do.call(rbind, lapply(GRAD_SUBGROUPS, function(s) do.call(rbind, lapply(WINDOW, function(y) {
  v <- ret[[paste0("cell_", s)]][ret$sy_end == y]; wv <- ret[[paste0("w_", s)]][ret$sy_end == y]
  data.frame(subgroup = s, sy_end = y, cells = length(v), t(as.vector(table(factor(v, levels = status_levels)))),
             usable_r5 = sum(cell_in_sample(v, wv, "r5")), usable_exact = sum(cell_in_sample(v, wv, "exact")))
}))))
names(supp)[4:8] <- status_levels
utils::write.csv(supp, file.path(out_dir, "cells_by_status.csv"), row.names = FALSE)
say("\n== Graduation cells by rule 3 status, retained districts (primary set), end years ", min(WINDOW), "-", max(WINDOW))
tot <- aggregate(supp[c("cells", status_levels, "usable_r5", "usable_exact")], supp["subgroup"], sum)
show(tot)

# ---- report 4: usable gap district-years by year --------------------------------------
gy <- do.call(rbind, lapply(names(MAX_WIDTH), function(smpl) do.call(rbind, lapply(names(GRAD_GAPS), function(g) {
  sg <- RACE_GAPS[[GRAD_GAPS[[g]]]]
  do.call(rbind, lapply(c(primary = "retained", r1 = "retained_r1", r2 = "retained_r2"), function(flag) {
    x <- smp[smp[[flag]] == 1L, ]
    ok <- Reduce(`&`, lapply(sg, function(s) cell_in_sample(x[[paste0("cell_", s)]], x[[paste0("w_", s)]], smpl)))
    cnt <- vapply(WINDOW, function(y) sum(ok & x$sy_end == y), integer(1))
    data.frame(sample = smpl, gap = g, event_set = sub("retained_?", "", flag), t(cnt), total = sum(cnt))
  }))
}))))
gy$event_set[gy$event_set == ""] <- "primary"
names(gy) <- c("sample", "gap", "event_set", paste0("sy", WINDOW), "total")
utils::write.csv(gy, file.path(out_dir, "usable_gap_district_years.csv"), row.names = FALSE)
say("\n== District-years with a usable graduation gap (both groups in the sample under rule 3), by end year")
show(gy)
say("Log: ", log_file)

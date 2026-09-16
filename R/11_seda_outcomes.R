# Step 11 (Run 2). SEDA grades 3-8 outcomes (docs/design_extension.md, Sections 3, 5 and 6).
# Run from the repository folder: Rscript R/11_seda_outcomes.R
#
# Inputs
#   data/raw/seda/seda_admindist_long_cs_2025.2.csv   SEDA 2025.2, CS scale (data use agreement)
#   data/raw/ccd/lea-directory-sy*.zip                 rules 1 and 2; 2009-10 grade span and membership
#   data/raw/saipe/saipe-district-2009.txt             rule 7 and the poverty quintiles
#   data/reference/event_table*.csv                    rule 6 (each state's group only)
# Output
#   data/derived/seda_gaps.csv, one row per gap and unit-year with at least one subject gap,
#   for units retained under at least one event set. Never deposited (Section 4: district-level
#   files derived from SEDA fall under the data use agreement).
#     gap                       a_poverty, b_black_white, c_hispanic_white
#     state, leaid, sy_end      leaid blank for gap (a), a state-year
#     seda_public_edc           1 for end years 2022-2025, which SEDA builds from public EDC
#                               data, 0 for 2009-2019 (Section 6 source indicator)
#     retained, retained_r1, retained_r2   rules 1, 2, 6 and 7 with each event set; for gap (a)
#                               the state is not excluded under that set
#     v                         mean of the math and RLA gaps, NA unless both are present
#     v_<subj>, se_<subj>       the subject gap in national SD units and its standard error
#     (b), (c): mean_<all|group|wh>_<subj>, se_..., grades_...   pooled all-students, group
#                               (Black or Hispanic) and White means, their standard errors and
#                               the number of grades pooled
#     (a): mean_q5_<subj>, mean_q1_<subj>, districts_q5_<subj>, districts_q1_<subj>
#   outputs/11_seda_outcomes/*.csv and outputs/logs/11_seda_outcomes_<stamp>.log: counts only
#
# Rules (Section 5; author decisions 2026-09-16, docs/deviations_run2.md):
#   Run 1 rules 1 and 2 (district_rules()) over SEDA_RULES_WINDOW, the SEDA end years with a
#   CCD LEA directory file (2010-2019, 2022-2024); rule 7, a SAIPE 2009 rate; rule 6, the
#   state's group in each event table. Rules 3, 4 and 5 do not apply to SEDA.
#   Pooling over grades 3-8 with weights 1 / se^2 on SEDA's unadjusted standard errors.
#   Gap (a) quintiles: SAIPE 2009 rate within state (poverty_quintile()) among districts
#   passing rules 1 and 2 with a SAIPE rate and a 2009-10 grade span including a grade 3-8;
#   weight 2009-10 CCD membership, fixed.
# No district-level value is written to the log.

for (f in list.files("R/functions", full.names = TRUE)) source(f)

stage2 <- as.integer(readLines("data/stage_run2.txt", n = 1, warn = FALSE))
if (!identical(stage2, 2L)) stop("R/11_seda_outcomes.R reads a Run 2 outcome file, which needs data/stage_run2.txt = 2.")

stamp   <- format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ")
out_dir <- "outputs/11_seda_outcomes"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/logs", recursive = TRUE, showWarnings = FALSE)
dir.create("data/derived", recursive = TRUE, showWarnings = FALSE)
log_file <- file.path("outputs", "logs", paste0("11_seda_outcomes_", stamp, ".log"))
say <- function(...) {
  txt <- paste0(...)
  cat(txt, "\n", sep = "")
  cat(txt, "\n", sep = "", file = log_file, append = TRUE)
}
show <- function(x) say(paste(utils::capture.output(print(x, row.names = FALSE)), collapse = "\n"))

say("Step 11 SEDA outcomes, run ", stamp, "; stage_run2 ", stage2, "; blinding ",
    readLines("data/reference/blinding_status.txt", n = 1, warn = FALSE))

# ---- event-set groups (rule 6) ---------------------------------------------------------
sets <- c(retained = "event_table.csv", retained_r1 = "event_table_r1.csv", retained_r2 = "event_table_r2.csv")
groups <- lapply(sets, function(f) {
  e <- utils::read.csv(file.path("data", "reference", f), stringsAsFactors = FALSE)
  stopifnot(setequal(e$state, names(STATE_FIPS)), !anyDuplicated(e$state),
            all(e$group %in% c("treated", "never", "excluded")))
  e[c("state", "group")]
})

# ---- SEDA long file and pooling --------------------------------------------------------
seda <- read_seda_long()
say("SEDA long file: ", nrow(seda), " district-subject-grade-years, ", length(unique(seda$leaid)), " units")
in_us <- substr(seda$leaid, 1, 2) %in% STATE_FIPS
say("Units outside the 50 states and DC (e.g. BIE), dropped: ", length(unique(seda$leaid[!in_us])))
seda <- seda[in_us, ]
stopifnot(all(seda$state == fips_to_state(substr(seda$leaid, 1, 2))))
no_se <- vapply(names(SEDA_SUBGROUPS), function(sg)
  sum(!is.na(seda[[paste0("mn_", sg)]]) & is.na(seda[[paste0("se_", sg)]])), integer(1))
say("Grade means with no unadjusted standard error, left out of the pool: ",
    paste(names(no_se), no_se, sep = " ", collapse = ", "))
p <- seda_pool(seda)
say("Pooled district-year-subjects: ", nrow(p))

# ---- rules 1, 2 and 7 ------------------------------------------------------------------
lea <- do.call(rbind, lapply(SEDA_RULES_WINDOW, read_ccd_lea_year))
lea$state <- fips_to_state(lea$fipst)
lea <- lea[!is.na(lea$state), ]
dr <- district_rules(lea, SEDA_RULES_WINDOW)

td <- tempfile("ccd09"); dir.create(td)
l09 <- read_ccd_lea(utils::unzip("data/raw/ccd/lea-directory-sy2009-10.zip", exdir = td), 2010L,
                    extra = c("GSLO", "MEMBER"))
saipe <- read_saipe("data/raw/saipe/saipe-district-2009.txt")

# Every district that passes rules 1 and 2 forms the quintiles, whether or not SEDA reports it.
dist <- data.frame(leaid = sort(union(dr$leaid, unique(seda$leaid))), stringsAsFactors = FALSE)
dist$state <- fips_to_state(substr(dist$leaid, 1, 2))
dist$rule12 <- dr$rule12[match(dist$leaid, dr$leaid)]
dist$saipe_pov_rate_2009 <- saipe$pov_rate[match(dist$leaid, saipe$leaid)]
k09 <- match(dist$leaid, l09$leaid)
dist$span_3_8 <- !is.na(k09) & span_overlaps(l09$gslo[k09], l09$gshi[k09])
dist$member_2009 <- ccd_count(l09$member[k09])
in_q <- !is.na(dist$rule12) & dist$rule12 == "pass" & dist$span_3_8 & !is.na(dist$saipe_pov_rate_2009)
dist$pov_quintile_2009 <- NA_integer_
dist$pov_quintile_2009[in_q] <- poverty_quintile(dist$state[in_q], dist$saipe_pov_rate_2009[in_q], dist$leaid[in_q])
for (flag in names(sets)) {
  grp <- groups[[flag]]$group[match(dist$state, groups[[flag]]$state)]
  dist[[paste0("reason_", flag)]] <- seda_reason(dist$rule12, dist$saipe_pov_rate_2009, grp)
  dist[[flag]] <- as.integer(dist[[paste0("reason_", flag)]] == "retained")
}

# ---- report 1: SEDA districts by rule ----------------------------------------------------
sd <- dist[dist$leaid %in% seda$leaid, ]
say("\n== SEDA districts (50 states and DC) by rule; rules 1-2 tested in end years ",
    paste(range(SEDA_RULES_WINDOW[SEDA_RULES_WINDOW < SEDA_PUBLIC_FROM]), collapse = "-"), " and ",
    paste(range(SEDA_RULES_WINDOW[SEDA_RULES_WINDOW >= SEDA_PUBLIC_FROM]), collapse = "-"))
rs <- as.data.frame(table(reason = sd$reason_retained), responseName = "districts", stringsAsFactors = FALSE)
rs$in_ccd_rules_window <- vapply(rs$reason, function(r) sum(sd$reason_retained == r & !is.na(sd$rule12)), integer(1))
show(rs)
steps <- data.frame(set = c("primary", "r1", "r2"),
                    retained = vapply(names(sets), function(f) sum(sd[[f]]), integer(1)))
show(steps)
utils::write.csv(rs, file.path(out_dir, "districts_by_rule_primary.csv"), row.names = FALSE)
utils::write.csv(steps, file.path(out_dir, "districts_retained_by_set.csv"), row.names = FALSE)
q <- dist[in_q & dist$retained == 1L, ]
say("Quintile districts (rules 1-2, SAIPE 2009 rate, 2009-10 span including a grade 3-8), primary set: ",
    nrow(q), "; of those with 2009-10 membership > 0: ", sum(!is.na(q$member_2009) & q$member_2009 > 0),
    "; in SEDA: ", sum(q$leaid %in% seda$leaid))
say("Districts in the quintile set that Run 1's rule (span reaching 12) left out: ",
    sum(in_q & !(ccd_grade_num(l09$gshi[k09]) %in% 12)))

# ---- gaps --------------------------------------------------------------------------------
keep_ids <- dist$leaid[dist$retained == 1L | dist$retained_r1 == 1L | dist$retained_r2 == 1L]
pk <- p[p$leaid %in% keep_ids, ]
race <- seda_race_gaps(pk)
kd <- match(race$leaid, dist$leaid)
for (flag in names(sets)) race[[flag]] <- dist[[flag]][kd]

pov <- seda_poverty_gap(pk, dist[in_q, ])
for (flag in names(sets))
  pov[[flag]] <- as.integer(groups[[flag]]$group[match(pov$state, groups[[flag]]$state)] != "excluded")
pov <- pov[pov$retained == 1L | pov$retained_r1 == 1L | pov$retained_r2 == 1L, ]
pov$leaid <- NA_character_

subj_cols <- function(pre) as.vector(outer(pre, names(SEDA_SUBJECTS), paste, sep = "_"))
cols <- c("gap", "state", "leaid", "sy_end", "seda_public_edc", names(sets), "v",
          subj_cols(c("v", "se")),
          subj_cols(as.vector(outer(c("mean", "se", "grades"), c("all", "group", "wh"), paste, sep = "_"))),
          subj_cols(c("mean_q5", "mean_q1", "districts_q5", "districts_q1")))
fill <- function(x) { for (v in setdiff(cols, names(x))) x[[v]] <- NA; x }
race$seda_public_edc <- as.integer(race$sy_end >= SEDA_PUBLIC_FROM)
pov$seda_public_edc  <- as.integer(pov$sy_end >= SEDA_PUBLIC_FROM)
stopifnot(all(names(race) %in% cols), all(names(pov) %in% cols))
out <- rbind(fill(race)[cols], fill(pov)[cols])
out <- out[order(out$gap, out$state, out$leaid, out$sy_end), ]
rownames(out) <- NULL
stopifnot(!anyDuplicated(out[c("gap", "state", "leaid", "sy_end")]), all(out$sy_end %in% SEDA_WINDOW))
out_file <- "data/derived/seda_gaps.csv"
utils::write.csv(out, out_file, row.names = FALSE, na = "")
say("\nWrote ", out_file, ": ", nrow(out), " rows (", paste(names(table(out$gap)), table(out$gap), collapse = ", "), ").")

# ---- report 2: usable gaps by end year and gap -------------------------------------------
say("\n== Unit-years with a usable gap (both subjects), by end year and gap")
say("Gaps (b) and (c): district-years. Gap (a): state-years. Event set = retained under that set.")
cnt <- do.call(rbind, lapply(names(sets), function(flag) {
  y <- out[out[[flag]] == 1L & !is.na(out$v), ]
  tb <- table(gap = factor(y$gap, levels = c("a_poverty", "b_black_white", "c_hispanic_white")),
              sy_end = factor(y$sy_end, levels = SEDA_WINDOW))
  cbind(event_set = sub("^retained_?", "", flag), as.data.frame(tb, responseName = "units", stringsAsFactors = FALSE))
}))
cnt$event_set[cnt$event_set == ""] <- "primary"
utils::write.csv(cnt, file.path(out_dir, "usable_gaps_by_year.csv"), row.names = FALSE)
for (es in unique(cnt$event_set)) {
  w <- stats::reshape(cnt[cnt$event_set == es, c("gap", "sy_end", "units")], idvar = "gap", timevar = "sy_end",
                      direction = "wide")
  names(w) <- sub("^units\\.", "", names(w))
  w$total <- rowSums(w[-1])
  say("\nEvent set ", es, ":")
  show(w)
}

# ---- report 3: one subject only, and grade sets ------------------------------------------
say("\n== Unit-years with one subject gap only (v missing), primary set")
one <- out[out$retained == 1L & is.na(out$v), ]
show(as.data.frame(table(gap = one$gap, only = ifelse(is.na(one$v_math), "rla", "math")), responseName = "units"))
say("\n== District-year-subjects entering gaps (b) and (c) whose group and White grade sets differ, primary set")
pr <- pk[pk$leaid %in% dist$leaid[dist$retained == 1L], ]
gs <- do.call(rbind, lapply(names(SEDA_GAPS), function(g) {
  a <- SEDA_GAPS[[g]][1]; b <- SEDA_GAPS[[g]][2]
  ok <- !is.na(pr$mn_all) & !is.na(pr[[paste0("mn_", a)]]) & !is.na(pr[[paste0("mn_", b)]])
  data.frame(gap = g, subject_gaps = sum(ok), grade_sets_differ = sum(ok & pr[[paste0("gmask_", a)]] != pr[[paste0("gmask_", b)]]),
             median_grades_group = stats::median(pr[[paste0("grades_", a)]][ok]),
             median_grades_wh = stats::median(pr[[paste0("grades_", b)]][ok]))
}))
show(gs)
utils::write.csv(gs, file.path(out_dir, "grade_sets.csv"), row.names = FALSE)
say("Log: ", log_file)

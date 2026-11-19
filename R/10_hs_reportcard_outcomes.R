for (f in list.files("R/functions", full.names = TRUE)) source(f)

stage <- as.integer(readLines("data/stage.txt", n = 1, warn = FALSE))
if (!identical(stage, 2L)) stop("R/10_hs_reportcard_outcomes.R reads report-card outcome files, which needs data/stage.txt = 2.")
reuse_long <- "--reuse-long" %in% commandArgs(TRUE)

stamp   <- format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ")
out_dir <- "outputs/10_hs_reportcard_outcomes"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/logs", recursive = TRUE, showWarnings = FALSE)
log_file <- file.path("outputs", "logs", paste0("10_hs_reportcard_outcomes_", stamp, ".log"))
say <- function(...) {
  txt <- paste0(...)
  cat(txt, "\n", sep = "")
  cat(txt, "\n", sep = "", file = log_file, append = TRUE)
}
show <- function(x) say(paste(utils::capture.output(print(x, row.names = FALSE)), collapse = "\n"))

say("Step 10 high school report-card outcomes, run ", stamp, "; stage ", stage, "; blinding ",
    readLines("data/reference/blinding_status.txt", n = 1, warn = FALSE))

hz <- read_hs_harmonization()
mapped <- hz[hz$mapping_status == "mapped", ]
stopifnot(all(mapped$sy_end %in% HS_RC_WINDOW), !anyDuplicated(hz[c("state", "sy_end")]),
          all(mapped$state %in% names(HS_RC_LOADERS)), all(nzchar(mapped$min_group_size)))
say("Harmonization table: ", nrow(hz), " state-years, ", nrow(mapped), " mapped (", length(unique(mapped$state)),
    " states), ", sum(hz$mapping_status == "unavailable"), " unavailable")

long_file <- "data/derived/hs_reportcard_long.csv"
parts_dir <- "data/derived/hs_reportcard_long_parts"
if (!reuse_long) unlink(parts_dir, recursive = TRUE)
dir.create(parts_dir, recursive = TRUE, showWarnings = FALSE)
read_part <- function(f) utils::read.csv(f, colClasses = c(st_id = "character", name = "character", part = "character",
                                                         component = "character"), stringsAsFactors = FALSE, na.strings = "")
reused <- 0L
long <- do.call(rbind, lapply(seq_len(nrow(mapped)), function(i) {
  row <- mapped[i, ]
  pf <- file.path(parts_dir, sprintf("%s_%d.csv", row$state, row$sy_end))
  if (reuse_long && file.exists(pf)) { reused <<- reused + 1L; return(read_part(pf)) }
  t0 <- Sys.time()
  x <- rc_pool(HS_RC_LOADERS[[row$state]](row))
  utils::write.csv(x, pf, row.names = FALSE, na = "")
  message(sprintf("%s %d: %d rows (%.0fs)", row$state, row$sy_end, nrow(x), as.numeric(Sys.time() - t0, units = "secs")))
  read_part(pf)
}))
utils::write.csv(long, long_file, row.names = FALSE, na = "")
say("Loaded ", nrow(mapped), " state-years (", reused, " reused from ", parts_dir, " with --reuse-long): ", nrow(long),
    " rows after pooling; wrote ", long_file)
stopifnot(setequal(unique(paste(long$state, long$sy_end)), paste(mapped$state, mapped$sy_end)))

ccd <- do.call(rbind, lapply(HS_RC_CCD_YEARS, rc_ccd_directory))
long$xw <- rc_xw_key(long$state, long$st_id, long$name)
keys <- long[!duplicated(long$xw), c("state", "st_id", "name", "xw")]
xw <- if (file.exists(HS_RC_CROSSWALK)) utils::read.csv(HS_RC_CROSSWALK, colClasses = "character", na.strings = "") else NULL
have <- if (is.null(xw)) character() else rc_xw_key(xw$state, xw$st_id, xw$name)
new <- keys[!keys$xw %in% have, c("state", "st_id", "name")]
if (nrow(new)) {
  draft <- rc_crosswalk_draft(new, ccd)
  xw <- rbind(xw, draft)
  xw <- xw[order(xw$state, xw$st_id, xw$name), ]
  xw[!is.na(xw) & xw == ""] <- NA
  data.table::fwrite(xw, HS_RC_CROSSWALK, quote = "auto", eol = "\n", na = "")
  say("Crosswalk: drafted ", nrow(draft), " new keys into ", HS_RC_CROSSWALK, " (author_check blank)")
}
xw[xw == ""] <- NA
xw_key <- rc_xw_key(xw$state, xw$st_id, xw$name)
say("\n== Crosswalk keys by method (all report-card district keys)")
show(as.data.frame(table(method = xw$method[xw_key %in% keys$xw]), responseName = "keys"))
long$leaid <- xw$leaid[match(long$xw, xw_key)]
um <- long[is.na(long$leaid), ]
say("Report-card rows without an NCES LEAID (dropped): ", nrow(um), " in ", length(unique(um$xw)), " district keys")
long <- long[!is.na(long$leaid), ]
long <- rc_dedupe(long)
cf <- attr(long, "conflicts")
say("District-year-subject-subgroup keys with conflicting duplicate rows (dropped): ",
    length(unique(paste(cf$leaid, cf$sy_end, cf$subject, cf$sg))))

cells <- do.call(rbind, lapply(seq_len(nrow(mapped)), function(i) {
  row <- mapped[i, ]
  x <- long[long$state == row$state & long$sy_end == row$sy_end, ]
  if (!nrow(x)) return(NULL)
  rc_cells(x, min_n = as.numeric(row$min_group_size), part_applies = !is.na(row$participation_col) && nzchar(row$participation_col))
}))

s1 <- utils::read.csv("data/derived/sample_district_year.csv", colClasses = c(leaid = "character"),
                      stringsAsFactors = FALSE, na.strings = "")
stopifnot(!anyDuplicated(s1[c("leaid", "sy_end")]))
dist <- s1[!duplicated(s1$leaid), c("leaid", "retained", "reason", "retained_r1", "retained_r2",
                                     "saipe_pov_rate_2009", "pov_quintile_2009")]
k <- match(cells$leaid, dist$leaid)
rc <- cells[c("leaid", "state", "sy_end")]
rc$rc_rule12 <- rc_rule12(rc$leaid, rc$sy_end, ccd)
ok12 <- rc$rc_rule12 == "pass"
for (flag in c("retained", "retained_r1", "retained_r2"))
  rc[[flag]] <- as.integer(!is.na(k) & dist[[flag]][k] %in% 1L & ok12)
rc$reason <- ifelse(is.na(k), "rule 2: not in the step 3 sample file (no CCD row 2010-2021)",
                    ifelse(dist$reason[k] != "retained", dist$reason[k],
                           ifelse(!ok12, paste(rc$rc_rule12, "(report-card year)"), "retained")))
rc$robust_from_2013 <- 1L
ky <- match(paste(rc$leaid, pmin(rc$sy_end, max(HS_RC_CCD_YEARS))), paste(ccd$leaid, ccd$sy_end))
rc$agency_type <- ccd$agency_type[ky]
rc$ccd_bound <- ccd$status[ky]
rc$boundary_change <- as.integer(rc$ccd_bound %in% BOUND_CHANGE)
rc$saipe_pov_rate_2009 <- dist$saipe_pov_rate_2009[k]
rc$pov_quintile_2009 <- dist$pov_quintile_2009[k]
cp <- rc_cep(rc$leaid, rc$sy_end)
rc$cep <- cp$cep; rc$cep_carried <- cp$cep_carried
tr <- utils::read.csv("data/reference/test_replacement.csv", stringsAsFactors = FALSE, na.strings = character())
kt <- match(paste(rc$state, rc$sy_end), paste(tr$state, tr$sy_end))
stopifnot(!anyNA(kt))
rc$test_replaced <- tr$replaced[kt]; rc$test_replaced_math <- tr$replaced_math[kt]; rc$test_replaced_rla <- tr$replaced_rla[kt]
rc <- cbind(rc, cells[setdiff(names(cells), c("leaid", "state", "sy_end"))])
rc$source <- "report_card"

sg_cols <- as.vector(outer(c("math", "rla"), RC_SAMPLE_SUBGROUPS, paste, sep = "_"))
s1$source <- "edfacts"; s1$cep_carried <- 0L; s1$rc_rule12 <- NA_character_
for (v in sg_cols) {
  s1[[paste0("nbasis_", v)]] <- ifelse(is.na(s1[[paste0("n_", v)]]), "none", "exact")
  s1[[paste0("nclamp_", v)]] <- s1[[paste0("n_", v)]]
}
cols <- c(names(utils::read.csv("data/derived/sample_district_year.csv", nrows = 1, check.names = FALSE)),
          "source", "cep_carried", "rc_rule12", paste0("nbasis_", sg_cols), paste0("nclamp_", sg_cols))
stopifnot(all(cols %in% names(rc)), all(cols %in% names(s1)))
panel <- rbind(s1[cols], rc[cols])
panel <- panel[order(panel$state, panel$leaid, panel$sy_end), ]
stopifnot(!anyDuplicated(panel[c("leaid", "sy_end")]), all(panel$sy_end %in% c(ACH_WINDOW, HS_RC_WINDOW)))
utils::write.csv(panel, "data/derived/hs_panel.csv", row.names = FALSE, na = "")
say("\nWrote data/derived/hs_panel.csv: ", nrow(panel), " district-years (", sum(panel$source == "edfacts"),
    " EDFacts, ", sum(panel$source == "report_card"), " report card)")

td <- tempfile("ccd09"); dir.create(td)
l09 <- read_ccd_lea(utils::unzip("data/raw/ccd/lea-directory-sy2009-10.zip", exdir = td), 2010L, extra = "MEMBER")
d <- rc[rc$retained == 1L | rc$retained_r1 == 1L | rc$retained_r2 == 1L, ]
d$member_2009 <- ccd_count(l09$member)[match(d$leaid, l09$leaid)]
race <- do.call(rbind, lapply(names(MAX_WIDTH), function(smpl)
  do.call(rbind, lapply(c("math", "rla"), function(subj) rc_race_gaps(d, subj, smpl)))))
pov <- do.call(rbind, lapply(names(MAX_WIDTH), function(smpl)
  do.call(rbind, lapply(c("math", "rla"), function(subj) {
    x <- d[!is.na(d$pov_quintile_2009), ]
    if (!nrow(x)) return(NULL)
    rc_poverty_gap(x, subj, smpl)
  }))))

gap_cols <- c("gap", "state", "leaid", "sy_end", "subject", "sample", "source", "retained", "retained_r1", "retained_r2",
              "v", "se", "n_group", "n_wh", "p_group", "p_wh", "w_group", "w_wh", "score_q5", "score_q1",
              "districts_q5", "districts_q1", "member_q5", "member_q1", "tested_q5", "tested_q1")
race_long <- function(r, source) do.call(rbind, lapply(names(RACE_GAPS), function(g) {
  a <- RACE_GAPS[[g]][1]
  x <- r[!is.na(r[[paste0("v_", g)]]), ]
  if (!nrow(x)) return(NULL)
  x$gap <- c(bw = "b_black_white", hw = "c_hispanic_white")[[g]]
  x$v <- x[[paste0("v_", g)]]; x$se <- x[[paste0("se_", g)]]
  for (pre in c("n", "p", "w")) x[[paste0(pre, "_group")]] <- x[[paste0(pre, "_", a)]]
  x$source <- source
  for (v in setdiff(gap_cols, names(x))) x[[v]] <- NA
  x[gap_cols]
}))
pov_long <- function(p, source) {
  if (is.null(p) || !nrow(p)) return(NULL)
  p$gap <- "a_poverty"; p$leaid <- NA_character_; p$v <- p$v_pov; p$se <- NA_real_; p$source <- source
  for (v in setdiff(gap_cols, names(p))) p[[v]] <- NA
  p[gap_cols]
}
g1r <- utils::read.csv("data/derived/gaps_race_district_year.csv", colClasses = c(leaid = "character"), stringsAsFactors = FALSE)
g1p <- utils::read.csv("data/derived/gap_poverty_state_year.csv", stringsAsFactors = FALSE)
gaps <- rbind(race_long(g1r, "edfacts"), pov_long(g1p, "edfacts"), race_long(race, "report_card"), pov_long(pov, "report_card"))
gaps <- gaps[order(gaps$gap, factor(gaps$sample, levels = names(MAX_WIDTH)), gaps$state, gaps$leaid, gaps$sy_end, gaps$subject), ]
stopifnot(!anyDuplicated(gaps[c("gap", "state", "leaid", "sy_end", "subject", "sample")]))
utils::write.csv(gaps, "data/derived/hs_gaps.csv", row.names = FALSE, na = "")
say("Wrote data/derived/hs_gaps.csv: ", nrow(gaps), " rows (", sum(gaps$source == "report_card"), " report card)")

say("\n== Unit-years with a usable gap (math and RLA both), primary sample, primary event set")
say("Gaps (b) and (c): district-years; gap (a): state-years. 2010-2021 EDFacts, 2022-2025 report cards.")
pr <- gaps[gaps$sample == "primary" & gaps$retained == 1L, ]
unit <- paste(pr$gap, pr$state, pr$leaid, pr$sy_end)
both <- pr[unit %in% unit[pr$subject == "math"] & unit %in% unit[pr$subject == "rla"] & pr$subject == "math", ]
years <- sort(unique(c(ACH_WINDOW, HS_RC_WINDOW)))
tab <- table(gap = factor(both$gap, levels = c("a_poverty", "b_black_white", "c_hispanic_white")),
             sy_end = factor(both$sy_end, levels = years))
wide <- as.data.frame.matrix(tab)
wide <- cbind(gap = rownames(wide), wide)
show(wide)
utils::write.csv(as.data.frame(tab, responseName = "units"), file.path(out_dir, "usable_gaps_by_year.csv"), row.names = FALSE)
any_subj <- as.data.frame(table(gap = pr$gap[pr$source == "report_card"], subject = pr$subject[pr$source == "report_card"],
                                sy_end = pr$sy_end[pr$source == "report_card"]), responseName = "units")
utils::write.csv(any_subj, file.path(out_dir, "usable_gaps_by_subject_rc.csv"), row.names = FALSE)
for (es in c("retained_r1", "retained_r2")) {
  x <- gaps[gaps$sample == "primary" & gaps[[es]] == 1L & gaps$source == "report_card", ]
  u <- paste(x$gap, x$state, x$leaid, x$sy_end)
  b <- x[u %in% u[x$subject == "math"] & u %in% u[x$subject == "rla"] & x$subject == "math", ]
  say("Report-card unit-years usable in both subjects, event set ", sub("retained_", "", es), ": ",
      paste(names(table(b$gap)), table(b$gap), collapse = ", "))
}

say("\n== States covered by the report-card years (primary sample, primary event set, both subjects)")
rcb <- both[both$sy_end %in% HS_RC_WINDOW, ]
cov <- do.call(rbind, lapply(HS_RC_WINDOW, function(y) {
  x <- rcb[rcb$sy_end == y, ]
  data.frame(sy_end = y, mapped = sum(mapped$sy_end == y),
             states_any_gap = length(unique(x$state)),
             states_gap_b = length(unique(x$state[x$gap == "b_black_white"])),
             states_gap_c = length(unique(x$state[x$gap == "c_hispanic_white"])),
             states_gap_a = length(unique(x$state[x$gap == "a_poverty"])),
             states = paste(sort(unique(x$state)), collapse = " "))
}))
show(cov)
utils::write.csv(cov, file.path(out_dir, "states_covered.csv"), row.names = FALSE)
nostate <- setdiff(unique(mapped$state), unique(rcb$state))
say("Mapped states with no usable report-card gap in any year: ", if (length(nostate)) paste(sort(nostate), collapse = " ") else "none")
by_state <- as.data.frame.matrix(table(state = rcb$state, gap = rcb$gap))
by_state <- cbind(state = rownames(by_state), by_state)
utils::write.csv(by_state, file.path(out_dir, "usable_gaps_by_state_rc.csv"), row.names = FALSE)

say("\n== Report-card district-years by reason (primary event set)")
show(as.data.frame(table(reason = rc$reason), responseName = "district_years"))
say("\n== Report-card cells (retained districts, primary set) by status and floor basis, Black, Hispanic, White, all")
rr <- rc[rc$retained == 1L, ]
cs <- do.call(rbind, lapply(c("math", "rla"), function(subj) do.call(rbind, lapply(RC_SUBGROUPS, function(s) {
  st <- rr[[paste0("cell_", subj, "_", s)]]; nb <- rr[[paste0("nbasis_", subj, "_", s)]]
  data.frame(subject = subj, subgroup = s, table_status = paste(names(table(st)), table(st), collapse = "; "),
             usable_by_basis = paste(names(table(nb[st == "usable"])), table(nb[st == "usable"]), collapse = "; "))
}))))
show(cs)
utils::write.csv(cs, file.path(out_dir, "cells_by_status_rc.csv"), row.names = FALSE)
pa <- rr[rr$state %in% mapped$state[nzchar(ifelse(is.na(mapped$participation_col), "", mapped$participation_col))], ]
say("Participation-rule failures among cells usable under rule 3 (states printing participation): ",
    sum(vapply(sg_cols[!grepl("ecd", sg_cols)], function(v)
      sum(pa[[paste0("cell_", v)]] == "usable" & pa[[paste0("part_ok_", v)]] %in% 0L, na.rm = TRUE), numeric(1))))
say("CEP: report-card district-years with cep = 1: ", sum(rc$cep == 1L), "; 2025 rows carrying 2024's value: ",
    sum(rc$cep_carried == 1L))
say("Log: ", log_file)

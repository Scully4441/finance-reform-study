# Checks for R/functions/run_all_run2.R and the Run 2 step 14 outputs (docs/design_extension.md,
# Sections 7, 8, 10 and 12). Sourced by tests/run_tests.R after tests/test_primary.R (sim()) and
# tests/test_run_all.R.

invisible(parse("R/14_run_all_run2.R"))

# ---- constants: windows, counts, the seventeen states --------------------------------------------------
stopifnot(identical(RUN2_WINDOWS$seda, SEDA_WINDOW), identical(RUN2_WINDOWS$hs, sort(c(ACH_WINDOW, HS_RC_WINDOW))),
          identical(RUN2_EDFACTS_YEARS, ACH_WINDOW), RUN2_RC_FROM == min(HS_RC_WINDOW),
          identical(RUN2_GAPS, outcome_gaps("achievement")), RUN2_BOOT_REPS == 9999L, RUN2_RI_REPS == 10000L,
          RI_REPS_VARIANT == 1000L, length(RUN2_CONFIRMED_STATES) == 17L, all(RUN2_CONFIRMED_STATES %in% c(state.abb, "DC")),
          CDID_BASE_YEAR == max(RUN2_WINDOWS$hs), CDID_BASE_YEAR == max(RUN2_WINDOWS$seda))

# ---- variants: one departure each; Run 1's set on high school, the splits per family ---------------------
stopifnot(all(vapply(RUN2_VARIANTS, function(v) sum(v$sample != "primary", !is.null(v$from_year), !is.null(v$years),
                                                    !is.null(v$states), v$drop_few_pre, v$anticipation != 0L), 0) == 1),
          identical(run2_variants_for("hs", split = FALSE), names(VARIANTS)),
          identical(run2_variants_for("seda", split = FALSE), c("drop_few_pre", "anticipation_1")),
          identical(run2_variants_for("seda", split = TRUE), c("seda_2009_2019", "seda_2022_2025")),
          identical(run2_variants_for("hs", split = TRUE), c("hs_edfacts_years", "hs_17_states")),
          identical(RUN2_VARIANTS$hs_edfacts_years$years, RUN2_EDFACTS_YEARS),
          all(RUN2_VARIANTS$seda_2009_2019$years %in% SEDA_WINDOW), all(RUN2_VARIANTS$seda_2022_2025$years %in% SEDA_WINDOW),
          all(vapply(names(VARIANTS), function(v) RUN2_VARIANTS[[v]]$anticipation == VARIANTS[[v]]$anticipation &&
                       identical(RUN2_VARIANTS[[v]]$sample, VARIANTS[[v]]$sample) && identical(RUN2_VARIANTS[[v]]$from_year, VARIANTS[[v]]$from_year), TRUE)))

# ---- block rule: applied where honest_rm() reports non-consecutive event times ----------------------------
fb <- run_cs(sim()$panel, ~x1, seed_step = "test run2 block", anticipation = 1L)
ib <- cs_influence(fb$fit)
fok <- run_cs(sim()$panel, ~x1, seed_step = "test run2 block ok")
iok <- cs_influence(fok$fit)
hb0 <- suppressWarnings(honest_rm(ib, c(0, 1), ref = -1L)); hok <- suppressWarnings(honest_rm(iok, c(0, 1)))
stopifnot(all(hb0$status == HONEST_NOT_CONSEC))
br <- run2_block_rule(list(b = hb0, ok = hok), list(b = ib, ok = iok), list(b = -1L, ok = -1L), c(0, 1))
stopifnot(identical(br$b, suppressWarnings(honest_block(ib, c(0, 1), ref = -1L))),
          identical(br$ok[names(hok)], hok), all(is.na(br$ok$event_block)), all(is.na(br$ok$event_block_note)),
          identical(names(br$b), names(br$ok)))

# ---- synthetic high school inputs --------------------------------------------------------------------------
hw <- c(2010L, 2011L, 2012L, 2021L, 2022L, 2023L)
hev <- data.frame(state = c("A", "B", "C", "D"), treat_year = c(2012L, 2022L, NA, NA),
                  group = c("treated", "treated", "never", "never"), stringsAsFactors = FALSE)
hrow <- function(leaid, state, y, v = -0.5, nb = 40, nw = 100) do.call(rbind, lapply(c("math", "rla"), function(s)
  data.frame(gap = "b_black_white", state = state, leaid = leaid, sy_end = y, subject = s, sample = "primary",
             source = ifelse(y >= 2022, "report_card", "edfacts"), retained = 1L, retained_r1 = 1L, retained_r2 = 1L,
             v = v + (s == "rla") * 0.2, n_group = nb + (s == "rla") * 10, n_wh = nw, stringsAsFactors = FALSE)))
hrace <- rbind(do.call(rbind, lapply(hw, function(y) hrow("A1", "A", y))), do.call(rbind, lapply(hw, function(y) hrow("B1", "B", y))),
               do.call(rbind, lapply(hw, function(y) hrow("C1", "C", y))), do.call(rbind, lapply(hw[5:6], function(y) hrow("C2", "C", y))),
               do.call(rbind, lapply(hw[-1], function(y) hrow("D1", "D", y))))
hrace <- rbind(hrace, transform(hrow("D1", "D", 2010L), sample = "r5"))            # another sample, not in the primary panel
hpov <- do.call(rbind, lapply(c("A", "C"), function(st) do.call(rbind, lapply(hw, function(y) data.frame(gap = "a_poverty", state = st,
  leaid = NA_character_, sy_end = y, subject = c("math", "rla"), sample = "primary", source = ifelse(y >= 2022, "report_card", "edfacts"),
  retained = 1L, retained_r1 = 1L, retained_r2 = 1L, v = -0.3, n_group = NA_real_, n_wh = NA_real_, stringsAsFactors = FALSE)))))
hcov <- data.frame(leaid = c("A1", "B1", "C1", "C2", "D1"), log_member_2009 = 1:5, saipe_pov_rate_2009 = 0.1,
                   black_share_2009 = 0.2, hisp_share_2009 = 0.1, stringsAsFactors = FALSE)
hinp <- list(family = "hs", window = hw, race = hrace, pov = hpov, cov = hcov, weights = NULL)

hr <- run2_outcome_rows(hinp, "b_black_white", "retained")
stopifnot(!anyDuplicated(hr[c("leaid", "sy_end")]), near(hr$y, -0.4), identical(hr$rc, as.numeric(hr$sy_end >= 2022)),
          near(hr$tested_2010[hr$leaid == "A1"], (140 + 150) / 2), all(is.na(hr$tested_2010[hr$leaid %in% c("C2", "D1")])),
          !any(hr$leaid == "D1" & hr$sy_end == 2010))                                      # the r5 row stays out
mp <- run2_model_panel(hinp, "b_black_white", "primary", events = hev)
# rc_first is recorded but never enters the CS formula (post-freeze correction 2026-09-17).
stopifnot(identical(mp$source_covariate, "not entered: report-card-only units have no pre-2022 rows"),
          identical(all.vars(mp$xformla), CS_COVARIATES),
          all(mp$panel$rc_first[mp$panel$leaid == "C2"] == 1L), all(mp$panel$rc_first[mp$panel$leaid != "C2"] == 0L),
          all(mp$panel$g[mp$panel$state == "A"] == 2012L), all(mp$panel$g[mp$panel$state == "B"] == 2022L), mp$units == 5L)
mw <- run2_model_panel(hinp, "b_black_white", "primary", weighting = "tested_weighted", events = hev)
stopifnot(!any(mw$panel$leaid %in% c("C2", "D1")), identical(mw$weightsname, "tested_2010"),
          identical(mw$source_covariate, "not entered: constant in this panel"), identical(all.vars(mw$xformla), CS_COVARIATES))
me <- run2_model_panel(hinp, "b_black_white", "primary", years = RUN2_EDFACTS_YEARS, events = hev)
stopifnot(all(me$panel$sy_end <= 2021), !"C2" %in% me$panel$leaid, all(me$panel$g[me$panel$state == "B"] == 0L),   # after the window
          identical(me$window, c(2010L, 2011L, 2012L, 2021L)), !"rc_first" %in% all.vars(me$xformla))
m22 <- run2_model_panel(hinp, "b_black_white", "primary", years = 2022:2025, events = hev)
stopifnot(identical(sort(unique(m22$panel$state)), c("C", "D")))                         # A and B treated by the first kept year
ms <- run2_model_panel(hinp, "b_black_white", "primary", states = c("A", "C"), events = hev)
stopifnot(identical(sort(unique(ms$panel$state)), c("A", "C")), ms$states == 2L)
mb <- run2_model_panel(hinp, "b_black_white", "primary", balanced = TRUE, events = hev)
stopifnot(identical(sort(unique(mb$panel$leaid)), c("A1", "B1", "C1")))
mf <- run2_model_panel(hinp, "b_black_white", "primary", from_year = 2013L, events = hev)
stopifnot(all(mf$panel$sy_end >= 2021), !"A" %in% mf$panel$state)                        # A treated before 2013: no pre-period
ma <- run2_model_panel(hinp, "a_poverty", "primary", events = hev)
stopifnot(identical(ma$unit, "state"), identical(sort(unique(ma$panel$state)), c("A", "C")), near(ma$panel$y, -0.3),
          identical(all.vars(ma$xformla), character()), identical(ma$source_covariate, "not entered: constant in this panel"))
stopifnot(inherits(try(run2_outcome_rows(modifyList(hinp, list(family = "seda")), "b_black_white", "retained", "r5"), silent = TRUE),
                   "try-error"))                                                        # SEDA has no suppression samples

# ---- SEDA weights, availability and outcome rows -------------------------------------------------------------
ex <- data.frame(leaid = c("0100001", "0100001", "0100001", "0100002", "0100001"), sy_end = c(2010L, 2010L, 2010L, 2010L, 2011L),
                 subject = c("math", "math", "rla", "math", "rla"), grade = c(3L, 4L, 3L, 3L, 3L),
                 has_all = c(TRUE, FALSE, TRUE, TRUE, TRUE), n_wh = c(30, NA, 15, 50, 9), n_bl = c(10, 20, 5, 5, 9),
                 n_hi = NA_real_, stringsAsFactors = FALSE)
sw <- seda_tested_weights(ex)
stopifnot(identical(sw$leaid, "0100001"), near(sw$b_black_white, ((10 + 20 + 30) + (5 + 15)) / 2), is.na(sw$c_hispanic_white))
sab <- seda_all_both(ex)
stopifnot(identical(sab$leaid, "0100001"), identical(sab$sy_end, 2010L))                 # 2011 has RLA only
sg <- data.frame(gap = "b_black_white", state = "AL", leaid = "0100001", sy_end = c(2009L, 2010L, 2022L), retained = 1L,
                 retained_r1 = 1L, retained_r2 = 0L, v = c(-0.5, -0.4, NA), stringsAsFactors = FALSE)
sinp <- list(family = "seda", window = SEDA_WINDOW, race = sg, pov = sg[0, ], cov = NULL, weights = sw)
sr <- run2_outcome_rows(sinp, "b_black_white", "retained")
stopifnot(identical(sr$sy_end, c(2009L, 2010L)), near(sr$tested_2010, rep(sw$b_black_white, 2)),
          nrow(run2_outcome_rows(sinp, "b_black_white", "retained_r2")) == 0L,
          all(is.na(run2_outcome_rows(modifyList(sinp, list(weights = NULL)), "b_black_white", "retained")$tested_2010)))

# ---- SEDA controls: CEP by district-year (2025 carries 2024) and the gap (a) CEP share -----------------------
dist <- data.frame(leaid = c("0100001", "0100002", "0100003"), state = "AL", in_quintile_set = TRUE, pov_quintile_2009 = c(1L, 5L, 3L),
                   member_2009 = 100, retained = 1L, retained_r1 = c(1L, 0L, 1L), retained_r2 = 1L, stringsAsFactors = FALSE)
allb <- data.frame(leaid = c("0100001", "0100002", "0100002", "0100003"), sy_end = c(2016L, 2016L, 2025L, 2016L), stringsAsFactors = FALSE)
stub <- function(leaid, state, sy_end) { stopifnot(all(sy_end <= 2024L)); as.integer(leaid == "0100002" | sy_end >= 2024L) }
race_s <- data.frame(gap = "b_black_white", state = "AL", leaid = "0100001", sy_end = c(2016L, 2025L), stringsAsFactors = FALSE)
sc <- run2_seda_controls(race_s, dist, allb, cep_fun = stub)
stopifnot(sc$cep$cep[sc$cep$leaid == "0100001" & sc$cep$sy_end == 2025L] == 1L,
          near(sc$cep_a$primary$cep[sc$cep_a$primary$sy_end == 2016L], 0.5),              # quintile 3 is not a gap (a) district
          near(sc$cep_a$r1$cep[sc$cep_a$r1$sy_end == 2016L], 0),
          nrow(sc$cep_a$primary[sc$cep_a$primary$sy_end == 2025L, ]) == 1L)
pa2 <- data.frame(id = 1L, state = "AL", sy_end = 2016L, y = 0, g = 0L)
stopifnot(near(run2_attach_controls(sc, pa2, "a_poverty", "primary")$panel$cep, 0.5),
          identical(run2_attach_controls(sc, transform(pa2, leaid = "0100001"), "b_black_white", "primary")$controls, "cep"),
          inherits(try(run2_attach_controls(sc, transform(pa2, sy_end = 2012L), "a_poverty", "primary"), silent = TRUE), "try-error"))

# ---- dose scaling: gap (a) revenue per event set ---------------------------------------------------------------
dd <- data.frame(leaid = c("A1", "A2", "A3", "B1"), state = "S1", pov_quintile_2009 = c(5L, 5L, 1L, 1L), member_2009 = c(100, 300, 50, 50),
                 retained = 1L, retained_r1 = c(1L, 1L, 1L, 0L), stringsAsFactors = FALSE)
rv <- data.frame(leaid = c("A1", "A2", "A3", "B1"), sy_end = 2015L, rev_pp_real = c(10, 14, 9, 13), excluded = c(FALSE, FALSE, FALSE, FALSE))
gp <- run2_gap_a_revenue_panel(dd, "retained", rv, 2015L, data.frame(state = c("S1", "S2"), g = c(2016L, 0L)))
gp1 <- run2_gap_a_revenue_panel(dd, "retained_r1", rv, 2015L, data.frame(state = "S1", g = 2016L))
stopifnot(nrow(gp) == 1L, near(gp$y, (10 * 100 + 14 * 300) / 400 - 11), gp$g == 2016L, near(gp1$y, (10 * 100 + 14 * 300) / 400 - 9))

# ---- step 14 outputs, when they have been built ------------------------------------------------------------------
o14 <- "outputs/run2/14_run_all"
for (fam in RUN2_FAMILIES) {
  vd <- file.path(o14, fam, "variants")
  if (!file.exists(file.path(vd, "randomization_overall.csv"))) next
  rd <- function(f) utils::read.csv(f, stringsAsFactors = FALSE, na.strings = "")
  ms <- rd(file.path(vd, "model_status.csv")); ri <- rd(file.path(vd, "randomization_overall.csv"))
  bo <- rd(file.path(vd, "bootstrap_overall.csv"))
  stopifnot(nrow(ms) == length(run2_variants_for(fam)) * 3L * 5L, setequal(ms$variant, run2_variants_for(fam)),
            !anyDuplicated(ms[c("variant", "gap", "event_set", "weighting")]), all(ri$reps == RI_REPS_VARIANT), all(bo$reps == RUN2_BOOT_REPS))
  s7 <- file.path(o14, fam, "07_inference")
  st <- rd(file.path(s7, "inference_settings.csv")); r7 <- rd(file.path(s7, "randomization_overall.csv"))
  stopifnot(st$value[st$setting == "bootstrap_reps"] == "9999", st$value[st$setting == "randomization_reps"] == "10000",
            all(r7$reps == RUN2_RI_REPS), nrow(rd(file.path(o14, fam, "05_primary", "model_status.csv"))) == 30L)
  for (hf in c(file.path(s7, "honestdid_overall.csv"), file.path(vd, "honestdid_overall.csv"))) {
    h <- rd(hf)
    k <- h$status == "ok" & !is.na(h$mbar)
    half <- (h$grid_ub - h$grid_lb) / (h$grid_points - 1) / 2
    stopifnot("event_block" %in% names(h), !any(h$status == HONEST_NOT_CONSEC & is.na(h$event_block_note)),   # the block rule ran
              all(h$lb[k] > h$grid_lb[k] + half[k]), all(h$ub[k] < h$grid_ub[k] - half[k]))
  }
}
mf14 <- file.path(o14, "seda", "mde", "mde_descriptive.csv")
if (file.exists(mf14)) stopifnot(all(utils::read.csv(mf14, stringsAsFactors = FALSE)$status %in% c("descriptive", "no randomization draws for the model")))
rf2 <- "outputs/run2/13_report/report.md"
if (file.exists(rf2)) {
  txt <- readLines(rf2, warn = FALSE, encoding = "UTF-8")
  stopifnot(!any(grepl("significan", txt, ignore.case = TRUE) & !grepl("no result is described as statistically significant", txt)))
  heads <- grep("^## (SEDA|High school) gap", txt)
  stopifnot(length(heads) == 6L, any(grepl("^## SEDA design: placebo-based minimum detectable effect \\(descriptive\\)", txt)))
  for (i in seq_along(heads)) {
    end <- if (i < length(heads)) heads[i + 1] - 1L else length(txt)
    sub <- txt[heads[i]:end]
    stopifnot(grepl("^### 1\\. Honest-DiD", sub[grep("^### ", sub)[1]]), any(grepl("\\*\\*headline\\*\\*|not estimable|no result row", sub)),
              all(paste0("### ", 1:11, ".") %in% sub("^(### [0-9]+\\.).*", "\\1", sub[grepl("^### [0-9]+\\.", sub)])))
  }
  for (f in list.files("outputs/run2/13_report/tables", full.names = TRUE))
    stopifnot(!any(c("g", "t", "leaid", "treat_year", "cohort_year") %in% names(utils::read.csv(f, nrows = 1))))
}

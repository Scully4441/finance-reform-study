withr::local_dir(ROOT)

test_that("run-all panels, variants, Lee bounds, dose scaling and the report", {
pa <- sim()$panel
fa <- run_cs(pa, ~x1, seed_step = "test run_all anticipation", anticipation = 1L)
f0 <- run_cs(pa, ~x1, seed_step = "test run_all anticipation")
expect_all(fa$status == "ok", identical(fa$event$e[fa$event$reference], -2L), fa$event$att[fa$event$e == -2] == 0,
          identical(f0$event$e[f0$event$reference], -1L),
          abs(fa$overall$att - 0.5) < 0.05,
          abs(fa$event$att[fa$event$e == -1]) < 0.05)
cpa <- cs_panel(fa$fit)
expect_all(cpa$anticipation == 1L, cs_panel(f0$fit)$anticipation == 0L,
          near(cs_overall(cpa$panel, cpa$xformla, cpa$weightsname, cpa$min_e, cpa$max_e, cpa$allow_unbalanced,
                          cpa$anticipation), fa$overall$att))

i0 <- cs_influence(f0$fit)
h_def <- honest_rm(i0, c(0, 1)); h_ref <- honest_rm(i0, c(0, 1), ref = -1L)
expect_all(identical(h_def, h_ref))
ia <- cs_influence(fa$fit)
ha <- honest_rm(ia, c(0, 1), ref = -2L)
post01 <- mean(fa$event$att[fa$event$e %in% 0:1])
expect_all(!any(startsWith(ha$status, "error")), all(ha$num_pre == 1L), all(ha$num_post == 3L),
          ha$status[is.na(ha$mbar)] == "ok",
          abs((ha$lb[is.na(ha$mbar)] + ha$ub[is.na(ha$mbar)]) / 2 - post01) < 1e-3,
          near(post01, fa$overall$att))
expect_all(honest_rm(ia, 1, ref = -1L)$status == "event times are not consecutive around the reference period")

hg <- suppressWarnings(honest_rm(i0, c(0, 2)))
expect_all(all(c("grid_lb", "grid_ub", "grid_points") %in% names(hg)), is.na(hg$grid_points[is.na(hg$mbar)]),
          all(hg$grid_points[!is.na(hg$mbar)] >= HONEST_GRID_POINTS))
hk <- hg$status == "ok" & !is.na(hg$mbar)
expect_all(all(hg$lb[hk] > hg$grid_lb[hk] + (hg$grid_ub[hk] - hg$grid_lb[hk]) / (hg$grid_points[hk] - 1) / 2),
          all(hg$ub[hk] < hg$grid_ub[hk] - (hg$grid_ub[hk] - hg$grid_lb[hk]) / (hg$grid_points[hk] - 1) / 2))
expect_all(identical(names(honest_rm(NULL, 1)), names(hg)))

inf2 <- infer_fits(list(a = list(fit = f0$fit, ref = -1L), b = list(fit = fa$fit, ref = -2L)), "test run_all boot", 99L)
expect_all(setequal(names(inf2$overall), c("a", "b")), all(is.na(inf2$event$b$att[inf2$event$b$e == -2])),
          !is.na(inf2$event$b$att[inf2$event$b$e == -1]), inf2$event$b$reference[inf2$event$b$e == -2],
          near(inf2$overall$a$att, f0$overall$att), length(inf2$t_boot$a) == 99L)
expect_all(identical(infer_fits(list(a = list(fit = f0$fit, ref = -1L)), "test run_all boot", 99L)$t_boot$a,
                    inf2$t_boot$a))

cf <- tempfile(fileext = ".rds")
r1 <- ri_cached(f0$fit, 5L, "test run_all ri", cf)
expect_all(file.exists(cf), identical(ri_cached(f0$fit, 5L, "test run_all ri", cf)$values, r1$values))
saveRDS(modifyList(r1, list(att = 99)), cf)
expect_all(identical(ri_cached(f0$fit, 5L, "test run_all ri", cf)$att, f0$fit$aggte$overall.att))

lp <- data.frame(id = 1:10, state = "S", g = c(rep(2012L, 6), rep(0L, 4)), sy_end = c(2011L, rep(2012L, 5), rep(2012L, 4)),
                 y = c(100, 1:5, 50, 60, 70, 80))
tt <- lee_trim(lp, 0.4, "top"); tb <- lee_trim(lp, 0.4, "bottom")
expect_all(tt$treated_post == 5L, tt$removed == 2L, identical(sort(tt$panel$y[tt$panel$g > 0 & tt$panel$sy_end >= 2012]), c(1, 2, 3)),
          identical(sort(tb$panel$y[tb$panel$g > 0 & tb$panel$sy_end >= 2012]), c(3, 4, 5)),
          100 %in% tt$panel$y, all(c(50, 60, 70, 80) %in% tb$panel$y),
          lee_trim(lp, 0, "top")$removed == 0L, lee_trim(lp, 2, "top")$removed == 5L)
expect_all(near(lee_p(0.8, 0.6), 0.25), near(lee_p(0.6, 0.8), 1 - 0.8 / 0.6), is.na(lee_p(0, 0.5)), is.na(lee_p(NA, 0.5)))
expect_all(near(lee_differential_fraction(-0.38, -0.36), 0.02), near(lee_differential_fraction(0.1, -0.2), 0.3),
          lee_differential_fraction(0.9, -0.9) == 1, is.na(lee_differential_fraction(NA, 0.1)),
          lee_differential_fraction(0.2, 0.2) == 0, !"group" %in% names(formals(lee_trim)))
lvp <- data.frame(id = c(1L, 2L, 3L, 1L, 2L, 3L), g = c(2012L, 2012L, 2013L, 2012L, 2012L, 2013L),
                  sy_end = c(2012L, 2012L, 2013L, 2013L, 2013L, 2014L), y = c(0.5, 0.7, 0.9, 0.6, 0.8, 1.0))
lvf <- list(status = "ok", overall = data.frame(att = 0.1),
            cells = data.frame(g = c(2012L, 2013L, 2012L, 2013L), t = c(2012L, 2013L, 2013L, 2014L), e = c(0L, 0L, 1L, 1L),
                               att = c(0.1, 0.1, 0.1, NA)))
lv <- lee_share_levels(lvf, lvp)
expect_all(near(lv[["q_T"]], mean(c((0.6 * 2 + 0.9 * 1) / 3, 0.7))), near(lv[["q_C"]], lv[["q_T"]] - 0.1))

wide <- tempfile(fileext = ".txt")
writeLines(c("NCESSCH\tLEAID\tG0909\tHI09M09\tHI09F09\tBL09M09\tBL09F09\tWH09M09\tWH09F09",
             "1\t0100001\t30\t1\t2\t3\t4\t5\t6", "2\t0100001\t-2\t-2\t-2\t-2\t-2\t-2\t-2",
             "3\t0100002\t20\t-1\t1\t2\t2\t3\t3", "4\t0100003\t-1\t-1\t-1\t-1\t-1\t-1\t-1"), wide)
gw <- ccd_grade9_district(wide, 2010L)
expect_all(identical(gw$leaid, c("0100001", "0100002", "0100003")), identical(gw$g9_all, c(30, 20, NA)),
          identical(gw$g9_bl, c(7, 4, 0)), identical(gw$g9_hi, c(3, NA, 0)))
long <- tempfile(fileext = ".csv")
row <- function(sch, lea, race, sex, n, ind) sprintf("%s,%s,Grade 9,%s,%s,%s,%s", sch, lea, race, sex, n, ind)
A <- "Category Set A - By Race/Ethnicity; Sex; Grade"; S <- "Subtotal 4 - By Grade"
writeLines(c("NCESSCH,LEAID,GRADE,RACE_ETHNICITY,SEX,STUDENT_COUNT,TOTAL_INDICATOR",
             row(1, "0100001", "No Category Codes", "No Category Codes", 10, S),
             row(1, "0100001", "White", "Male", 4, A), row(1, "0100001", "White", "Female", 6, A),
             row(1, "0100001", "Black or African American", "Male", "", A), row(1, "0100001", "Black or African American", "Female", "", A),
             row(2, "0100002", "No Category Codes", "No Category Codes", 12, S),
             row(2, "0100002", "White", "Male", 4, A), row(2, "0100002", "White", "Female", 6, A),
             row(2, "0100002", "Black or African American", "Male", "", A)), long)
gl <- ccd_grade9_district(long, 2018L)
expect_all(identical(gl$g9_all, c(10, 12)), identical(gl$g9_wh, c(10, 10)),
          identical(gl$g9_bl, c(0, NA)))

lay <- tempfile(fileext = ".txt")
writeLines(c("Variable\tStart\tEnd\tField\t\tData", "NCESSCH\t        0001\t0012\t12\t\tAN\t\tid",
             "+LEAID\t        0001\t0007\t7\t\tAN\t\tagency", "SCHNAM06\t0013\t0016\t4\t\tAN\t\tname \x97 dash",
             "G0906   \t0017\t0020\t4\t\tN\t\tgrade 9", "HI09M06 \t0021\t0024\t4\t\tN\t\tx", "HI09F06 \t0025\t0028\t4\t\tN\t\tx",
             "BL09M06 \t0029\t0032\t4\t\tN\t\tx", "BL09F06 \t0033\t0036\t4\t\tN\t\tx", "WH09M06 \t0037\t0040\t4\t\tN\t\tx",
             "WH09F06 \t0041\t0044\t4\t\tN\t\tx"), lay, useBytes = TRUE)
dat1 <- tempfile(fileext = ".dat"); dat2 <- tempfile(fileext = ".dat")
writeLines("010000100001Caf\xe9  30   1   2   3   4   5   6", dat1, useBytes = TRUE)
writeLines(c("010000100002ABCD  -2  -2  -2  -2  -2  -2  -2", "010000200003ABCD  20  -1   1   2   2   3   3"), dat2)
gf <- ccd_grade9_district(c(dat1, dat2), 2007L, layout = lay)
expect_all(identical(gf$leaid, c("0100001", "0100002")), identical(gf$g9_all, c(30, 20)),
          identical(gf$g9_bl, c(7, 4)), identical(gf$g9_hi, c(3, NA)))
expect_all(LEE_FIRST_CCD == 2007L, identical(ACH_WINDOW[ACH_WINDOW - LEE_LAG >= LEE_FIRST_CCD], ACH_WINDOW))

base <- data.frame(id = 1:2, leaid = c("0100001", "0100002"), state = c("S1", "S2"), sy_end = 2013L, y = 0, g = c(2016L, 2013L),
                   log_member_2009 = 1, saipe_pov_rate_2009 = 0.1, black_share_2009 = 0.1, hisp_share_2009 = 0.1)
sm <- data.frame(leaid = rep(c("0100001", "0100002"), each = 2), sy_end = rep(c(2013L, 2014L), 2),
                 n_math_bl = c(5, 6, 5, 5), n_rla_bl = c(7, 6, 5, 5), n_math_all = c(20, 22, 30, 30), n_rla_all = c(20, 22, 30, 30))
g9s <- data.frame(leaid = c("0100001", "0100001"), sy_end = c(2010L, 2011L), g9_all = c(40, 44), g9_bl = c(12, NA))
sp <- lee_share_panel(base, sm, g9s, "bl", 2013:2014)
expect_all(identical(sp$leaid, c("0100001", "0100001")),
          near(sp$y, c(6 / 12, 22 / 44)), identical(sp$fallback, c(0L, 1L)))

fdir <- tempfile("f33"); dir.create(fdir)
writeLines(c('"STATE","NCESID","V33","TSTREV","TLOCREV"', '"01","0100001",100,500,300,', '"01","0100002",0,5,5,',
             '"01","N",10,1,1,'), file.path(fdir, "f33-fy2015.csv"))
fr <- read_f33_revenue(2015L, fdir)
expect_all(identical(fr$leaid, "0100001"), near(fr$rev_pp, 8))

mk <- function(att, sc) list(states = c("S1", "S2", "S3"), n = 3L, overall_att = att,
                             scores = cbind(overall = sc))
dw <- list(states = c("S1", "S2", "S3"), w = { set.seed(seed_for("test run_all dose")); webb_weights(3, 999) })
dr_ok <- dose_ratio(mk(0.2, c(0.01, -0.01, 0.02)), mk(2, c(0.05, -0.02, 0.03)), dw)
expect_all(near(dr_ok$dose_scaled, 0.1), dr_ok$status == "ok", dr_ok$ci_lo <= 0.1, dr_ok$ci_hi >= 0.1)
dr_weak <- dose_ratio(mk(0.2, c(0.01, -0.01, 0.02)), mk(0.01, c(0.5, -0.4, 0.3)), dw)
expect_all(startsWith(dr_weak$status, "unbounded"), is.na(dr_weak$ci_lo), !is.na(dr_weak$percentile_lo))

expect_all(identical(variants_for("graduation"), setdiff(variants_for("achievement"), "participation_from_2013")),
          all(vapply(VARIANTS, function(v) sum(v$sample != "primary", !is.null(v$from_year), v$drop_few_pre,
                                               v$anticipation != 0L), 0) == 1), HEADLINE_MBAR %in% MBAR_GRID,
          RI_REPS_VARIANT == 1000L)

expect_all(identical(FAMILY_WINDOWS$seda, SEDA_WINDOW), identical(FAMILY_WINDOWS$hs, sort(c(ACH_WINDOW, HS_RC_WINDOW))),
          identical(EDFACTS_YEARS, ACH_WINDOW), RC_FROM == min(HS_RC_WINDOW),
          identical(FAMILY_GAPS, outcome_gaps("achievement")), BOOT_REPS == 9999L, RI_REPS == 10000L,
          RI_REPS_VARIANT == 1000L, length(CONFIRMED_STATES) == 17L, all(CONFIRMED_STATES %in% c(state.abb, "DC")),
          CDID_BASE_YEAR == max(FAMILY_WINDOWS$hs), CDID_BASE_YEAR == max(FAMILY_WINDOWS$seda))

expect_all(all(vapply(FAMILY_VARIANTS, function(v) sum(v$sample != "primary", !is.null(v$from_year), !is.null(v$years),
                                                    !is.null(v$states), v$drop_few_pre, v$anticipation != 0L), 0) == 1),
          identical(family_variants_for("hs", split = FALSE), names(VARIANTS)),
          identical(family_variants_for("seda", split = FALSE), c("drop_few_pre", "anticipation_1")),
          identical(family_variants_for("seda", split = TRUE), c("seda_2009_2019", "seda_2022_2025")),
          identical(family_variants_for("hs", split = TRUE), c("hs_edfacts_years", "hs_17_states")),
          identical(FAMILY_VARIANTS$hs_edfacts_years$years, EDFACTS_YEARS),
          all(FAMILY_VARIANTS$seda_2009_2019$years %in% SEDA_WINDOW), all(FAMILY_VARIANTS$seda_2022_2025$years %in% SEDA_WINDOW),
          all(vapply(names(VARIANTS), function(v) FAMILY_VARIANTS[[v]]$anticipation == VARIANTS[[v]]$anticipation &&
                       identical(FAMILY_VARIANTS[[v]]$sample, VARIANTS[[v]]$sample) && identical(FAMILY_VARIANTS[[v]]$from_year, VARIANTS[[v]]$from_year), TRUE)))

fb <- run_cs(sim()$panel, ~x1, seed_step = "test run_all block", anticipation = 1L)
ib <- cs_influence(fb$fit)
fok <- run_cs(sim()$panel, ~x1, seed_step = "test run_all block ok")
iok <- cs_influence(fok$fit)
hb0 <- suppressWarnings(honest_rm(ib, c(0, 1), ref = -1L)); hok <- suppressWarnings(honest_rm(iok, c(0, 1)))
expect_all(all(hb0$status == HONEST_NOT_CONSEC))
br <- honest_block_rule(list(b = hb0, ok = hok), list(b = ib, ok = iok), list(b = -1L, ok = -1L), c(0, 1))
expect_all(identical(br$b, suppressWarnings(honest_block(ib, c(0, 1), ref = -1L))),
          identical(br$ok[names(hok)], hok), all(is.na(br$ok$event_block)), all(is.na(br$ok$event_block_note)),
          identical(names(br$b), names(br$ok)))

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
hrace <- rbind(hrace, transform(hrow("D1", "D", 2010L), sample = "r5"))
hpov <- do.call(rbind, lapply(c("A", "C"), function(st) do.call(rbind, lapply(hw, function(y) data.frame(gap = "a_poverty", state = st,
  leaid = NA_character_, sy_end = y, subject = c("math", "rla"), sample = "primary", source = ifelse(y >= 2022, "report_card", "edfacts"),
  retained = 1L, retained_r1 = 1L, retained_r2 = 1L, v = -0.3, n_group = NA_real_, n_wh = NA_real_, stringsAsFactors = FALSE)))))
hcov <- data.frame(leaid = c("A1", "B1", "C1", "C2", "D1"), log_member_2009 = 1:5, saipe_pov_rate_2009 = 0.1,
                   black_share_2009 = 0.2, hisp_share_2009 = 0.1, stringsAsFactors = FALSE)
hinp <- list(family = "hs", window = hw, race = hrace, pov = hpov, cov = hcov, weights = NULL)

hr <- family_outcome_rows(hinp, "b_black_white", "retained")
expect_all(!anyDuplicated(hr[c("leaid", "sy_end")]), near(hr$y, -0.4), identical(hr$rc, as.numeric(hr$sy_end >= 2022)),
          near(hr$tested_2010[hr$leaid == "A1"], (140 + 150) / 2), all(is.na(hr$tested_2010[hr$leaid %in% c("C2", "D1")])),
          !any(hr$leaid == "D1" & hr$sy_end == 2010))
mp <- family_model_panel(hinp, "b_black_white", "primary", events = hev)
expect_all(identical(mp$source_covariate, "not entered: report-card-only units have no pre-2022 rows"),
          identical(all.vars(mp$xformla), CS_COVARIATES),
          all(mp$panel$rc_first[mp$panel$leaid == "C2"] == 1L), all(mp$panel$rc_first[mp$panel$leaid != "C2"] == 0L),
          all(mp$panel$g[mp$panel$state == "A"] == 2012L), all(mp$panel$g[mp$panel$state == "B"] == 2022L), mp$units == 5L)
mw <- family_model_panel(hinp, "b_black_white", "primary", weighting = "tested_weighted", events = hev)
expect_all(!any(mw$panel$leaid %in% c("C2", "D1")), identical(mw$weightsname, "tested_2010"),
          identical(mw$source_covariate, "not entered: constant in this panel"), identical(all.vars(mw$xformla), CS_COVARIATES))
me <- family_model_panel(hinp, "b_black_white", "primary", years = EDFACTS_YEARS, events = hev)
expect_all(all(me$panel$sy_end <= 2021), !"C2" %in% me$panel$leaid, all(me$panel$g[me$panel$state == "B"] == 0L),
          identical(me$window, c(2010L, 2011L, 2012L, 2021L)), !"rc_first" %in% all.vars(me$xformla))
m22 <- family_model_panel(hinp, "b_black_white", "primary", years = 2022:2025, events = hev)
expect_all(identical(sort(unique(m22$panel$state)), c("C", "D")))
ms <- family_model_panel(hinp, "b_black_white", "primary", states = c("A", "C"), events = hev)
expect_all(identical(sort(unique(ms$panel$state)), c("A", "C")), ms$states == 2L)
mb <- family_model_panel(hinp, "b_black_white", "primary", balanced = TRUE, events = hev)
expect_all(identical(sort(unique(mb$panel$leaid)), c("A1", "B1", "C1")))
mf <- family_model_panel(hinp, "b_black_white", "primary", from_year = 2013L, events = hev)
expect_all(all(mf$panel$sy_end >= 2021), !"A" %in% mf$panel$state)
fl <- family_cohort_floor(hinp, "b_black_white", "primary", events = hev)
expect_all(identical(fl$cohort, c(2012L, 2022L)), identical(fl$base_year, c(2011L, 2021L)), identical(fl$treated_units_base, c(1L, 1L)),
          all(fl$below_floor), !any(family_cohort_floor(hinp, "b_black_white", "primary", events = hev, floor = 1L)$below_floor),
          nrow(family_cohort_floor(hinp, "a_poverty", "primary", events = hev)) == 0L, COHORT_FLOOR == 20L)
mfl <- family_model_panel(hinp, "b_black_white", "primary", events = hev, cohort_floor = TRUE)
expect_all(identical(sort(unique(mfl$panel$state)), c("C", "D")), identical(mfl$floor_removed$cohort, c(2012L, 2022L)),
          nrow(mp$floor_removed) == 0L, identical(all.vars(mfl$xformla), CS_COVARIATES))
mfe <- family_model_panel(hinp, "b_black_white", "primary", years = EDFACTS_YEARS, events = hev, cohort_floor = TRUE)
expect_all(identical(mfe$floor_removed$cohort, 2012L), all(mfe$panel$g[mfe$panel$state == "B"] == 0L))
mfw <- family_model_panel(hinp, "b_black_white", "primary", weighting = "tested_weighted", events = hev, cohort_floor = TRUE)
expect_all(!any(mfw$panel$state %in% c("A", "B")))
expect_all(identical(family_model_panel(hinp, "a_poverty", "primary", events = hev, cohort_floor = TRUE)$panel,
                    family_model_panel(hinp, "a_poverty", "primary", events = hev)$panel))
ma <- family_model_panel(hinp, "a_poverty", "primary", events = hev)
expect_all(identical(ma$unit, "state"), identical(sort(unique(ma$panel$state)), c("A", "C")), near(ma$panel$y, -0.3),
          identical(all.vars(ma$xformla), character()), identical(ma$source_covariate, "not entered: constant in this panel"))
expect_all(inherits(try(family_outcome_rows(modifyList(hinp, list(family = "seda")), "b_black_white", "retained", "r5"), silent = TRUE),
                   "try-error"))

ex <- data.frame(leaid = c("0100001", "0100001", "0100001", "0100002", "0100001"), sy_end = c(2010L, 2010L, 2010L, 2010L, 2011L),
                 subject = c("math", "math", "rla", "math", "rla"), grade = c(3L, 4L, 3L, 3L, 3L),
                 has_all = c(TRUE, FALSE, TRUE, TRUE, TRUE), n_wh = c(30, NA, 15, 50, 9), n_bl = c(10, 20, 5, 5, 9),
                 n_hi = NA_real_, stringsAsFactors = FALSE)
sw <- seda_tested_weights(ex)
expect_all(identical(sw$leaid, "0100001"), near(sw$b_black_white, ((10 + 20 + 30) + (5 + 15)) / 2), is.na(sw$c_hispanic_white))
sab <- seda_all_both(ex)
expect_all(identical(sab$leaid, "0100001"), identical(sab$sy_end, 2010L))
sg <- data.frame(gap = "b_black_white", state = "AL", leaid = "0100001", sy_end = c(2009L, 2010L, 2022L), retained = 1L,
                 retained_r1 = 1L, retained_r2 = 0L, v = c(-0.5, -0.4, NA), stringsAsFactors = FALSE)
sinp <- list(family = "seda", window = SEDA_WINDOW, race = sg, pov = sg[0, ], cov = NULL, weights = sw)
sr <- family_outcome_rows(sinp, "b_black_white", "retained")
expect_all(identical(sr$sy_end, c(2009L, 2010L)), near(sr$tested_2010, rep(sw$b_black_white, 2)),
          nrow(family_outcome_rows(sinp, "b_black_white", "retained_r2")) == 0L,
          all(is.na(family_outcome_rows(modifyList(sinp, list(weights = NULL)), "b_black_white", "retained")$tested_2010)))

dist <- data.frame(leaid = c("0100001", "0100002", "0100003"), state = "AL", in_quintile_set = TRUE, pov_quintile_2009 = c(1L, 5L, 3L),
                   member_2009 = 100, retained = 1L, retained_r1 = c(1L, 0L, 1L), retained_r2 = 1L, stringsAsFactors = FALSE)
allb <- data.frame(leaid = c("0100001", "0100002", "0100002", "0100003"), sy_end = c(2016L, 2016L, 2025L, 2016L), stringsAsFactors = FALSE)
stub <- function(leaid, state, sy_end) { expect_all(all(sy_end <= 2024L)); as.integer(leaid == "0100002" | sy_end >= 2024L) }
race_s <- data.frame(gap = "b_black_white", state = "AL", leaid = "0100001", sy_end = c(2016L, 2025L), stringsAsFactors = FALSE)
sc <- seda_controls(race_s, dist, allb, cep_fun = stub)
expect_all(sc$cep$cep[sc$cep$leaid == "0100001" & sc$cep$sy_end == 2025L] == 1L,
          near(sc$cep_a$primary$cep[sc$cep_a$primary$sy_end == 2016L], 0.5),
          near(sc$cep_a$r1$cep[sc$cep_a$r1$sy_end == 2016L], 0),
          nrow(sc$cep_a$primary[sc$cep_a$primary$sy_end == 2025L, ]) == 1L)
pa2 <- data.frame(id = 1L, state = "AL", sy_end = 2016L, y = 0, g = 0L)
expect_all(near(family_attach_controls(sc, pa2, "a_poverty", "primary")$panel$cep, 0.5),
          identical(family_attach_controls(sc, transform(pa2, leaid = "0100001"), "b_black_white", "primary")$controls, "cep"),
          inherits(try(family_attach_controls(sc, transform(pa2, sy_end = 2012L), "a_poverty", "primary"), silent = TRUE), "try-error"))

dd <- data.frame(leaid = c("A1", "A2", "A3", "B1"), state = "S1", pov_quintile_2009 = c(5L, 5L, 1L, 1L), member_2009 = c(100, 300, 50, 50),
                 retained = 1L, retained_r1 = c(1L, 1L, 1L, 0L), stringsAsFactors = FALSE)
rv <- data.frame(leaid = c("A1", "A2", "A3", "B1"), sy_end = 2015L, rev_pp_real = c(10, 14, 9, 13), excluded = c(FALSE, FALSE, FALSE, FALSE))
gp <- family_gap_a_revenue_panel(dd, "retained", rv, 2015L, data.frame(state = c("S1", "S2"), g = c(2016L, 0L)))
gp1 <- family_gap_a_revenue_panel(dd, "retained_r1", rv, 2015L, data.frame(state = "S1", g = 2016L))
expect_all(nrow(gp) == 1L, near(gp$y, (10 * 100 + 14 * 300) / 400 - 11), gp$g == 2016L, near(gp1$y, (10 * 100 + 14 * 300) / 400 - 9))


ra <- "outputs/13_run_all"
expect_all(DOSE_BASE_YEAR == 2025L, CDID_BASE_YEAR == DOSE_BASE_YEAR, !"rc" %in% HS_CONTROLS)
edge_ok <- function(f) {
  if (!file.exists(f)) return(TRUE)
  h <- utils::read.csv(f, stringsAsFactors = FALSE, na.strings = "")
  if (!"grid_points" %in% names(h)) return(FALSE)
  k <- h$status == "ok" & !is.na(h$mbar)
  half <- (h$grid_ub - h$grid_lb) / (h$grid_points - 1) / 2
  all(h$lb[k] > h$grid_lb[k] + half[k]) && all(h$ub[k] < h$grid_ub[k] - half[k]) &&
    all(is.na(h$lb[h$status != "ok"])) && "event_block" %in% names(h) &&
    !any(h$status %in% HONEST_NOT_CONSEC & is.na(h$event_block_note))
}
vd <- file.path(ra, "graduation", "variants")
if (file.exists(file.path(vd, "randomization_overall.csv"))) {
  rd <- function(f) utils::read.csv(file.path(vd, f), stringsAsFactors = FALSE, na.strings = "")
  ms <- rd("model_status.csv"); ri <- rd("randomization_overall.csv"); bo <- rd("bootstrap_overall.csv")
  hd <- rd("honestdid_overall.csv"); st <- rd("inference_settings.csv")
  expect_all(nrow(ms) == length(variants_for("graduation")) * 3L * 4L, !anyDuplicated(ms[c("variant", "gap", "event_set", "weighting")]),
            setequal(ms$variant, variants_for("graduation")), all(ms$panel == "unbalanced"),
            all(ri$reps == RI_REPS_VARIANT), all(bo$reps == BOOT_REPS),
            st$value[st$setting == "bootstrap_reps"] == "9999", st$value[st$setting == "randomization_reps"] == "1000",
            setequal(unique(hd$mbar[!is.na(hd$mbar)]), MBAR_GRID) || any(hd$status != "ok"))
  s7 <- utils::read.csv("outputs/07_inference/graduation/inference_settings.csv", stringsAsFactors = FALSE)
  expect_all(s7$value[s7$setting == "bootstrap_reps"] == "9999", s7$value[s7$setting == "randomization_reps"] == "10000",
            s7$value[s7$setting == "quick_run"] == "false")
}
expect_all(edge_ok("outputs/07_inference/graduation/honestdid_overall.csv"), edge_ok(file.path(vd, "honestdid_overall.csv")))
for (nm in c("hs", "graduation", "seda")) {
  gaps_nm <- if (nm == "graduation") outcome_gaps("graduation") else FAMILY_GAPS
  ds_f <- file.path(ra, nm, "dose", "dose_scaled.csv")
  if (file.exists(ds_f)) {
    ds <- utils::read.csv(ds_f, stringsAsFactors = FALSE, na.strings = "")
    expect_all(nrow(ds) == 3L * length(gaps_nm), all(near(ds$dose_scaled, ds$att_outcome / ds$att_revenue) | is.na(ds$dose_scaled)),
              all(ds$revenue_units == "thousands of 2025 dollars per pupil" | is.na(ds$revenue_units)))
  }
  xf <- file.path(ra, nm, "dose", "revenue_exclusions.csv")
  if (file.exists(xf)) {
    xr <- utils::read.csv(xf, stringsAsFactors = FALSE, na.strings = "")
    expect_all(nrow(xr) == 1L + 3L * length(gaps_nm),
              all(xr$excluded_total <= xr$excluded_enrollment_below_30 + xr$excluded_revenue_above_100k),
              all(xr$excluded_total >= pmax(xr$excluded_enrollment_below_30, xr$excluded_revenue_above_100k)),
              all(xr$excluded_total <= xr$district_years_with_revenue))
  }
}
expect_all(!dir.exists(file.path(ra, "achievement")))
lf <- file.path(ra, "hs", "lee", "lee_bounds.csv")
if (file.exists(lf)) {
  lb <- utils::read.csv(lf, stringsAsFactors = FALSE, na.strings = "")
  expect_all(identical(lb$gap, c("b_black_white", "c_hispanic_white")),
            all(lb$lee_lower <= lb$lee_upper | lb$status != "ok"), all(lb$trim_fraction >= 0 & lb$trim_fraction <= 1 | is.na(lb$trim_fraction)),
            all(lb$trimmed_unit_years == round(lb$trim_fraction * lb$treated_post_unit_years) | is.na(lb$trim_fraction)),
            all(near(lb$trim_fraction, pmin(abs(lb$p_minority - lb$p_white), 1)) | is.na(lb$trim_fraction)))
  ls2 <- utils::read.csv(file.path(ra, "hs", "lee", "lee_share_models.csv"), stringsAsFactors = FALSE, na.strings = "")
  expect_all(all(near(ls2$p, 1 - ls2$q_C / ls2$q_T) | is.na(ls2$p)))
  for (i in seq_len(nrow(lb))) {
    s <- ls2[ls2$gap == lb$gap[i], ]
    expect_all(near(lb$p_white[i], s$p[s$subgroup == "wh"]), near(lb$p_minority[i], s$p[s$subgroup != "wh"]))
  }
}
for (fam in FAMILIES) {
  vd <- file.path(ra, fam, "variants")
  if (!file.exists(file.path(vd, "randomization_overall.csv"))) next
  rd <- function(f) utils::read.csv(f, stringsAsFactors = FALSE, na.strings = "")
  ms <- rd(file.path(vd, "model_status.csv")); ri <- rd(file.path(vd, "randomization_overall.csv"))
  bo <- rd(file.path(vd, "bootstrap_overall.csv"))
  expect_all(nrow(ms) == length(family_variants_for(fam)) * 3L * 5L, setequal(ms$variant, family_variants_for(fam)),
            !anyDuplicated(ms[c("variant", "gap", "event_set", "weighting")]), all(ri$reps == RI_REPS_VARIANT), all(bo$reps == BOOT_REPS))
  s7 <- file.path(ra, fam, "07_inference")
  st <- rd(file.path(s7, "inference_settings.csv")); r7 <- rd(file.path(s7, "randomization_overall.csv"))
  expect_all(st$value[st$setting == "bootstrap_reps"] == "9999", st$value[st$setting == "randomization_reps"] == "10000",
            all(r7$reps == RI_REPS), nrow(rd(file.path(ra, fam, "05_primary", "model_status.csv"))) == 30L)
  cf <- file.path(ra, fam, "05_primary", "cohort_floor.csv")
  if (file.exists(cf)) {
    fl13 <- rd(cf); pc13 <- rd(file.path(ra, fam, "05_primary", "panel_counts.csv"))
    expect_all(identical(fl13$below_floor, fl13$treated_units_base < COHORT_FLOOR), "cohorts_removed_by_floor" %in% names(pc13),
              all(pc13$cohorts_removed_by_floor[pc13$gap == "a_poverty"] == "none"))
    if (any(fl13$below_floor)) expect_all(file.exists(file.path(ra, fam, "05_primary", "thin_cohorts.csv")))
  }
  expect_all(edge_ok(file.path(s7, "honestdid_overall.csv")), edge_ok(file.path(vd, "honestdid_overall.csv")))
}
mf13 <- file.path(ra, "seda", "mde", "mde_descriptive.csv")
if (file.exists(mf13)) expect_all(all(utils::read.csv(mf13, stringsAsFactors = FALSE)$status %in% c("descriptive", "no randomization draws for the model")))
rf <- "outputs/13_report/report.md"
if (file.exists(rf)) {
  txt <- readLines(rf, warn = FALSE, encoding = "UTF-8")
  expect_all(!any(grepl("significan", txt, ignore.case = TRUE) & !grepl("no result is described as statistically significant", txt)),
            all(paste0("- H", 1:5, ".") %in% substr(txt, 1, 5)))
  heads <- grep("^## (High school gap|Graduation:|SEDA gap)", txt)
  cont <- grep("^# Continuous-treatment estimates", txt)
  heads_event <- heads[heads < cont]
  n_gaps <- length(FAMILY_GAPS) * 2L + length(outcome_gaps("graduation"))
  expect_all(length(cont) == 1L, length(heads_event) == n_gaps, length(heads) == 2L * n_gaps,
            any(grepl("^## SEDA design: placebo-based minimum detectable effect \\(descriptive\\)", txt)))
  for (i in seq_along(heads_event)) {
    end <- if (i < length(heads_event)) heads_event[i + 1] - 1L else cont - 1L
    sub <- txt[heads_event[i]:end]
    expect_all(grepl("^### 1\\. Honest-DiD", sub[grep("^### ", sub)[1]]), any(grepl("\\*\\*headline\\*\\*|not estimable|no result row", sub)),
              all(paste0("### ", 1:11, ".") %in% sub("^(### [0-9]+\\.).*", "\\1", sub[grepl("^### [0-9]+\\.", sub)])),
              !any(grepl("^### 12\\.", sub)))
  }
  fh <- vapply(c("^# High school achievement gaps", "^# Graduation-rate gaps", "^# SEDA grades 3", "^# Continuous-treatment estimates",
                 "^# Appendix"), function(p) min(grep(p, txt)), 0)
  expect_all(all(is.finite(fh)), !is.unsorted(fh), !any(grepl("federal files, gap", txt)))
  for (f in list.files("outputs/13_report/tables", full.names = TRUE))
    expect_all(!any(c("g", "t", "leaid", "treat_year", "cohort_year", "group") %in% names(utils::read.csv(f, nrows = 1))))
  expect_all(length(list.files("outputs/13_report/plots", pattern = "\\.png$")) <= n_gaps)
}
})

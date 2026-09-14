# Checks for R/functions/run_all.R, the step 10 additions to run_cs() and honest_rm(), and
# the step 10 and Section 13 report outputs. Sourced by tests/run_tests.R after
# tests/test_primary.R (whose sim() builds the synthetic panel used here).

# ---- anticipation = 1: reference period -2 (deviation 2026-09-13) ----------------------------
pa <- sim()$panel
fa <- run_cs(pa, ~x1, seed_step = "test run_all anticipation", anticipation = 1L)
f0 <- run_cs(pa, ~x1, seed_step = "test run_all anticipation")
stopifnot(fa$status == "ok", identical(fa$event$e[fa$event$reference], -2L), fa$event$att[fa$event$e == -2] == 0,
          identical(f0$event$e[f0$event$reference], -1L),
          abs(fa$overall$att - 0.5) < 0.05,                                  # the effect starts at 0 in sim()
          abs(fa$event$att[fa$event$e == -1]) < 0.05)                         # -1 is estimated, relative to -2
cpa <- cs_panel(fa$fit)
stopifnot(cpa$anticipation == 1L, cs_panel(f0$fit)$anticipation == 0L,
          near(cs_overall(cpa$panel, cpa$xformla, cpa$weightsname, cpa$min_e, cpa$max_e, cpa$allow_unbalanced,
                          cpa$anticipation), fa$overall$att))

# ---- honest_rm: ref = -1 is the registered call; ref = -2 zero-weights event time -1 ---------
i0 <- cs_influence(f0$fit)
h_def <- honest_rm(i0, c(0, 1)); h_ref <- honest_rm(i0, c(0, 1), ref = -1L)
stopifnot(identical(h_def, h_ref))
ia <- cs_influence(fa$fit)
ha <- honest_rm(ia, c(0, 1), ref = -2L)
post01 <- mean(fa$event$att[fa$event$e %in% 0:1])
stopifnot(!any(startsWith(ha$status, "error")), all(ha$num_pre == 1L), all(ha$num_post == 3L),   # -1, 0, 1 after -2
          ha$status[is.na(ha$mbar)] == "ok",
          abs((ha$lb[is.na(ha$mbar)] + ha$ub[is.na(ha$mbar)]) / 2 - post01) < 1e-3,            # -1 carries zero weight
          near(post01, fa$overall$att))
stopifnot(honest_rm(ia, 1, ref = -1L)$status == "event times are not consecutive around the reference period")

# ---- honest_rm search grid (code correction 2026-09-14) ------------------------------------------
hg <- suppressWarnings(honest_rm(i0, c(0, 2)))
stopifnot(all(c("grid_lb", "grid_ub", "grid_points") %in% names(hg)), is.na(hg$grid_points[is.na(hg$mbar)]),
          all(hg$grid_points[!is.na(hg$mbar)] >= HONEST_GRID_POINTS))
hk <- hg$status == "ok" & !is.na(hg$mbar)
stopifnot(all(hg$lb[hk] > hg$grid_lb[hk] + (hg$grid_ub[hk] - hg$grid_lb[hk]) / (hg$grid_points[hk] - 1) / 2),
          all(hg$ub[hk] < hg$grid_ub[hk] - (hg$grid_ub[hk] - hg$grid_lb[hk]) / (hg$grid_points[hk] - 1) / 2))
stopifnot(identical(names(honest_rm(NULL, 1)), names(hg)))                          # failure rows bind with the rest

# ---- infer_fits: shared draws, reference-aware event rows -------------------------------------
inf2 <- infer_fits(list(a = list(fit = f0$fit, ref = -1L), b = list(fit = fa$fit, ref = -2L)), "test run_all boot", 99L)
stopifnot(setequal(names(inf2$overall), c("a", "b")), all(is.na(inf2$event$b$att[inf2$event$b$e == -2])),
          !is.na(inf2$event$b$att[inf2$event$b$e == -1]), inf2$event$b$reference[inf2$event$b$e == -2],
          near(inf2$overall$a$att, f0$overall$att), length(inf2$t_boot$a) == 99L)
stopifnot(identical(infer_fits(list(a = list(fit = f0$fit, ref = -1L)), "test run_all boot", 99L)$t_boot$a,
                    inf2$t_boot$a))                                            # same seed step, same draws

# ---- ri_cached: saved per model and reused ------------------------------------------------------
cf <- tempfile(fileext = ".rds")
r1 <- ri_cached(f0$fit, 5L, "test run_all ri", cf)
stopifnot(file.exists(cf), identical(ri_cached(f0$fit, 5L, "test run_all ri", cf)$values, r1$values))
saveRDS(modifyList(r1, list(att = 99)), cf)                                    # a stale cache is refitted
stopifnot(identical(ri_cached(f0$fit, 5L, "test run_all ri", cf)$att, f0$fit$aggte$overall.att))

# ---- Lee trimming ---------------------------------------------------------------------------------
lp <- data.frame(id = 1:10, state = "S", g = c(rep(2012L, 6), rep(0L, 4)), sy_end = c(2011L, rep(2012L, 5), rep(2012L, 4)),
                 y = c(100, 1:5, 50, 60, 70, 80))
tt <- lee_trim(lp, 0.4, "top"); tb <- lee_trim(lp, 0.4, "bottom")
stopifnot(tt$treated_post == 5L, tt$removed == 2L, identical(sort(tt$panel$y[tt$panel$g > 0 & tt$panel$sy_end >= 2012]), c(1, 2, 3)),
          identical(sort(tb$panel$y[tb$panel$g > 0 & tb$panel$sy_end >= 2012]), c(3, 4, 5)),
          100 %in% tt$panel$y, all(c(50, 60, 70, 80) %in% tb$panel$y),         # pre-reform and control rows stay
          lee_trim(lp, 0, "top")$removed == 0L, lee_trim(lp, 2, "top")$removed == 5L)

# ---- CCD grade 9 membership readers ---------------------------------------------------------------
wide <- tempfile(fileext = ".txt")
writeLines(c("NCESSCH\tLEAID\tG0909\tHI09M09\tHI09F09\tBL09M09\tBL09F09\tWH09M09\tWH09F09",
             "1\t0100001\t30\t1\t2\t3\t4\t5\t6", "2\t0100001\t-2\t-2\t-2\t-2\t-2\t-2\t-2",
             "3\t0100002\t20\t-1\t1\t2\t2\t3\t3", "4\t0100003\t-1\t-1\t-1\t-1\t-1\t-1\t-1"), wide)
gw <- ccd_grade9_district(wide, 2010L)
stopifnot(identical(gw$leaid, c("0100001", "0100002", "0100003")), identical(gw$g9_all, c(30, 20, NA)),
          identical(gw$g9_bl, c(7, 4, 0)), identical(gw$g9_hi, c(3, NA, 0)))    # a missing race count on a school with grade 9
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
stopifnot(identical(gl$g9_all, c(10, 12)), identical(gl$g9_wh, c(10, 10)),
          identical(gl$g9_bl, c(0, NA)))                                          # blank = 0 only when the cells add up

# fixed-width 2006-07 layout (data addition 2026-09-14): positions from the NCES record layout
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
stopifnot(identical(gf$leaid, c("0100001", "0100002")), identical(gf$g9_all, c(30, 20)),
          identical(gf$g9_bl, c(7, 4)), identical(gf$g9_hi, c(3, NA)))
stopifnot(LEE_FIRST_CCD == 2007L, identical(ACH_WINDOW[ACH_WINDOW - LEE_LAG >= LEE_FIRST_CCD], ACH_WINDOW))

# ---- tested shares --------------------------------------------------------------------------------
base <- data.frame(id = 1:2, leaid = c("0100001", "0100002"), state = c("S1", "S2"), sy_end = 2013L, y = 0, g = c(2016L, 2013L),
                   log_member_2009 = 1, saipe_pov_rate_2009 = 0.1, black_share_2009 = 0.1, hisp_share_2009 = 0.1)
sm <- data.frame(leaid = rep(c("0100001", "0100002"), each = 2), sy_end = rep(c(2013L, 2014L), 2),
                 n_math_bl = c(5, 6, 5, 5), n_rla_bl = c(7, 6, 5, 5), n_math_all = c(20, 22, 30, 30), n_rla_all = c(20, 22, 30, 30))
g9s <- data.frame(leaid = c("0100001", "0100001"), sy_end = c(2010L, 2011L), g9_all = c(40, 44), g9_bl = c(12, NA))
sp <- lee_share_panel(base, sm, g9s, "bl", 2013:2014)
stopifnot(identical(sp$leaid, c("0100001", "0100001")),                       # district 2 is treated in the first share year
          near(sp$y, c(6 / 12, 22 / 44)), identical(sp$fallback, c(0L, 1L)))

# ---- F-33 revenue: trailing comma on data rows ----------------------------------------------------
fdir <- tempfile("f33"); dir.create(fdir)
writeLines(c('"STATE","NCESID","V33","TSTREV","TLOCREV"', '"01","0100001",100,500,300,', '"01","0100002",0,5,5,',
             '"01","N",10,1,1,'), file.path(fdir, "f33-fy2015.csv"))
fr <- read_f33_revenue(2015L, fdir)
stopifnot(identical(fr$leaid, "0100001"), near(fr$rev_pp, 8))                  # thousands per pupil
# revenue exclusions (data correction 2026-09-14): enrollment below 30, or above $100,000 per pupil
rx <- data.frame(v33 = c(29, 30, 500, 500), rev_pp_real = c(10, 10, 100, 100.01))
stopifnot(identical(revenue_excluded(rx), c(TRUE, FALSE, FALSE, TRUE)))

# ---- gap (a) revenue ---------------------------------------------------------------------------------
dd <- data.frame(leaid = c("A1", "A2", "A3", "B1"), state = c("S1", "S1", "S1", "S1"), sy_end = 2015L, retained = 1L,
                 pov_quintile_2009 = c(5L, 5L, 1L, 3L), member_2009 = c(100, 300, 50, 10))
rv <- data.frame(leaid = c("A1", "A2", "A3", "B1"), sy_end = 2015L, rev_pp_real = c(10, 14, 9, 99))
pr <- pov_revenue_panel(dd, "retained", rv, 2015L, data.frame(state = "S1", g = 0L))
stopifnot(nrow(pr) == 1L, near(pr$y, (10 * 100 + 14 * 300) / 400 - 9))

# ---- dose ratio -----------------------------------------------------------------------------------------
mk <- function(att, sc) list(states = c("S1", "S2", "S3"), n = 3L, overall_att = att,
                             scores = cbind(overall = sc))
dw <- list(states = c("S1", "S2", "S3"), w = { set.seed(seed_for("test run_all dose")); webb_weights(3, 999) })
dr_ok <- dose_ratio(mk(0.2, c(0.01, -0.01, 0.02)), mk(2, c(0.05, -0.02, 0.03)), dw)
stopifnot(near(dr_ok$dose_scaled, 0.1), dr_ok$status == "ok", dr_ok$ci_lo <= 0.1, dr_ok$ci_hi >= 0.1)
dr_weak <- dose_ratio(mk(0.2, c(0.01, -0.01, 0.02)), mk(0.01, c(0.5, -0.4, 0.3)), dw)
stopifnot(startsWith(dr_weak$status, "unbounded"), is.na(dr_weak$ci_lo), !is.na(dr_weak$percentile_lo))

# ---- variants are one departure each -------------------------------------------------------------------
stopifnot(identical(variants_for("graduation"), setdiff(variants_for("achievement"), "participation_from_2013")),
          all(vapply(VARIANTS, function(v) sum(v$sample != "primary", !is.null(v$from_year), v$drop_few_pre,
                                               v$anticipation != 0L), 0) == 1), HEADLINE_MBAR %in% MBAR_GRID,
          RI_REPS_VARIANT == 1000L)

# ---- step 10 outputs, when they have been built ----------------------------------------------------------
for (o in c("achievement", "graduation")) {
  vd <- file.path("outputs/10_run_all/variants", o)
  if (!file.exists(file.path(vd, "randomization_overall.csv"))) next
  rd <- function(f) utils::read.csv(file.path(vd, f), stringsAsFactors = FALSE, na.strings = "")
  ms <- rd("model_status.csv"); ri <- rd("randomization_overall.csv"); bo <- rd("bootstrap_overall.csv")
  hd <- rd("honestdid_overall.csv"); st <- rd("inference_settings.csv")
  n_models <- length(variants_for(o)) * 3L * (if (o == "achievement") 5L else 4L)
  stopifnot(nrow(ms) == n_models, !anyDuplicated(ms[c("variant", "gap", "event_set", "weighting")]),
            setequal(ms$variant, variants_for(o)), all(ms$panel == "unbalanced"),
            all(ms$status[ms$event_set == "primary" & ms$weighting == "unweighted"] == "ok"),
            all(ri$reps == RI_REPS_VARIANT), all(bo$reps == 9999L),
            st$value[st$setting == "bootstrap_reps"] == "9999", st$value[st$setting == "randomization_reps"] == "1000",
            setequal(unique(hd$mbar[!is.na(hd$mbar)]), MBAR_GRID) || any(hd$status != "ok"))
  s7 <- utils::read.csv(file.path(if (o == "achievement") "outputs/07_inference" else "outputs/07_inference/graduation",
                                  "inference_settings.csv"), stringsAsFactors = FALSE)
  stopifnot(s7$value[s7$setting == "bootstrap_reps"] == "9999", s7$value[s7$setting == "randomization_reps"] == "10000",
            s7$value[s7$setting == "quick_run"] == "false")
  ds <- utils::read.csv(file.path("outputs/10_run_all/dose", o, "dose_scaled.csv"), stringsAsFactors = FALSE, na.strings = "")
  stopifnot(nrow(ds) == 3L * length(outcome_gaps(o)), all(near(ds$dose_scaled, ds$att_outcome / ds$att_revenue) | is.na(ds$dose_scaled)),
            all(is.na(ds$ci_lo) == startsWith(ds$status, "unbounded") | !startsWith(ds$status, "ok")))
}
# no reported bound set sits on its search grid's edge (code correction 2026-09-14)
edge_ok <- function(f) {
  if (!file.exists(f)) return(TRUE)
  h <- utils::read.csv(f, stringsAsFactors = FALSE, na.strings = "")
  if (!"grid_points" %in% names(h)) return(FALSE)
  k <- h$status == "ok" & !is.na(h$mbar)
  half <- (h$grid_ub - h$grid_lb) / (h$grid_points - 1) / 2
  all(h$lb[k] > h$grid_lb[k] + half[k]) && all(h$ub[k] < h$grid_ub[k] - half[k]) &&
    all(is.na(h$lb[h$status != "ok"]))
}
stopifnot(edge_ok("outputs/07_inference/honestdid_overall.csv"), edge_ok("outputs/07_inference/graduation/honestdid_overall.csv"),
          edge_ok("outputs/10_run_all/variants/achievement/honestdid_overall.csv"),
          edge_ok("outputs/10_run_all/variants/graduation/honestdid_overall.csv"))
for (o in c("achievement", "graduation")) {
  xf <- file.path("outputs/10_run_all/dose", o, "revenue_exclusions.csv")
  if (!file.exists(xf)) next
  xr <- utils::read.csv(xf, stringsAsFactors = FALSE, na.strings = "")
  stopifnot(nrow(xr) == 1L + 3L * length(outcome_gaps(o)),
            all(xr$excluded_total <= xr$excluded_enrollment_below_30 + xr$excluded_revenue_above_100k),
            all(xr$excluded_total >= pmax(xr$excluded_enrollment_below_30, xr$excluded_revenue_above_100k)),
            all(xr$excluded_total <= xr$district_years_with_revenue))
}
lsf <- "outputs/10_run_all/lee/lee_share_models.csv"
if (file.exists(lsf)) stopifnot(all(utils::read.csv(lsf)$share_years_from == min(ACH_WINDOW)))   # 2010 on, from the 2006-07 CCD file
lf <- "outputs/10_run_all/lee/lee_bounds.csv"
if (file.exists(lf)) {
  lb <- utils::read.csv(lf, stringsAsFactors = FALSE, na.strings = "")
  stopifnot(identical(lb$gap, c("b_black_white", "c_hispanic_white")),
            all(lb$lee_lower <= lb$lee_upper | lb$status != "ok"), all(lb$trim_fraction >= 0 & lb$trim_fraction <= 1 | is.na(lb$trim_fraction)))
}
rf <- "outputs/13_report/report.md"
if (file.exists(rf)) {
  txt <- readLines(rf, warn = FALSE, encoding = "UTF-8")
  stopifnot(!any(grepl("significan", txt, ignore.case = TRUE) & !grepl("no result is described as statistically significant", txt)))
  gaps_all <- c(outcome_gaps("achievement"), outcome_gaps("graduation"))
  heads <- grep("^## Gap|^## Graduation", txt)
  stopifnot(length(heads) == length(gaps_all))
  for (i in seq_along(heads)) {                                                 # honest-DiD bound sets lead every gap
    end <- if (i < length(heads)) heads[i + 1] else length(txt)
    sub <- txt[heads[i]:end]
    stopifnot(grepl("^### 1\\. Honest-DiD", sub[grep("^### ", sub)[1]]), any(grepl("\\*\\*headline\\*\\*", sub)),
              all(paste0("### ", 1:9, ".") %in% substr(sub[grepl("^### [1-9]\\.", sub)], 1, 6)))
  }
  stopifnot(max(grep("^# Primary achievement gaps", txt)) < min(grep("^# Secondary outcome: graduation", txt)))
  tabs <- list.files("outputs/13_report/tables", full.names = TRUE)
  for (f in tabs) stopifnot(!any(c("g", "t", "treat_year", "cohort_year", "group") %in% names(utils::read.csv(f, nrows = 1))))
  stopifnot(length(list.files("outputs/13_report/plots", pattern = "\\.png$")) == length(gaps_all))
}

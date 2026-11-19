withr::local_dir(ROOT)

test_that("graduation loaders, gaps and the graduation pass", {
GW <- GRAD_WINDOW
expect_all(identical(GW, 2011:2021), identical(GRAD_FILE_YEARS, 2011:2024), identical(GRAD_RULES_WINDOW, 2010:2021),
          identical(unname(GRAD_GAPS), c("bw", "hw")), identical(GRAD_SEC_FLAGS, "cep"))

expect_all(outcome_arg(character()) == "achievement", outcome_arg(c("--quick")) == "achievement",
          outcome_arg(c("--quick", "--outcome", "graduation")) == "graduation",
          outcome_arg("--outcome=graduation") == "graduation", outcome_arg("--outcome=achievement") == "achievement")
expect_all(inherits(try(outcome_arg(c("--outcome", "poverty")), silent = TRUE), "try-error"),
          inherits(try(outcome_arg("--outcome"), silent = TRUE), "try-error"),
          inherits(try(outcome_arg(c("--outcome=graduation", "--outcome", "achievement")), silent = TRUE), "try-error"))

expect_all(identical(acgr_value(c(">=80%", ">=80", "<50%", "<=5%", "90-94%", "93%", "93", "S", "MISSING", "PS",
                                 "GE95", "LT50", "", NA, " 20-29 ")),
                    c("GE80", "GE80", "LT50", "LE5", "90-94", "93", "93", "PS", "PS", "PS",
                      "GE95", "LT50", "", "", "20-29")))
expect_all(inherits(try(acgr_value("about 90"), silent = TRUE), "try-error"),
          inherits(try(acgr_value("n<10"), silent = TRUE), "try-error"))
r <- edfacts_range(acgr_value(c(">=80%", "<50%", "90-94%", "93%", "S")))
expect_all(identical(r$width, c(20, 50, 4, 0, NA)), identical(r$mid, c(90, 25, 92, 93, NA)))

tmpw <- tempfile(fileext = ".csv")
writeLines(c("STNAM,FIPST,LEAID,LEANM,ALL_COHORT_1011,ALL_RATE_1011,MBL_COHORT_1011,MBL_RATE_1011,MHI_COHORT_1011,MHI_RATE_1011,MWH_COHORT_1011,MWH_RATE_1011,DATE_CUR",
             "ALABAMA,01,0100005,A,252,80,40,70-79,,,184,80-84,x",
             "ALABAMA,01,0100006,\"B, County\",398,75,29,GE50,31,PS,362,77,x"), tmpw)
aw <- read_acgr_lea(tmpw, 2011L)
expect_all(identical(names(aw), c("leaid", "n_wh", "r_wh", "n_bl", "r_bl", "n_hi", "r_hi")),
          identical(aw$leaid, c("0100005", "0100006")), identical(aw$r_bl, c("70-79", "GE50")),
          identical(aw$n_hi, c("", "31")), identical(aw$r_hi, c("", "PS")), identical(aw$n_wh, c("184", "362")))
expect_all(inherits(try(read_acgr_lea(tmpw, 2012L), silent = TRUE), "try-error"))

tmpl <- tempfile(fileext = ".csv")
hdr <- "\"School Year\",State,\"NCES LEA ID\",LEA,School,\"NCES SCH ID\",\"Data Group\",\"Data Description\",Value,Numerator,Denominator,Population,Subgroup,Characteristics,Age/Grade,\"Academic Subject\",Outcome,\"Program Type\""
row <- function(id, v, n, sg) sprintf("2020-2021,ALABAMA,%s,\"L\",,,695|696,\"ACGR\",%s,,%s,\"All Students\",\"%s\",,,,,", id, v, n, sg)
writeLines(c(hdr, row("0100005", "93%", "385", "All Students in LEA"),
             row("0100005", ">=80%", "40", "Black (not Hispanic) African American"),
             row("0100005", "90-94%", "120", "White or Caucasian (not Hispanic)"),
             row("0100006", "S", "3", "Hispanic/Latino"),
             row("0100006", "<50%", "12", "White or Caucasian (not Hispanic)"),
             row("Not Applicable", "MISSING", "0", "Missing")), tmpl)
al <- read_acgr_long(tmpl, 2021L)
expect_all(identical(al$leaid, c("0100005", "0100006")), identical(al$r_bl, c("GE80", "")), identical(al$n_bl, c("40", "")),
          identical(al$r_wh, c("90-94", "LT50")), identical(al$r_hi, c("", "PS")), identical(al$n_hi, c("", "3")))
expect_all(inherits(try(read_acgr_long(tmpl, 2020L), silent = TRUE), "try-error"))
bad <- readLines(tmpl); bad[7] <- row("Not Applicable", "50%", "10", "Missing"); writeLines(bad, tmpl)
expect_all(inherits(try(read_acgr_long(tmpl, 2021L), silent = TRUE), "try-error"))

ac <- data.frame(leaid = sprintf("01%05d", 1:7), sy_end = 2011L,
                 n_wh = c("30", "29", "45", "45", "", "400", "80"), r_wh = c("80-89", "GE80", "GE80", "PS", "", "91", "GE95"),
                 n_bl = "50", r_bl = "70-79", n_hi = "", r_hi = "", stringsAsFactors = FALSE)
gc <- grad_cells(ac)
expect_all(identical(gc$cell_wh, c("usable", "below_30", "wide_range", "suppressed", "not_reported", "usable", "usable")),
          identical(gc$p_wh, c(84.5, NA, NA, NA, NA, 91, 97.5)), identical(gc$w_wh, c(9, 20, 20, NA, NA, 0, 5)),
          identical(gc$n_wh, c(30, 29, 45, 45, NA, 400, 80)), all(gc$cell_hi == "not_reported"))
expect_all(identical(cell_in_sample(gc$cell_wh, gc$w_wh, "r5"), c(FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, TRUE)),
          identical(cell_in_sample(gc$cell_wh, gc$w_wh, "exact"), c(FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE)))

gd <- cbind(gc, state = "AL", retained = 1L, retained_r1 = 0L, retained_r2 = 1L)
gg <- grad_gaps(gd, "primary")
expect_all(identical(gg$leaid, gd$leaid[c(1, 6, 7)]), all(is.na(gg$v_hw)),
          near(gg$v_bw, v_gap(0.745, gg$p_wh, 50, gg$n_wh)), all(gg$v_bw < 0),
          near(gg$se_bw, v_gap_se(0.745, gg$p_wh, 50, gg$n_wh)), identical(gg$p_wh, c(0.845, 0.91, 0.975)))
expect_all(identical(grad_gaps(gd, "r5")$leaid, gd$leaid[integer()]))
g100 <- gd[6, ]; g100$p_wh <- 100; g100$p_bl <- 55; g100$w_bl <- 0
expect_all(is.finite(grad_gaps(g100, "exact")$v_bw), near(grad_gaps(g100, "exact")$v_bw, qnorm(0.55) - qnorm(1 - 1 / 800)))

gp <- function(leaid, years, v = -0.3, n_bl = 40, n_wh = 100, state = "AL", sample = "primary", r = 1L)
  data.frame(leaid = leaid, state = state, sy_end = years, sample = sample, retained = r, retained_r1 = r,
             retained_r2 = 1L, v_bw = v, se_bw = 0.1, v_hw = NA_real_, se_hw = NA_real_,
             n_wh = n_wh, n_bl = n_bl, n_hi = NA_real_, stringsAsFactors = FALSE)
pg <- rbind(gp("D1", GW), gp("D2", GW[-3]), gp("D3", GW[-1]), gp("D4", GW, r = 0L), gp("D5", GW, sample = "r5"))
pg$n_bl[pg$leaid == "D1" & pg$sy_end == 2012] <- 90
pb <- grad_panel(pg, "bw", "retained", GW, "primary", balanced = TRUE)
pu <- grad_panel(pg, "bw", "retained", GW, "primary", balanced = FALSE)
expect_all(identical(unique(pb$leaid), "D1"), identical(pb$sy_end, GW), all(pb$cohort_2011 == 140),
          identical(names(pb), c("leaid", "state", "sy_end", "y", GRAD_WEIGHT)))
expect_all(identical(sort(unique(pu$leaid)), c("D1", "D2", "D3")), identical(pu$sy_end[pu$leaid == "D2"], GW[-3]),
          all(is.na(pu$cohort_2011[pu$leaid == "D3"])), !anyNA(pu$cohort_2011[pu$leaid != "D3"]),
          identical(sort(unique(grad_panel(pg, "bw", "retained_r2", GW, balanced = FALSE)$leaid)), c("D1", "D2", "D3", "D4")),
          nrow(grad_panel(pg, "hw", "retained", GW)) == 0)
expect_all(identical(unique(grad_panel(pg[pg$sy_end != 2020, ], "bw", "retained", GW)$leaid), character()))
cg <- cohort_coding(data.frame(state = c("A", "B", "C", "D"), treat_year = c(2011L, 2012L, 2022L, NA),
                               group = c("treated", "treated", "treated", "never"), stringsAsFactors = FALSE), GW)
expect_all(identical(cg$cohort_status, c("first_year", "estimable", "after_window", "never")),
          identical(cg$g, c(NA, 2012L, 0L, 0L)))

fl <- data.frame(leaid = c("D1", "D1", "D2"), sy_end = c(2011L, 2012L, 2011L), cep = c(0L, 1L, 0L), stringsAsFactors = FALSE)
pa <- attach_district_flags(data.frame(leaid = c("D1", "D2", "D1"), sy_end = c(2012L, 2011L, 2011L)), fl)
expect_all(identical(pa$cep, c(1L, 0L, 0L)),
          inherits(try(attach_district_flags(data.frame(leaid = "D3", sy_end = 2011L), fl), silent = TRUE), "try-error"))

tmps <- tempfile(fileext = ".csv")
utils::write.csv(data.frame(leaid = c("0100005", "0100005", "0100006"), sy_end = c(2011, 2012, 2011),
                            saipe_pov_rate_2009 = c(0.2, 0.2, 0.3)), tmps, row.names = FALSE)
sp <- graduation_saipe(c("0100006"), tmps)
expect_all(identical(sp$leaid, "0100006"), sp$sy_end == 2010L, sp$saipe_pov_rate_2009 == 0.3)

tmpc <- tempfile(fileext = ".csv")
writeLines(c("SCHOOL_YEAR,FIPST,LEAID,LEA_NAME,UPDATED_STATUS,LEA_TYPE,GSHI",
             "2020-2021,01,0100005,\"A, City\",1,1,12", "2020-2021,01,0100006,B,5,2,12", "2020-2021,01,0100007,C,3,9,08"), tmpc)
cc <- read_ccd_lea_any(tmpc, 2021L)
expect_all(identical(cc$agency_type, c(1L, 2L, 9L)), identical(cc$ccd_bound, c(1L, 5L, 3L)),
          identical(cc$gshi, c("12", "12", "08")), all(cc$sy_end == 2021L), identical(cc$fipst, rep("01", 3)))
tmpt <- tempfile(fileext = ".txt")
writeLines(c("SURVYEAR\tFIPST\tLEAID\tLEA_TYPE\tUPDATED_STATUS\tGSHI", "2014\t01\t0100005\t1\t8\t12"), tmpt)
expect_all(read_ccd_lea_any(tmpt, 2015L)$ccd_bound == 8L)
writeLines(c("SURVYEAR\tFIPST\tLEAID\tLEA_TYPE\tUPDATED_STATUS\tGSHI", "2014\t01\t0100005\t1\t9\t12"), tmpt)
expect_all(inherits(try(read_ccd_lea_any(tmpt, 2015L), silent = TRUE), "try-error"))
lr <- data.frame(leaid = rep(c("A", "B", "C", "D"), each = 3), sy_end = rep(2019:2021, 4),
                 agency_type = c(1, 1, 1, 1, 1, 1, 1, 1, 9, 2, 2, 2), ccd_bound = c(1, 1, 1, 1, 5, 1, 1, 1, 1, 1, 6, 1))
expect_all(identical(district_rules(lr, 2019:2021)$rule12,
                    c("pass", "rule 2: boundary change (BOUND 5 or 8)", "rule 1: agency type not 1 or 2",
                      "rule 2: not operational in every window year")))

am <- acgr_manifest()
expect_all(identical(am$sy_end, GRAD_FILE_YEARS), identical(am$sy_end[!am$published], 2022:2024))
if (all(file.exists(am$path[am$published]))) {
  for (y in c(2011L, 2019L, 2021L)) {
    x <- read_acgr_lea(am$path[am$sy_end == y], y)
    expect_all(nrow(x) > 10000, !anyDuplicated(x$leaid), all(grepl("^[0-9]{7}$", x$leaid)))
    for (s in GRAD_SUBGROUPS) {
      n <- x[[paste0("n_", s)]]
      expect_all(all(!nzchar(n) | grepl("^[0-9]+$", n)), sum(nzchar(n)) > 1000,
                all(grepl(ACGR_VALUE_OK, x[[paste0("r_", s)]])))
    }
  }
}
for (y in c(2014L, 2015L, 2021L)) {
  if (!file.exists(ccd_lea_zip(y))) next
  x <- read_ccd_lea_year(y)
  expect_all(nrow(x) > 18000, all(x$agency_type %in% 1:9), all(x$ccd_bound %in% 1:8), sum(x$agency_type %in% 1:2) > 13000)
}

expect_all(!any(grepl("treat_year", c(readLines("R/03g_graduation_sample.R"), readLines("R/04g_graduation_outcomes.R")))))

gsf <- "data/derived/graduation_sample_district_year.csv"
if (file.exists(gsf)) {
  gs <- utils::read.csv(gsf, colClasses = c(leaid = "character"), stringsAsFactors = FALSE, na.strings = "")
  expect_all(identical(names(gs), c("leaid", "state", "sy_end", "retained", "reason", "retained_r1", "retained_r2",
                                   "agency_type", "ccd_bound", "saipe_pov_rate_2009", "cep",
                                   as.vector(outer(c("n_", "p_", "w_", "cell_"), GRAD_SUBGROUPS, paste0)))))
  expect_all(setequal(gs$sy_end, GW), !anyDuplicated(gs[c("leaid", "sy_end")]), all(gs$cep %in% 0:1),
            setequal(gs$state, names(STATE_FIPS)))
  for (s in GRAD_SUBGROUPS) {
    cl <- gs[[paste0("cell_", s)]]; n <- gs[[paste0("n_", s)]]; p <- gs[[paste0("p_", s)]]; w <- gs[[paste0("w_", s)]]
    expect_all(all(cl %in% c("not_reported", "below_30", "suppressed", "wide_range", "usable")),
              identical(!is.na(p), cl == "usable"), all(n[cl == "usable"] >= 30), all(w[cl == "usable"] <= 10),
              all(is.na(n[cl == "not_reported"])), all(n[cl == "below_30"] < 30), all(w[cl == "wide_range"] > 10))
  }
  kr <- gs$retained == 1L | gs$retained_r1 == 1L | gs$retained_r2 == 1L
  expect_all(all(gs$agency_type[kr] %in% 1:2), !any(gs$ccd_bound[kr] %in% c(2L, 5L, 6L, 7L, 8L)),
            !anyNA(gs$saipe_pov_rate_2009[kr]), all(table(gs$leaid[kr]) == length(GW)))
  sets <- c(retained = "event_table.csv", retained_r1 = "event_table_r1.csv", retained_r2 = "event_table_r2.csv")
  pass <- !gs$reason %in% c("rule 1: agency type not 1 or 2", "rule 2: not operational in every window year",
                            "rule 2: boundary change (BOUND 5 or 8)", "no SAIPE 2009 poverty rate")
  for (fg in names(sets)) {
    e <- utils::read.csv(file.path("data", "reference", sets[[fg]]), stringsAsFactors = FALSE)
    expect_all(identical(gs[[fg]] == 1L, pass & !gs$state %in% e$state[e$group == "excluded"]))
  }
}

ggf <- "data/derived/gaps_graduation_district_year.csv"
if (file.exists(ggf) && file.exists(gsf)) {
  g <- utils::read.csv(ggf, colClasses = c(leaid = "character"), stringsAsFactors = FALSE, na.strings = "")
  expect_all(identical(names(g), c("leaid", "state", "sy_end", "sample", "retained", "retained_r1", "retained_r2",
                                  "v_bw", "se_bw", "v_hw", "se_hw",
                                  paste0(rep(c("n_", "p_", "w_"), each = 3), GRAD_SUBGROUPS))))
  expect_all(!anyDuplicated(g[c("leaid", "sy_end", "sample")]), all(g$sample %in% names(MAX_WIDTH)),
            all(g$sy_end %in% GW), all(!is.na(g$v_bw) | !is.na(g$v_hw)))
  for (gk in GRAD_GAPS) {
    a <- RACE_GAPS[[gk]][1]; b <- RACE_GAPS[[gk]][2]
    v <- g[[paste0("v_", gk)]]; k <- !is.na(v)
    expect_all(near(v[k], v_gap(g[[paste0("p_", a)]][k], g[[paste0("p_", b)]][k], g[[paste0("n_", a)]][k], g[[paste0("n_", b)]][k])),
              all(g[[paste0("n_", a)]][k] >= 30), all(g[[paste0("n_", b)]][k] >= 30),
              all(g[[paste0("w_", a)]][k] <= MAX_WIDTH[g$sample[k]]), all(g[[paste0("w_", b)]][k] <= MAX_WIDTH[g$sample[k]]))
    for (pr in list(c("exact", "r5"), c("r5", "primary"))) {
      x <- g[g$sample == pr[1] & k, ]; y <- g[g$sample == pr[2] & k, ]
      m <- match(paste(x$leaid, x$sy_end), paste(y$leaid, y$sy_end))
      expect_all(!anyNA(m), near(x[[paste0("v_", gk)]], y[[paste0("v_", gk)]][m]))
    }
  }
  expect_all(mean(g$v_bw[g$sample == "primary"], na.rm = TRUE) < 0, mean(g$v_hw[g$sample == "primary"], na.rm = TRUE) < 0)
  m <- match(paste(g$leaid, g$sy_end), paste(gs$leaid, gs$sy_end))
  expect_all(!anyNA(m), all(g$retained == gs$retained[m]), all(g$retained_r1 == gs$retained_r1[m]),
            all(g$retained_r2 == gs$retained_r2[m]), all(g$state == gs$state[m]))
  cy <- utils::read.csv(file.path("outputs", "04g_graduation_outcomes", "gap_counts_by_year.csv"), stringsAsFactors = FALSE)
  x <- cy[cy$sample == "primary" & cy$event_set == "primary" & cy$gap == "grad_black_white", ]
  expect_all(identical(x$sy_end, GW),
            identical(x$district_years, vapply(GW, function(y) sum(g$sample == "primary" & g$retained == 1L &
                                                                      !is.na(g$v_bw) & g$sy_end == y), integer(1))))
}

rdg <- function(f) utils::read.csv(f, stringsAsFactors = FALSE, na.strings = "")
of5g <- file.path("outputs", "05_primary", "graduation",
                  c("event_time_estimates.csv", "overall_estimates.csv", "model_status.csv", "panel_counts.csv"))
if (all(file.exists(of5g))) {
  ee <- rdg(of5g[1]); oo <- rdg(of5g[2]); ms <- rdg(of5g[3]); pc <- rdg(of5g[4])
  keyg <- function(x) paste(x$gap, x$event_set, x$weighting, x$panel)
  models <- as.vector(outer(outer(names(GRAD_GAPS), c("primary", "r1", "r2"), paste),
                            outer(c("unweighted", "tested_weighted"), names(PANEL_TYPES), paste), paste))
  expect_all(nrow(ms) == 24, setequal(keyg(ms), models), !anyDuplicated(keyg(ms)),
            all(ms$status %in% c("ok", "no estimable cohort") | startsWith(ms$status, "error:")),
            sum(ms$status == "ok") >= 12, nrow(ee) == 24 * 14, nrow(oo) == 24)
  ok <- keyg(ee) %in% keyg(ms)[ms$status == "ok"]
  expect_all(all(ee$att[ok & ee$e == -1] == 0), all(is.na(ee$att[!ok])), all(ee$treated_units >= ee$treated_states))
  expect_all(nrow(pc) == 12, setequal(pc$gap, names(GRAD_GAPS)), all(pc$unit == "district"),
            all(pc$units_in_model == pc$units_estimable + pc$units_after_window + pc$units_never),
            all(pc$unit_years_per_unit[pc$panel == "balanced"] == length(GW) | pc$units_in_model == 0),
            all(pc$unit_years_per_unit <= length(GW)), all(pc$dropped_missing_weight[pc$panel == "balanced"] == 0))
}

for (d6 in c(unbalanced = "outputs/06_secondary/graduation", balanced = "outputs/06_secondary/appendix/graduation")) {
of6g <- file.path(d6, c("event_time_estimates.csv", "overall_estimates.csv", "model_status.csv", "panel_counts.csv"))
if (all(file.exists(of6g))) {
  pname <- if (grepl("appendix", d6)) "balanced" else "unbalanced"
  ee <- rdg(of6g[1]); oo <- rdg(of6g[2]); ms <- rdg(of6g[3]); pc6 <- rdg(of6g[4])
  ests <- c("sun_abraham", "imputation", "synthdid", "stacked", "twfe", "twfe_static")
  models <- as.vector(outer(ests, outer(names(GRAD_GAPS), c("primary", "r1", "r2"), paste), paste))
  key6 <- function(x) paste(x$estimator, x$gap, x$event_set)
  expect_all(nrow(ms) == 36, setequal(key6(ms), models), all(ms$panel == pname), all(ms$weighting == "unweighted"),
            nrow(ee) == 30 * 14, nrow(oo) == 36)
  if (all(file.exists(of5g))) {
    p5 <- rdg(of5g[4]); p5 <- p5[p5$panel == pname, ]
    x <- pc6[pc6$estimator == "twfe", ]
    k <- match(paste(x$gap, x$event_set), paste(p5$gap, p5$event_set))
    expect_all(!anyNA(k), all(x$units_in_model == p5$units_in_model[k]))
  }
  fits <- readRDS(file.path(d6, "secondary_models.rds"))
  tw <- fits[[paste("twfe", "grad_black_white", "primary", sep = ".")]]
  if (!is.null(tw)) expect_all(!any(grepl("test_replaced", names(stats::coef(tw)))),
                              any(grepl("^cy_log_member_2009_", names(stats::coef(tw)))))
}
}

of7g <- file.path("outputs", "07_inference", "graduation",
                  c("bootstrap_overall.csv", "romano_wolf.csv", "honestdid_overall.csv", "randomization_overall.csv",
                    "model_status.csv", "inference_settings.csv"))
if (all(file.exists(of7g))) {
  bo <- rdg(of7g[1]); rwg <- rdg(of7g[2]); hd <- rdg(of7g[3]); ro <- rdg(of7g[4]); st <- rdg(of7g[5]); se <- rdg(of7g[6])
  expect_all(se$value[se$setting == "outcome"] == "graduation", nrow(st) == 24, setequal(st$gap, names(GRAD_GAPS)))
  used <- paste(st$gap, st$event_set, st$weighting, st$panel)[st$status == "ok"]
  k7 <- function(x) paste(x$gap, x$event_set, x$weighting, x$panel)
  expect_all(setequal(k7(bo), used), setequal(k7(ro), used), setequal(k7(hd), used),
            all(bo$p_value > 0 & bo$p_value <= 1), all(ro$p_value > 0 & ro$p_value <= 1))
  expect_all(all(rwg$hypotheses == 2L), all(rwg$gap %in% names(GRAD_GAPS)), all(rwg$weighting == rwg$family),
            all(rwg$p_romano_wolf >= rwg$p_unadjusted - 1e-12))
}
})

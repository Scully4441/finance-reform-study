withr::local_dir(ROOT)

test_that("report-card outcomes and the step 10 output", {
expect_all(identical(RC_SAMPLE_SUBGROUPS, unname(SUBGROUPS)), identical(HS_RC_WINDOW, 2022:2025),
          identical(HS_RC_CCD_YEARS, 2022:2024))

expect_all(identical(rc_count(c("1,234", "45", "19.00", "*", "-1", "TFS", "", NA, "30 - 35")),
                    c(1234, 45, 19, NA, NA, NA, NA, NA, NA)))
expect_all(identical(rc_count_band_lo(c("30 - 35", "     290 - 299", "1 - 5", "45", "*")), c(30, 290, 1, NA, NA)))

r <- rc_pct(c("45.2", "45.2%", "20-29%", "<5", "< 5.0%", ">95", ">= 90%", paste0(intToUtf8(0x2264), " 20%"), paste0(intToUtf8(0x2265), " 80%"), "LT5", "*", "", NA, "NSIZE", "  95.1%"))
expect_all(identical(r$lo, c(45.2, 45.2, 20, 0, 0, 95, 90, 0, 80, 0, NA, NA, NA, NA, 95.1)),
          identical(r$hi, c(45.2, 45.2, 29, 5, 5, 100, 100, 20, 100, 5, NA, NA, NA, NA, 95.1)))
expect_all(identical(rc_pct(c("0.4523", "1"), scale = 100)$lo, c(45.23, 100)))
expect_all(inherits(try(rc_pct("60-40"), silent = TRUE), "try-error"), inherits(try(rc_pct("120"), silent = TRUE), "try-error"))
s <- rc_pct_sum(c("22", "< 5", "*", "< 5"), c("10", "30", "5", "< 5"))
expect_all(identical(s$lo, c(32, 30, NA, 0)), identical(s$hi, c(32, 35, NA, 10)))

x <- rc_long("NH", 2023, st_id = NA_character_, name = c("A", "A", "B"), subject = c("math", "rla", "math"),
             sg = c("all", "bl", "wh"), n_band_lo = c(30, 25, NA), p = data.frame(lo = c(50, 40, NA), hi = c(50, 40, NA)))
expect_all(nrow(x) == 3, identical(x$sg, c("all", "bl", "wh")), identical(x$subject, c("math", "rla", "math")), all(is.na(x$st_id)))
expect_all(inherits(try(rc_long("XX", 2023, "1", "a", "science", "all"), silent = TRUE), "try-error"))

comp <- function(id, sg, n, p, component, part = NA, part_n = NA)
  rc_long("GA", 2022, st_id = id, name = "d", subject = "math", sg = sg, n = n, p = data.frame(lo = p, hi = p),
          component = component, part = part, part_n = part_n)
pl <- rc_pool(rbind(comp("1", "all", c(100, 50), c(40, 70), c("Algebra I", "Coordinate Algebra"), c("90", "100"), c(110, 50)),
                    comp("2", "all", c(100, NA), c(40, 70), c("Algebra I", "Coordinate Algebra")),
                    comp("3", "all", c(100, 3), c(40, NA), c("Algebra I", "Coordinate Algebra")),
                    comp("4", "all", c(NA, NA), c(40, 70), c("Algebra I", "Coordinate Algebra")),
                    rc_long("GA", 2022, "5", "d", "rla", "all", n = 80, p = data.frame(lo = 60, hi = 60))))
pl <- pl[order(pl$st_id), ]
expect_all(identical(pl$st_id, c("1", "2", "3", "5")), identical(pl$n, c(150, 100, 100, 80)),
          isTRUE(all.equal(pl$p_lo, c(50, 40, 40, 60))), all(is.na(pl$component)),
          isTRUE(all.equal(as.numeric(pl$part[1]), (110 * 90 + 50 * 100) / 160)), is.na(pl$part[2]))
pr <- rc_pool(rbind(rc_long("DC", 2024, "1", "d", "math", "bl", n = c(20, 20), p = data.frame(lo = c(0, 30), hi = c(10, 30)),
                            component = c("Algebra I", "Geometry"))))
expect_all(pr$p_lo == 15, pr$p_hi == 20)

cx <- rc_long("ZZ", 2023, st_id = "1", name = "d", subject = "math", sg = c("all", "wh", "bl", "hi"),
              n = c(40, 20, NA, NA), n_band_lo = c(NA, NA, 0, NA), p = data.frame(lo = c(45, 50, 30, 20), hi = c(45, 50, 30, 29)),
              part = c("96.0%", ">95", NA, "GE95"))
cx <- rbind(cx, rc_long("ZZ", 2023, st_id = "1", name = "d", subject = "rla", sg = c("all", "wh", "bl", "hi"),
                        n = c(35, NA, NA, 31), p = data.frame(lo = c(NA, 0, 90, 10), hi = c(NA, 30, 100, 10)), part = "99"))
cx$leaid <- "0100001"
ce <- rc_cells(cx, min_n = 10, part_applies = TRUE)
expect_all(nrow(ce) == 1, ce$cell_math_all == "usable", ce$nbasis_math_all == "exact", ce$nclamp_math_all == 40,
          ce$cell_math_wh == "below_30", ce$cell_math_bl == "below_30", ce$nbasis_math_bl == "band_lower",
          ce$cell_math_hi == "usable", ce$nbasis_math_hi == "min_group", ce$nclamp_math_hi == 10, ce$p_math_hi == 24.5,
          ce$w_math_hi == 9, is.na(ce$n_math_hi),
          ce$cell_rla_all == "suppressed", ce$cell_rla_wh == "wide_range", ce$cell_rla_bl == "usable", ce$p_rla_bl == 95,
          ce$cell_math_ecd == "not_reported", ce$nbasis_math_ecd == "none",
          ce$part_ok_math_all == 1L, ce$part_ok_math_wh == 1L, ce$part_ok_math_bl == 0L, ce$part_ok_math_hi == 1L,
          ce$part_ok_math_ecd == 0L)
ce2 <- rc_cells(cx, min_n = 10, part_applies = FALSE)
expect_all(is.na(ce2$part_ok_math_all), is.na(ce2$part_math_all))
expect_all(inherits(try(rc_cells(rbind(cx, cx), 10, TRUE), silent = TRUE), "try-error"))

ce$retained <- ce$retained_r1 <- ce$retained_r2 <- 1L
ce$part_ok_math_bl <- 1L; ce$cell_math_bl <- "usable"; ce$p_math_bl <- 30; ce$w_math_bl <- 0; ce$nclamp_math_bl <- 35
ce$cell_math_wh <- "usable"; ce$p_math_wh <- 50; ce$w_math_wh <- 0; ce$n_math_wh <- 60; ce$nclamp_math_wh <- 60; ce$part_ok_math_wh <- 1L
g <- rc_race_gaps(ce, "math", "primary")
expect_all(nrow(g) == 1, isTRUE(all.equal(g$v_hw, v_gap(0.245, 0.5, 10, 60))), is.na(g$se_hw),
          is.finite(g$v_bw), is.na(g$se_bw))
ce$n_math_hi <- 40; ce$nclamp_math_hi <- 40
g <- rc_race_gaps(ce, "math", "primary")
expect_all(isTRUE(all.equal(g$se_hw, v_gap_se(0.245, 0.5, 40, 60))), isTRUE(all.equal(g$v_hw, v_gap(0.245, 0.5, 40, 60))))
g5 <- rc_race_gaps(ce, "math", "exact")
expect_all(is.na(g5$v_hw))

expect_all(identical(rc_name_key(c("Albany County School District #1", "Albany #1", "Nashua School District", "Bristol-Warren")),
                    c("ALBANY 1", "ALBANY 1", "NASHUA", "BRISTOL WARREN")))
ccd <- data.frame(sy_end = c(2024L, 2023L, 2024L, 2024L, 2024L), state = c("GA", "GA", "WY", "NH", "NH"),
                  leaid = c("1300001", "1300009", "5600001", "3300001", "3300002"), st_leaid = c("601", "602", "0101000", "001", "002"),
                  lea_name = c("Appling County", "Old", "Albany County School District #1", "Dover School District", "Dover"),
                  agency_type = c(1L, 1L, 1L, 1L, 4L), status = c(1L, 2L, 5L, 1L, 1L), stringsAsFactors = FALSE)
keys <- data.frame(state = c("GA", "GA", "GA", "WY", "NH", "WY"), st_id = c("601", "602", "999", NA, NA, NA),
                   name = c("x", "y", "z", "Albany #1", "Dover", "Nowhere"), stringsAsFactors = FALSE)
cw <- rc_crosswalk_draft(keys, ccd)
expect_all(identical(cw$leaid, c("1300001", "1300009", NA, "5600001", NA, NA)),
          identical(cw$method, c("st_leaid", "st_leaid", "unmatched", "name", "ambiguous", "unmatched")),
          all(cw$author_check == ""))
expect_all(identical(rc_xw_key(c("NH", "GA"), c(NA, "601"), c("Dover", "x")), c("NH name Dover", "GA id 601")))

expect_all(!exists("rc_rule12"), identical(HS_RULES_WINDOW, c(2010:2019, 2021:2024)), identical(hs_rules_window(2L), HS_RULES_WINDOW),
           identical(hs_rules_window(1L), 2010:2013))
lea_t <- rbind(data.frame(leaid = "0100001", sy_end = HS_RULES_WINDOW, agency_type = 1L, ccd_bound = 1L),
               data.frame(leaid = "0100002", sy_end = HS_RULES_WINDOW, agency_type = 1L, ccd_bound = ifelse(HS_RULES_WINDOW == 2023L, 5L, 1L)),
               data.frame(leaid = "0100003", sy_end = setdiff(HS_RULES_WINDOW, 2024L), agency_type = 1L, ccd_bound = 1L))
dr_t <- district_rules(lea_t, HS_RULES_WINDOW)
expect_all(identical(dr_t$rule12, c("pass", "rule 2: boundary change (BOUND 5 or 8)", "rule 2: not operational in every window year")))

dd <- rbind(cx, cx[1, ], transform(cx[2, ], p_lo = 99, p_hi = 99))
dd <- rc_dedupe(dd)
expect_all(nrow(dd) == nrow(cx) - 1, nrow(attr(dd, "conflicts")) == 2)

hz <- read_hs_harmonization()
expect_all(all(c("subgroup_all", "participation_col", "min_group_size", "min_group_source") %in% names(hz)),
          !anyDuplicated(hz[c("state", "sy_end")]), all(hz$sy_end %in% HS_RC_WINDOW),
          all(hz$mapping_status %in% c("mapped", "unavailable")))
mp <- hz[hz$mapping_status == "mapped", ]
expect_all(nrow(mp) == 167, all(mp$state %in% names(HS_RC_LOADERS)), all(names(HS_RC_LOADERS) %in% mp$state),
          all(grepl("^[0-9]+$", mp$min_group_size)), all(nzchar(mp$min_group_source)))
rcf <- unlist(lapply(split(mp, seq_len(nrow(mp))), rc_files))
rc_man <- utils::read.csv("data/manifest/download_manifest.csv", colClasses = "character", na.strings = character(0))
expect_all(all(sub("^data/raw/", "", rcf) %in% rc_man$filename))
if (any(file.exists(rcf))) expect_all(all(file.exists(rcf)))
expect_all(all(is.na(mp$subgroup_all[mp$state %in% c("CO", "CT", "FL", "OH", "RI")]) |
                !nzchar(mp$subgroup_all[mp$state %in% c("CO", "CT", "FL", "OH", "RI")])))
un <- hz[hz$mapping_status == "unavailable", ]
expect_all(setequal(paste(un$state, un$sy_end), c(paste("AK", 2022:2025), "AR 2022", paste("IA", 2022:2025), "ID 2025", "ME 2022",
                                                  paste("MI", 2022:2025), paste("MS", 2022:2025), paste("MT", 2022:2025))))

if (file.exists(HS_RC_CROSSWALK)) {
  xw <- utils::read.csv(HS_RC_CROSSWALK, colClasses = "character", na.strings = "")
  expect_all(identical(names(xw), c("state", "st_id", "name", "leaid", "method", "ccd_st_leaid", "ccd_name", "ccd_sy_end", "author_check")),
            all(xw$method %in% c("st_leaid", "name", "ambiguous", "unmatched")),
            identical(is.na(xw$leaid), xw$method %in% c("ambiguous", "unmatched")),
            all(grepl("^[0-9]{7}$", xw$leaid[!is.na(xw$leaid)])),
            !anyDuplicated(rc_xw_key(xw$state, xw$st_id, xw$name)),
            all(xw$state[xw$method == "name"] %in% HS_RC_NAME_STATES))
}

if (file.exists("data/derived/hs_panel.csv") && file.exists("data/derived/sample_district_year.csv")) {
  p <- utils::read.csv("data/derived/hs_panel.csv", colClasses = c(leaid = "character"), stringsAsFactors = FALSE, na.strings = "")
  s1 <- utils::read.csv("data/derived/sample_district_year.csv", colClasses = c(leaid = "character"), stringsAsFactors = FALSE, na.strings = "")
  e1 <- p[p$source == "edfacts", names(s1)]
  rownames(e1) <- NULL
  s1 <- s1[order(s1$state, s1$leaid, s1$sy_end), ]; rownames(s1) <- NULL
  expect_all(isTRUE(all.equal(e1, s1, check.attributes = FALSE)),
            all(p$sy_end[p$source == "edfacts"] %in% ACH_WINDOW), all(p$sy_end[p$source == "report_card"] %in% HS_RC_WINDOW),
            !anyDuplicated(p[c("leaid", "sy_end")]), all(p$source %in% c("edfacts", "report_card")),
            all(p$cep_carried == as.integer(p$source == "report_card" & p$sy_end == 2025L)),
            !"rc_rule12" %in% names(p))
  r2 <- p[p$source == "report_card", ]
  kd <- match(r2$leaid, s1$leaid)
  expect_all(all(r2$retained[is.na(kd)] == 0L), all(r2$retained[!is.na(kd)] == s1$retained[kd[!is.na(kd)]]), all(r2$robust_from_2013 == 1L),
            all(substr(r2$leaid, 1, 2) == STATE_FIPS[r2$state]))
  for (v in as.vector(outer(c("math", "rla"), RC_SAMPLE_SUBGROUPS, paste, sep = "_"))) {
    cl <- r2[[paste0("cell_", v)]]; nb <- r2[[paste0("nbasis_", v)]]; pp <- r2[[paste0("p_", v)]]
    expect_all(all(cl %in% c("not_reported", "below_30", "suppressed", "wide_range", "usable")),
              identical(!is.na(pp), cl == "usable"), all(pp[!is.na(pp)] >= 0 & pp[!is.na(pp)] <= 100),
              all(r2[[paste0("w_", v)]][cl == "usable"] <= 10), all(nb[cl == "usable"] != "none"),
              all(!is.na(r2[[paste0("nclamp_", v)]][cl == "usable"])))
  }
  ev <- c(retained = "event_table.csv", retained_r1 = "event_table_r1.csv", retained_r2 = "event_table_r2.csv")
  for (flag in names(ev)) {
    e <- utils::read.csv(file.path("data", "reference", ev[[flag]]), stringsAsFactors = FALSE)
    expect_all(!any(p[[flag]] == 1L & p$state %in% e$state[e$group == "excluded"]))
  }
}
if (file.exists("data/derived/hs_gaps.csv")) {
  g <- utils::read.csv("data/derived/hs_gaps.csv", colClasses = c(leaid = "character"), stringsAsFactors = FALSE, na.strings = "")
  expect_all(setequal(unique(g$gap), c("a_poverty", "b_black_white", "c_hispanic_white")),
            all(g$source %in% c("edfacts", "report_card")), all(g$sample %in% names(MAX_WIDTH)),
            all(g$sy_end[g$source == "report_card"] %in% HS_RC_WINDOW), all(g$sy_end[g$source == "edfacts"] %in% ACH_WINDOW),
            !anyDuplicated(g[c("gap", "state", "leaid", "sy_end", "subject", "sample")]), all(is.finite(g$v)),
            all(is.na(g$leaid) == (g$gap == "a_poverty")))
  rb <- g[g$gap != "a_poverty", ]
  n_ok <- !is.na(rb$n_group) & !is.na(rb$n_wh)
  expect_all(all(is.na(rb$se[!n_ok & rb$source == "report_card"])), all(rb$se[n_ok] > 0))
  ex <- rb[rb$gap == "c_hispanic_white" & n_ok & rb$source == "report_card", ][1, ]
  if (!is.na(ex$v)) expect_all(isTRUE(all.equal(ex$v, v_gap(ex$p_group, ex$p_wh, ex$n_group, ex$n_wh))))
}
})

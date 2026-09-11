# Checks for R/functions/outcomes.R and the step 4 outputs (design Section 6).
# Sourced by tests/run_tests.R after the shared functions are loaded.

# probit_score() applies v_gap()'s clamp, so the gap is a difference of scores
pa <- c(0.7, 1, 0, 0.35); pb <- c(0.4, 0.2, 0.5, 0.35); na <- c(40, 40, 50, 60); nb <- c(30, 80, 40, 60)
stopifnot(near(v_gap(pa, pb, na, nb), probit_score(pa, na) - probit_score(pb, nb)),
          near(probit_score(0.5), 0), is.finite(probit_score(1, 40)), is.finite(probit_score(0, 40)))

# CCD counts: negative codes and text are missing
stopifnot(identical(ccd_count(c("120", " 0 ", "-1", "-2", "-9", "M", "")), c(120, 0, NA, NA, NA, NA, NA)))

# CCD reader: extra fields as reported, 2009-10 year suffix removed
tmp <- tempfile(fileext = ".txt")
writeLines(c("LEAID\tFIPST\tTYPE09\tBOUND09\tGSHI09\tMEMBER09",
             "0100005\t01\t1\t1\t12\t3467", "0100006\t01\t1\t1\t12\t-9"), tmp)
cc <- read_ccd_lea(tmp, 2010L, extra = "MEMBER")
stopifnot(identical(cc$member, c("3467", "-9")), identical(ccd_count(cc$member), c(3467, NA)),
          !"member" %in% names(read_ccd_lea(tmp, 2010L)))

# synthetic district-years in the layout of data/derived/sample_district_year.csv
dy <- function(leaid, state = "X", sy_end = 2011L, q = NA_integer_, member = 1000) {
  r <- data.frame(leaid = leaid, state = state, sy_end = sy_end, retained = 1L, retained_r1 = 1L,
                  retained_r2 = 1L, pov_quintile_2009 = q, member_2009 = member, stringsAsFactors = FALSE)
  for (subj in names(SUBJECTS)) for (sg in SUBGROUPS) {
    r[[paste0("n_", subj, "_", sg)]] <- 100
    r[[paste0("p_", subj, "_", sg)]] <- 50
    r[[paste0("w_", subj, "_", sg)]] <- 0
    r[[paste0("cell_", subj, "_", sg)]] <- "usable"
    r[[paste0("part_ok_", subj, "_", sg)]] <- if (sy_end >= 2013L) 1L else NA_integer_
  }
  r
}
set_cell <- function(d, i, sg, n = NULL, p = NULL, w = NULL, cell = NULL, part = NULL, subj = "math") {
  if (!is.null(n)) d[i, paste0("n_", subj, "_", sg)] <- n
  if (!is.null(p)) d[i, paste0("p_", subj, "_", sg)] <- p
  if (!is.null(w)) d[i, paste0("w_", subj, "_", sg)] <- w
  if (!is.null(cell)) d[i, paste0("cell_", subj, "_", sg)] <- cell
  if (!is.null(part)) d[i, paste0("part_ok_", subj, "_", sg)] <- part
  d
}

# gaps (b) and (c)
d <- rbind(dy("D1"), dy("D2", sy_end = 2013L), dy("D3", sy_end = 2012L), dy("D4"))
d <- set_cell(d, 1, "wh", n = 200, p = 60, w = 0)
d <- set_cell(d, 1, "bl", n = 50, p = 42, w = 4)       # 5-point range at its midpoint
d <- set_cell(d, 1, "hi", n = 40, p = 54.5, w = 9)     # 10-point range at its midpoint
d <- set_cell(d, 2, "bl", part = 0L)                   # 2012-13: fails rule 4
d <- set_cell(d, 3, "wh", n = 20, p = NA, w = 19, cell = "below_30")
d <- set_cell(d, 4, "wh", p = 70); d <- set_cell(d, 4, "bl", p = 35); d <- set_cell(d, 4, "hi", p = 55)
rp <- race_gaps(d, "math", "primary"); r5 <- race_gaps(d, "math", "r5"); rx <- race_gaps(d, "math", "exact")
stopifnot(identical(rp$leaid, c("D1", "D2", "D4")), identical(r5$leaid, c("D1", "D2", "D4")),
          identical(rx$leaid, c("D2", "D4")))              # D3 has no gap; D1 has no exact pair
stopifnot(all(rp$sample == "primary"), all(rp$subject == "math"))
i <- rp$leaid == "D1"
stopifnot(near(rp$v_bw[i], v_gap(0.42, 0.60, 50, 200)), rp$v_bw[i] < 0,       # Black minus White
          near(rp$se_bw[i], v_gap_se(0.42, 0.60, 50, 200)),
          near(rp$v_hw[i], v_gap(0.545, 0.60, 40, 200)),                      # Hispanic minus White
          near(rp$p_bl[i], 0.42), rp$w_hi[i] == 9, rp$n_wh[i] == 200)
stopifnot(!is.na(r5$v_bw[r5$leaid == "D1"]), is.na(r5$v_hw[r5$leaid == "D1"]))  # 9-point range out of r5
stopifnot(is.na(rp$v_bw[rp$leaid == "D2"]), !is.na(rp$v_hw[rp$leaid == "D2"])) # rule 4 drops one gap only
stopifnot(near(rx$v_bw[rx$leaid == "D4"], rp$v_bw[rp$leaid == "D4"]),             # same value in every sample
          near(rp$v_bw[rp$leaid == "D4"], qnorm(0.35) - qnorm(0.70)))
stopifnot(nrow(race_gaps(d, "rla", "primary")) == 4)                              # math-only changes leave rla usable
stopifnot(identical(gap_cells_ok(d, "math", c("bl", "wh"), "primary"), c(TRUE, FALSE, FALSE, TRUE)))

# gap (a): membership-weighted quintile means, quintile 5 minus quintile 1
d <- rbind(dy("A", q = 1L, member = 100), dy("B", q = 1L, member = 300), dy("C", q = 5L, member = 200),
           dy("E", q = 5L, member = NA), dy("F", q = 3L, member = 500),
           dy("A", sy_end = 2012L, q = 1L, member = 100), dy("C", sy_end = 2012L, q = 5L, member = 200),
           dy("G", state = "Y", q = 5L), dy("H", state = "Z", sy_end = 2013L, q = 1L),
           dy("K", state = "Z", sy_end = 2013L, q = 5L))
d <- set_cell(d, 1, "all", n = 100, p = 80); d <- set_cell(d, 2, "all", n = 200, p = 70, w = 4)
d <- set_cell(d, 3, "all", n = 50, p = 30); d <- set_cell(d, 4, "all", p = 10); d <- set_cell(d, 5, "all", p = 99)
d <- set_cell(d, 6, "all", w = 19, cell = "wide_range", p = NA)   # 2012: no usable quintile-1 district
d <- set_cell(d, 10, "all", part = 0L)                            # 2012-13: quintile 5 fails rule 4
pg <- poverty_gap(d, "math", "primary")
stopifnot(nrow(pg) == 1, pg$state == "X", pg$sy_end == 2011L)     # X 2012, Y (no q1), Z 2013 give no row
q1 <- (100 * qnorm(0.8) + 300 * qnorm(0.7)) / 400
stopifnot(near(pg$score_q1, q1), near(pg$score_q5, qnorm(0.3)),   # E has no weight; F is quintile 3
          near(pg$v_pov, qnorm(0.3) - q1), pg$v_pov < 0,
          pg$districts_q1 == 2, pg$districts_q5 == 1, pg$member_q1 == 400, pg$member_q5 == 200,
          pg$tested_q1 == 300, pg$tested_q5 == 50, pg$sample == "primary", pg$subject == "math")
px <- poverty_gap(d, "math", "exact")                             # B's 5-point range leaves the exact sample
stopifnot(nrow(px) == 1, near(px$score_q1, qnorm(0.8)), px$districts_q1 == 1)
stopifnot(nrow(poverty_gap(d[d$state == "Y", ], "math", "primary")) == 0)
d$retained[1] <- 0L
stopifnot(inherits(try(poverty_gap(d, "math", "primary"), silent = TRUE), "try-error"))  # flags must be state-level

# step 4 never reads treatment years into its code
stopifnot(!any(grepl("treat_year", readLines("R/04_outcomes.R"))))

# step 4 outputs, when they have been built
rf <- "data/derived/gaps_race_district_year.csv"; pf <- "data/derived/gap_poverty_state_year.csv"
if (file.exists(rf) && file.exists(pf)) {
  r <- utils::read.csv(rf, colClasses = c(leaid = "character"), stringsAsFactors = FALSE, na.strings = "")
  stopifnot(identical(names(r), c("leaid", "state", "sy_end", "subject", "sample", "retained", "retained_r1",
                                   "retained_r2", "v_bw", "se_bw", "v_hw", "se_hw",
                                   paste0(rep(c("n_", "p_", "w_"), each = 3), c("wh", "bl", "hi")))))
  stopifnot(!anyDuplicated(r[c("leaid", "sy_end", "subject", "sample")]), all(r$sample %in% names(MAX_WIDTH)),
            all(r$subject %in% names(SUBJECTS)), all(!is.na(r$v_bw) | !is.na(r$v_hw)),
            all(r$retained == 1 | r$retained_r1 == 1 | r$retained_r2 == 1))
  for (g in names(RACE_GAPS)) {
    a <- RACE_GAPS[[g]][1]; b <- RACE_GAPS[[g]][2]
    v <- r[[paste0("v_", g)]]; k <- !is.na(v)
    pa <- r[[paste0("p_", a)]][k]; pb <- r[[paste0("p_", b)]][k]; na <- r[[paste0("n_", a)]][k]; nb <- r[[paste0("n_", b)]][k]
    stopifnot(near(v[k], v_gap(pa, pb, na, nb)), near(r[[paste0("se_", g)]][k], v_gap_se(pa, pb, na, nb)),
              all(na >= 30 & nb >= 30),
              all(r[[paste0("w_", a)]][k] <= MAX_WIDTH[r$sample[k]] & r[[paste0("w_", b)]][k] <= MAX_WIDTH[r$sample[k]]),
              all(is.na(r[[paste0("se_", g)]][!k])))
    # nested samples: a gap in exact is in r5, a gap in r5 is in primary, with the same value
    for (pr in list(c("exact", "r5"), c("r5", "primary"))) {
      x <- r[r$sample == pr[1] & !is.na(v), ]; y <- r[r$sample == pr[2] & !is.na(v), ]
      m <- match(paste(x$leaid, x$sy_end, x$subject), paste(y$leaid, y$sy_end, y$subject))
      stopifnot(!anyNA(m), near(x[[paste0("v_", g)]], y[[paste0("v_", g)]][m]))
    }
  }
  # orientation: the disadvantaged group is lower on average (Black minus White)
  stopifnot(mean(r$v_bw[r$sample == "primary"], na.rm = TRUE) < 0, mean(r$v_hw[r$sample == "primary"], na.rm = TRUE) < 0)
  # flags and participation agree with the step 3 file
  s <- utils::read.csv("data/derived/sample_district_year.csv", colClasses = c(leaid = "character"),
                       stringsAsFactors = FALSE, na.strings = "")
  m <- match(paste(r$leaid, r$sy_end), paste(s$leaid, s$sy_end))
  stopifnot(!anyNA(m), all(r$retained == s$retained[m]), all(r$retained_r1 == s$retained_r1[m]),
            all(r$retained_r2 == s$retained_r2[m]), all(r$state == s$state[m]))
  for (subj in names(SUBJECTS)) for (g in names(RACE_GAPS)) {
    k <- r$subject == subj & r$sy_end >= 2013 & !is.na(r[[paste0("v_", g)]])
    for (sg in RACE_GAPS[[g]]) stopifnot(all(s[[paste0("part_ok_", subj, "_", sg)]][m[k]] == 1))
  }

  p <- utils::read.csv(pf, stringsAsFactors = FALSE, na.strings = "")
  stopifnot(identical(names(p), c("state", "sy_end", "subject", "sample", "retained", "retained_r1", "retained_r2",
                                  "v_pov", "score_q5", "score_q1", "districts_q5", "districts_q1",
                                  "member_q5", "member_q1", "tested_q5", "tested_q1")))
  stopifnot(!anyDuplicated(p[c("state", "sy_end", "subject", "sample")]), all(p$sample %in% names(MAX_WIDTH)),
            near(p$v_pov, p$score_q5 - p$score_q1), all(p$districts_q1 >= 1 & p$districts_q5 >= 1),
            all(p$member_q1 > 0 & p$member_q5 > 0), all(p$tested_q1 >= 30 & p$tested_q5 >= 30),
            !any(p$state %in% c("DC", "HI")), mean(p$v_pov[p$sample == "primary"]) < 0)
  # state-level flags match the state's quintile districts in the step 3 file
  qs <- unique(s[!is.na(s$pov_quintile_2009), c("state", "retained", "retained_r1", "retained_r2")])
  stopifnot(!anyDuplicated(qs$state))
  k <- match(p$state, qs$state)
  stopifnot(!anyNA(k), all(p$retained == qs$retained[k]), all(p$retained_r1 == qs$retained_r1[k]),
            all(p$retained_r2 == qs$retained_r2[k]))
  # a sample never has more gap (a) rows than a wider one
  np <- table(factor(p$sample, levels = names(MAX_WIDTH)))
  stopifnot(np[["exact"]] <= np[["r5"]], np[["r5"]] <= np[["primary"]])
}

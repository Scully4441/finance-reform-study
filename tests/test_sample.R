# Checks for R/functions/sample_rules.R and the step 3 output (design Section 5).
# Sourced by tests/run_tests.R after the shared functions are loaded.

# state universe and year tags
stopifnot(length(STATE_FIPS) == 51, setequal(names(STATE_FIPS), c(state.abb, "DC")), !anyDuplicated(STATE_FIPS))
stopifnot(identical(fips_to_state(c("01", "11", "56", "72")), c("AL", "DC", "WY", NA)))
stopifnot(identical(edfacts_year_tag(c(2010L, 2013L)), c("0910", "1213")))

# rule 3 (author decision 2026-09-11): exact count >= 30; percent proficient exact
# or a range no wider than 10 points; robustness samples at 5 points and exact only
stopifnot(identical(MAX_WIDTH, c(primary = 10, r5 = 5, exact = 0)))
n <- c("45", "25", "100", "", ".", "30", "30", "29", "45", "45", "45", "45", "301", "40", "30")
p <- c("50.5", "GE50", "40-44", "", ".", "PS", "12", "12", "21-39", "GE90", "LE10", "N/A", "GE99", "11-19", "GE80")
st <- cell_status(n, p)
stopifnot(identical(st, c("usable", "below_30", "usable", "not_reported", "not_reported", "suppressed", "usable",
                          "below_30", "wide_range", "usable", "usable", "suppressed", "usable", "usable", "wide_range")))
stopifnot(identical(cell_status(n, p, max_width = 5)[c(3, 10, 11, 14)], c("usable", "wide_range", "wide_range", "wide_range")))
wd <- edfacts_range(p)$width
stopifnot(identical(cell_in_sample(st, wd, "primary"), st == "usable"),
          identical(which(cell_in_sample(st, wd, "r5")), c(1L, 3L, 7L, 13L)),
          identical(which(cell_in_sample(st, wd, "exact")), c(1L, 7L)))
stopifnot(inherits(try(cell_in_sample("usable", 0, "r3"), silent = TRUE), "try-error"))

# rule 4 (author decision 2026-09-11): the exact value or band midpoint must reach 95
x <- c("96", "GE95", "GE90", "90-94", "95-99", "LT50", "PS", "n/a", ".", "", "94.9", "GE99", NA, " ge90 ",
       "80-89", "GE80", "LE1", "95")
stopifnot(identical(part_value(x), c(96, 97.5, 95, 92, 97, 25, NA, NA, NA, NA, 94.9, 99.5, NA, 95, 84.5, 90, 0.5, 95)))
stopifnot(identical(part_pass(x), c(TRUE, TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE,
                                    FALSE, TRUE, FALSE, FALSE, FALSE, TRUE)))

# rules 1 and 2 on a synthetic CCD panel
w <- 2010:2013
mk <- function(id, type, bound, years = w) data.frame(leaid = id, sy_end = years, agency_type = type, ccd_bound = bound)
lea_t <- rbind(
  mk("A", 1L, 1L),                                  # pass
  mk("B", c(1L, 7L, 1L, 1L), 1L),                   # type 7 in one year
  mk("C", 1L, 1L, c(2010L, 2011L, 2013L)),          # missing a year
  mk("D", 1L, c(1L, 1L, 1L, 2L)),                   # closed in the last year
  mk("E", 1L, c(5L, 1L, 1L, 1L)),                   # boundary change in the first window year
  mk("F", 2L, c(3L, 1L, 1L, 1L)),                   # new in 2010, then open: pass
  mk("G", 2L, c(1L, 6L, 1L, 1L)),                   # temporarily closed
  mk("H", 1L, c(1L, 1L, 8L, 1L)),                   # reopened: a change code, like 5
  mk("L", 1L, c(8L, 1L, 1L, 1L)),                   # reopened in the first window year
  mk("I", 1L, c(1L, 1L, 1L, 7L)),                   # future
  mk("J", c(1L, 2L, 2L, 1L), 1L),                   # switches between types 1 and 2: pass
  mk("K", 1L, c(1L, 1L, 2L, 5L)))                   # closed and boundary change: presence reported first
dr_t <- district_rules(lea_t, w)
want <- c(A = "pass", B = "rule 1: agency type not 1 or 2", C = "rule 2: not operational in every window year",
          D = "rule 2: not operational in every window year", E = "rule 2: boundary change (BOUND 5 or 8)",
          F = "pass", G = "rule 2: not operational in every window year",
          H = "rule 2: boundary change (BOUND 5 or 8)", I = "rule 2: not operational in every window year",
          J = "pass", K = "rule 2: not operational in every window year",
          L = "rule 2: boundary change (BOUND 5 or 8)")
stopifnot(identical(setNames(dr_t$rule12, dr_t$leaid), want))
# rows outside the window are ignored
stopifnot(district_rules(rbind(mk("A", 1L, 1L), mk("A", 7L, 5L, 2009L)), w)$rule12 == "pass")

# poverty quintiles: equal-count groups within state, 1 = lowest poverty, ties by LEAID
q <- poverty_quintile(rep("X", 10), 10:1 / 100, sprintf("%02d", 1:10))
stopifnot(identical(q, c(5L, 5L, 4L, 4L, 3L, 3L, 2L, 2L, 1L, 1L)))
q <- poverty_quintile(rep("X", 5), rep(0.2, 5), c("e", "d", "c", "b", "a"))
stopifnot(identical(q, 5:1))
q <- poverty_quintile(c(rep("X", 7), rep("Y", 5)), c(1:7, 5:1) / 10, c(letters[1:7], letters[1:5]))
stopifnot(identical(q[1:7], c(1L, 2L, 3L, 3L, 4L, 5L, 5L)), identical(q[8:12], 5:1))
stopifnot(inherits(try(poverty_quintile("X", NA_real_, "a"), silent = TRUE), "try-error"))

# CCD reader: 2009-10 year-suffixed names, a quoted name holding a tab, row-count check
tmp <- tempfile(fileext = ".txt")
writeLines(c("LEAID\tFIPST\tNAME09\tTYPE09\tBOUND09\tGSHI09\tG0109",
             "0100005\t01\tALBERTVILLE\t1\t1\t12\t5",
             "0100006\t01\t\"ACME\tINC.\"\t7\t3\t08\t1"), tmp)
cc <- read_ccd_lea(tmp, 2010L)
stopifnot(nrow(cc) == 2, identical(cc$agency_type, c(1L, 7L)), identical(cc$ccd_bound, c(1L, 3L)),
          identical(cc$gshi, c("12", "08")), identical(cc$fipst, c("01", "01")), all(cc$sy_end == 2010L))
writeLines(c("SURVYEAR\tLEAID\tFIPST\tTYPE\tBOUND\tGSHI", "2012\t0100005\t01\t2\t5\t12"), tmp)
stopifnot(read_ccd_lea(tmp, 2013L)$ccd_bound == 5L)
writeLines(c("LEAID\tFIPST\tTYPE\tBOUND\tGSHI", "0100005\t01\t9\t1\t12"), tmp)
stopifnot(inherits(try(read_ccd_lea(tmp, 2013L), silent = TRUE), "try-error"))   # TYPE outside 1-8

# EDFacts reader: HS columns only, case of the field names varies by year
ed_cols <- function(tag, up) {
  f <- function(s) if (up) toupper(s) else s
  unlist(lapply(names(SUBGROUPS), function(sg) c(paste0(sg, "_MTH00", f("numvalid"), "_", tag),
                                                 paste0(sg, "_MTHHS", f("numvalid"), "_", tag),
                                                 paste0(sg, "_MTHHS", f("pctprof"), "_", tag))))
}
for (case in list(list(y = 2010L, up = FALSE), list(y = 2013L, up = TRUE))) {
  cn <- ed_cols(edfacts_year_tag(case$y), case$up)
  vals <- rep(c("999", "40", "55"), length(SUBGROUPS))
  df <- as.data.frame(as.list(c("ALABAMA", "01", "0100005", "X", vals)), stringsAsFactors = FALSE)
  names(df) <- c("STNAM", "FIPST", "LEAID", "LEANM", cn)
  tmp_csv <- tempfile(fileext = ".csv"); utils::write.csv(df, tmp_csv, row.names = FALSE)
  e <- read_edfacts_hs(tmp_csv, "math", case$y, "achievement")
  stopifnot(identical(e$leaid, "0100005"), e$n_all == "40", e$p_bl == "55", ncol(e) == 1 + 2 * length(SUBGROUPS))
  stopifnot(inherits(try(read_edfacts_hs(tmp_csv, "rla", case$y, "achievement"), silent = TRUE), "try-error"))
}

# SAIPE reader: fields found by pattern whatever the column widths
tmp <- tempfile(fileext = ".txt")
writeLines(c("01 00005 Albertville City School District                                     19085     3467     1049 USSD09.txt 05APR2011  ",
             "56 06090 Weston County School District 7                                        1357      227       16 USSD09.txt 05APR2011",
             "02 00001 Empty District                                        10         0        0 USSD10.txt 01JAN2012"), tmp)
sa <- read_saipe(tmp)
stopifnot(identical(sa$leaid, c("0100005", "5606090", "0200001")), identical(sa$pop_5_17, c(3467, 227, 0)),
          all.equal(sa$pov_rate[1:2], c(1049 / 3467, 16 / 227)), is.na(sa$pov_rate[3]))
con <- file(tmp, "wb")                                    # a Latin-1 accent in a district name
writeBin(c(charToRaw("35 03990 Espa"), as.raw(0xf1), charToRaw("ola Public Schools     1000     200     50 USSD09.txt 05APR2011\n")), con)
close(con)
stopifnot(identical(read_saipe(tmp)$leaid, "3503990"), read_saipe(tmp)$pov_rate == 0.25)
writeLines("01 0005 Bad line 1 2 3 X Y", tmp)
stopifnot(inherits(try(read_saipe(tmp), silent = TRUE), "try-error"))

# step 3 never reads treatment years into its code
stopifnot(!any(grepl("treat_year", readLines("R/03_sample.R"))))

# step 3 output, when it has been built
out <- "data/derived/sample_district_year.csv"
if (file.exists(out)) {
  s <- utils::read.csv(out, colClasses = c(leaid = "character"), stringsAsFactors = FALSE, na.strings = "")
  sg <- as.vector(outer(names(SUBJECTS), SUBGROUPS, paste, sep = "_"))
  stopifnot(all(c("leaid", "state", "sy_end", "retained", "reason", "retained_r1", "retained_r2", "robust_from_2013",
                  "agency_type", "boundary_change", "pov_quintile_2009", "cep", "test_replaced",
                  "test_replaced_math", "test_replaced_rla", paste0("part_", sg), paste0("part_ok_", sg),
                  paste0("n_", sg), paste0("p_", sg), paste0("w_", sg), paste0("cell_", sg),
                  "ccd_bound", "saipe_pov_rate_2009") %in% names(s)))
  stopifnot(all(grepl("^[0-9]{7}$", s$leaid)), !anyDuplicated(s[c("leaid", "sy_end")]),
            all(s$state %in% names(STATE_FIPS)), all(substr(s$leaid, 1, 2) == STATE_FIPS[s$state]))
  stopifnot(all(s$retained == (s$reason == "retained")), all(s$agency_type[s$retained == 1] %in% 1:2),
            all(s$boundary_change == as.integer(s$ccd_bound %in% c(5, 8))),
            all(s$boundary_change[s$retained == 1] == 0))
  # districts with no SAIPE 2009 rate are dropped (author decision 2026-09-11)
  stopifnot(!anyNA(s$saipe_pov_rate_2009[s$retained == 1 | s$retained_r1 == 1 | s$retained_r2 == 1]),
            all(is.na(s$saipe_pov_rate_2009[s$reason == "no SAIPE 2009 poverty rate"])))
  stopifnot(all(tapply(s$reason, s$leaid, function(r) length(unique(r)) == 1)))       # district-level rules
  yrs <- sort(unique(s$sy_end))
  stopifnot(all(tapply(s$sy_end[s$retained == 1], s$leaid[s$retained == 1], function(v) identical(sort(v), yrs))))
  stopifnot(all(s$robust_from_2013 == as.integer(s$sy_end >= 2013)))
  stopifnot(all(is.na(unlist(s[s$sy_end < 2013, paste0("part_ok_", sg)]))),
            all(unlist(s[s$sy_end >= 2013, paste0("part_ok_", sg)]) %in% 0:1))
  stopifnot(all(unlist(s[paste0("cell_", sg)]) %in% c("not_reported", "below_30", "suppressed", "wide_range", "usable")))
  for (v in sg) {
    cs <- s[[paste0("cell_", v)]]; u <- cs == "usable"
    wv <- s[[paste0("w_", v)]]; pv <- s[[paste0("p_", v)]]
    stopifnot(all(s[[paste0("n_", v)]][u] >= 30), all(wv[u] <= 10), !anyNA(pv[u]), all(pv[u] >= 0 & pv[u] <= 100),
              all(is.na(pv[!u])), all(wv[cs == "wide_range"] > 10), all(is.na(wv[cs == "suppressed"])))
    # participation flag = exact value or band midpoint >= 95; the exact-only sample's
    # cells report participation exactly or at a 1-point end band (GE99/LE1)
    pr <- s[[paste0("part_", v)]]; t13 <- s$sy_end >= 2013
    stopifnot(all(s[[paste0("part_ok_", v)]][t13] == as.integer(part_pass(pr[t13]))))
    pw <- edfacts_range(pr[t13 & cell_in_sample(cs, wv, "exact")])$width
    stopifnot(all(is.na(pw) | pw <= 1))
  }
  q <- s$pov_quintile_2009[s$retained == 1 & !is.na(s$pov_quintile_2009)]
  stopifnot(all(q %in% 1:5))
  trr <- utils::read.csv("data/reference/test_replacement.csv", stringsAsFactors = FALSE, na.strings = character())
  k <- match(paste(s$state, s$sy_end), paste(trr$state, trr$sy_end))
  stopifnot(!anyNA(k), all(s$test_replaced == trr$replaced[k]), all(s$test_replaced_math == trr$replaced_math[k]),
            all(s$test_replaced_rla == trr$replaced_rla[k]))
  # CEP: the state phase-in table before end year 2014, the district's own CCD
  # NSLPSTATUS from 2014 on (data acquisition 2.5)
  cp <- utils::read.csv("data/reference/cep_phase_in.csv", stringsAsFactors = FALSE)
  e <- s$sy_end < CEP_FROM_CCD
  stopifnot(all(s$cep[e] == as.integer(s$sy_end[e] >= cp$first_cep_sy_end[match(s$state[e], cp$state)])))
  for (y in sort(unique(s$sy_end[!e]))) {
    d <- cep_from_ccd(y)
    k <- which(s$sy_end == y)
    m <- match(s$leaid[k], d$leaid)
    stopifnot(all(s$cep[k] == ifelse(is.na(m), 0L, d$cep[m])))
  }
  for (set in c("", "_r1", "_r2")) {
    ev <- utils::read.csv(paste0("data/reference/event_table", set, ".csv"), stringsAsFactors = FALSE)
    rv <- s[[paste0("retained", if (nzchar(set)) set else "")]]
    stopifnot(!any(rv == 1 & s$state %in% ev$state[ev$group == "excluded"]))
  }
}

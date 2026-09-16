# Checks for R/functions/seda.R and the step 11 output (docs/design_extension.md, Sections 5, 6).
# Sourced by tests/run_tests.R after the shared functions are loaded.

stopifnot(identical(SEDA_WINDOW, c(2009:2019, 2022:2025)),
          identical(SEDA_RULES_WINDOW, c(2010:2019, 2022:2024)),
          all(SEDA_RULES_WINDOW %in% SEDA_WINDOW), SEDA_PUBLIC_FROM == 2022L)

# reader: a synthetic long file in SEDA's layout (sedaadmin without its leading zero)
sg_cols <- as.vector(outer(c("cs_mn_", "cs_mn_se_", "cs_mn_se_adj_"), SEDA_SUBGROUPS, paste0))
raw <- data.frame(sedaadmin = c(100005, 100005, 3400001), sedaadminname = "x", subject = c("mth", "rla", "mth"),
                  grade = c(3L, 3L, 8L), year = c(2009L, 2022L, 2025L), fips = c(1L, 1L, 34L),
                  stateabb = c("AL", "AL", "NJ"), stringsAsFactors = FALSE)
for (v in sg_cols) raw[[v]] <- NA_real_
raw$cs_mn_all <- c(0.1, -0.2, 0.3); raw$cs_mn_se_all <- c(0.05, 0.06, 0.07); raw$cs_mn_se_adj_all <- 9
raw$cs_mn_blk <- c(-0.5, NA, NA);    raw$cs_mn_se_blk <- c(0.2, NA, NA)
tmp <- tempfile(fileext = ".csv")
utils::write.csv(raw, tmp, row.names = FALSE, na = "")
s <- read_seda_long(tmp)
stopifnot(identical(s$leaid, c("0100005", "0100005", "3400001")), identical(s$subject, c("math", "rla", "math")),
          identical(s$sy_end, c(2009L, 2022L, 2025L)), near(s$se_all, c(0.05, 0.06, 0.07)),   # unadjusted SE
          near(s$mn_bl[1], -0.5), is.na(s$mn_wh[1]), is.na(s$mn_hi[3]))
bad <- raw; bad$fips[3] <- 1L
utils::write.csv(bad, tmp, row.names = FALSE, na = "")
stopifnot(inherits(try(read_seda_long(tmp), silent = TRUE), "try-error"))        # FIPS does not match the id
bad <- raw; bad$year[1] <- 2020L
utils::write.csv(bad, tmp, row.names = FALSE, na = "")
stopifnot(inherits(try(read_seda_long(tmp), silent = TRUE), "try-error"))        # 2020 is not a SEDA year
bad <- rbind(raw, raw[1, ])
utils::write.csv(bad, tmp, row.names = FALSE, na = "")
stopifnot(inherits(try(read_seda_long(tmp), silent = TRUE), "try-error"))        # duplicate grade row

# pooling: precision weights 1/se^2, pooled SE 1/sqrt(sum of weights)
g <- function(leaid, grade, subject = "math", sy_end = 2011L, state = "AL", all = c(0, 0.1), wh = c(NA, NA),
              bl = c(NA, NA), hi = c(NA, NA)) {
  data.frame(leaid = leaid, state = state, sy_end = sy_end, subject = subject, grade = grade,
             mn_all = all[1], se_all = all[2], mn_wh = wh[1], se_wh = wh[2],
             mn_bl = bl[1], se_bl = bl[2], mn_hi = hi[1], se_hi = hi[2], stringsAsFactors = FALSE)
}
x <- rbind(g("0100001", 3, all = c(0.2, 0.1), wh = c(0.5, 0.1), bl = c(-0.3, 0.2)),
           g("0100002", 3, all = c(1, 0.1)),                                           # another district between
           g("0100001", 4, all = c(0.4, 0.2), wh = c(0.8, 0.2), bl = c(NA, NA)),
           g("0100001", 5, all = c(9, NA)),                                            # mean without an SE: out
           g("0100001", 3, subject = "rla", all = c(-0.1, 0.1), wh = c(0.1, 0.1), bl = c(-0.6, 0.1)))
p <- seda_pool(x)
stopifnot(nrow(p) == 3, identical(p$leaid, c("0100001", "0100002", "0100001")), identical(p$subject, c("math", "math", "rla")))
w <- c(1 / 0.1^2, 1 / 0.2^2)
stopifnot(near(p$mn_all[1], sum(w * c(0.2, 0.4)) / sum(w)), near(p$se_all[1], 1 / sqrt(sum(w))),
          near(p$mn_wh[1], sum(w * c(0.5, 0.8)) / sum(w)), p$grades_all[1] == 2L, p$gmask_all[1] == 3L,
          near(p$mn_bl[1], -0.3), near(p$se_bl[1], 0.2), p$grades_bl[1] == 1L, p$gmask_bl[1] == 1L,
          is.na(p$mn_hi[1]), is.na(p$se_hi[1]), p$grades_hi[1] == 0L,
          near(p$mn_all[2], 1), near(p$mn_all[3], -0.1))
stopifnot(near(seda_pool(g("0100009", 8, all = c(0.3, 0.1)))$gmask_all, 32))           # grade 8 = bit 5
# equal SEs pool to the plain mean
e <- seda_pool(rbind(g("0100003", 3, all = c(0.1, 0.1)), g("0100003", 6, all = c(0.5, 0.1))))
stopifnot(near(e$mn_all, 0.3), near(e$se_all, 0.1 / sqrt(2)))

# gaps (b) and (c): group minus White, both subjects required for v
x <- rbind(g("0100001", 3, all = c(0, 0.1), wh = c(0.5, 0.1), bl = c(-0.3, 0.2), hi = c(0.1, 0.1)),
           g("0100001", 3, subject = "rla", all = c(0, 0.1), wh = c(0.4, 0.1), bl = c(-0.2, 0.1)),
           g("0100002", 3, all = c(NA, NA), wh = c(0.5, 0.1), bl = c(0, 0.1)),        # no all-students mean
           g("0100004", 3, all = c(0, 0.1), wh = c(NA, NA), bl = c(0, 0.1)))            # no White mean
r <- seda_race_gaps(seda_pool(x))
stopifnot(identical(r$gap, c("b_black_white", "c_hispanic_white")), all(r$leaid == "0100001"))
b <- r[r$gap == "b_black_white", ]; h <- r[r$gap == "c_hispanic_white", ]
stopifnot(near(b$v_math, -0.8), near(b$se_math, sqrt(0.2^2 + 0.1^2)), near(b$v_rla, -0.6),
          near(b$v, -0.7), b$v < 0,
          near(b$mean_group_math, -0.3), near(b$mean_wh_math, 0.5), near(b$mean_all_rla, 0), b$grades_group_math == 1L,
          near(h$v_math, -0.4), is.na(h$v_rla), is.na(h$v))                            # RLA Hispanic missing
stopifnot(identical(names(b)[1:5], c("gap", "leaid", "state", "sy_end", "v")))

# gap (a): membership-weighted quintile means, top minus bottom poverty quintile
x <- rbind(g("0100011", 3, all = c(-0.5, 0.1)), g("0100012", 3, all = c(-0.2, 0.1)),   # q5
           g("0100013", 3, all = c(0.4, 0.1)),                                         # q1
           g("0100014", 3, all = c(9, 0.1)),                                           # q1, no membership
           g("0100015", 3, all = c(9, 0.1)),                                           # q3
           g("0100011", 3, subject = "rla", all = c(-0.4, 0.1)), g("0100013", 3, subject = "rla", all = c(0.2, 0.1)),
           g("0100011", 3, sy_end = 2012L, all = c(-0.4, 0.1)),                        # no q1 district in 2012
           g("0200011", 3, state = "AK", all = c(0, 0.1)), g("0200013", 3, state = "AK", all = c(0, 0.1)))
dist <- data.frame(leaid = c("0100011", "0100012", "0100013", "0100014", "0100015", "0200011", "0200013"),
                   pov_quintile_2009 = c(5L, 5L, 1L, 1L, 3L, 5L, 1L),
                   member_2009 = c(100, 300, 50, NA, 10, 10, 10), stringsAsFactors = FALSE)
a <- seda_poverty_gap(seda_pool(x), dist)
stopifnot(nrow(a) == 2, all(a$gap == "a_poverty"), setequal(paste(a$state, a$sy_end), c("AL 2011", "AK 2011")))
al <- a[a$state == "AL", ]
q5 <- (100 * -0.5 + 300 * -0.2) / 400
stopifnot(near(al$mean_q5_math, q5), near(al$mean_q1_math, 0.4), near(al$v_math, q5 - 0.4),
          al$districts_q5_math == 2L, al$districts_q1_math == 1L,
          near(al$se_math, sqrt((sqrt(100^2 * 0.01 + 300^2 * 0.01) / 400)^2 + 0.1^2)),
          near(al$v_rla, -0.6), near(al$v, (q5 - 0.4 - 0.6) / 2),
          near(a$v_math[a$state == "AK"], 0), is.na(a$v[a$state == "AK"]))            # AK has no RLA rows

# CCD grade spans (quintile set: 2009-10 span including a grade 3-8)
stopifnot(identical(ccd_grade_num(c("PK", "KG", "01", "12", "UG", "N", "", " 08 ")), c(-1, 0, 1, 12, NA, NA, NA, 8)))
stopifnot(identical(span_overlaps(c("PK", "09", "KG", "01", "UG", "06", "N"), c("02", "12", "12", "03", "UG", "08", "N")),
                    c(FALSE, FALSE, TRUE, TRUE, FALSE, TRUE, FALSE)))

# retention reasons: rules 1-2, then SAIPE (rule 7), then rule 6
rs <- seda_reason(c("pass", "pass", "pass", "rule 1: agency type not 1 or 2", NA, "pass"),
                  c(0.1, NA, 0.2, 0.1, 0.1, 0.3), c("treated", "never", "excluded", "never", "never", "never"))
stopifnot(identical(rs, c("retained", SEDA_NO_SAIPE, "rule 6: state excluded (reform in 2005-2009)",
                          "rule 1: agency type not 1 or 2", "rule 2: not operational in every window year", "retained")))

# the step 11 output, when it has been built
if (file.exists("data/derived/seda_gaps.csv")) {
  o <- utils::read.csv("data/derived/seda_gaps.csv", colClasses = c(leaid = "character"),
                       stringsAsFactors = FALSE, na.strings = "")
  stopifnot(setequal(unique(o$gap), c("a_poverty", "b_black_white", "c_hispanic_white")),
            all(o$sy_end %in% SEDA_WINDOW), !anyDuplicated(o[c("gap", "state", "leaid", "sy_end")]),
            all(o$seda_public_edc == as.integer(o$sy_end >= 2022L)),
            all(unlist(o[c("retained", "retained_r1", "retained_r2")]) %in% 0:1),
            all(o$retained == 1L | o$retained_r1 == 1L | o$retained_r2 == 1L),
            all(is.na(o$leaid) == (o$gap == "a_poverty")),
            all(grepl("^[0-9]{7}$", o$leaid[o$gap != "a_poverty"])),
            all(substr(o$leaid[o$gap != "a_poverty"], 1, 2) == STATE_FIPS[o$state[o$gap != "a_poverty"]]),
            all(o$state %in% names(STATE_FIPS)),
            all(!is.na(o$v_math) | !is.na(o$v_rla)),
            identical(is.na(o$v), is.na(o$v_math) | is.na(o$v_rla)),
            isTRUE(all.equal(o$v[!is.na(o$v)], (o$v_math[!is.na(o$v)] + o$v_rla[!is.na(o$v)]) / 2)),
            all(o$se_math[!is.na(o$v_math)] > 0), all(o$se_rla[!is.na(o$v_rla)] > 0))
  rc <- o[o$gap != "a_poverty" & !is.na(o$v_math), ]
  stopifnot(isTRUE(all.equal(rc$v_math, rc$mean_group_math - rc$mean_wh_math)),
            all(!is.na(rc$mean_all_math)), all(rc$grades_group_math %in% 1:6), all(rc$grades_wh_math %in% 1:6))
  pa <- o[o$gap == "a_poverty" & !is.na(o$v_math), ]
  stopifnot(isTRUE(all.equal(pa$v_math, pa$mean_q5_math - pa$mean_q1_math)),
            all(pa$districts_q5_math >= 1), all(pa$districts_q1_math >= 1))
  # rule 6: no retained unit in a state its event table excludes
  ev <- c(retained = "event_table.csv", retained_r1 = "event_table_r1.csv", retained_r2 = "event_table_r2.csv")
  for (flag in names(ev)) {
    e <- utils::read.csv(file.path("data", "reference", ev[[flag]]), stringsAsFactors = FALSE)
    stopifnot(!any(o[[flag]] == 1L & o$state %in% e$state[e$group == "excluded"]))
  }
}

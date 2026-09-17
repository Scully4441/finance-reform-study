# Checks for R/functions/continuous_did.R and the step 13 output (docs/design_extension.md, Sections 3, 7).
# Sourced by tests/run_tests.R after the shared functions are loaded. The estimator itself is not run
# here (see the memory note in R/13_continuous_did.R); the counting rules were checked against
# did_multiplegt_dyn() 2.4.0 on synthetic panels with placeholder years, missing treatment and outcomes, many
# baseline bins (discrete treatment) and a single bin (continuous = 1),
# and units moving both up and down: the switcher counts per effect and placebo, and switchers plus
# control unit-years against the package's N for effects, all matched.

stopifnot(CDID_PACKAGE_VERSION == "2.4.0", CDID_POLARS_SHA == "08ba07909a0b4968eaa3d77103c9585849a6f35d",
          CDID_EFFECTS == 9L, CDID_PLACEBO == 5L, CDID_BASE_YEAR == 2025L, identical(CDID_F33_YEARS, 2010:2024),
          identical(unname(CDID_BIN_WIDTHS), c(1, 2)), CDID_MIN_STAYERS == 20L, CDID_MIN_STAYER_STATES == 3L,
          CDID_REV_MIN_ENROLL == 30, CDID_REV_MAX_PP == 100)
# 2025 has no F-33 year and leaves every window; SEDA's 2009 likewise
stopifnot(all(vapply(CDID_WINDOWS, function(w) all(w %in% CDID_F33_YEARS), TRUE)),
          identical(CDID_WINDOWS$hs, c(2010:2019, 2021:2024)), identical(CDID_WINDOWS$seda, c(2010:2019, 2022:2024)),
          identical(CDID_WINDOWS$graduation, 2011:2021))

# bins: round down to the width, an edge value stays in its own bin
stopifnot(identical(revenue_bin(c(12.999, 13, 13 - 1e-12, 13.5, NA), 1), c(12, 13, 13, 13, NA)),
          identical(revenue_bin(c(13.5, 14, 15.99, 0.3 * 3 * 10), 2), c(12, 14, 14, 8)))

# F-33 rows: revenue per pupil, invalid ids and enrollments dropped, negative codes missing
f <- data.frame(NCESID = c("0100005", "0100005", "01005", "0100006", "0100007", "0100008"),
                V33 = c("100", "100", "50", "0", "40", "-2"), TSTREV = c("800", "1", "10", "10", "-1", "10"),
                TLOCREV = c("400", "1", "10", "10", "20", "10"), stringsAsFactors = FALSE)
r <- f33_rows(f, 2012L)
stopifnot(identical(r$leaid, "0100005"), near(r$rev_pp, 12), r$sy_end == 2012L)

# Run 1 floor in 2025 dollars
if (file.exists("data/raw/cpi/cuur0000sa0.csv")) {
  rr <- cdid_real_revenue(data.frame(leaid = c("a", "b", "c"), sy_end = c(2025L, 2025L, 2012L), rev_sl = 1,
                                     v33 = c(29, 30, 30), rev_pp = c(10, 100.5, 10), stringsAsFactors = FALSE))
  stopifnot(near(rr$rev_pp_real[1:2], c(10, 100.5)), rr$rev_pp_real[3] > 10, identical(rr$excluded, c(TRUE, TRUE, FALSE)))
}

# gap (a) treatment: membership-weighted quintile 5 minus quintile 1 revenue within state-year
d <- data.frame(leaid = c("1", "2", "3", "4", "5", "6"), state = c("AA", "AA", "AA", "AA", "BB", "BB"), sy_end = 2012L,
                pov_quintile_2009 = c(5L, 5L, 1L, 3L, 5L, 5L), member_2009 = c(100, 300, 50, 10, 10, 10), stringsAsFactors = FALSE)
rv <- data.frame(leaid = c("1", "2", "3", "4", "5", "6"), sy_end = 2012L, rev_pp_real = c(10, 14, 20, 99, 5, 6),
                 excluded = c(FALSE, FALSE, FALSE, FALSE, FALSE, TRUE), stringsAsFactors = FALSE)
g <- quintile_revenue_gap(d, rv)
stopifnot(nrow(g) == 1L, g$state == "AA", near(g$rev_gap, (10 * 100 + 14 * 300) / 400 - 20), g$districts_q5 == 2L, g$districts_q1 == 1L)
rv$excluded[3] <- TRUE
stopifnot(nrow(quintile_revenue_gap(d, rv)) == 0L)                      # no quintile 1 revenue left
dd <- data.frame(leaid = c("1", "2", "3", "4"), state = "AA", retained = c(1L, 1L, 0L, 1L), pov_quintile_2009 = c(1L, 5L, 5L, 3L),
                 member_2009 = c(10, NA, 10, 10), stringsAsFactors = FALSE)
ay <- gap_a_district_years(dd, 2010:2012)
stopifnot(nrow(ay) == 3L, all(ay$leaid == "1"), identical(ay$sy_end, 2010:2012))

# panel with a placeholder year: the treatment is kept, the outcome is not
y <- data.frame(unit = c("u1", "u1", "u2"), state = "AA", sy_end = c(2010L, 2012L, 2012L), y = c(1, 2, 3), stringsAsFactors = FALSE)
tr <- data.frame(unit = c("u1", "u1", "u1", "u2"), sy_end = c(2010L, 2011L, 2012L, 2012L), d = c(10, 11, 11, 9), stringsAsFactors = FALSE)
p <- cdid_panel(y, tr, c(2010L, 2012L))
stopifnot(nrow(p) == 6L, identical(p$placeholder, rep(c(FALSE, TRUE, FALSE), 2)), p$d[p$unit == "u1" & p$sy_end == 2011L] == 11,
          is.na(p$y[p$unit == "u1" & p$sy_end == 2011L]), is.na(p$d[p$unit == "u2" & p$sy_end == 2010L]))
stopifnot(inherits(try(cdid_panel(y, tr, 2010L), silent = TRUE), "try-error"))   # outcome outside the window

# covariate-by-year controls: every window year but the first, none for the placeholder year
cv <- data.frame(unit = c("u1", "u2"), a = c(2, 5), b = c(1, NA), stringsAsFactors = FALSE)
yi <- year_interactions(p, cv, c("a", "b"), c(2010L, 2012L))
stopifnot(identical(yi$controls, c("x_a_2012", "x_b_2012")), yi$dropped_units == 1L, all(yi$panel$unit == "u1"),
          identical(yi$panel$x_a_2012, c(0, 0, 2)))

# switchers and stayers on a hand-built panel, 2010-2014 (column index 1-5)
#   baseline bin 10:
#   A (AA) 10 10 11 11 11  first switch 2012, up
#   B (AA) 10 10 10 10 10  never switches
#   C (BB) 10 10 10 12 12  first switch 2013
#   D (CC) 10  9 11 11 11  down in 2011, both sides of baseline from 2012: rows dropped from 2012
#   E (BB) NA 10 10 10 10  baseline 2011, its 2010 outcome is not used
#   F (CC) 10 NA 12 12 12  switch date uncertain: outcomes after 2010 dropped, never enters
#   baseline bin 20: G (CC) 20 20 21 21 21, alone in its bin: bin dropped, no stayer
#   baseline bin 30: H (DD) 30 30 31 31 31 against I (DD) 30 30 30 30 30
#   baseline bin 40: J (EE) 40 41 41 41 41 and K (EE) 40 40 40 41 41: every unit has switched from 2013,
#                    so bin 40 has no rows from 2013 and K has no stayer
toy_d <- rbind(A = c(10, 10, 11, 11, 11), B = rep(10, 5), C = c(10, 10, 10, 12, 12), D = c(10, 9, 11, 11, 11),
               E = c(NA, 10, 10, 10, 10), F = c(10, NA, 12, 12, 12), G = c(20, 20, 21, 21, 21), H = c(30, 30, 31, 31, 31),
               I = rep(30, 5), J = c(40, 41, 41, 41, 41), K = c(40, 40, 40, 41, 41))
toy_state <- c(A = "AA", B = "AA", C = "BB", D = "CC", E = "BB", F = "CC", G = "CC", H = "DD", I = "DD", J = "EE", K = "EE")
toy_panel <- function(ids) {
  x <- expand.grid(unit = ids, sy_end = 2010:2014, stringsAsFactors = FALSE)
  x$state <- toy_state[x$unit]
  x$d <- toy_d[cbind(match(x$unit, rownames(toy_d)), x$sy_end - 2009L)]
  x$y <- 1
  x$placeholder <- FALSE
  x
}
check_counts <- function(cn, switchers, stayers, stayer_states, stayer_cells) {
  lab <- c("Effect_1", "Effect_2", "Effect_3", "Placebo_1", "Placebo_2", "Placebo_3")
  cn <- cn[match(lab, cn$package_label), ]
  stopifnot(identical(cn$event_time, c(0L, 1L, 2L, -2L, -3L, -4L)), identical(as.integer(cn$switchers), switchers),
            identical(as.integer(cn$stayers), stayers), identical(as.integer(cn$stayer_states), stayer_states),
            identical(as.integer(cn$stayer_cells), stayer_cells))
}
# bin 10 alone: the same counts whether or not switchers are matched within their baseline bin
for (bb in c(TRUE, FALSE))
  check_counts(cdid_counts(toy_panel(c("A", "B", "C", "D", "E", "F")), effects = 3L, placebo = 3L, by_baseline = bb),
               c(3L, 2L, 1L, 2L, 1L, 0L), c(4L, 2L, 2L, 3L, 1L, 0L), c(2L, 2L, 2L, 2L, 1L, 0L), c(8L, 4L, 2L, 4L, 1L, 0L))
# all bins, matched within the baseline bin
cn <- cdid_counts(toy_panel(rownames(toy_d)), effects = 3L, placebo = 3L)
check_counts(cn, c(5L, 4L, 2L, 3L, 1L, 0L), c(6L, 4L, 3L, 4L, 1L, 0L), c(4L, 4L, 3L, 3L, 1L, 0L), c(10L, 6L, 3L, 5L, 1L, 0L))
su <- attr(cn, "switcher_units")
stopifnot(identical(su$unit, c("A", "C", "D", "F", "G", "H", "J", "K")),
          identical(su$used, c(TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, FALSE)),
          identical(su$level_dropped, c(FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE)),
          identical(su$no_stayer, c(FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, TRUE)))   # F: uncertain date, not a missing stayer
sd <- cdid_switch_dates(toy_panel(c("A", "B", "C", "D", "E", "F")))
stopifnot(identical(sd$direction, c("up", "stayer", "up", "down", "stayer", "up")),
          identical(sd$first_switch, c(2012, Inf, 2013, 2011, Inf, 2012)), identical(sd$baseline_year, c(2010L, 2010L, 2010L, 2010L, 2011L, 2010L)))

# estimability: at least 20 stayers and stayers in at least 3 states, both required
stopifnot(identical(cdid_estimable(c(20L, 19L, 100L, 20L), c(3L, 10L, 2L, 20L)), c(TRUE, FALSE, FALSE, TRUE)))
cr <- cdid_results(data.frame(row_type = c("effect", "effect", "placebo"), package_label = c("Effect_1", "Effect_2", "Placebo_1"),
                              index = c(1L, 2L, 1L), event_time = c(0L, 1L, -2L), switchers = c(30L, 30L, 5L), stayers = c(50L, 10L, 50L),
                              stayer_states = c(5L, 5L, 5L), stayer_cells = c(70L, 10L, 60L), stringsAsFactors = FALSE),
                   data.frame(package_label = c("Effect_1", "Effect_2"), estimate = c(0.1, 0.2), se = 0.05, ci_lo = 0, ci_hi = 0.3,
                              n = c(100, 40), switchers_package = c(30, 30), stringsAsFactors = FALSE))
stopifnot(identical(cr$status, c("ok", "not estimable: 10 stayers in 5 states (need 20 in 3)", "not estimated by the package")),
          near(cr$estimate[1], 0.1), is.na(cr$estimate[2]), identical(cr$n_match_package, c(TRUE, TRUE, NA)),
          all(grepl("can be liberal", cr$se_caveat)))
stopifnot(identical(cdid_results(cn[1:2, ], NULL)$status, rep("not estimated by the package", 2)))

# the step 13 output, when it has been run
cdir <- "outputs/run2/13_continuous"
if (file.exists(file.path(cdir, "counts.csv"))) {
  mo <- utils::read.csv(file.path(cdir, "models.csv"), stringsAsFactors = FALSE)
  co <- utils::read.csv(file.path(cdir, "counts.csv"), stringsAsFactors = FALSE)
  st <- utils::read.csv(file.path(cdir, "settings.csv"), stringsAsFactors = FALSE)
  n_models <- sum(lengths(CDID_GAPS)) * length(CDID_BIN_WIDTHS)
  stopifnot(nrow(mo) == n_models, !anyDuplicated(mo[c("family", "gap", "bin")]), setequal(mo$bin, names(CDID_BIN_WIDTHS)),
            nrow(co) == n_models * (CDID_EFFECTS + CDID_PLACEBO), all(mo$last_year <= 2024L))
  stopifnot(all(co$event_time[co$row_type == "effect"] == co$index[co$row_type == "effect"] - 1L),
            all(co$event_time[co$row_type == "placebo"] == -(co$index[co$row_type == "placebo"] + 1L)),
            all(co$package_label == paste0(ifelse(co$row_type == "effect", "Effect_", "Placebo_"), co$index)),
            identical(co$estimable, co$stayers >= CDID_MIN_STAYERS & co$stayer_states >= CDID_MIN_STAYER_STATES),
            all(co$stayer_states <= co$stayers), all(co$bin_width_dollars == 1000 * CDID_BIN_WIDTHS[co$bin]))
  stopifnot(all(mo$controls == 0L), all(mo$controls_specified[mo$gap == "a_poverty"] == 0L),       # controls dropped: memory
            all(mo$controls_specified[mo$gap != "a_poverty"] == length(CS_COVARIATES) * (lengths(CDID_WINDOWS)[mo$family[mo$gap != "a_poverty"]] - 1L)),
            all(mo$switchers_used + mo$switchers_dropped_no_stayer_in_bin + mo$switchers_unused_other == mo$switcher_units),
            all(mo$switchers_bin_with_one_switch_date <= mo$switchers_dropped_no_stayer_in_bin),
            all(mo$placeholder_years[mo$family == "hs"] == "2020"), all(mo$placeholder_years[mo$family == "seda"] == "2020 2021"))
  stopifnot(st$value[st$setting == "polars_remote_sha"] == CDID_POLARS_SHA)
  if (file.exists(file.path(cdir, "results.csv"))) {
    rs <- utils::read.csv(file.path(cdir, "results.csv"), stringsAsFactors = FALSE)
    stopifnot(nrow(rs) == nrow(co), all(is.na(rs$estimate[!rs$estimable])), all(nzchar(rs$se_caveat)),
              all(rs$switchers_match_package[!is.na(rs$switchers_package)]), all(rs$n_match_package %in% c(TRUE, NA)),
              all(!is.na(rs$estimate[rs$status == "ok"])), all(mo$estimation %in% "ok" | grepl("^(error|aborted)", mo$estimation)))
  }
}

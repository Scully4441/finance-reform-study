withr::local_dir(ROOT)

rc_fixture_dir <- function(env = parent.frame()) {
  d <- tempfile("rcfix", tmpdir = "data/raw"); dir.create(d, recursive = TRUE)
  withr::defer(unlink(d, recursive = TRUE), envir = env)
  d
}
rc_row <- function(state, sy_end, dir, files)
  data.frame(state = state, sy_end = as.integer(sy_end), file_name = paste(file.path(basename(dir), files), collapse = " | "),
             stringsAsFactors = FALSE)
pick <- function(x, subject, sg, id = NULL, name = NULL) {
  k <- x$subject == subject & x$sg == sg
  if (!is.null(id)) k <- k & x$st_id == id
  if (!is.null(name)) k <- k & x$name == name
  x[k, ]
}

test_that("the Florida loader reads one row per district and indicator from the pair files", {
  fx <- rc_fixture_dir()
  fl_file <- function(path, pair, district, indicator, cnt, n, p) {
    d <- data.frame(`School Year` = "2022-23", `Subject Area` = "s", `Individual Assessment` = "t", `Indicator Pair` = pair,
                    `Achievement Level` = "Level 3 and Above", `District Name` = district, Indicator = indicator,
                    `Measure Names` = "m", `AGG(# Achievement Level)` = cnt, `AGG(# of Students)` = n,
                    `AGG(% Achievement Level)` = p, `AGG(Index)` = "1", `Measure Values` = "0", check.names = FALSE)
    d <- d[rep(seq_len(nrow(d)), each = 3), ]
    d[["Measure Names"]] <- rep(c("a", "b", "c"), length(district))
    utils::write.csv(d, path, row.names = FALSE)
  }
  dist <- c("01-Alpha", "01-Alpha", "02-Beta", "02-Beta")
  white <- list(cnt = c("60", "30"), n = c("100", "50"), p = c("0.6", "0.6"))
  black <- function(path) fl_file(path, "White - Black", dist, c("Black", "White", "Black", "White"),
                                  c("20", white$cnt[1], "%null%", white$cnt[2]), c("40", white$n[1], "%null%", white$n[2]),
                                  c("0.5", white$p[1], "%null%", white$p[2]))
  hisp <- function(path, wcnt = white$cnt) fl_file(path, "White - Hispanic", dist, c("Hispanic", "White", "Hispanic", "White"),
                                                   c("10", wcnt[1], "%null%", wcnt[2]), c("50", white$n[1], "%null%", white$n[2]),
                                                   c("0.2", white$p[1], "%null%", white$p[2]))
  files <- c("FL_2023_alg1_white-black.csv", "FL_2023_alg1_white-hispanic.csv",
             "FL_2023_ela10_white-black.csv", "FL_2023_ela10_white-hispanic.csv")
  black(file.path(fx, files[1])); hisp(file.path(fx, files[2])); black(file.path(fx, files[3])); hisp(file.path(fx, files[4]))
  x <- rc_load_fl(rc_row("FL", 2023, fx, files))
  expect_all(nrow(x) == 12, setequal(x$sg, c("bl", "hi", "wh")), identical(sort(unique(x$st_id)), c("01", "02")),
             identical(sort(unique(x$name)), c("Alpha", "Beta")),
             pick(x, "math", "bl", "01")$p_lo == 50, pick(x, "math", "bl", "01")$n == 40,
             pick(x, "rla", "wh", "02")$p_hi == 60, pick(x, "math", "hi", "01")$p_lo == 20,
             nrow(pick(x, "math", "wh", "01")) == 1)
  expect_all(is.na(pick(x, "math", "bl", "02")$p_lo), is.na(pick(x, "math", "hi", "02")$n))
  hisp(file.path(fx, files[2]), wcnt = c("61", "30"))
  expect_error(rc_load_fl(rc_row("FL", 2023, fx, files)), "White rows differ")
  hisp(file.path(fx, files[2]))
  expect_error(rc_load_fl(rc_row("FL", 2024, fx, files)), "filter columns")
})

test_that("the Maryland loader reads the LEA sheet of both workbooks in the zip", {
  fx <- rc_fixture_dir()
  wb <- function(path, tests) {
    lea <- data.frame(Year = "2023", LEA = "01", `LEA Name` = "Alpha", School = "A", `School Name` = "All Alpha Schools",
                      Assessment = c(rep(tests[1], 5), tests[2]),
                      `Student Group` = c("All Students", "Black/African American", "Hispanic/Latino of any race", "White", "Asian",
                                          "All Students"),
                      `Tested Count` = c("100", "20", "15", "*", "12", "90"), `Proficient Count` = c("40", "*", "6", "*", "3", "9"),
                      `Proficient Pct` = c("40.0", "<= 5.0", "40.0", "*", "25.0", "10.0"), check.names = FALSE)
    openxlsx::write.xlsx(list(School_Level = lea[0, ], LEA_Level = lea, State_Level = lea[0, ]), path)
  }
  td <- tempfile("mdzip"); dir.create(td)
  wb(file.path(td, "2023 MCAP ELA Administrative Data Report Card.xlsx"), c("English Language Arts 10", "English Language Arts 08"))
  wb(file.path(td, "2023 MCAP MATH Administrative Data Report Card.xlsx"), c("Algebra 1", "Geometry"))
  zip::zipr(file.path(fx, "MCAP_ELA_Math_2023.zip"), list.files(td, full.names = TRUE))
  x <- rc_load_md(rc_row("MD", 2023, fx, "MCAP_ELA_Math_2023.zip"))
  expect_all(nrow(x) == 8, all(x$st_id == "01"), setequal(x$sg, c("all", "bl", "hi", "wh")),
             pick(x, "math", "all")$p_lo == 40, pick(x, "math", "all")$n == 100,
             pick(x, "rla", "bl")$p_lo == 0, pick(x, "rla", "bl")$p_hi == 5, pick(x, "rla", "bl")$n == 20,
             pick(x, "math", "hi")$p_hi == 40)
  expect_all(is.na(pick(x, "math", "wh")$n), is.na(pick(x, "math", "wh")$p_lo))
  expect_error(rc_load_md(rc_row("MD", 2024, fx, "MCAP_ELA_Math_2023.zip")), "no rows with")
})

test_that("the Maine loader reads one year of the district rows of a multi-year crosstab", {
  fx <- rc_fixture_dir()
  hdr <- c("Assessment", "Grade", "Name", "Population", "Report Type", "Subcategory (Assessments with suppression)", "Year",
           "Students  (*)", "Students  (not *)", "Achievement Level", "Assessment", "Year", "Max. Students Tested")
  r <- function(name, pop, type, year, sub, lev, k, mx)
    c("Mathematics", "High School", name, pop, type, sub, year, "", k, lev, "Mathematics", year, mx)
  at <- "At or Above State Expectations"; below <- "Below State Expectations"
  rows <- rbind(r("Alpha", "All Students", "District", "2023-2024", at, at, "30", "100"),
                r("Alpha", "All Students", "District", "2023-2024", below, below, "70", "100"),
                r("Alpha", "Black or African American", "District", "2023-2024", "Suppressed", "*", "", "8"),
                r("Alpha", "Hispanic/Latino", "District", "2023-2024", "Suppressed", at, "5", "20"),
                r("Alpha", "Hispanic/Latino", "District", "2023-2024", below, below, "15", "20"),
                r("Alpha", "White", "District", "2023-2024", at, at, "45", "50"),
                r("Alpha", "White", "District", "2023-2024", below, below, "5", "50"),
                r("Alpha", "Asian", "District", "2023-2024", at, at, "5", "10"),
                r("Alpha", "All Students", "District", "2022-2023", at, at, "99", "100"),
                r("Alpha High School", "All Students", "School", "2023-2024", at, at, "1", "100"),
                r("Statewide", "All Students", "Statewide", "2023-2024", at, at, "1", "100"))
  con <- file(file.path(fx, "me_math.csv"), "w", encoding = "UTF-16")
  writeLines(c(paste(hdr, collapse = "\t"), apply(rows, 1, paste, collapse = "\t")), con)
  close(con)
  x <- rc_load_me(rc_row("ME", 2024, fx, "me_math.csv"))
  expect_all(nrow(x) == 4, all(x$subject == "math"), all(is.na(x$st_id)), all(x$name == "Alpha"),
             pick(x, "math", "all")$p_lo == 30, pick(x, "math", "all")$n == 100, pick(x, "math", "wh")$p_hi == 90,
             pick(x, "math", "bl")$n == 8, pick(x, "math", "hi")$n == 20)
  expect_all(is.na(pick(x, "math", "bl")$p_lo), is.na(pick(x, "math", "hi")$p_lo))
  expect_error(rc_load_me(rc_row("ME", 2025, fx, "me_math.csv")), "no rows with")
})

test_that("the West Virginia loader reads the grade 11 blocks of the district total rows", {
  fx <- rc_fixture_dir()
  wv_file <- function(path, sheet, math, rla) {
    lev <- c("Does Not Meet Standard", "Partially Meets Standard", "Meets Standard", "Exceeds Standard", "Proficiency Rate (%)")
    top <- c(rep("", 6), "Mathematics: Grade 11", rep("", 4), "Reading: Grade 11", rep("", 4))
    hdr <- c("Dist", "District", "Schl", "School", "PopulationGroup", "Subgroup", lev, lev)
    id <- rbind(c("002", "Alpha", "999", "Alpha County Schools", "Total Population", "Total"),
                c("002", "Alpha", "999", "Alpha County Schools", "Race/Ethnicity", "Black or African American"),
                c("002", "Alpha", "999", "Alpha County Schools", "Race/Ethnicity", "Hispanic or Latino"),
                c("002", "Alpha", "999", "Alpha County Schools", "Race/Ethnicity", "White"),
                c("002", "Alpha", "999", "Alpha County Schools", "Gender", "Female"),
                c("002", "Alpha", "201", "Alpha High School", "Race/Ethnicity", "White"),
                c("101", "WV Academy", "999", "West Virginia Academy", "Race/Ethnicity", "White"),
                c("999", "Statewide", "999", "State Total", "Race/Ethnicity", "White"))
    blk <- function(v) cbind(matrix("", length(v), 4), v)
    body <- cbind(id, blk(math), blk(rla))
    m <- rbind(top, hdr, body, c("Please Note", rep("", 15)))
    sheets <- list(data.frame(x = 1), as.data.frame(m))
    names(sheets) <- c("Cover", sheet)
    openxlsx::write.xlsx(sheets, path, colNames = FALSE)
  }
  wv_file(file.path(fx, "SY24.xlsx"), "SY24 Schl & Dist Comp. Results",
          c("0.45", "***", "0.2", "0.5", "0.6", "0.7", "0.8", "0.9"), c("0.55", "***", "0.3", "0.4", "0.1", "0.2", "0.3", "0.4"))
  x <- rc_load_wv(rc_row("WV", 2024, fx, "SY24.xlsx"))
  expect_all(nrow(x) == 10, identical(sort(unique(x$st_id)), c("0200000", "1010000")), all(is.na(x$n)),
             pick(x, "math", "all", "0200000")$p_lo == 45, pick(x, "rla", "wh", "0200000")$p_hi == 40,
             pick(x, "math", "wh", "1010000")$p_lo == 80, pick(x, "rla", "hi", "0200000")$p_lo == 30)
  expect_all(is.na(pick(x, "math", "bl", "0200000")$p_lo))
  wv_file(file.path(fx, "SY22.xlsx"), "SY22 School & District",
          c("45", "**", "20", "50", "60", "70", "80", "90"), c("55", "**", "30", "40", "10", "20", "30", "40"))
  y <- rc_load_wv(rc_row("WV", 2022, fx, "SY22.xlsx"))
  expect_all(identical(y$p_lo, x$p_lo), identical(y$st_id, x$st_id))
})

test_that("the new report-card states are registered and mapped", {
  expect_all(all(c("FL", "MD", "ME", "WV") %in% names(HS_RC_LOADERS)), "ME" %in% HS_RC_NAME_STATES,
             !"FL" %in% HS_RC_NAME_STATES)
  hz <- read_hs_harmonization()
  st <- function(s) hz$mapping_status[hz$state == s]
  expect_all(identical(st("FL"), rep("mapped", 4)), identical(st("MD"), rep("mapped", 4)), identical(st("WV"), rep("mapped", 4)),
             identical(st("ME"), c("unavailable", rep("mapped", 3))))
  for (s in c("AK", "IA", "MI", "MS", "MT"))
    expect_all(identical(st(s), rep("unavailable", 4)), all(nzchar(hz$notes[hz$state == s])))
})

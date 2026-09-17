# One loader per state for the report-card files of data/reference/hs_reportcard_harmonization.csv
# (docs/design_extension.md, Sections 4-6). Each loader takes one harmonization row (a mapped
# state-year) and returns rc_long() rows (R/functions/hs_reportcard.R): district rows only, the
# harmonization table's grade or course, test group, subgroups and proficiency definition. Values
# are parsed but no rule is applied here; rc_pool(), the crosswalk and rc_cells() follow.

# ---- file helpers ----------------------------------------------------------------------------

# Extract the members of a zip matching pattern into a temporary folder; returns their paths.
rc_unzip <- function(zip, pattern) {
  m <- grep(pattern, utils::unzip(zip, list = TRUE)$Name, value = TRUE, ignore.case = TRUE)
  if (!length(m)) stop(basename(zip), ": no member matching ", pattern)
  td <- tempfile("rc"); dir.create(td)
  utils::unzip(zip, files = m, exdir = td)
  file.path(td, m)
}

rc_fread <- function(path, ...) {
  data.table::fread(path, colClasses = "character", na.strings = NULL, showProgress = FALSE,
                    data.table = FALSE, encoding = "UTF-8", check.names = FALSE, ...)
}

# A spreadsheet sheet as character columns. header_row: the row holding the column names
# (1 = first row); header_row = 0 reads without names (columns ...1, ...2).
rc_excel <- function(path, sheet, header_row = 1) {
  if (grepl("\\.xlsb$", path, ignore.case = TRUE)) {
    d <- readxlsb::read_xlsb(path, sheet = sheet, skip = max(header_row - 1, 0), col_names = header_row > 0,
                             col_types = "string")
  } else {
    d <- suppressMessages(readxl::read_excel(path, sheet = sheet, skip = max(header_row - 1, 0),
                                             col_names = header_row > 0, col_types = "text",
                                             .name_repair = "minimal", na = character()))
  }
  d <- as.data.frame(d, stringsAsFactors = FALSE, optional = TRUE)
  names(d) <- trimws(gsub("[\r\n]+", " ", names(d)))
  d
}

# The column named nm (exact, then case- and space-insensitive); stops if absent or ambiguous.
rc_col <- function(d, nm, file = "") {
  k <- which(names(d) == nm)
  if (!length(k)) k <- which(tolower(gsub("\\s+", " ", names(d))) == tolower(gsub("\\s+", " ", nm)))
  if (length(k) != 1L) stop(basename(file), ": expected one column '", nm, "', found ", length(k),
                            " (columns: ", paste(utils::head(names(d), 40), collapse = " | "), ")")
  d[[k]]
}

# Stop when a filter keeps nothing, naming the values that were there.
rc_need <- function(keep, what, values, file) {
  if (!any(keep)) stop(basename(file), ": no rows with ", what, "; values: ",
                       paste(utils::head(unique(values), 30), collapse = " | "))
  invisible(keep)
}

# ---- loaders -----------------------------------------------------------------------------------

rc_load_ca <- function(row) {
  f <- rc_files(row)[1]
  txt <- rc_unzip(f, "_all_csv_v1\\.txt$")
  d <- rc_fread(txt, sep = "^", quote = "")
  n_name <- if ("Total Students Tested with Scores" %in% names(d)) "Total Students Tested with Scores" else "Students with Scores"
  keep <- d[["School Code"]] == "0000000" & d[["Type ID"]] == "6" & d[["Grade"]] == "11" &
    d[["Test Type"]] == "B" & d[["Test ID"]] %in% c("1", "2") & d[["Student Group ID"]] %in% c("1", "74", "78", "80")
  rc_need(keep, "district grade 11 rows", d[["Type ID"]], f)
  d <- d[keep, ]
  unlink(dirname(txt), recursive = TRUE)
  rc_long("CA", row$sy_end, st_id = paste0(d[["County Code"]], d[["District Code"]]),
          name = if ("District Name" %in% names(d)) d[["District Name"]] else "",
          subject = ifelse(d[["Test ID"]] == "2", "math", "rla"),
          sg = c(`1` = "all", `74` = "bl", `78` = "hi", `80` = "wh")[d[["Student Group ID"]]],
          n = rc_count(d[[n_name]]), p = rc_pct(d[["Percentage Standard Met and Above"]]))
}

rc_load_ct <- function(row) {
  out <- NULL
  for (f in rc_files(row)) {
    d <- utils::read.csv(f, skip = 4, header = FALSE, colClasses = "character", na.strings = character(),
                         check.names = FALSE)
    hdr <- utils::read.csv(f, skip = 4, nrows = 1, header = FALSE, colClasses = "character")
    if (!identical(unname(trimws(unlist(hdr[1, c(1:3, 7)]))),
                   c("District", "District Code", "Race/Ethnicity", "Total Numberwith Scored Tests")))
      stop(basename(f), ": unexpected header row 5")
    d <- d[-1, ]
    # District and District Code print on each district's first row only: fill down.
    code <- gsub("[^0-9]", "", d[[2]])
    code[code == ""] <- NA
    grp <- cumsum(!is.na(code))
    code <- code[!is.na(code)][grp]
    name <- d[[1]][nzchar(d[[1]])][grp]
    sg <- rc_sg(d[[3]], c(bl = "Black or African American", hi = "Hispanic/Latino of any race", wh = "White"))
    k <- !is.na(sg)
    out <- rbind(out, rc_long("CT", row$sy_end, st_id = code[k], name = name[k],
                              subject = if (grepl("_math\\.csv$", f)) "math" else "rla", sg = sg[k],
                              n = rc_count(d[[7]][k]), p = rc_pct(d[[17]][k]), part = d[[6]][k]))
  }
  out
}

rc_load_de <- function(row) {
  f <- rc_files(row)[1]
  d <- rc_fread(f)
  keep <- d$schoolcode == "0" & d$gender == "All Students" & d$specialdemo == "All Students" &
    d$geography == "All Students" & d$assessmentname == "SAT School-Day (Spring)" &
    d$grade == "11th Grade" & toupper(d$contentarea) %in% c("MATH", "ELA")
  rc_need(keep, "district 11th Grade SAT rows", d$grade, f)
  d <- d[keep, ]
  sg <- rc_sg(d$race, c(all = "All Students", bl = "African American", hi = "Hispanic/Latino", wh = "White"))
  d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
  red <- d$rowstatus == "REDACTED"
  rc_long("DE", row$sy_end, st_id = d$districtcode, name = d$district,
          subject = ifelse(toupper(d$contentarea) == "MATH", "math", "rla"), sg = sg,
          n = ifelse(red, NA, rc_count(d$tested)), p = rc_pct(ifelse(red, "", d$pctproficient)))
}

rc_load_ga <- function(row) {
  f <- rc_files(row)[1]
  d <- rc_fread(f)
  names(d) <- sub("^#", "", names(d))
  keep <- d$INSTN_NUMBER == "ALL" & d$SCHOOL_DISTRCT_CD != "ALL"
  if ("ACDMC_LVL" %in% names(d)) keep <- keep & d$ACDMC_LVL == "ALL GRADES"
  rc_need(keep, "district ALL rows", d$INSTN_NUMBER, f)
  d <- d[keep, ]
  math_tests <- switch(as.character(row$sy_end),
                       "2022" = , "2023" = c("Algebra I", "Coordinate Algebra"),
                       "2024" = c("Algebra: Concepts and Connections", "Algebra I", "Coordinate Algebra"),
                       "2025" = "Algebra: Concepts and Connections")
  rla_test <- "American Literature and Composition"
  d <- d[d$TEST_CMPNT_TYP_NM %in% c(math_tests, rla_test), ]
  for (t in c(math_tests, rla_test)) rc_need(d$TEST_CMPNT_TYP_NM == t, t, d$TEST_CMPNT_TYP_NM, f)
  sg <- rc_sg(d$SUBGROUP_NAME, c(all = "All Students", bl = "Black or African American", hi = "Hispanic", wh = "White"))
  d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
  n <- rc_count(d$NUM_TESTED_CNT)
  cnt <- rc_count(d$PROFICIENT_CNT) + rc_count(d$DISTINGUISHED_CNT)
  p <- rc_pct_sum(d$PROFICIENT_PCT, d$DISTINGUISHED_PCT)
  by_cnt <- !is.na(cnt) & !is.na(n) & n > 0                  # counts where printed, else the percentages
  p$lo[by_cnt] <- p$hi[by_cnt] <- round(100 * cnt[by_cnt] / n[by_cnt], 6)
  math <- d$TEST_CMPNT_TYP_NM %in% math_tests
  pooled <- math & length(math_tests) > 1
  # TFS in NUM_TESTED_CNT means fewer than 10 tested, though the percentages may still be printed:
  # a count band [0, 9], below the floor (n_band_lo = 0).
  rc_long("GA", row$sy_end, st_id = d$SCHOOL_DISTRCT_CD, name = d$SCHOOL_DSTRCT_NM,
          n_band_lo = ifelse(d$NUM_TESTED_CNT == "TFS", 0, NA),
          subject = ifelse(math, "math", "rla"), sg = sg, n = n, p = p,
          component = ifelse(pooled, d$TEST_CMPNT_TYP_NM, NA))
}

rc_load_ky <- function(row) {
  f <- rc_files(row)[1]
  d <- rc_fread(f)
  names(d) <- toupper(names(d))
  school <- if (row$sy_end <= 2023) "---District Total---" else "All Schools"
  grade <- c(`2022` = "10", `2023` = "10", `2024` = "Grade 10", `2025` = "10th")[[as.character(row$sy_end)]]
  subj <- if (row$sy_end <= 2023) c(math = "MA", rla = "RD") else c(math = "Mathematics", rla = "Reading")
  keep <- d[["SCHOOL NAME"]] == school & d$GRADE == grade & d$SUBJECT %in% subj
  if (row$sy_end >= 2024) keep <- keep & d[["SCHOOL TYPE"]] == ""
  rc_need(keep, "district grade 10 rows", paste(d[["SCHOOL NAME"]][1:50], d$GRADE[1:50]), f)
  d <- d[keep, ]
  sg <- rc_sg(d$DEMOGRAPHIC, c(all = "All Students", bl = "African American", hi = "Hispanic or Latino",
                               wh = "White (non-Hispanic)"))
  d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
  pd <- grep("^PROFICIENT ?/ ?DISTINGUISHED$", names(d), value = TRUE)
  rc_long("KY", row$sy_end, st_id = paste0(d[["COUNTY NUMBER"]], d[["DISTRICT NUMBER"]], "000"),
          name = d[["DISTRICT NAME"]], subject = names(subj)[match(d$SUBJECT, subj)], sg = sg,
          p = rc_pct(ifelse(d$SUPPRESSED == "Y", "", d[[pd]])))
}

rc_load_ma <- function(row) {
  f <- rc_files(row)[1]
  d <- rc_fread(f)
  keep <- d$org_type == "Public School District" & d$org_code == d$dist_code & d$test_grade == "10" &
    d$subject_code %in% c("MATH", "ELA") & d$sy == as.character(row$sy_end)
  rc_need(keep, "district grade 10 rows", d$org_type, f)
  d <- d[keep, ]
  sg <- rc_sg(d$stu_grp, c(all = "All Students", bl = "Black or African American", hi = "Hispanic or Latino", wh = "White"))
  d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
  n <- rc_count(d$stu_cnt); cnt <- rc_count(d$m_plus_e_cnt)
  p <- rc_pct(d$m_plus_e_pct, scale = 100)
  by_cnt <- !is.na(cnt) & !is.na(n) & n > 0                  # the printed share is rounded to 0.01
  p$lo[by_cnt] <- p$hi[by_cnt] <- round(100 * cnt[by_cnt] / n[by_cnt], 6)
  part <- rc_pct(d$stu_part_pct, scale = 100)$lo
  rc_long("MA", row$sy_end, st_id = substr(d$dist_code, 1, 4), name = d$dist_name,
          subject = ifelse(d$subject_code == "MATH", "math", "rla"), sg = sg, n = n, p = p,
          part = ifelse(is.na(part), NA, format(part, trim = TRUE)))
}

rc_load_ny <- function(row) {
  f <- file.path(HS_RC_DIR, sprintf("NY/SRC%d_annual_regents_exams.csv", row$sy_end))   # R/02a_ny_access_export.R
  d <- rc_fread(f)
  math <- switch(as.character(row$sy_end), "2022" = , "2023" = "Regents Common Core Algebra I",
                 "2024" = c("Regents Common Core Algebra I", "Regents Algebra I"), "2025" = "Regents Algebra I")
  rla <- "Regents Common Core English Language Art"
  keep <- d$YEAR == as.character(row$sy_end) & grepl("^[0-9]{8}0000$", d$ENTITY_CD) &
    !startsWith(d$ENTITY_CD, "0000") & d$SUBJECT %in% c(math, rla)
  for (t in c(math, rla)) rc_need(keep & d$SUBJECT == t, t, d$SUBJECT, f)
  d <- d[keep, ]
  sg <- rc_sg(d$SUBGROUP_NAME, c(all = "All Students", bl = "Black or African American", hi = "Hispanic or Latino", wh = "White"))
  d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
  n <- rc_count(d$TESTED); cnt <- rc_count(d$NUM_PROF)
  p <- rc_pct(d$PER_PROF)
  by_cnt <- !is.na(cnt) & !is.na(n) & n > 0
  p$lo[by_cnt] <- p$hi[by_cnt] <- round(100 * cnt[by_cnt] / n[by_cnt], 6)
  is_math <- d$SUBJECT %in% math
  rc_long("NY", row$sy_end, st_id = d$ENTITY_CD, name = d$ENTITY_NAME, subject = ifelse(is_math, "math", "rla"),
          sg = sg, n = n, p = p, component = ifelse(is_math & length(math) > 1, d$SUBJECT, NA))
}

rc_load_az <- function(row) {
  f <- rc_files(row)[1]
  d <- rc_excel(f, "District")
  keep <- rc_col(d, "FAY Status", f) == "All" & rc_col(d, "Test Level", f) %in% c("Math Grade 11", "ELA Grade 11")
  rc_need(keep, "FAY All grade 11 rows", rc_col(d, "Test Level", f), f)
  d <- d[keep, ]
  sg <- rc_sg(rc_col(d, "Subgroup", f), c(all = "All Students", bl = "Black or African American",
                                          hi = "Hispanic or Latino", wh = "White"))
  d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
  nm <- if ("District Name" %in% names(d)) "District Name" else "DistrictName"
  rc_long("AZ", row$sy_end, st_id = rc_col(d, "District Entity ID", f), name = d[[nm]],
          subject = ifelse(d[["Test Level"]] == "Math Grade 11", "math", "rla"), sg = sg,
          n = rc_count(d[["Number Tested"]]), p = rc_pct(d[["Percent Passing"]]))
}

# A sheet whose column names sit in the row whose first cell is first_cell; attribute "above"
# carries the row above it (group labels for wide layouts).
rc_excel_at <- function(path, sheet, first_cell) {
  raw <- rc_excel(path, sheet, header_row = 0)
  h <- which(trimws(raw[[1]]) == first_cell)[1]
  if (is.na(h)) stop(basename(path), ": no row starting '", first_cell, "' in sheet ", sheet)
  d <- raw[-seq_len(h), , drop = FALSE]
  names(d) <- trimws(gsub("\\s+", " ", unlist(raw[h, ])))
  attr(d, "above") <- if (h > 1) unlist(raw[h - 1, ]) else NULL
  d
}

rc_load_co <- function(row) {
  out <- NULL
  files <- rc_files(row)
  for (i in seq_along(files)) {
    f <- files[i]
    d <- rc_excel_at(f, "Race Ethnicity", "Level")
    keep <- d$Level == "District" & d$Grade %in% c("SAT Grade 11", "PSAT Grade 10", "PSAT Grade 9")
    rc_need(keep, "district SAT/PSAT rows", d$Grade, f)
    d <- d[keep, ]
    sg <- rc_sg(d[["Race/Ethnicity"]], c(bl = "Black", hi = "Hispanic", wh = "White"))
    d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
    n <- rc_count(rc_col(d, "Number of Valid Scores", f))
    cnt <- rc_count(d[[grep("^Number Met or Exceeded Expectations", names(d))]])
    p <- rc_pct(d[[grep("^Percent Met or Exceeded Expectations", names(d))]])
    by_cnt <- !is.na(cnt) & !is.na(n) & n > 0
    p$lo[by_cnt] <- p$hi[by_cnt] <- round(100 * cnt[by_cnt] / n[by_cnt], 6)
    out <- rbind(out, rc_long("CO", row$sy_end, st_id = d[["District Code"]], name = d[["District Name"]],
                              subject = c("math", "rla")[i], sg = sg, n = n, p = p,
                              part = rc_col(d, "Participation Rate", f), component = d$Grade,
                              part_n = rc_count(rc_col(d, "Number of Total Records", f))))
  }
  out
}

rc_load_dc <- function(row) {
  f <- rc_files(row)[1]
  d <- rc_excel(f, if (row$sy_end == 2022) "prof" else "Meeting, Exceeding")
  grp <- if (row$sy_end == 2022) "Subgroup Value" else "Student Group Value"
  test <- if (row$sy_end == 2025) "Enrolled Grade or Course" else "Tested Grade/Subject"
  math <- c("Algebra I", "Geometry", "Algebra II"); rla <- "English II"
  if (row$sy_end == 2025) { math <- paste0("HS-", math); rla <- paste0("HS-", rla) }
  keep <- d[["Aggregation Level"]] == "LEA" & d[["Assessment Name"]] == "All" & d[[test]] %in% c(math, rla)
  if ("Grade of Enrollment" %in% names(d)) keep <- keep & d[["Grade of Enrollment"]] == "All"
  if ("School Framework" %in% names(d)) keep <- keep & d[["School Framework"]] == "All"
  rc_need(keep, "LEA high school rows", d[[test]], f)
  d <- d[keep, ]
  sg <- rc_sg(d[[grp]], c(all = "All", all = "All Students", bl = "Black/African American",
                          hi = "Hispanic/Latino", hi = "Hispanic/Latino of any race", wh = "White/Caucasian", wh = "White"))
  d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
  n <- rc_count(d[["Total Count"]]); cnt <- rc_count(d$Count)
  p <- rc_pct(d$Percent)
  by_cnt <- !is.na(cnt) & !is.na(n) & n > 0
  p$lo[by_cnt] <- p$hi[by_cnt] <- round(100 * cnt[by_cnt] / n[by_cnt], 6)
  is_math <- d[[test]] %in% math
  rc_long("DC", row$sy_end, st_id = d[["LEA Code"]], name = d[["LEA Name"]], subject = ifelse(is_math, "math", "rla"),
          sg = sg, n = n, p = p, component = ifelse(is_math, d[[test]], NA))
}

rc_load_id <- function(row) {
  f <- rc_files(row)[1]
  d <- switch(as.character(row$sy_end), "2022" = rc_excel(f, "Districts", 3),
              "2023" = rc_excel(f, "Districts (LEAs)", 2), "2024" = rc_excel(f, "Districts", 1))
  names(d) <- gsub(" ", "", names(d))                   # 2022 prints "Subject Name", later "SubjectName"
  keep <- d$Grade == "High School" & d$SubjectName %in% c("Math", "ELA")
  rc_need(keep, "High School rows", d$Grade, f)
  d <- d[keep, ]
  sg <- rc_sg(d$Population, c(all = "All Students", bl = "Black / African American", hi = "Hispanic or Latino", wh = "White"))
  d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
  p <- rc_pct_sum(d$AdvancedRate, d$ProficientRate)
  n <- NA_real_; part <- NA_character_
  if ("ProficiencyDenominator" %in% names(d)) {
    n <- rc_count(d$ProficiencyDenominator)
    cnt <- rc_count(d$Advanced) + rc_count(d$Proficient)
    by_cnt <- !is.na(cnt) & !is.na(n) & n > 0
    p$lo[by_cnt] <- p$hi[by_cnt] <- round(100 * cnt[by_cnt] / n[by_cnt], 6)
    part <- d$TestedRate
  }
  rc_long("ID", row$sy_end, st_id = d$DistrictId, name = d$DistrictName,
          subject = ifelse(d$SubjectName == "Math", "math", "rla"), sg = sg, n = n, p = p, part = part)
}

rc_load_il <- function(row) {
  f <- rc_files(row)[1]
  y <- row$sy_end
  d <- rc_excel(f, if (y == 2025) "ACT" else "SAT")
  lev <- if (y == 2025) "Level" else "Type"
  d <- d[d[[lev]] == "District", ]
  rc_need(nrow(d) > 0, "District rows", lev, f)
  id <- gsub("-", "", d$RCDTS)
  st_id <- paste(substr(id, 1, 2), substr(id, 3, 5), substr(id, 6, 9), substr(id, 10, 11), sep = "-")
  groups <- c(all = "Total", wh = "White", bl = "Black or African American", hi = "Hispanic or Latino")
  # The all-students participation columns carry no group suffix: "# Students SAT Math Participation",
  # "% Students SAT Math Participation", "% SAT ELA Participation".
  part_col <- function(pre, s2, g) {
    cand <- if (g == "Total") paste0(pre, c(" Students ", " "), s2, " Participation") else paste0(pre, " ", s2, " Participation - ", g)
    k <- cand[cand %in% names(d)]
    if (length(k) != 1L) stop(basename(f), ": no single column among ", paste(cand, collapse = " / "))
    d[[k]]
  }
  out <- NULL
  for (subj in c("math", "rla")) for (sg in names(groups)) {
    g <- groups[[sg]]
    if (y <= 2023) {
      s <- if (subj == "math") "SAT Math" else "SAT Reading"
      who <- if (sg == "all") "Total Students" else paste("Total", g, "Students")
      p <- rc_pct_sum(rc_col(d, paste(s, who, "Level 3 %"), f), rc_col(d, paste(s, who, "Level 4 %"), f))
      s2 <- if (subj == "math") "SAT Math" else "SAT ELA"
      n <- rc_count(part_col("#", s2, g))
      part <- part_col("%", s2, g)
    } else if (y == 2024) {
      s <- if (subj == "math") "SAT Math" else "SAT ELA"
      p <- rc_pct(rc_col(d, paste0(s, " Proficiency Rate - ", g), f))
      n <- NA_real_
      pc <- if (g == "Total") paste0("% Students ", s, " Participation") else paste0("% ", s, " Participation - ", g)
      part <- if (pc %in% names(d)) d[[pc]] else {             # no "% ... - Total": 100 minus the no-participation rate
        np <- rc_pct(rc_col(d, paste0(s, " No Participation Rate - ", g), f))$lo
        ifelse(is.na(np), NA, format(round(100 - np, 6), trim = TRUE))
      }
    } else {
      s <- if (subj == "math") "ACT Math" else "ACT ELA"
      p <- rc_pct(rc_col(d, paste0(s, " Proficiency Rate Grade 11 - ", g), f))
      n <- NA_real_
      part <- rc_col(d, paste0(s, " Participation Rate Grade 11 - ", g), f)
    }
    out <- rbind(out, rc_long("IL", y, st_id = st_id, name = d$District, subject = subj, sg = sg, n = n, p = p, part = part))
  }
  out
}

rc_load_in <- function(row) {
  f <- rc_files(row)[1]
  out <- NULL
  for (subj in c("math", "rla")) {
    s <- if (subj == "math") "Math" else "EBRW"
    # all students: sheet Math / EBRW (block "Corporation Total")
    a <- rc_excel_at(f, s, "Corp ID")
    a <- a[grepl("^[0-9]{4}$", a[["Corp ID"]]), ]
    out <- rbind(out, rc_long("IN", row$sy_end, st_id = a[["Corp ID"]], name = a[["Corp Name"]], subject = subj, sg = "all",
                              n = rc_count(rc_col(a, paste(s, "Total Tested"), f)),
                              p = rc_in_share(a, 3:7, s, f)))
    d <- rc_excel_at(f, paste(s, "Demographics"), "Corp ID")
    above <- attr(d, "above")
    block <- zoo::na.locf(ifelse(is.na(above) | above == "", NA, above), na.rm = FALSE)
    d <- d[grepl("^[0-9]{4}$", d[["Corp ID"]]), ]
    for (sg in c("bl", "hi", "wh")) {
      lab <- c(bl = "Black", hi = "Hispanic", wh = "White")[[sg]]
      cols <- which(block == lab)
      if (length(cols) != 5L) stop(basename(f), ": expected five columns under group ", lab)
      out <- rbind(out, rc_long("IN", row$sy_end, st_id = d[["Corp ID"]], name = d[["Corp Name"]], subject = subj, sg = sg,
                                n = rc_count(d[[cols[4]]]), p = rc_in_share(d, cols, s, f)))
    }
  }
  out
}

# Indiana: At Benchmark over Total Tested where both are printed, else Benchmark % (a proportion).
rc_in_share <- function(d, cols, s, f) {
  nm <- names(d)[cols]
  want <- paste(s, c("Below Benchmark", "Approaching Benchmark", "At Benchmark", "Total Tested", "Benchmark %"))
  if (!identical(nm, want)) stop(basename(f), ": unexpected block columns ", paste(nm, collapse = " | "))
  n <- rc_count(d[[cols[4]]]); cnt <- rc_count(d[[cols[3]]])
  p <- rc_pct(d[[cols[5]]], scale = 100)
  by_cnt <- !is.na(cnt) & !is.na(n) & n > 0
  p$lo[by_cnt] <- p$hi[by_cnt] <- round(100 * cnt[by_cnt] / n[by_cnt], 6)
  p
}

rc_load_ks <- function(row) {
  f <- rc_files(row)[1]
  d <- rc_excel(f, as.character(row$sy_end))
  if (row$sy_end == 2022) {
    keep <- d[["Bldg. No."]] == "0" & grepl("^D0", d[["Org. No."]])
    grp <- d$Group; name <- sub("^D0[0-9]+ - ", "", d[["Organization/Building/State Name"]])
  } else {
    keep <- d$Building == "*** District Totals ***"
    grp <- d[["Student Subgroup"]]; name <- d$Organization
  }
  keep <- keep & d$Grade == "10th Grade" & d$Subject %in% c("Math", "ELA")
  rc_need(keep, "district 10th Grade rows", d$Grade, f)
  sg <- rc_sg(grp, c(all = "All Students", bl = "African-American Students", hi = "Hispanic", wh = "White"))
  keep <- keep & !is.na(sg)
  d <- d[keep, ]
  part <- NA_character_
  if ("Pct. Not Tested" %in% names(d)) {
    nt <- rc_pct(d[["Pct. Not Tested"]])$lo
    part <- ifelse(is.na(nt), NA, format(round(100 - nt, 6), trim = TRUE))
  }
  rc_long("KS", row$sy_end, st_id = d[["Org. No."]], name = name[keep],
          subject = ifelse(d$Subject == "Math", "math", "rla"), sg = sg[keep],
          p = rc_pct_sum(d[["Pct. Level 3"]], d[["Pct. Level 4"]]), part = part)
}

# A sheet with two header rows, a block label row (filled rightwards) above a measure row: the
# column names are "<block> | <measure>" ("<measure>" alone left of the first block).
rc_excel_two_rows <- function(path, sheet, block_row) {
  raw <- rc_excel(path, sheet, header_row = 0)
  top <- unlist(raw[block_row, ]); top[is.na(top)] <- ""
  for (j in seq_along(top)[-1]) if (top[j] == "" && top[j - 1] != "" && j > 1) top[j] <- top[j - 1]
  meas <- unlist(raw[block_row + 1, ]); meas[is.na(meas)] <- ""
  nm <- ifelse(meas == "", top, ifelse(top == "" | top == meas, meas, paste(top, "|", meas)))
  d <- raw[-seq_len(block_row + 1), , drop = FALSE]
  names(d) <- trimws(gsub("\\s+", " ", nm))
  d
}

rc_load_la <- function(row) {
  f <- rc_files(row)[1]
  raw <- rc_excel(f, "LEAP HS", header_row = 0)
  h <- which(raw[[1]] == "Summary Level")[1]
  d <- raw[-seq_len(h + 1), ]
  top <- unlist(raw[h, ]); meas <- unlist(raw[h + 1, ])
  top[is.na(top)] <- ""; meas[is.na(meas)] <- ""
  for (j in seq_along(top)[-1]) if (top[j] == "" && meas[j] != "") top[j] <- top[j - 1]
  names(d) <- ifelse(meas == "", top, paste(top, "|", meas))
  d <- d[d[["Summary Level"]] == "School System", ]
  rc_need(nrow(d) > 0, "School System rows", raw[[1]], f)
  sg <- rc_sg(d$Subgroup, c(all = "Total Population", bl = "Black or African American", hi = "Hispanic/Latino", wh = "White"))
  d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
  out <- NULL
  for (subj in c("math", "rla")) {
    t <- if (subj == "math") "Algebra I" else "English II"
    pr <- paste(t, "| % Participation Rate")
    out <- rbind(out, rc_long("LA", row$sy_end, st_id = d[["School System Code"]], name = d[["School System Name"]],
                              subject = subj, sg = sg,
                              p = rc_pct_sum(rc_col(d, paste(t, "| % Advanced"), f), rc_col(d, paste(t, "| % Mastery"), f)),
                              part = if (pr %in% names(d)) d[[pr]] else NA_character_))
  }
  out
}

rc_load_mn <- function(row) {
  out <- NULL
  files <- rc_files(row)
  for (i in seq_along(files)) {
    f <- files[i]; subj <- c("math", "rla")[i]
    d <- rc_excel(f, "District")
    grade <- if (subj == "math") "11" else "10"
    cat_race <- if (row$sy_end == 2022) "Federal Race/Ethnicity" else "State Race/Ethnicity"
    keep <- d$Grade == grade & d[["Group Category"]] %in% c("All Categories", cat_race)
    rc_need(keep, paste("grade", grade, "rows"), d$Grade, f)
    d <- d[keep, ]
    sg <- rc_sg(d[["Student Group"]], c(all = "All students", bl = "Black or African American students",
                                        hi = "Hispanic or Latino students", wh = "White students"))
    d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
    sup <- d[["Filter All"]] == "Y"
    n <- rc_count(d[["Total Tested"]]); n[sup] <- NA
    p <- rc_pct(ifelse(sup, "", d[["Percent Proficient"]]), scale = 100)
    cnt <- rc_count(d[["Count Level M"]]) + rc_count(d[["Count Level E"]])
    by_cnt <- !sup & !is.na(cnt) & !is.na(n) & n > 0             # the printed share is rounded to 0.0001
    p$lo[by_cnt] <- p$hi[by_cnt] <- round(100 * cnt[by_cnt] / n[by_cnt], 6)
    out <- rbind(out, rc_long("MN", row$sy_end,
                              st_id = sprintf("%02d%04d", as.integer(d[["District Type"]]), as.integer(d[["District Number"]])),
                              name = d[["District Name"]], subject = subj, sg = sg, n = n, p = p))
  }
  out
}

rc_load_mo <- function(row) {
  f <- rc_files(row)[1]
  d <- rc_excel(f, "Sheet1")
  keep <- d$SUMMARY_LEVEL == "District" & d$GRADE_LEVEL %in% c("A1", "E2") & d$CATEGORY %in% c("Total", "Race/Ethnicity")
  rc_need(keep, "district A1/E2 rows", d$GRADE_LEVEL, f)
  d <- d[keep, ]
  sg <- rc_sg(d$TYPE, c(all = "Total", bl = "Black (not Hispanic)", hi = "Hispanic", wh = "White (not Hispanic)"))
  d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
  n <- rc_count(d$REPORTABLE)
  p <- rc_pct_sum(d$PROFICIENT_PCT, d$ADVANCED_PCT)
  cnt <- rc_count(d$PROFICIENT) + rc_count(d$ADVANCED)
  by_cnt <- !is.na(cnt) & !is.na(n) & n > 0
  p$lo[by_cnt] <- p$hi[by_cnt] <- round(100 * cnt[by_cnt] / n[by_cnt], 6)
  # printed rate of students with no level determined (NON-PARTICIPANT(LND)PCT in 2022,
  # LEVEL_NOT_DETERMINED_PCT later)
  lnd <- rc_pct(d[[grep("^(NON-PARTICIPANT.*|LEVEL_NOT_DETERMINED_)PCT$", names(d))]])$lo
  rc_long("MO", row$sy_end, st_id = sprintf("%06d", as.integer(d$COUNTY_DISTRICT)), name = d$DISTRICT_NAME,
          subject = ifelse(d$GRADE_LEVEL == "A1", "math", "rla"), sg = sg, n = n, p = p,
          part = ifelse(is.na(lnd), NA, format(round(100 - lnd, 6), trim = TRUE)))
}

rc_load_nc <- function(row) {
  f <- rc_files(row)[1]
  txt <- rc_unzip(f, "_Data\\.txt$")
  d <- rc_fread(txt, sep = "\t", quote = "")
  unlink(dirname(txt), recursive = TRUE)
  keep <- grepl("^[0-9]{3}LEA$", d$school_code) & d$subject %in% c("M1", "E2") & d$type == "ALL" & d$grade == "EOC"
  rc_need(keep, "LEA EOC M1/E2 rows", paste(d$grade, d$type), f)
  d <- d[keep, ]
  sg <- rc_sg(d$subgroup, c(all = "ALL", bl = "BLCK", hi = "HISP", wh = "WHTE"))
  d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
  rc_long("NC", row$sy_end, st_id = substr(d$school_code, 1, 3), name = d$name,
          subject = ifelse(d$subject == "M1", "math", "rla"), sg = sg, n = rc_count(d$num_tested), p = rc_pct(d$pct_glp))
}

rc_load_nd <- function(row) {
  f <- rc_files(row)[1]
  x <- readLines(f, warn = FALSE, encoding = "UTF-8")
  h <- grep("AcademicYear,InstitutionName,", x, fixed = TRUE)[1]   # 2022-2024: on the last line of an HTML stub
  if (is.na(h)) stop(basename(f), ": no AcademicYear header row")
  x[h] <- sub("^.*AcademicYear,", "AcademicYear,", x[h])
  body <- x[-seq_len(h)]
  d <- rc_fread(text = c(x[h], body[grepl("^[0-9]{4}-[0-9]{4},", body)]))   # the stub's closing HTML tags are dropped
  keep <- grepl("^[0-9]{5}$", d$InstitutionID) & d$Grade == "10" & d$Subject %in% c("Math", "Reading") &
    d$AssessmentType == "Comp" & d$Accomodations == "All"
  rc_need(keep, "district grade 10 Comp rows", d$Grade, f)
  d <- d[keep, ]
  sg <- rc_sg(d$Subgroup, c(all = "All", bl = "Black", hi = "Hispanic", wh = "White"))
  d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
  num <- function(v) { v <- suppressWarnings(as.numeric(v)); v }
  # author decision 2026-09-16: the summed printed range of Proficient and Advanced (proportions)
  lo <- 100 * (num(d$ProficientRangeLow) + num(d$AdvancedRangeLow))
  hi <- 100 * (num(d$ProficientRangeHigh) + num(d$AdvancedRangeHigh))
  rc_long("ND", row$sy_end, st_id = d$InstitutionID, name = d$InstitutionName,
          subject = ifelse(d$Subject == "Math", "math", "rla"), sg = sg,
          p = data.frame(lo = round(pmin(lo, 100), 6), hi = round(pmin(hi, 100), 6)))
}

rc_load_ne <- function(row) {
  out <- NULL
  files <- rc_files(row)
  for (i in seq_along(files)) {
    f <- files[i]
    d <- rc_fread(f)
    names(d) <- toupper(gsub("_", "", sub(paste0("^", intToUtf8(0xFEFF)), "", names(d))))   # 2022-23 SUBGROUP_DESCRIPTION, 2024-25 SubgroupDescription
    d <- d[d$LEVEL == "DI", ]
    rc_need(nrow(d) > 0, "DI rows", "", f)
    sg <- rc_sg(d$SUBGROUPDESCRIPTION, c(all = "All Students", all = "All", bl = "Black or African American", hi = "Hispanic", wh = "White"))
    if ("SUBGROUPTYPE" %in% names(d)) sg[d$SUBGROUPTYPE != "ALL STUDENTS" & sg == "all"] <- NA
    d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
    y22 <- row$sy_end <= 2023
    mask <- function(v) ifelse(trimws(v) %in% c("-1", "-1.0000", "*", "NA"), "", v)
    scale <- if (y22) 100 else 1                                       # 2022-23 print proportions
    top <- if ("ACTBENCHMARKPERCENT" %in% names(d)) "ACTBENCHMARKPERCENT" else "ADVANCEDPERCENT"
    p <- rc_pct_sum(mask(d$ONTRACKPERCENT), mask(d[[top]]), scale = scale)
    dev <- rc_pct(mask(d$DEVELOPINGPERCENT), scale = scale)            # 100 minus Developing where a level is masked
    use_dev <- is.na(p$lo) & !is.na(dev$lo)
    p$lo[use_dev] <- 100 - dev$hi[use_dev]; p$hi[use_dev] <- 100 - dev$lo[use_dev]
    nt <- rc_pct(mask(d$NOTTESTEDPERCENT), scale = scale)$lo
    # NDE masks counts under 10: a masked tested count is a band [0, 9], below the floor.
    masked_n <- mask(d$TESTEDCOUNT) == "" & !trimws(d$TESTEDCOUNT) %in% c("NA", "")
    out <- rbind(out, rc_long("NE", row$sy_end, st_id = paste0(d$COUNTY, d$DISTRICT, "000"), name = d$NAME,
                              subject = c("math", "rla")[i], sg = sg, n = rc_count(mask(d$TESTEDCOUNT)), p = p,
                              n_band_lo = ifelse(masked_n, 0, NA),
                              part = ifelse(is.na(nt), NA, format(round(100 - nt, 6), trim = TRUE))))
  }
  out
}

rc_load_nh <- function(row) {
  f <- rc_files(row)[1]
  d <- rc_fread(f)
  keep <- d[["Level of Data"]] == "District Level" & d$DenominatorType == "Regular" & d$Grade == "11" &
    d$Subject %in% c("mat", "rea")
  rc_need(keep, "District Level grade 11 rows", d$Grade, f)
  d <- d[keep, ]
  sg <- rc_sg(trimws(d$Subgroup), c(all = "All students", bl = "Black", hi = "Hispanic", wh = "White"))
  d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
  # author decision 2026-09-16: the banded count passes the floor on its lower bound
  rc_long("NH", row$sy_end, st_id = NA_character_, name = d$District,
          subject = ifelse(d$Subject == "mat", "math", "rla"), sg = sg,
          n_band_lo = rc_count_band_lo(d[["Total FAY Students"]]), p = rc_pct(d[["Above prof% (lvl 3&4)"]]),
          part = d[["Participate%"]])
}

rc_load_nj <- function(row) {
  out <- NULL
  files <- rc_files(row)
  for (i in seq_along(files)) {
    f <- files[i]
    d <- rc_excel(f, c("ALG01", "ELA09")[i], header_row = 3)
    keep <- d[["School Name"]] == "District Total" & d$Subgroup %in% c("Total", "Race/Ethnicity")
    rc_need(keep, "District Total rows", d[["School Name"]], f)
    d <- d[keep, ]
    sg <- rc_sg(d[["Subgroup Type"]], c(all = "All Students", bl = "African American", bl = "Black or African American",
                                        hi = "Hispanic", wh = "White"))
    d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
    out <- rbind(out, rc_long("NJ", row$sy_end, st_id = paste0(d[["County Code"]], d[["District Code"]]),
                              name = d[["District Name"]], subject = c("math", "rla")[i], sg = sg,
                              n = rc_count(d[["Valid Scores"]]), p = rc_pct_sum(d[["L4 Percent"]], d[["L5 Percent"]])))
  }
  out
}

rc_load_nm <- function(row) {
  out <- NULL
  files <- rc_files(row)
  for (i in seq_along(files)) {
    f <- files[i]
    d <- rc_fread(f)
    keep <- d$Level == "District" & d$Grade == "11" & d$Test == "SAT"
    rc_need(keep, "District grade 11 SAT rows", paste(d$Grade, d$Test), f)
    d <- d[keep, ]
    sg <- rc_sg(d$Demographic, c(all = "All Students", bl = "Black", hi = "Hispanic", wh = "White"))
    d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
    n <- rc_count(d$StudentTotal_Masked); cnt <- rc_count(d$ProficientN_Masked)
    p <- rc_pct(d$ProficiencyRate_Masked)
    by_cnt <- !is.na(cnt) & !is.na(n) & n > 0
    p$lo[by_cnt] <- p$hi[by_cnt] <- round(100 * cnt[by_cnt] / n[by_cnt], 6)
    out <- rbind(out, rc_long("NM", row$sy_end, st_id = sprintf("%03d", as.integer(d$DistrictCode)), name = d$DistrictName,
                              subject = c("math", "rla")[i], sg = sg, n = n, p = p))
  }
  out
}

rc_load_nv <- function(row) {
  out <- NULL
  files <- rc_files(row)
  for (i in seq_along(files)) {
    f <- files[i]
    x <- readLines(f, warn = FALSE, encoding = "UTF-8")
    h <- grep('^"?Organization Code', x)[1]
    d <- rc_fread(text = x[h:length(x)])
    d <- d[grepl("^[0-9]{2}$", d[["Organization Code"]]) & d[["Organization Code"]] != "00", ]
    # the first row of each organization is its all-students row, with the name in Group
    first <- !duplicated(d[["Organization Code"]])
    name <- d$Group[first][cumsum(first)]
    sg <- ifelse(first, "all", rc_sg(d$Group, c(bl = "Black", hi = "Hispanic", wh = "White")))
    k <- !is.na(sg)
    s <- if (i == 1) "Mathematics" else "ELA"
    col <- function(m) rc_col(d, paste(s, "-", m), f)[k]
    part <- col("% Tested")
    out <- rbind(out, rc_long("NV", row$sy_end, st_id = d[["Organization Code"]][k], name = name[k],
                              subject = c("math", "rla")[i], sg = sg[k], n = rc_count(col("Number Tested")),
                              p = rc_pct(col("% Proficient")), part = part))
  }
  out
}

rc_load_oh <- function(row) {
  f <- rc_files(row)[1]
  d <- rc_excel(f, "RACE")
  sg <- rc_sg(d[["Student Group"]], c(bl = "BLACK, NON-HISPANIC", hi = "HISPANIC", wh = "WHITE, NON-HISPANIC"))
  rc_need(!is.na(sg), "race rows", d[["Student Group"]], f)
  d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
  pc <- function(t) grep(paste0("^High School ", t, " (20[0-9]{2}-20[0-9]{2} )?Percent Proficient or above$"), names(d), value = TRUE)
  alg <- pc("Algebra I"); eng <- pc("English II")
  if (length(alg) != 1L || length(eng) != 1L) stop(basename(f), ": Algebra I / English II proficiency columns not found")
  nm <- grep("^District Name", names(d), value = TRUE)[1]
  rbind(rc_long("OH", row$sy_end, st_id = d[["District IRN"]], name = d[[nm]], subject = "math", sg = sg, p = rc_pct(d[[alg]])),
        rc_long("OH", row$sy_end, st_id = d[["District IRN"]], name = d[[nm]], subject = "rla", sg = sg, p = rc_pct(d[[eng]])))
}

rc_load_ri <- function(row) {
  out <- NULL
  files <- rc_files(row)
  for (i in seq_along(files)) {
    f <- files[i]
    d <- rc_fread(f, sep = "\t")
    keep <- d$School == "All Schools" & d$District != "Statewide" & d$Grade == "Grade: 11"
    rc_need(keep, "district grade 11 rows", d$Grade, f)
    d <- d[keep, ]
    sg <- rc_sg(d$Group, c(bl = "Black or African American", hi = "Hispanic or Latino", wh = "White"))
    d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
    out <- rbind(out, rc_long("RI", row$sy_end, st_id = NA_character_, name = d$District, subject = c("math", "rla")[i],
                              sg = sg, n = rc_count(d$Number_of_Students_Tested),
                              p = rc_pct(d$Percent_Meeting_or_Exceeding_Expectations), part = d$Percent_of_Students_Tested))
  }
  out
}

rc_load_sd <- function(row) {
  f <- rc_files(row)[1]
  con <- file(f, encoding = "UTF-16"); x <- readLines(con, warn = FALSE); close(con)
  top <- unlist(utils::read.csv(text = x[1], header = FALSE, colClasses = "character"))
  d <- utils::read.csv(text = x[-(1:2)], header = FALSE, colClasses = "character", na.strings = character())
  meas <- unlist(utils::read.csv(text = x[2], header = FALSE, colClasses = "character"))
  keep <- d[[5]] == "All Schools" & d[[2]] != "All Districts" & d[[7]] == "11" & d[[9]] == "Regular and Alternate" &
    d[[10]] == "With and Without Accommodations" & d[[8]] %in% c("Mathematics", "English Language Arts")
  rc_need(keep, "district grade 11 rows", d[[7]], f)
  d <- d[keep, ]
  groups <- c(all = "All Students", bl = "Black/African American", hi = "Hispanic/Latino", wh = "White/Caucasian")
  out <- NULL
  for (sg in names(groups)) {
    blk <- which(top == groups[[sg]])
    m <- sub("^All Students - ", "", meas[blk])                     # every block's metric labels read "All Students - ..."
    col <- function(lab) { k <- blk[m == lab]; if (length(k) != 1L) stop(basename(f), ": no '", lab, "' in block ", groups[[sg]]); d[[k]] }
    out <- rbind(out, rc_long("SD", row$sy_end, st_id = d[[3]], name = d[[2]],
                              subject = ifelse(d[[8]] == "Mathematics", "math", "rla"), sg = sg,
                              n = rc_count(col("Tested - Number of Students")),
                              p = rc_pct(col("Level 3 or Level 4 - Percentage")), part = col("Tested - Percentage")))
  }
  out
}

# Alabama's .xlsb workbooks: readxlsb reads a whole sheet of this size in hours, and a range of
# 2,000 rows in about a second at any offset, so the sheet is read in 2,000-row ranges from the
# row after the header until a range comes back empty, keeping the rows keep(d) selects. The
# number of columns is the header row's (the ELA workbooks carry a First Year EL Exemption column
# that some mathematics workbooks do not).
rc_xlsb_rows <- function(path, sheet, header_row, keep, chunk = 2000L) {
  hdr <- unlist(readxlsb::read_xlsb(path, sheet = sheet, range = sprintf("R%dC1:R%dC40", header_row, header_row),
                                    col_names = FALSE, col_types = "string"))
  hdr[is.na(hdr)] <- ""
  ncol <- max(which(nzchar(trimws(hdr))))
  hdr <- hdr[seq_len(ncol)]
  rng <- function(r1, r2) sprintf("R%dC1:R%dC%d", r1, r2, ncol)
  out <- list(); r <- header_row + 1L
  repeat {
    d <- tryCatch(readxlsb::read_xlsb(path, sheet = sheet, range = rng(r, r + chunk - 1L), col_names = FALSE,
                                      col_types = "string"),
                  error = function(e) if (grepl("No data found", conditionMessage(e))) NULL else stop(e))  # past the last row
    if (is.null(d) || !nrow(d) || all(is.na(d[[1]]) | d[[1]] == "")) break
    d <- as.data.frame(d, stringsAsFactors = FALSE)
    names(d) <- trimws(hdr)
    out[[length(out) + 1L]] <- d[which(keep(d) %in% TRUE), , drop = FALSE]       # NA (blank cells) is not kept
    r <- r + chunk
  }
  do.call(rbind, out)
}

rc_load_al <- function(row) {
  out <- NULL
  files <- rc_files(row)
  sheets <- if (row$sy_end <= 2023) "Participation and Proficiency" else c("County", "City", "Charter")
  grade <- if (row$sy_end == 2022) "High School" else "11"
  for (i in seq_along(files)) {
    f <- files[i]
    keep <- function(d) d[["School Code"]] == "0000" & d[["System Code"]] != "000" & d$Grade == grade &
      d$Gender == "All Gender" & d$SubPopulation == "All SubPopulation" &
      ((d$Ethnicity == "All Ethnicity" & d$Race %in% c("All Race", "Black or African American", "White")) |
         (d$Race == "All Race" & d$Ethnicity == "Hispanic/Latino"))
    d <- do.call(rbind, lapply(sheets, function(s) {
      if (grepl("\\.xlsb$", f)) rc_xlsb_rows(f, s, header_row = 5L, keep = keep)
      else { x <- rc_excel(f, s, header_row = 6); x[which(keep(x) %in% TRUE), ] }
    }))
    rc_need(nrow(d) > 0, paste("district grade", grade, "rows"), "", f)
    sg <- ifelse(d$Ethnicity == "Hispanic/Latino", "hi",
                 c(`All Race` = "all", `Black or African American` = "bl", White = "wh")[d$Race])
    out <- rbind(out, rc_long("AL", row$sy_end, st_id = d[["System Code"]], name = d[["System Name"]],
                              subject = c("math", "rla")[i], sg = sg, p = rc_pct(d[["Percent Proficient"]]),
                              part = d[["Participation Rate"]]))
  }
  out
}

rc_load_or <- function(row) {
  out <- NULL
  files <- rc_files(row)
  for (i in seq_along(files)) {
    f <- files[i]
    d <- rc_excel(f, readxl::excel_sheets(f)[1])
    keep <- d[["Grade Level"]] == "Grade HS (11)"
    rc_need(keep, "Grade HS (11) rows", d[["Grade Level"]], f)
    d <- d[keep, ]
    sg <- rc_sg(d[["Student Group"]], c(all = "Total Population (All Students)", bl = "Black/African American",
                                        hi = "Hispanic/Latino", wh = "White"))
    d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
    n <- rc_count(rc_col(d, "Number of Participants", f)); cnt <- rc_count(rc_col(d, "Number Proficient", f))
    p <- rc_pct(d[[intersect(c("Percent Proficient (Level 3 or 4)", "Percent Proficient"), names(d))[1]]])   # renamed from 2023-24
    by_cnt <- !is.na(cnt) & !is.na(n) & n > 0
    p$lo[by_cnt] <- p$hi[by_cnt] <- round(100 * cnt[by_cnt] / n[by_cnt], 6)
    subj <- if (grepl("_MATH_", basename(f))) "math" else "rla"
    out <- rbind(out, rc_long("OR", row$sy_end, st_id = sprintf("%014d", as.numeric(d[["District ID"]])),
                              name = d$District, subject = subj, sg = sg, n = n, p = p, part = d[["Participation Rate"]]))
  }
  out
}

rc_load_pa <- function(row) {
  f <- rc_files(row)[1]
  d <- rc_excel(f, readxl::excel_sheets(f)[1], header_row = if (row$sy_end == 2022) 5 else 4)
  keep <- d$Grade == "11" & d$Subject %in% c("Algebra I", "Literature")
  rc_need(keep, "grade 11 Algebra I / Literature rows", d$Subject, f)
  d <- d[keep, ]
  sg <- rc_sg(d$Group, c(all = "All Students", bl = "Black or African American (not Hispanic)",
                         hi = "Hispanic (any race)", wh = "White (not Hispanic)"))
  d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
  pc <- intersect(c("Percent Proficient and above", "% Advanced/Proficient"), names(d))
  rc_long("PA", row$sy_end, st_id = d$AUN, name = d[["District Name"]],
          subject = ifelse(d$Subject == "Algebra I", "math", "rla"), sg = sg,
          n = rc_count(d[["Number Scored"]]), p = rc_pct(d[[pc]]))
}

rc_load_sc <- function(row) {
  f <- rc_files(row)[1]
  sh <- grep("_DISTRICT$", readxl::excel_sheets(f), value = TRUE)
  d <- rc_excel(f, sh)
  keep <- d$testid %in% c("1", "3")
  d <- d[keep, ]
  sg <- rc_sg(d$demoid, c(all = "1", bl = "7", hi = "4", wh = "9"))
  d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
  rc_long("SC", row$sy_end, st_id = d$distcode, name = d$districtname, subject = ifelse(d$testid == "1", "math", "rla"),
          sg = sg, n = rc_count(d$numbertested), p = rc_pct_sum(d$pcta, d$pctb, d$pctc))   # C or better
}

rc_load_tn <- function(row) {
  f <- rc_files(row)[1]
  d <- rc_excel(f, readxl::excel_sheets(f)[1])
  keep <- d$test == "EOC" & d$subject %in% c("Algebra I", "English II") & d$grade == "All Grades"
  rc_need(keep, "EOC All Grades rows", d$grade, f)
  d <- d[keep, ]
  sg <- rc_sg(d$student_group, c(all = "All Students", bl = "Black or African American", hi = "Hispanic", wh = "White"))
  d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
  small <- trimws(d$valid_tests) %in% c("*", "<10 students")          # TDOE: fewer than 10 students
  rc_long("TN", row$sy_end, st_id = sprintf("%05d", as.integer(d$system)), name = d$system_name,
          subject = ifelse(d$subject == "Algebra I", "math", "rla"), sg = sg,
          n = rc_count(d$valid_tests), n_band_lo = ifelse(small, 0, NA),
          p = rc_pct(d$pct_met_exceeded), part = d$participation_rate)
}

rc_load_tx <- function(row) {
  out <- NULL
  files <- rc_files(row)
  for (i in seq_along(files)) {
    f <- files[i]
    x <- readLines(f, warn = FALSE, encoding = "UTF-8")
    if (!startsWith(x[1], "DISTRICT")) x <- x[-1]                        # 2024-25: a labelled header row above the codes
    d <- rc_fread(text = x)
    d$DISTRICT <- sub("^'", "", d$DISTRICT)
    re <- "^DD([ABHW])00A(..)1([0S23])[0-9]{2}([DN])$"
    codes <- grep(re, names(d), value = TRUE)
    test <- unique(sub(re, "\\2", codes))
    if (length(test) != 1L) stop(basename(f), ": expected one test code, found ", paste(test, collapse = " "))
    num <- function(v) { v <- suppressWarnings(as.numeric(v)); v[!is.na(v) & v < 0] <- NA; v }  # -1, -3 masked; "." no base
    for (g in c(all = "A", bl = "B", hi = "H", wh = "W")) {
      den <- grep(paste0("^DD", g, "00A", test, "10[0-9]{2}D$"), names(d), value = TRUE)
      met <- grep(paste0("^DD", g, "00A", test, "12[0-9]{2}N$"), names(d), value = TRUE)
      if (length(den) != 1L || length(met) != 1L) stop(basename(f), ": group ", g, " columns not found")
      n <- num(d[[den]]); cnt <- num(d[[met]])
      p <- ifelse(!is.na(n) & n > 0 & !is.na(cnt), round(100 * cnt / n, 6), NA)
      sg <- names(which(c(all = "A", bl = "B", hi = "H", wh = "W") == g))
      out <- rbind(out, rc_long("TX", row$sy_end, st_id = d$DISTRICT, name = if ("DISTNAME" %in% names(d)) d$DISTNAME else "",
                                subject = c("math", "rla")[i], sg = sg, n = n, p = data.frame(lo = p, hi = p)))
    }
  }
  out
}

rc_load_ut <- function(row) {
  f <- rc_files(row)[1]
  d <- rc_excel(f, "LEA by Subject")
  keep <- d[["Assessment Type"]] == "Utah Aspire Plus (Grades 9-10)" & d[["Subject Area"]] %in% c("Mathematics", "English Language Arts")
  rc_need(keep, "Utah Aspire Plus rows", d[["Assessment Type"]], f)
  d <- d[keep, ]
  groups <- c(all = "All Students", bl = "AfAm/Black", hi = "Hispanic/Latino", wh = "White")
  out <- NULL
  for (sg in names(groups)) {
    v <- trimws(rc_col(d, groups[[sg]], f))
    # exact values print as proportions, bands as percentages ("20-29%", "<20%", ">=80%")
    p <- rc_pct(ifelse(grepl("%", v), v, ""))
    ex <- rc_pct(ifelse(grepl("%", v), "", v), scale = 100)
    p$lo[!is.na(ex$lo)] <- ex$lo[!is.na(ex$lo)]; p$hi[!is.na(ex$hi)] <- ex$hi[!is.na(ex$hi)]
    out <- rbind(out, rc_long("UT", row$sy_end, st_id = NA_character_, name = d[["LEA Name"]],
                              subject = ifelse(d[["Subject Area"]] == "Mathematics", "math", "rla"), sg = sg, p = p,
                              n_band_lo = ifelse(tolower(v) == "n<10", 0, NA)))   # USBE: groups under 10
  }
  out
}

rc_load_va <- function(row) {
  f <- rc_files(row)[1]
  d <- rc_excel(f, "Division by Student Group")
  yr <- sprintf("%d-%d", row$sy_end - 1L, row$sy_end)
  pc <- grep(paste0("^", yr, " Pct Passed\\s+\\(Adv & Proficien"), names(d), value = TRUE)   # 2024-2025 prints two spaces
  if (length(pc) != 1L) stop(basename(f), ": no pass-rate column for ", yr)
  keep <- d$Level == "DIV" & d[["Subject or Test"]] %in% c("Algebra I", "EOC Reading")
  rc_need(keep, "DIV Algebra I / EOC Reading rows", d[["Subject or Test"]], f)
  d <- d[keep, ]
  sg <- rc_sg(d[["Student Group"]], c(all = "All Students", bl = "Black", hi = "Hispanic", wh = "White"))
  d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
  rc_long("VA", row$sy_end, st_id = sprintf("%03d", as.integer(d[["Division Number"]])), name = d[["Division Name"]],
          subject = ifelse(d[["Subject or Test"]] == "Algebra I", "math", "rla"), sg = sg, p = rc_pct(d[[pc]]))
}

rc_load_vt <- function(row) {
  f <- rc_files(row)[1]
  if (grepl("\\.zip$", f)) {
    x <- rc_unzip(f, "Math_ELA_General_Assessment_[0-9]{4}\\.xlsx$")
    d <- rc_excel(x, 1); unlink(dirname(dirname(x)), recursive = TRUE)
    val <- "SupervisoryUnionValue"
  } else {
    d <- rc_fread(f); val <- "Value_W_SUSD"
  }
  tests <- c(math = if (row$sy_end == 2022) "SB Math Grade 09" else "Math Grade 09",
             rla = if (row$sy_end == 2022) "SB English Language Arts Grade 09" else "English Language Arts Grade 09")
  keep <- grepl("^SU", d$SchoolIdentifier) & d$TestName %in% tests &
    d$IndicatorLabel %in% c("Number of Students Tested", "Total Proficient and Above")
  rc_need(keep, "SU grade 9 rows", d$TestName, f)
  d <- d[keep, ]
  sg <- ifelse(d$AssessGroup %in% c("All Students", "All"), "all",
               ifelse(d$AssessGroup == "Race/Ethnicity", rc_sg(d$AssessLabel, c(bl = "Black", hi = "Hispanic", wh = "White")), NA))
  d$sg <- sg; d <- d[!is.na(d$sg), ]
  d$subject <- names(tests)[match(d$TestName, tests)]
  key <- c("SchoolIdentifier", "OrgName", "subject", "sg")
  n <- d[d$IndicatorLabel == "Number of Students Tested", c(key, val)]
  p <- d[d$IndicatorLabel == "Total Proficient and Above", c(key, val)]
  m <- merge(n, p, by = key, all = TRUE, suffixes = c("_n", "_p"))
  pv <- m[[paste0(val, "_p")]]
  rc_long("VT", row$sy_end, st_id = m$SchoolIdentifier, name = m$OrgName, subject = m$subject, sg = m$sg,
          n = rc_count(m[[paste0(val, "_n")]]), p = rc_pct(pv, scale = if (all(rc_pct(pv)$hi <= 1, na.rm = TRUE)) 100 else 1))
}

rc_load_wa <- function(row) {
  f <- rc_files(row)[1]
  d <- rc_fread(f, select = c("OrganizationLevel", "DistrictCode", "DistrictName", "StudentGroupType", "StudentGroup",
                              "GradeLevel", "TestAdministration", "TestSubject", "DAT",
                              "Count of Students Tested (including previously passed)",
                              "Count Consistent Grade Level Knowledge And Above (including previously passed)",
                              "Percent Consistent Grade Level Knowledge And Above (including previously passed)",
                              "Percent_Participation_IncludingPP"))
  keep <- d$OrganizationLevel == "District" & d$GradeLevel == "10" & d$TestAdministration == "SBAC" &
    d$TestSubject %in% c("Math", "ELA")
  rc_need(keep, "District grade 10 SBAC rows", d$GradeLevel, f)
  d <- d[keep, ]
  sg <- ifelse(d$StudentGroupType == "All", "all",
               ifelse(d$StudentGroupType == "Race", rc_sg(d$StudentGroup, c(bl = "Black/ African American",
                                                                           hi = "Hispanic/ Latino of any race(s)", wh = "White")), NA))
  d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
  ok <- d$DAT == "None"                                       # DAT: the suppression reason, None when reported
  n <- rc_count(d[["Count of Students Tested (including previously passed)"]]); n[!ok] <- NA
  cnt <- rc_count(d[["Count Consistent Grade Level Knowledge And Above (including previously passed)"]])
  p <- rc_pct(ifelse(ok, d[["Percent Consistent Grade Level Knowledge And Above (including previously passed)"]], ""), scale = 100)
  by_cnt <- ok & !is.na(cnt) & !is.na(n) & n > 0
  p$lo[by_cnt] <- p$hi[by_cnt] <- round(100 * cnt[by_cnt] / n[by_cnt], 6)
  part <- rc_pct(ifelse(ok, d$Percent_Participation_IncludingPP, ""), scale = 100)$lo
  rc_long("WA", row$sy_end, st_id = d$DistrictCode, name = d$DistrictName, subject = ifelse(d$TestSubject == "Math", "math", "rla"),
          sg = sg, n = n, p = p, n_band_lo = ifelse(d$DAT == "N<10", 0, NA),
          part = ifelse(is.na(part), NA, format(round(part, 6), trim = TRUE)))
}

rc_load_wi <- function(row) {
  f <- rc_files(row)[1]
  x <- rc_unzip(f, "act_statewide_certified_[0-9-]+\\.csv$")
  d <- rc_fread(x); unlink(dirname(x), recursive = TRUE)
  keep <- d$SCHOOL_NAME == "[Districtwide]" & d$TEST_GROUP == "ACT" & d$TEST_SUBJECT %in% c("Mathematics", "ELA") &
    d$GROUP_BY %in% c("All Students", "Race/Ethnicity")
  rc_need(keep, "Districtwide ACT rows", d$SCHOOL_NAME, f)
  d <- d[keep, ]
  d$sg <- ifelse(d$GROUP_BY == "All Students", "all", rc_sg(d$GROUP_BY_VALUE, c(bl = "Black", hi = "Hispanic", wh = "White")))
  d <- d[!is.na(d$sg), ]
  d$cnt <- rc_count(d$STUDENT_COUNT)
  key <- paste(d$DISTRICT_CODE, d$TEST_SUBJECT, d$sg, sep = "|")
  scored <- d$TEST_RESULT_CODE %in% c("1", "2", "3", "4")      # Not Benchmarked and No Test are not in the denominator
  prof <- d$TEST_RESULT_CODE %in% c("3", "4")
  s <- function(k) tapply(ifelse(k, d$cnt, 0), key, function(v) sum(v))   # NA if a counted row is suppressed
  first <- d[!duplicated(key), ]
  kf <- key[!duplicated(key)]
  n <- as.vector(s(scored)[kf]); cnt <- as.vector(s(prof)[kf])
  if (any(!(c("1", "2", "3", "4") %in% d$TEST_RESULT_CODE))) stop(basename(f), ": result codes 1-4 not all present")
  p <- ifelse(!is.na(n) & n > 0 & !is.na(cnt), round(100 * cnt / n, 6), NA)
  rc_long("WI", row$sy_end, st_id = first$DISTRICT_CODE, name = first$DISTRICT_NAME,
          subject = ifelse(first$TEST_SUBJECT == "Mathematics", "math", "rla"), sg = first$sg, n = n,
          p = data.frame(lo = p, hi = p))
}

rc_load_wy <- function(row) {
  out <- NULL
  files <- rc_files(row)
  for (i in seq_along(files)) {
    f <- files[i]
    d <- rc_fread(f)
    names(d) <- gsub(",", " ", sub(paste0("^", intToUtf8(0xFEFF)), "", names(d)))
    keep <- d[["Specific Grade"]] == "10"
    rc_need(keep, "grade 10 rows", d[["Specific Grade"]], f)
    d <- d[keep, ]
    sg <- rc_sg(d$Subgroup, c(all = "All Students", bl = "Race / Ethnicity: Black", hi = "Race / Ethnicity: Hispanic",
                              wh = "Race / Ethnicity: White"))
    d <- d[!is.na(sg), ]; sg <- sg[!is.na(sg)]
    # author decision 2026-09-16: the banded count passes the floor on its lower bound
    out <- rbind(out, rc_long("WY", row$sy_end, st_id = NA_character_, name = d[["District Name"]], subject = c("math", "rla")[i],
                              sg = sg, n_band_lo = rc_count_band_lo(d[["No. of Students Tested"]]),
                              p = rc_pct(d[["Percent Proficient & Advanced"]]), part = d[["Participation Rate"]]))
  }
  out
}

HS_RC_LOADERS <- list(AL = rc_load_al, OR = rc_load_or, PA = rc_load_pa, SC = rc_load_sc, TN = rc_load_tn,
                      TX = rc_load_tx, UT = rc_load_ut, VA = rc_load_va, VT = rc_load_vt, WA = rc_load_wa,
                      WI = rc_load_wi, WY = rc_load_wy,
                      AZ = rc_load_az, CA = rc_load_ca, CO = rc_load_co, CT = rc_load_ct, DC = rc_load_dc,
                      DE = rc_load_de, GA = rc_load_ga, ID = rc_load_id, IL = rc_load_il, IN = rc_load_in,
                      KS = rc_load_ks, KY = rc_load_ky, LA = rc_load_la, MA = rc_load_ma, MN = rc_load_mn,
                      MO = rc_load_mo, NC = rc_load_nc, ND = rc_load_nd, NE = rc_load_ne, NH = rc_load_nh,
                      NJ = rc_load_nj, NM = rc_load_nm, NV = rc_load_nv, NY = rc_load_ny, OH = rc_load_oh,
                      RI = rc_load_ri, SD = rc_load_sd)

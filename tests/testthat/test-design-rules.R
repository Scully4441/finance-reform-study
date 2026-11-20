withr::local_dir(ROOT)

test_that("step 1 accepts court and legislative events only", {
  root <- tempfile("evref"); dir.create(root)
  repo <- file.path(root, "finance-reform-study"); priv <- file.path(root, "finance-reform-study-private")
  dir.create(file.path(repo, "R"), recursive = TRUE); dir.create(priv)
  file.copy("R/01_build_event_table.R", file.path(repo, "R", "01_build_event_table.R"))
  hdr <- "state,event_year,event_type,source,notes"
  writeLines(c(hdr, "KS,2010,referendum,LRS,x"), file.path(priv, "lrs_events.csv"))
  writeLines(hdr, file.path(priv, "court_events_after_2011.csv"))
  writeLines(hdr, file.path(priv, "legislative_events_after_2011.csv"))
  writeLines("77", file.path(priv, "permutation_seed.txt"))
  withr::local_dir(repo)
  expect_error(capture.output(source("R/01_build_event_table.R")), "court or legislative")
})

test_that("the graduation rules window and the high school rules window follow the design", {
  expect_equal(GRAD_RULES_WINDOW, 2011:2021)
  expect_equal(HS_RULES_WINDOW, c(2010:2019, 2021:2024))
  expect_false(2025L %in% HS_RULES_WINDOW)
})

test_that("the F-33 release with more records is read", {
  d <- tempfile("f33"); dir.create(d)
  txt <- c('"STATE","NCESID","V33","TSTREV","TLOCREV"', '"01","0100001",100,500,300,', '"01","0100002",200,600,100,')
  writeLines(txt, file.path(d, "f33-fy2015.csv"))
  ch <- f33_choose(2015L, d)
  expect_equal(ch$choice, "text")
  expect_equal(ch$records_text, 2L)
  openxlsx::write.xlsx(data.frame(NCESID = c("0100001", "0100002", "0100003"), V33 = c("100", "200", "50"),
                                  TSTREV = c("500", "600", "20"), TLOCREV = c("300", "100", "10")), file.path(d, "f33-fy2015.xlsx"))
  ch2 <- f33_choose(2015L, d)
  expect_equal(ch2$choice, "spreadsheet")
  expect_equal(ch2$records_xlsx, 3L)
  r <- f33_revenue(2015L, d)
  expect_equal(nrow(r), 3L)
  expect_equal(attr(r, "sources")$choice, "spreadsheet")
  writeLines(c(txt, '"01","0100003",50,20,10,', '"01","0100004",60,20,10,'), file.path(d, "f33-fy2015.csv"))
  expect_equal(f33_choose(2015L, d)$choice, "text")
  expect_error(f33_choose(2016L, d), "no F-33 file")
})

test_that("end year 2019 is read from the copy that covers the 50 states and DC, ED's own first, else the copy covering the most", {
  d <- tempfile("edf"); dir.create(d)
  mk <- function(states) {
    fips <- STATE_FIPS[states]
    x <- expand.grid(leaid = paste0(fips, "00001"), CATEGORY = names(SUBGROUPS), stringsAsFactors = FALSE)
    data.frame(SCHOOL_YEAR = "2018-2019", LEAID = x$leaid, SUBJECT = "MTH", GRADE = "HS", CATEGORY = x$CATEGORY,
               NUMVALID = "40", PCTPROF = "50", stringsAsFactors = FALSE)
  }
  utils::write.csv(mk(names(STATE_FIPS)[1:40]), file.path(d, "ed-math-achievement.csv"), row.names = FALSE)
  utils::write.csv(mk(names(STATE_FIPS)), file.path(d, "arch-math-achievement.csv"), row.names = FALSE)
  cands <- c(ed = file.path(d, "ed-%s-%s.csv"), archive = file.path(d, "arch-%s-%s.csv"))
  a <- edfacts_2019_read("math", "achievement", candidates = cands)
  expect_equal(attr(a, "choice"), "archive")
  expect_equal(attr(a, "choice_log")$covers_all, c(FALSE, TRUE))
  utils::write.csv(mk(names(STATE_FIPS)), file.path(d, "ed-math-achievement.csv"), row.names = FALSE)
  expect_equal(attr(edfacts_2019_read("math", "achievement", candidates = cands), "choice"), "ed")
  utils::write.csv(mk(names(STATE_FIPS)[1:35]), file.path(d, "ed-math-achievement.csv"), row.names = FALSE)
  utils::write.csv(mk(setdiff(names(STATE_FIPS), "VT")), file.path(d, "arch-math-achievement.csv"), row.names = FALSE)
  b <- edfacts_2019_read("math", "achievement", candidates = cands)
  expect_equal(attr(b, "choice"), "archive")
  expect_equal(attr(b, "choice_log")$covers_all, c(FALSE, FALSE))
  utils::write.csv(mk(names(STATE_FIPS)[1:10]), file.path(d, "arch-math-achievement.csv"), row.names = FALSE)
  expect_equal(attr(edfacts_2019_read("math", "achievement", candidates = cands), "choice"), "ed")
  unlink(file.path(d, c("ed-math-achievement.csv", "arch-math-achievement.csv")))
  expect_error(edfacts_2019_read("math", "achievement", candidates = cands), "could be read")
  expect_equal(names(EDFACTS_2019_CANDIDATES), c("ed", "archive"))
})

test_that("SEDA release 2025.1 is read only when 2025.2 lacks end years 2009-2019", {
  d <- tempfile("seda"); dir.create(d)
  f2 <- file.path(d, "seda_admindist_long_cs_2025.2.csv"); f1 <- file.path(d, "seda_admindist_long_cs_2025.1.csv")
  writeLines("year", f2)
  expect_equal(as.character(seda_release(d, years_of = function(f) c(2009:2019, 2022:2025))), "2025.2")
  writeLines("x", f2); Sys.setFileTime(f2, Sys.time() + 5)
  expect_error(seda_release(d, years_of = function(f) 2022:2025), "2025.1 is not downloaded")
  writeLines("year", f1)
  r <- seda_release(d, years_of = function(f) 2015:2025)
  expect_equal(as.character(r), "2025.1")
  expect_match(attr(r, "reason"), "lacks end years 2009 2010")
  expect_equal(seda_long_file("2025.1"), "data/raw/seda/seda_admindist_long_cs_2025.1.csv")
  man <- utils::read.csv("data/manifest/download_manifest.csv", colClasses = "character")
  expect_true(all(c("seda/seda_admindist_long_cs_2025.1.csv", "seda/seda_codebook_admindist_2025.1.xlsx",
                    "seda/SEDA_documentation_v2025.1.pdf") %in% man$filename))
  expect_true(all(grepl("hm970gr1371", man$url[grepl("2025\\.1", man$filename)])))
})

test_that("the SEDA placebo MDE is not part of the run", {
  src <- readLines("R/13_run_all.R")
  expect_false(any(grepl("run_mde|mde_descriptive", src)))
})

test_that("the manifest lists both F-33 releases of fiscal year 2022 and the 2019 EDFacts copies", {
  man <- utils::read.csv("data/manifest/download_manifest.csv", colClasses = "character")
  f <- man$filename[man$dataset == "f33_school_finance" & man$sy_end == "2022"]
  expect_setequal(f, c("f33/f33-fy2022.csv", "f33/f33-fy2022.xlsx"))
  for (s in c("math", "rla")) for (k in c("achievement", "participation"))
    expect_true(all(sub("^data/raw/", "", sprintf(EDFACTS_2019_CANDIDATES, s, k)) %in% man$filename))
})

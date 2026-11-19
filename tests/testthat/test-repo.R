withr::local_dir(ROOT)

test_that("manifest, stage gate, reference tables and code", {
man <- utils::read.csv("data/manifest/download_manifest.csv", stringsAsFactors = FALSE, colClasses = "character",
                       na.strings = character(0))
expect_all(identical(names(man), c("dataset", "sy_end", "url", "filename", "sha256", "downloaded_utc", "state", "page_url",
                                  "status", "source", "notes")),
          all(nzchar(man$dataset)), all(nzchar(man$filename) | man$status == "unavailable"),
          !anyDuplicated(man[c("dataset", "sy_end", "filename")]),
          all(man$status %in% c("", "not_published", "unavailable")),
          all(!nzchar(man$sha256) | grepl("^[0-9a-f]{64}$", man$sha256)),
          all(nzchar(man$sha256) == nzchar(man$downloaded_utc)),
          all(!nzchar(man$sy_end) | grepl("^[0-9]{4}$", man$sy_end)),
          !any(grepl("deviations|recon|design_", man$notes)))

expect_all(read_stage() %in% 1:2)
a1 <- stage_allows(man$dataset, man$sy_end, 1L)
a2 <- stage_allows(man$dataset, man$sy_end, 2L)
y <- suppressWarnings(as.integer(man$sy_end))
allowed1 <- paste(man$dataset[a1], man$sy_end[a1])
expected1 <- c(paste(rep(c("edfacts_math_lea", "edfacts_rla_lea"), each = 4), 2010:2013),
               paste(c("edfacts_math_participation_lea", "edfacts_rla_participation_lea"), 2013),
               paste("edfacts_docs", 2011:2013), paste("ccd_lea_directory", 2010:2013),
               paste("ccd_membership", c(2007, 2007, 2007, 2008:2013)), "ccd_membership_layout 2007",
               paste("saipe_district", 2009:2012), paste("f33_school_finance", 2010:2013))
expect_all(all(a2), setequal(allowed1, expected1), length(allowed1) == length(expected1), length(allowed1) == 35L,
          all(!is.na(y[a1]) & y[a1] <= STAGE1_LAST_YEAR),
          !any(a1 & grepl("^(seda_|hs_reportcard_|edfacts_acgr|bls_cpi|ccd_school_characteristics)", man$dataset)),
          all(a1[grepl("^ccd_", man$dataset) & !is.na(y) & y >= 2007 & y <= 2013]),
          inherits(try(stage_allows("x", 2010L, 3L), silent = TRUE), "try-error"),
          identical(ach_window(1L), 2010:2013), identical(ach_window(2L), ACH_WINDOW))

seda_rows <- man[startsWith(man$dataset, "seda_"), ]
expect_all(nrow(seda_rows) == 3L, file.path("data/raw", seda_rows$filename[seda_rows$dataset == "seda_admindist_long_cs"]) == seda_long_file(),
          all(grepl("2025\\.2", seda_rows$filename)))

refs <- c("data/reference/cep_phase_in.csv", "data/reference/test_replacement.csv",
          "data/reference/hs_reportcard_harmonization.csv", "data/reference/hs_reportcard_leaid_crosswalk.csv")
expect_all(all(file.exists(refs)))
hz_raw <- utils::read.csv("data/reference/hs_reportcard_harmonization.csv", stringsAsFactors = FALSE, colClasses = "character",
                          na.strings = character(0))
expect_all(all(!nzchar(hz_raw$manifest_status)), all(!nzchar(hz_raw$notes)),
          !any(grepl("recon", hz_raw$min_group_source, fixed = TRUE)))

code <- c(list.files("R", pattern = "\\.R$", full.names = TRUE, recursive = TRUE),
          list.files("tests", pattern = "\\.R$", full.names = TRUE, recursive = TRUE))
for (f in code) {
  pd <- utils::getParseData(parse(f, keep.source = TRUE, encoding = "UTF-8"))
  if (any(pd$token == "COMMENT")) stop(f, " carries a comment")
}
steps <- list.files("R", pattern = "^[0-9]{2}[a-z]?_.*\\.R$")
expect_all(identical(sort(unique(substr(steps, 1, 2))), sprintf("%02d", 0:13)))
})

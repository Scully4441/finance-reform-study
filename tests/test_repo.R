man <- utils::read.csv("data/manifest/download_manifest.csv", stringsAsFactors = FALSE, colClasses = "character",
                       na.strings = character(0))
stopifnot(identical(names(man), c("dataset", "sy_end", "url", "filename", "sha256", "downloaded_utc", "state", "page_url",
                                  "status", "source", "notes")),
          all(nzchar(man$dataset)), all(nzchar(man$filename) | man$status == "unavailable"), !anyDuplicated(man[c("dataset", "sy_end", "filename")]),
          all(man$status %in% c("", "not_published", "unavailable")),
          all(!nzchar(man$sha256) | grepl("^[0-9a-f]{64}$", man$sha256)),
          all(nzchar(man$sha256) == nzchar(man$downloaded_utc)),
          all(!nzchar(man$sy_end) | grepl("^[0-9]{4}$", man$sy_end)))

st <- readLines("data/stage.txt", n = 1, warn = FALSE)
stopifnot(st %in% c("1", "2"))
a1 <- stage_allows(man$dataset, man$sy_end, 1L)
a2 <- stage_allows(man$dataset, man$sy_end, 2L)
y <- suppressWarnings(as.integer(man$sy_end))
stopifnot(all(a2), any(a1), all(!is.na(y[a1]) & y[a1] <= STAGE1_LAST_YEAR),
          !any(a1 & grepl("^(seda_|hs_reportcard_|edfacts_acgr|bls_cpi|ccd_school_characteristics)", man$dataset)),
          any(a1 & man$dataset == "edfacts_math_lea"), any(a1 & man$dataset == "saipe_district"),
          !any(a1 & man$dataset == "edfacts_math_lea" & y > 2013L),
          inherits(try(stage_allows("x", 2010L, 3L), silent = TRUE), "try-error"))

refs <- c("data/reference/cep_phase_in.csv", "data/reference/test_replacement.csv",
          "data/reference/hs_reportcard_harmonization.csv", "data/reference/hs_reportcard_leaid_crosswalk.csv")
stopifnot(all(file.exists(refs)))

code <- c(list.files("R", pattern = "\\.R$", full.names = TRUE, recursive = TRUE),
          list.files("tests", pattern = "\\.R$", full.names = TRUE))
for (f in code) {
  pd <- utils::getParseData(parse(f, keep.source = TRUE, encoding = "UTF-8"))
  if (any(pd$token == "COMMENT")) stop(f, " carries a comment")
}
steps <- list.files("R", pattern = "^[0-9]{2}[a-z]?_.*\\.R$")
stopifnot(identical(sort(unique(substr(steps, 1, 2))), sprintf("%02d", 0:13)))

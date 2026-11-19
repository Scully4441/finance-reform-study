STAGE1_LAST_YEAR <- 2013L
STAGE2_DATASETS <- "^(edfacts_acgr|seda_|hs_reportcard_|bls_cpi|ccd_school_characteristics)"

stage_allows <- function(dataset, sy_end, stage) {
  stage <- as.integer(stage)
  if (!length(stage) || is.na(stage) || !stage %in% c(1L, 2L)) stop("stage must be 1 or 2")
  if (stage == 2L) return(rep(TRUE, length(dataset)))
  sy_end <- suppressWarnings(as.integer(sy_end))
  !grepl(STAGE2_DATASETS, dataset) & !is.na(sy_end) & sy_end <= STAGE1_LAST_YEAR
}

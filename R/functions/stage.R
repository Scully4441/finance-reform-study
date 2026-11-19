STAGE1_LAST_YEAR <- 2013L
STAGE1_ROWS <- list(
  edfacts_math_lea               = 2010:2013,
  edfacts_rla_lea                = 2010:2013,
  edfacts_math_participation_lea = 2013L,
  edfacts_rla_participation_lea  = 2013L,
  edfacts_docs                   = 2011:2013,
  ccd_lea_directory              = 2010:2013,
  ccd_membership                 = 2010L,
  saipe_district                 = 2009L)

stage_allows <- function(dataset, sy_end, stage) {
  stage <- as.integer(stage)
  if (!length(stage) || is.na(stage) || !stage %in% c(1L, 2L)) stop("stage must be 1 or 2")
  if (stage == 2L) return(rep(TRUE, length(dataset)))
  sy_end <- suppressWarnings(as.integer(sy_end))
  vapply(seq_along(dataset), function(i) dataset[i] %in% names(STAGE1_ROWS) && !is.na(sy_end[i]) &&
           sy_end[i] %in% STAGE1_ROWS[[dataset[i]]], TRUE)
}

read_stage <- function(path = "data/stage.txt") {
  stage <- suppressWarnings(as.integer(readLines(path, n = 1, warn = FALSE)))
  if (!length(stage) || is.na(stage) || !stage %in% c(1L, 2L)) stop(path, " must read 1 or 2")
  stage
}

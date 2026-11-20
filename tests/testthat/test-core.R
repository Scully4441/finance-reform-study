withr::local_dir(ROOT)

test_that("seeds derive from the master seed 130", {
expect_all(MASTER_SEED == 130L)
expect_all(seed_for("bootstrap") == seed_for("bootstrap"))
expect_all(seed_for("bootstrap") != seed_for("randomization"))
expect_all(is.integer(seed_for("power")), seed_for("power") >= 0)
})

test_that("the probit gap V and its standard error", {
expect_all(near(v_gap(0.5, 0.5), 0))
expect_all(v_gap(0.7, 0.4) > 0, near(v_gap(0.7, 0.4), -v_gap(0.4, 0.7)))
expect_all(is.finite(v_gap(1, 0, n_a = 40, n_b = 40)))
expect_all(inherits(try(v_gap(70, 40), silent = TRUE), "try-error"))
cut <- c(-1, 0, 0.5, 1.2)
pa <- 1 - pnorm(cut, mean = 0.4); pb <- 1 - pnorm(cut, mean = 0)
expect_all(near(v_gap(pa, pb), rep(0.4, 4)))
expect_all(v_gap_se(0.6, 0.5, 30, 30) > v_gap_se(0.6, 0.5, 300, 300))
})

test_that("EDFacts labels are parsed by the printed-endpoint rule", {
x <- c("45", "45.5", "GE50", "20-29", "PS", "", NA, " 12 ")
expect_all(identical(edfacts_exact(x), c(45, 45.5, NA, NA, NA, NA, NA, 12)))
expect_all(identical(edfacts_suppressed(x), c(FALSE, FALSE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE)))
r <- edfacts_range(c("45", "20-29", "GE95", "LE5", "LT50", "GE99", "PS", "", NA, " ge90 ", "12.5", "N/A"))
expect_all(identical(r$width, c(0, 9, 5, 5, 50, 1, NA, NA, NA, 10, 0, NA)),
          identical(r$mid, c(45, 24.5, 97.5, 2.5, 25, 99.5, NA, NA, NA, 95, 12.5, NA)),
          identical(r$lo[1:6], c(45, 20, 95, 0, 0, 99)), identical(r$hi[1:6], c(45, 29, 100, 5, 50, 100)))
expect_all(inherits(try(edfacts_range("60-40"), silent = TRUE), "try-error"),
          inherits(try(edfacts_range("GE101"), silent = TRUE), "try-error"))
})

test_that("the CPI school-year average and gap fill", {
m <- expand.grid(month = 1:12, year = 2009:2011)
m$value <- 100 + (m$year - 2009) * 12 + m$month
sy <- cpi_school_year(m)
expect_all(sy$complete[sy$sy_end == 2010], !sy$complete[sy$sy_end == 2009])
expect_all(near(sy$cpi[sy$sy_end == 2010], mean(c(107:112, 113:118))))
expect_all(near(deflate_to_base(100, 2010, sy, 2011), 100 * sy$cpi[sy$sy_end == 2011] / sy$cpi[sy$sy_end == 2010]))
g <- m[!(m$year == 2010 & m$month == 10), ]
f <- cpi_fill_gaps(g)
expect_all(nrow(f) == nrow(m), sum(f$filled) == 1)
expect_all(near(f$value[f$year == 2010 & f$month == 10], mean(m$value[m$year == 2010 & m$month %in% c(9, 11)])))
syg <- cpi_school_year(g)
expect_all(syg$complete[syg$sy_end == 2011], syg$filled[syg$sy_end == 2011] == 1)
expect_all(near(syg$cpi, sy$cpi))
g$value[g$year == 2011 & g$month == 3] <- NA
expect_all(sum(cpi_fill_gaps(g)$filled) == 2)
expect_all(nrow(cpi_fill_gaps(m[-1, ])) == nrow(m) - 1)
expect_all(inherits(try(cpi_fill_gaps(m[!(m$year == 2010 & m$month %in% 10:11), ]), silent = TRUE), "try-error"))
})

test_that("the CPI series is read from the BLS API responses", {
js <- function(years, periods, values, status = "REQUEST_SUCCEEDED", id = "CUUR0000SA0") {
  f <- tempfile(fileext = ".json")
  d <- paste0('{"year":"', years, '","period":"', periods, '","periodName":"x","value":"', values, '","footnotes":[{}]}', collapse = ",")
  writeLines(paste0('{"status":"', status, '","responseTime":1,"message":[],"Results":{"series":[{"seriesID":"', id, '","data":[', d, ']}]}}'), f)
  f
}
a <- js(c(2011, 2011, 2011), c("M02", "M01", "M13"), c("220.1", "219.5", "224.9"))
b <- js(c(2012, 2012), c("M01", "M02"), c("226.7", "-"))
x <- cpi_from_bls_json(c(b, a))
expect_all(identical(names(x), c("series_id", "year", "month", "value")), nrow(x) == 4,
           identical(x$year, c(2011L, 2011L, 2012L, 2012L)), identical(x$month, c(1L, 2L, 1L, 2L)))
expect_all(near(x$value[1:3], c(219.5, 220.1, 226.7)), is.na(x$value[4]))
expect_all(inherits(try(cpi_from_bls_json(js(2011, "M01", "1", status = "REQUEST_NOT_PROCESSED")), silent = TRUE), "try-error"),
           inherits(try(cpi_from_bls_json(js(2011, "M01", "1", id = "CUSR0000SA0")), silent = TRUE), "try-error"),
           inherits(try(cpi_from_bls_json(c(a, a)), silent = TRUE), "try-error"))
})

test_that("the test-replacement table follows its coding rules", {
tr <- read.csv("data/reference/test_replacement.csv", stringsAsFactors = FALSE, na.strings = character())
tr_cols <- c("state", "sy_end", "replaced_math", "replaced_rla", "replaced",
             "assessment_math", "assessment_rla", "source", "evidence", "notes")
expect_all(identical(names(tr), tr_cols) || identical(names(tr), c(tr_cols, "author_check")))
expect_all(nrow(tr) == 816, !anyDuplicated(tr[c("state", "sy_end")]))
expect_all(setequal(tr$state, c(state.abb, "DC")), all(table(tr$state) == 16), setequal(tr$sy_end, 2010:2025))
expect_all(all(unlist(tr[c("replaced_math", "replaced_rla", "replaced")]) %in% 0:1))
expect_all(all(tr$replaced == pmax(tr$replaced_math, tr$replaced_rla)))
expect_all(all(tr$evidence %in% c("documented", "inferred")), all(tr$replaced[tr$evidence == "inferred"] == 0))
expect_all(all(nzchar(tr$assessment_math)), all(nzchar(tr$assessment_rla)))
src <- trimws(unlist(strsplit(tr$source, " | ", fixed = TRUE)))
expect_all(length(src) >= nrow(tr), all(grepl("^(SEA|Wayback|ESEA flexibility request|ESEA workbook|ESSA plan): ", src)))
wb <- src[startsWith(src, "Wayback: ")]
expect_all(all(grepl("web\\.archive\\.org/web/[0-9]+", wb)), all(grepl("\\(captured [0-9]{4}-[0-9]{2}-[0-9]{2}\\)$", wb)))
})

test_that("the CEP phase-in table covers every state", {
cep <- read.csv("data/reference/cep_phase_in.csv", stringsAsFactors = FALSE, na.strings = character())
expect_all(identical(names(cep), c("state", "first_cep_sy_end", "source")))
expect_all(nrow(cep) == 51, !anyDuplicated(cep$state), setequal(cep$state, c(state.abb, "DC")))
expect_all(all(cep$first_cep_sy_end %in% 2012:2015), all(nzchar(trimws(cep$source))))
})

test_that("CEP status is read from the CCD", {
expect_all(identical(ccd_nslp_zip(2014L), "data/raw/ccd/membership-sy2013-14.zip"),
          identical(ccd_nslp_zip(2021L), "data/raw/ccd/school-characteristics-sy2020-21.zip"))
sch <- data.frame(leaid = c("0100005", "0100005", "0100006", "0100006", "0100007"),
                  ncessch = sprintf("%012d", 1:5), sy_end = 2015L,
                  cep_school = c(0L, 1L, 0L, 0L, 0L), stringsAsFactors = FALSE)
dy <- cep_district_year(sch)
expect_all(identical(dy$leaid, c("0100005", "0100006", "0100007")), identical(dy$cep, c(1L, 0L, 0L)))
for (y in c(2014L, 2015L, 2021L)) {
  if (!file.exists(ccd_nslp_zip(y))) next
  d <- cep_from_ccd(y)
  expect_all(all(grepl("^[0-9]{7}$", d$leaid)), !anyDuplicated(d$leaid), all(d$cep %in% 0:1),
            all(d$sy_end == y), sum(d$cep) > 0)
}
if (file.exists(ccd_nslp_zip(2015L))) {
  d <- cep_from_ccd(2015L)
  one <- d$leaid[d$cep == 1][1]
  st <- fips_to_state(substr(one, 1, 2))
  expect_all(cep_indicator(one, st, 2015L) == 1L,
            cep_indicator("9999999", st, 2015L) == 0L,
            cep_indicator(one, "IL", 2012L) == 1L,
            cep_indicator(one, "AK", 2012L) == 0L)
}
})

test_that("step 1 builds and permutes the three event tables", {
root <- tempfile("evtest"); dir.create(root)
repo <- file.path(root, "finance-reform-study"); priv <- file.path(root, "finance-reform-study-private")
dir.create(repo); dir.create(priv); dir.create(file.path(repo, "R"), showWarnings = FALSE)
invisible(file.copy("R/01_build_event_table.R", file.path(repo, "R", "01_build_event_table.R")))
hdr <- "state,event_year,event_type,source,notes"
writeLines(c(hdr, "KS,2010,court,LRS,x", "WA,2011,court,LRS,x", "NJ,2008,court,LRS,x",
             "CA,2005,legislative,LRS,x"), file.path(priv, "lrs_events.csv"))
writeLines(c(hdr, "WA,2013,court,ELC-SC,x", "SC,2015,court,ELC-SC,x", "NM,2019,court,ELC-LC,x"),
           file.path(priv, "court_events_after_2011.csv"))
writeLines(c(hdr, "IL,2018,legislative,STAT,x", "TX,2020,legislative,STAT,x", "CA,2014,legislative,STAT,x"),
           file.path(priv, "legislative_events_after_2011.csv"))
writeLines("77", file.path(priv, "permutation_seed.txt"))
withr::local_dir(repo)
invisible(capture.output(source("R/01_build_event_table.R")))
real <- read.csv(file.path(priv, "event_table_real.csv"), stringsAsFactors = FALSE)
perm <- read.csv("data/reference/event_table.csv", stringsAsFactors = FALSE)
r1   <- read.csv(file.path(priv, "event_table_real_r1.csv"), stringsAsFactors = FALSE)
r2   <- read.csv(file.path(priv, "event_table_real_r2.csv"), stringsAsFactors = FALSE)
expect_all(real$treat_year[real$state == "WA"] == 2011)
expect_all(real$group[real$state == "NJ"] == "excluded")
expect_all(real$group[real$state == "CA"] == "excluded")
expect_all(real$group[real$state == "TX"] == "never" || real$treat_year[real$state == "TX"] == 2020)
expect_all(sum(real$group == "treated") == 6)
expect_all(sum(r1$group == "treated") == 3)
expect_all(sum(r2$group == "treated") == 4)
expect_all(identical(sort(real$treat_year[real$group == "treated"]),
                    sort(perm$treat_year[perm$group == "treated"])))
expect_all(!identical(real$treat_year, perm$treat_year))
expect_all(identical(real$state, perm$state), identical(real$group, perm$group))
expect_all(readLines("data/reference/blinding_status.txt", n = 1) == "PERMUTED")
expect_all(file.exists("data/reference/event_table_r1.csv"), file.exists("data/reference/event_table_r2.csv"))
})

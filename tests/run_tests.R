# Base-R checks for the shared functions. Run: Rscript tests/run_tests.R
for (f in list.files("R/functions", full.names = TRUE)) source(f)
near <- function(a, b, tol = 1e-8) all(abs(a - b) < tol)

# seeds
stopifnot(MASTER_SEED == 130L)
stopifnot(seed_for("bootstrap") == seed_for("bootstrap"))
stopifnot(seed_for("bootstrap") != seed_for("randomization"))
stopifnot(is.integer(seed_for("power")), seed_for("power") >= 0)

# gap V
stopifnot(near(v_gap(0.5, 0.5), 0))
stopifnot(v_gap(0.7, 0.4) > 0, near(v_gap(0.7, 0.4), -v_gap(0.4, 0.7)))
stopifnot(is.finite(v_gap(1, 0, n_a = 40, n_b = 40)))
stopifnot(inherits(try(v_gap(70, 40), silent = TRUE), "try-error"))
# a common cut cancels: two normal groups, any cut, same V
cut <- c(-1, 0, 0.5, 1.2)
pa <- 1 - pnorm(cut, mean = 0.4); pb <- 1 - pnorm(cut, mean = 0)
stopifnot(near(v_gap(pa, pb), rep(0.4, 4)))
stopifnot(v_gap_se(0.6, 0.5, 30, 30) > v_gap_se(0.6, 0.5, 300, 300))

# EDFacts parsing
x <- c("45", "45.5", "GE50", "20-29", "PS", "", NA, " 12 ")
stopifnot(identical(edfacts_exact(x), c(45, 45.5, NA, NA, NA, NA, NA, 12)))
stopifnot(identical(edfacts_suppressed(x), c(FALSE, FALSE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE)))
# ranges from printed endpoints; one-sided labels close at 0 and 100 (author decision 2026-09-11)
r <- edfacts_range(c("45", "20-29", "GE95", "LE5", "LT50", "GE99", "PS", "", NA, " ge90 ", "12.5", "N/A"))
stopifnot(identical(r$width, c(0, 9, 5, 5, 50, 1, NA, NA, NA, 10, 0, NA)),
          identical(r$mid, c(45, 24.5, 97.5, 2.5, 25, 99.5, NA, NA, NA, 95, 12.5, NA)),
          identical(r$lo[1:6], c(45, 20, 95, 0, 0, 99)), identical(r$hi[1:6], c(45, 29, 100, 5, 50, 100)))
stopifnot(inherits(try(edfacts_range("60-40"), silent = TRUE), "try-error"),
          inherits(try(edfacts_range("GE101"), silent = TRUE), "try-error"))

# CPI
m <- expand.grid(month = 1:12, year = 2009:2011)
m$value <- 100 + (m$year - 2009) * 12 + m$month   # rises 1 per month
sy <- cpi_school_year(m)
stopifnot(sy$complete[sy$sy_end == 2010], !sy$complete[sy$sy_end == 2009])
stopifnot(near(sy$cpi[sy$sy_end == 2010], mean(c(107:112, 113:118))))
stopifnot(near(deflate_to_base(100, 2010, sy, 2011), 100 * sy$cpi[sy$sy_end == 2011] / sy$cpi[sy$sy_end == 2010]))
# CPI fill (design v17): a single missing month takes the mean of its neighbours
g <- m[!(m$year == 2010 & m$month == 10), ]
f <- cpi_fill_gaps(g)
stopifnot(nrow(f) == nrow(m), sum(f$filled) == 1)
stopifnot(near(f$value[f$year == 2010 & f$month == 10], mean(m$value[m$year == 2010 & m$month %in% c(9, 11)])))
syg <- cpi_school_year(g)
stopifnot(syg$complete[syg$sy_end == 2011], syg$filled[syg$sy_end == 2011] == 1)
stopifnot(near(syg$cpi, sy$cpi))                          # linear series: the fill equals the true value
g$value[g$year == 2011 & g$month == 3] <- NA              # an NA value is a gap too
stopifnot(sum(cpi_fill_gaps(g)$filled) == 2)
stopifnot(nrow(cpi_fill_gaps(m[-1, ])) == nrow(m) - 1)    # a month outside the published range is not filled
stopifnot(inherits(try(cpi_fill_gaps(m[!(m$year == 2010 & m$month %in% 10:11), ]), silent = TRUE), "try-error"))

# test-replacement table (data acquisition 3.2)
tr <- read.csv("data/reference/test_replacement.csv", stringsAsFactors = FALSE, na.strings = character())
tr_cols <- c("state", "sy_end", "replaced_math", "replaced_rla", "replaced",
             "assessment_math", "assessment_rla", "source", "evidence", "notes")
stopifnot(identical(names(tr), tr_cols) || identical(names(tr), c(tr_cols, "author_check")))  # author_check optional, last
stopifnot(nrow(tr) == 204, !anyDuplicated(tr[c("state", "sy_end")]))
stopifnot(setequal(tr$state, c(state.abb, "DC")), all(table(tr$state) == 4), setequal(tr$sy_end, 2010:2013))
stopifnot(all(unlist(tr[c("replaced_math", "replaced_rla", "replaced")]) %in% 0:1))
stopifnot(all(tr$replaced == pmax(tr$replaced_math, tr$replaced_rla)))
stopifnot(all(tr$evidence %in% c("documented", "inferred")), all(tr$replaced[tr$evidence == "inferred"] == 0))
stopifnot(all(nzchar(tr$assessment_math)), all(nzchar(tr$assessment_rla)))
src <- trimws(unlist(strsplit(tr$source, " | ", fixed = TRUE)))
stopifnot(length(src) >= nrow(tr), all(grepl("^(SEA|Wayback|ESEA flexibility request|ESEA workbook|ESSA plan): ", src)))
wb <- src[startsWith(src, "Wayback: ")]
stopifnot(all(grepl("web\\.archive\\.org/web/[0-9]+", wb)), all(grepl("\\(captured [0-9]{4}-[0-9]{2}-[0-9]{2}\\)$", wb)))

# CEP phase-in table (data acquisition 3.3)
cep <- read.csv("data/reference/cep_phase_in.csv", stringsAsFactors = FALSE, na.strings = character())
stopifnot(identical(names(cep), c("state", "first_cep_sy_end", "source")))
stopifnot(nrow(cep) == 51, !anyDuplicated(cep$state), setequal(cep$state, c(state.abb, "DC")))
stopifnot(all(cep$first_cep_sy_end %in% 2012:2015), all(nzchar(trimws(cep$source))))

# event-table build script on synthetic inputs, in a temporary tree
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
old <- setwd(repo); on.exit(setwd(old), add = TRUE)
invisible(capture.output(source("R/01_build_event_table.R")))
real <- read.csv(file.path(priv, "event_table_real.csv"), stringsAsFactors = FALSE)
perm <- read.csv("data/reference/event_table.csv", stringsAsFactors = FALSE)
r1   <- read.csv(file.path(priv, "event_table_real_r1.csv"), stringsAsFactors = FALSE)
r2   <- read.csv(file.path(priv, "event_table_real_r2.csv"), stringsAsFactors = FALSE)
stopifnot(real$treat_year[real$state == "WA"] == 2011)     # earliest in-window event wins
stopifnot(real$group[real$state == "NJ"] == "excluded")     # 2005-2009 event excludes
stopifnot(real$group[real$state == "CA"] == "excluded")     # excluded despite a later statute
stopifnot(real$group[real$state == "TX"] == "never" || real$treat_year[real$state == "TX"] == 2020)
stopifnot(sum(real$group == "treated") == 6)                # KS WA SC NM IL TX
stopifnot(sum(r1$group == "treated") == 3)                  # KS WA SC (LRS + ELC-SC)
stopifnot(sum(r2$group == "treated") == 4)                  # KS WA SC NM (court only)
stopifnot(identical(sort(real$treat_year[real$group == "treated"]),
                    sort(perm$treat_year[perm$group == "treated"])))  # same multiset
stopifnot(!identical(real$treat_year, perm$treat_year))     # but shuffled
stopifnot(identical(real$state, perm$state), identical(real$group, perm$group))
stopifnot(readLines("data/reference/blinding_status.txt", n = 1) == "PERMUTED")
stopifnot(file.exists("data/reference/event_table_r1.csv"), file.exists("data/reference/event_table_r2.csv"))
setwd(old)

# sample rules and the step 3 output
source("tests/test_sample.R")

# outcome construction and the step 4 outputs
source("tests/test_outcomes.R")
cat("All tests passed.\n")

for (f in list.files("R/functions", full.names = TRUE)) source(f)

stage <- as.integer(readLines("data/stage.txt", n = 1, warn = FALSE))
if (!identical(stage, 2L)) stop("R/04g_graduation_outcomes.R needs stage 2 (graduation files after 2012-13).")
WINDOW <- GRAD_WINDOW

stamp   <- format(Sys.time(), tz = "UTC", "%Y%m%dT%H%M%SZ")
out_dir <- "outputs/04g_graduation_outcomes"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/logs", recursive = TRUE, showWarnings = FALSE)
log_file <- file.path("outputs", "logs", paste0("04g_graduation_outcomes_", stamp, ".log"))
say <- function(...) {
  txt <- paste0(...)
  cat(txt, "\n", sep = "")
  cat(txt, "\n", sep = "", file = log_file, append = TRUE)
}
show <- function(x) say(paste(utils::capture.output(print(x, row.names = FALSE)), collapse = "\n"))

say("Step 4g graduation gaps, run ", stamp, "; stage ", stage, "; blinding ",
    readLines("data/reference/blinding_status.txt", n = 1, warn = FALSE))

s <- utils::read.csv("data/derived/graduation_sample_district_year.csv", colClasses = c(leaid = "character"),
                     stringsAsFactors = FALSE, na.strings = "")
stopifnot(setequal(unique(s$sy_end), WINDOW), !anyDuplicated(s[c("leaid", "sy_end")]))
sets <- c(retained = "event_table.csv", retained_r1 = "event_table_r1.csv", retained_r2 = "event_table_r2.csv")
for (flag in names(sets)) {
  e <- utils::read.csv(file.path("data", "reference", sets[[flag]]), stringsAsFactors = FALSE)[c("state", "group")]
  stopifnot(!any(s[[flag]] == 1L & s$state %in% e$state[e$group == "excluded"]))
}

d <- s[s$retained == 1L | s$retained_r1 == 1L | s$retained_r2 == 1L, ]
say("District-years retained under at least one event set: ", nrow(d), " (", length(unique(d$leaid)),
    " districts, ", length(unique(d$state)), " states)")

gaps <- do.call(rbind, lapply(names(MAX_WIDTH), function(smpl) grad_gaps(d, smpl)))
gaps <- gaps[order(factor(gaps$sample, levels = names(MAX_WIDTH)), gaps$state, gaps$leaid, gaps$sy_end), ]
stopifnot(!anyDuplicated(gaps[c("leaid", "sy_end", "sample")]))
utils::write.csv(gaps, "data/derived/gaps_graduation_district_year.csv", row.names = FALSE, na = "")
say("Wrote data/derived/gaps_graduation_district_year.csv: ", nrow(gaps), " rows.")

flags <- c(primary = "retained", r1 = "retained_r1", r2 = "retained_r2")
by_year <- do.call(rbind, lapply(names(MAX_WIDTH), function(smpl) do.call(rbind, lapply(names(GRAD_GAPS), function(g)
  do.call(rbind, lapply(names(flags), function(set) {
    v <- paste0("v_", GRAD_GAPS[[g]])
    x <- gaps[gaps$sample == smpl & gaps[[flags[[set]]]] == 1L & !is.na(gaps[[v]]), ]
    data.frame(sample = smpl, gap = g, event_set = set, sy_end = WINDOW,
               district_years = vapply(WINDOW, function(y) sum(x$sy_end == y), integer(1)),
               states = vapply(WINDOW, function(y) length(unique(x$state[x$sy_end == y])), integer(1)),
               stringsAsFactors = FALSE)
  }))))))
utils::write.csv(by_year, file.path(out_dir, "gap_counts_by_year.csv"), row.names = FALSE)
wide <- stats::reshape(by_year[c("sample", "gap", "event_set", "sy_end", "district_years")],
                       idvar = c("sample", "gap", "event_set"), timevar = "sy_end", direction = "wide")
names(wide) <- sub("^district_years\\.", "sy", names(wide))
wide$total <- rowSums(wide[paste0("sy", WINDOW)])
say("\n== District-years with a usable graduation gap, by end year")
say("Samples: primary = exact or range <= ", MAX_WIDTH[["primary"]], " points; r5 = <= ", MAX_WIDTH[["r5"]],
    " points; exact = exact values only. Event set = districts retained under rules 1, 2 and 6 with that table.")
show(wide)
utils::write.csv(wide, file.path(out_dir, "gap_counts.csv"), row.names = FALSE)

desc <- do.call(rbind, lapply(names(MAX_WIDTH), function(smpl) do.call(rbind, lapply(names(GRAD_GAPS), function(g) {
  v <- gaps[[paste0("v_", GRAD_GAPS[[g]])]][gaps$sample == smpl & gaps$retained == 1L]
  v <- v[!is.na(v)]
  data.frame(gap = g, sample = smpl, n = length(v), mean = round(mean(v), 3), sd = round(stats::sd(v), 3),
             p10 = round(stats::quantile(v, 0.1, names = FALSE), 3), median = round(stats::median(v), 3),
             p90 = round(stats::quantile(v, 0.9, names = FALSE), 3))
}))))
say("\n== Distribution of V, primary event set, pooled over end years (probit units; negative = Black or Hispanic rate lower)")
show(desc)
utils::write.csv(desc, file.path(out_dir, "gap_distribution.csv"), row.names = FALSE)
clamped <- vapply(GRAD_SUBGROUPS, function(sg) {
  x <- gaps[gaps$sample == "primary", ]
  p <- x[[paste0("p_", sg)]]; n <- x[[paste0("n_", sg)]]
  sum(!is.na(p) & !is.na(n) & (p < 1 / (2 * n) | p > 1 - 1 / (2 * n)))
}, integer(1))
say("Primary-sample rates clamped at 1/(2n) before the probit (a rate of 0 or 100): ",
    paste(names(clamped), clamped, collapse = ", "))
say("Log: ", log_file)

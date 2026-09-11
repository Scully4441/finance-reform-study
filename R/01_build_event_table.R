# Step 1. Build the reform event table and its blinded (permuted) version.
#
# RUN THIS YOURSELF in a plain terminal from the repository folder, not inside
# a Claude Code session, so the real table never enters that session:
#   Rscript R/01_build_event_table.R
#
# Inputs, all in ../finance-reform-study-private/:
#   lrs_events.csv                     LRS (2018) list, 1990-2011
#   court_events_after_2011.csv        court rule events (rulings after Dec 31, 2011)
#   legislative_events_after_2011.csv  statute rule events (statutes after Dec 31, 2011)
#     columns: state,event_year,event_type,source,notes
#     event_year = end year of the school year (2010-11 -> 2011); a ruling or
#       enactment in calendar year Y is coded Y+1
#     event_type = court, legislative, or referendum
#     source = LRS, ELC-SC (final state supreme court ruling), ELC-LC (final
#       ruling of a lower court), or STAT (statute rule)
#   permutation_seed.txt  one integer on the first line (not 130)
# Outputs:
#   ../finance-reform-study-private/event_table_real*.csv   never in the repository
#   data/reference/event_table.csv       PERMUTED, full event set (primary)
#   data/reference/event_table_r1.csv    PERMUTED, LRS + ELC-SC only (robustness 1)
#   data/reference/event_table_r2.csv    PERMUTED, court events only (robustness 2)
#   data/reference/blinding_status.txt   "PERMUTED"
#
# Rules (design document, Sections 3 and 5):
#   Window starts at end year 2010. Treatment year = earliest in-window event.
#   Any event in end years 2005-2009 excludes the state.

WINDOW_START <- 2010L
PRE_EXCLUDE  <- 2005:2009
MASTER_SEED  <- 130L
priv <- file.path("..", "finance-reform-study-private")
if (!dir.exists(priv)) stop("Private folder not found beside the repository: ", normalizePath(priv, mustWork = FALSE))

read_events <- function(f) {
  d <- read.csv(file.path(priv, f), stringsAsFactors = FALSE, strip.white = TRUE,
                colClasses = "character")
  need <- c("state", "event_year", "event_type", "source", "notes")
  miss <- setdiff(need, names(d))
  if (length(miss)) stop(f, " is missing columns: ", paste(miss, collapse = ", "))
  d <- d[nzchar(d$state), need]
  d$state <- toupper(d$state)
  d$event_year <- as.integer(d$event_year)
  d$event_type <- tolower(d$event_type)
  d$source <- toupper(d$source)
  if (any(!d$event_type %in% c("court", "legislative", "referendum")))
    stop(f, ": event_type must be court, legislative, or referendum")
  if (any(!d$source %in% c("LRS", "ELC-SC", "ELC-LC", "STAT")))
    stop(f, ": source must be LRS, ELC-SC, ELC-LC, or STAT")
  if (any(is.na(d$event_year))) stop(f, ": event_year must be an integer end year")
  d
}

lrs   <- read_events("lrs_events.csv")
court <- read_events("court_events_after_2011.csv")
stat  <- read_events("legislative_events_after_2011.csv")
if (any(court$event_year <= 2012L)) stop("court_events_after_2011.csv: rulings must be after Dec 31, 2011 (end year 2013 or later)")
if (any(stat$event_year  <= 2012L)) stop("legislative_events_after_2011.csv: statutes must be after Dec 31, 2011 (end year 2013 or later)")

events <- rbind(lrs, court, stat)
events <- events[order(events$state, events$event_year), ]

build_table <- function(ev) {
  states <- sort(unique(c(state.abb, "DC", ev$state)))
  tab <- data.frame(state = states, treat_year = NA_integer_, excluded = FALSE,
                    n_window_events = 0L, stringsAsFactors = FALSE)
  for (k in seq_len(nrow(tab))) {
    e <- ev[ev$state == tab$state[k], ]
    if (any(e$event_year %in% PRE_EXCLUDE)) tab$excluded[k] <- TRUE
    in_window <- e$event_year[e$event_year >= WINDOW_START]
    tab$n_window_events[k] <- length(in_window)
    if (length(in_window)) tab$treat_year[k] <- min(in_window)
  }
  tab$group <- ifelse(tab$excluded, "excluded",
                      ifelse(is.na(tab$treat_year), "never", "treated"))
  tab$treat_year[tab$group != "treated"] <- NA_integer_
  tab
}

sets <- list(
  full = events,
  r1   = events[events$source %in% c("LRS", "ELC-SC"), ],
  r2   = events[events$event_type == "court", ]
)
tables <- lapply(sets, build_table)

# Blinding permutation: same private seed for every set
seed_line <- readLines(file.path(priv, "permutation_seed.txt"), n = 1, warn = FALSE)
pseed <- suppressWarnings(as.integer(trimws(seed_line)))
if (is.na(pseed)) stop("permutation_seed.txt must hold one integer on its first line")
if (pseed == MASTER_SEED) stop("The permutation seed must differ from the master seed 130")

# Permute treatment years among the treated states. The robustness sets can
# have very few treated states, so an identity draw is likely; the loop keeps
# drawing from the same seeded stream until the permutation differs from the
# real table. The result is still fully determined by the seed.
permute <- function(tab, label) {
  perm <- tab
  tr <- which(perm$group == "treated")
  if (length(tr) < 2L || length(unique(tab$treat_year[tr])) < 2L) {
    message("Set ", label, ": fewer than two distinct treatment years, so no permutation is possible; table written as is.")
    return(perm)
  }
  set.seed(pseed)
  for (k in seq_len(1000L)) {
    idx <- sample.int(length(tr))
    if (!identical(tab$treat_year[tr][idx], tab$treat_year[tr])) {
      perm$treat_year[tr] <- tab$treat_year[tr][idx]
      return(perm)
    }
  }
  stop("Could not find a non-identity permutation for set ", label)
}

write.csv(events, file.path(priv, "events_merged_real.csv"), row.names = FALSE)
dir.create("data/reference", recursive = TRUE, showWarnings = FALSE)
suffix <- c(full = "", r1 = "_r1", r2 = "_r2")
for (nm in names(tables)) {
  write.csv(tables[[nm]], file.path(priv, paste0("event_table_real", suffix[[nm]], ".csv")), row.names = FALSE)
  write.csv(permute(tables[[nm]], nm), file.path("data", "reference", paste0("event_table", suffix[[nm]], ".csv")), row.names = FALSE)
}
writeLines(c("PERMUTED",
             paste("built_utc:", format(Sys.time(), tz = "UTC", "%Y-%m-%dT%H:%M:%SZ"))),
           "data/reference/blinding_status.txt")

cat("Event tables built (full, r1, r2).\n")
for (nm in names(tables)) { cat(nm, ": "); print(table(tables[[nm]]$group)) }
multi <- tables$full$state[tables$full$n_window_events > 1L & tables$full$group == "treated"]
if (length(multi)) cat("States with more than one in-window event (earliest used):",
                       paste(multi, collapse = " "), "\n")
cat("Real tables written to the private folder. Permuted tables written to data/reference/.\n")

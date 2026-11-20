# Performance regression check: time the same embedding with two installed
# versions of ggumap (e.g. the base branch and a pull request).
#
#   Rscript bench/regression.R <lib_base> <lib_head> [summary.md]
#
# Each library path must contain an installed ggumap. Runs single-threaded so
# that results are comparable on shared CI machines.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) >= 2)
libs <- c(base = args[[1]], head = args[[2]])
summary_file <- if (length(args) >= 3) args[[3]] else ""
reps <- 5L

source("bench/datasets.R")
data_file <- tempfile(fileext = ".rds")
saveRDS(bench_blobs(10000, p = 50), data_file)

time_one <- function(lib, flavour, data_file) {
  library(ggumap, lib.loc = lib)
  x <- readRDS(data_file)$x
  umap_embed(
    x[1:1000, ],
    flavour = flavour,
    seed = 1,
    n_threads = 1,
    control = umap_control(progress = FALSE)
  )
  start <- proc.time()[["elapsed"]]
  umap_embed(
    x,
    flavour = flavour,
    seed = 1,
    n_threads = 1,
    control = umap_control(progress = FALSE)
  )
  proc.time()[["elapsed"]] - start
}

rows <- list()
for (flavour in c("0.5", "0.6")) {
  # Interleave versions to spread machine noise evenly.
  times <- list(base = numeric(), head = numeric())
  for (rep in seq_len(reps)) {
    for (v in names(libs)) {
      times[[v]] <- c(
        times[[v]],
        callr::r(time_one, list(libs[[v]], flavour, data_file))
      )
    }
  }
  rows[[flavour]] <- data.frame(
    flavour = flavour,
    base = stats::median(times$base),
    head = stats::median(times$head),
    change = stats::median(times$head) / stats::median(times$base) - 1,
    p_value = suppressWarnings(
      stats::wilcox.test(times$base, times$head)$p.value
    )
  )
}
res <- do.call(rbind, rows)

md <- c(
  "### ggumap performance (10,000 x 50 blobs, 1 thread, median of 5 runs)",
  "",
  "| flavour | base (s) | head (s) | change | p-value |",
  "|---|---|---|---|---|",
  sprintf(
    "| %s | %.2f | %.2f | %+.1f%% | %.3f |",
    res$flavour,
    res$base,
    res$head,
    100 * res$change,
    res$p_value
  )
)
writeLines(md)
if (nzchar(summary_file)) {
  write(md, summary_file, append = TRUE)
}
# Fail on a clear slowdown (> 15% and significant).
if (any(res$change > 0.15 & res$p_value < 0.05)) {
  message("Performance regression detected")
  quit(status = 1)
}

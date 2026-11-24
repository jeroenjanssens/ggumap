# Run the UMAP benchmarks. See bench/README.md.
#
#   Rscript bench/run.R [--suite=quick|full] [--contenders=a,b] [--reps=N]
#                       [--threads=N] [--out=bench/results/results.csv]

source("bench/datasets.R")
source("bench/contenders.R")
source("bench/quality.R")

# ---- arguments ---------------------------------------------------------------

parse_args <- function(args) {
  out <- list()
  for (a in args) {
    kv <- strsplit(sub("^--", "", a), "=", fixed = TRUE)[[1]]
    out[[kv[1]]] <- if (length(kv) > 1) kv[2] else "true"
  }
  out
}
opts <- parse_args(commandArgs(trailingOnly = TRUE))
suite <- opts$suite %||% "quick"
threads <- as.integer(opts$threads %||% if (suite == "quick") 4L else 8L)
reps <- as.integer(opts$reps %||% if (suite == "quick") 1L else 3L)
out_file <- opts$out %||% file.path("bench", "results", "results.csv")
# The README suite compares ggumap with the umap package (uwot for reference).
default_contenders <- if (suite == "readme") {
  c("ggumap-0.5", "uwot", "umap-naive")
} else {
  names(contenders)
}
use <- if (is.null(opts$contenders)) {
  default_contenders
} else {
  strsplit(opts$contenders, ",")[[1]]
}
stopifnot(all(use %in% names(contenders)))

# ---- plan ----------------------------------------------------------------------

datasets <- switch(
  suite,
  quick = list(
    list(name = "iris", load = bench_iris),
    list(name = "penguins", load = bench_penguins),
    list(name = "blobs", n = 1000, load = function() bench_blobs(1000)),
    list(name = "blobs", n = 5000, load = function() bench_blobs(5000)),
    list(name = "blobs", n = 10000, load = function() bench_blobs(10000))
  ),
  full = c(
    list(
      list(name = "iris", load = bench_iris),
      list(name = "penguins", load = bench_penguins)
    ),
    lapply(c(1000, 5000, 10000, 25000, 50000, 100000), function(n) {
      list(name = "blobs", n = n, load = function() bench_blobs(n))
    }),
    list(
      list(name = "mnist", n = 10000, load = function() bench_mnist(10000)),
      list(
        name = "mnist",
        n = 70000,
        load = function() bench_mnist(),
        save_embedding = TRUE
      )
    )
  ),
  # ggumap vs the umap package (and uwot for reference), for the README.
  readme = lapply(c(1000, 2500, 5000, 10000, 20000), function(n) {
    list(name = "blobs", n = n, load = function() bench_blobs(n))
  }),
  stop("unknown suite: ", suite)
)

# Thread scaling (full suite only): one dataset, several thread counts.
scaling <- if (suite == "full") {
  list(
    data = list(name = "blobs", n = 50000, load = function() {
      bench_blobs(50000)
    }),
    threads = c(1L, 2L, 4L, 8L),
    contenders = intersect(
      c("ggumap-0.5", "ggumap-0.6", "uwot", "umap-learn-0.6"),
      use
    )
  )
}

# ---- one measurement in a fresh process ----------------------------------------

child <- function(contender, data_file, threads, seed, emb_file) {
  source("bench/contenders.R")
  spec <- contenders[[contender]]
  spec$setup()
  x <- readRDS(data_file)$x
  # Never time a cache hit: ggumap caches results in memory.
  options(ggumap.cache_size = 0L)
  # Untimed warm-up: loads libraries, starts thread pools and JIT-compiles
  # numba code. umap-learn only uses (and compiles) PyNNDescent above 4096
  # rows, so warm up on up to 5000 rows, with another seed than the timed run.
  invisible(spec$run(
    x[seq_len(min(5000, nrow(x))), , drop = FALSE],
    threads,
    seed + 1000L
  ))
  gc()
  baseline <- ps::ps_memory_info()[["rss"]]
  start <- proc.time()[["elapsed"]]
  emb <- spec$run(x, threads, seed)
  seconds <- proc.time()[["elapsed"]] - start
  saveRDS(unname(as.matrix(emb)), emb_file)
  list(
    seconds = seconds,
    baseline = baseline,
    version = contender_versions(contender)
  )
}

measure <- function(contender, data_file, threads, seed, timeout = 3600) {
  emb_file <- tempfile(fileext = ".rds")
  proc <- callr::r_bg(
    child,
    args = list(contender, data_file, threads, seed, emb_file),
    wd = getwd(),
    supervise = TRUE,
    package = FALSE
  )
  handle <- proc$as_ps_handle()
  peak <- 0
  start <- Sys.time()
  while (proc$is_alive()) {
    rss <- tryCatch(ps::ps_memory_info(handle)[["rss"]], error = function(e) NA)
    if (!is.na(rss)) {
      peak <- max(peak, rss)
    }
    if (as.numeric(Sys.time() - start, units = "secs") > timeout) {
      proc$kill()
      return(NULL)
    }
    Sys.sleep(0.02)
  }
  res <- tryCatch(proc$get_result(), error = function(e) {
    message("    failed: ", conditionMessage(e))
    NULL
  })
  if (is.null(res)) {
    return(NULL)
  }
  res$peak <- peak
  res$embedding <- readRDS(emb_file)
  unlink(emb_file)
  res
}

# ---- machine info ----------------------------------------------------------------

machine <- list(
  date = format(Sys.time(), "%Y-%m-%d"),
  os = paste(Sys.info()[["sysname"]], Sys.info()[["release"]]),
  cpu = tryCatch(
    if (Sys.info()[["sysname"]] == "Darwin") {
      system("sysctl -n machdep.cpu.brand_string", intern = TRUE)
    } else {
      sub(
        ".*: ",
        "",
        grep("model name", readLines("/proc/cpuinfo"), value = TRUE)[1]
      )
    },
    error = function(e) NA_character_
  ),
  cores = parallel::detectCores(),
  r = paste(R.version$major, R.version$minor, sep = "."),
  rustc = tryCatch(
    system("rustc --version", intern = TRUE),
    error = function(e) NA_character_
  )
)

# ---- run -----------------------------------------------------------------------

dir.create(dirname(out_file), showWarnings = FALSE, recursive = TRUE)
emb_dir <- file.path(dirname(out_file), "embeddings")
dir.create(emb_dir, showWarnings = FALSE)

# Append each measurement as soon as it is done, so interrupted runs keep
# their results.
append_result <- function(row) {
  header <- !file.exists(out_file)
  utils::write.table(
    row,
    out_file,
    sep = ",",
    row.names = FALSE,
    col.names = header,
    append = !header
  )
}

run_dataset <- function(ds, contenders_to_run, thread_counts, experiment) {
  data <- ds[["load"]]()
  n <- nrow(data$x)
  data_file <- tempfile(fileext = ".rds")
  saveRDS(data, data_file)
  on.exit(unlink(data_file))
  sub <- quality_subsample(n)
  label <- paste0(ds[["name"]], if (!is.null(ds[["n"]])) paste0("-", ds[["n"]]))
  rows <- list()
  for (contender in contenders_to_run) {
    if (n > contenders[[contender]]$max_n) {
      next
    }
    ths <- if (isTRUE(contenders[[contender]]$single_threaded)) {
      1L
    } else {
      thread_counts
    }
    for (th in ths) {
      for (rep in seq_len(reps)) {
        message(sprintf(
          "%-10s %-16s threads=%d rep=%d",
          label,
          contender,
          th,
          rep
        ))
        res <- measure(contender, data_file, th, seed = rep)
        if (is.null(res)) {
          next
        }
        q <- embedding_quality(
          data$x[sub, , drop = FALSE],
          res$embedding[sub, , drop = FALSE],
          data$labels[sub]
        )
        message(sprintf(
          "    %.2fs, peak %.0f MB, trust %.3f, accuracy %.3f",
          res$seconds,
          res$peak / 2^20,
          q$trustworthiness,
          q$knn_accuracy
        ))
        if (isTRUE(ds[["save_embedding"]]) && rep == 1) {
          keep <- quality_subsample(n, 10000)
          saveRDS(
            data.frame(
              contender = contender,
              x = res$embedding[keep, 1],
              y = res$embedding[keep, 2],
              label = data$labels[keep]
            ),
            file.path(emb_dir, paste0(label, "-", contender, ".rds"))
          )
        }
        row <- data.frame(
          experiment = experiment,
          suite = suite,
          dataset = ds[["name"]],
          n = n,
          p = ncol(data$x),
          contender = contender,
          version = res$version,
          threads = th,
          rep = rep,
          seconds = res$seconds,
          peak_mb = res$peak / 2^20,
          extra_mb = (res$peak - res$baseline) / 2^20,
          trustworthiness = q$trustworthiness,
          knn_recall = q$knn_recall,
          knn_accuracy = q$knn_accuracy,
          as.data.frame(machine)
        )
        append_result(row)
        rows[[length(rows) + 1]] <- row
      }
    }
  }
  do.call(rbind, rows)
}

# The README suite times every multi-threaded contender with 1 thread too.
dataset_threads <- if (suite == "readme") unique(c(1L, threads)) else threads
results <- list()
for (ds in datasets) {
  results[[length(results) + 1]] <- run_dataset(
    ds,
    use,
    dataset_threads,
    "datasets"
  )
}
if (!is.null(scaling)) {
  results[[length(results) + 1]] <- run_dataset(
    scaling$data,
    scaling$contenders,
    scaling$threads,
    "scaling"
  )
}
results <- do.call(rbind, results)

message("Wrote ", nrow(results), " rows to ", out_file)

# Copy the latest results for the benchmark article.
article_dir <- file.path("vignettes", "articles")
if (suite == "full" && dir.exists(article_dir)) {
  file.copy(
    out_file,
    file.path(article_dir, "benchmark-results.csv"),
    overwrite = TRUE
  )
  embs <- list.files(
    emb_dir,
    pattern = "^mnist-70000-.*\\.rds$",
    full.names = TRUE
  )
  if (length(embs)) {
    all <- do.call(rbind, lapply(embs, readRDS))
    utils::write.csv(
      all,
      file.path(article_dir, "benchmark-mnist-embeddings.csv"),
      row.names = FALSE
    )
  }
}

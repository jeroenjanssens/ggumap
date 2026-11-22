# The shared computational engine behind stat_umap() and umap_embed().

# Largest magnitude whose squared distances stay finite in single precision.
float_limit <- 1e15

# Smallest number of complete observations UMAP can embed.
umap_min_rows <- 3L

# Select feature columns with tidyselect and return a double matrix.
select_features <- function(data, features, call = caller_env()) {
  data <- data[setdiff(names(data), c("PANEL", "group", ".umap_row"))]
  loc <- tidyselect::eval_select(
    features,
    data,
    allow_rename = FALSE,
    error_call = call
  )
  if (length(loc) == 0) {
    cli::cli_abort(
      c(
        "No feature columns were selected.",
        i = "Use {.arg features} to select the numeric columns to embed."
      ),
      call = call
    )
  }
  cols <- data[loc]
  bad <- !vapply(cols, function(x) is.numeric(x) || is.logical(x), logical(1))
  if (any(bad)) {
    cli::cli_abort(
      c(
        "Feature columns must be numeric.",
        x = "{cli::qty(sum(bad))}Column{?s} {.field {names(cols)[bad]}} {?is/are} not.",
        i = "Convert categorical columns first, e.g. with {.fn model.matrix}."
      ),
      call = call
    )
  }
  mat <- matrix(
    as.double(unlist(cols, use.names = FALSE)),
    nrow = nrow(data),
    ncol = length(cols),
    dimnames = list(NULL, names(cols))
  )
  mat
}

# Standardise columns; constant columns become zero instead of NaN.
scale_features <- function(x) {
  centre <- colMeans(x)
  x <- sweep(x, 2, centre)
  sds <- sqrt(colSums(x^2) / max(nrow(x) - 1, 1))
  sds[sds == 0] <- 1
  sweep(x, 2, sds, "/")
}

# Run UMAP on a complete, finite double matrix. Returns a list with
# `embedding` (n x n_components) and `knn_dist` (mean distance to the
# neighbours in input space), or NULL when there are too few rows.
umap_compute <- function(x, args, seed, call = caller_env()) {
  n <- nrow(x)
  if (any(is.infinite(x))) {
    cli::cli_abort(
      "Feature values must be finite; found {.val {Inf}}.",
      call = call
    )
  }
  if (n < umap_min_rows) {
    cli::cli_warn(
      "UMAP needs at least {umap_min_rows} complete observations, not {n}.",
      call = call
    )
    return(NULL)
  }
  if (args$scale) {
    x <- scale_features(x)
  }
  if (max(abs(x)) > float_limit) {
    cli::cli_abort(
      c(
        "Feature values are too large for single-precision floating point.",
        i = "Rescale the features, e.g. with {.code scale = TRUE}."
      ),
      call = call
    )
  }
  n_neighbors <- args$n_neighbors
  if (n_neighbors >= n) {
    cli::cli_warn(
      c(
        "{.arg n_neighbors} ({n_neighbors}) must be smaller than the number of observations ({n}).",
        i = "Using {.code n_neighbors = {n - 1L}} instead."
      ),
      call = call
    )
    n_neighbors <- n - 1L
  }
  if (args$n_components >= n) {
    cli::cli_abort(
      "{.arg n_components} ({args$n_components}) must be smaller than the number of observations ({n}).",
      call = call
    )
  }
  if (args$metric == "haversine" && ncol(x) != 2) {
    cli::cli_abort(
      "The {.val haversine} metric needs exactly 2 features (latitude and longitude, in radians), not {ncol(x)}.",
      call = call
    )
  }
  params <- rust_params(args, seed = seed, n_neighbors = n_neighbors)

  key <- hash(list(x, params))
  cached <- cache_get(key)
  if (!is.null(cached)) {
    return(cached)
  }
  res <- run_umap(x, params, progress = args$control$progress, call = call)
  out <- list(
    embedding = res$embedding,
    knn_dist = mean_knn_dist(res$knn_indices, res$knn_distances)
  )
  cache_set(key, out)
  out
}

# Mean distance to the neighbours, excluding the point itself.
mean_knn_dist <- function(idx, dist) {
  self <- idx == row(idx)
  dist[self | is.na(idx)] <- NA
  out <- rowMeans(dist, na.rm = TRUE)
  out[is.nan(out)] <- NA
  out
}

# Call into Rust, translating interrupts and errors into R conditions.
run_umap <- function(x, params, progress = TRUE, call = caller_env()) {
  storage.mode(x) <- "double"
  dimnames(x) <- NULL
  callback <- NULL
  if (progress) {
    stage <- ""
    id <- cli::cli_progress_bar(
      format = "UMAP: {stage} {cli::pb_bar} {cli::pb_percent}",
      total = 100,
      clear = TRUE,
      auto_terminate = FALSE,
      .envir = environment()
    )
    callback <- function(fraction, label) {
      stage <<- label
      cli::cli_progress_update(id = id, set = round(100 * fraction))
    }
  }
  counter$calls <- counter$calls + 1L
  res <- umap_rs(x, params, callback)
  if (progress) {
    cli::cli_progress_done(id = id)
  }
  if (is.character(res)) {
    if (identical(res, "interrupt")) {
      rlang::interrupt()
    }
    cli::cli_abort(
      c("UMAP failed.", x = "{sub('^error: ', '', res)}"),
      call = call,
      class = "ggumap_error_rust"
    )
  }
  res
}

# Resolve a seed: integers pass through, NULL draws one from R's RNG, and NA
# derives one from `key` so that results are stable but data-dependent.
resolve_seed <- function(seed, key = NULL) {
  if (is.null(seed)) {
    return(sample.int(.Machine$integer.max, 1L))
  }
  if (identical(seed, NA) || (is.numeric(seed) && is.na(seed))) {
    hex <- substr(hash(key), 1, 7)
    return(strtoi(hex, 16L))
  }
  as.double(seed)
}

hash <- function(x) rlang::hash(x)

#' Number of threads used by UMAP
#'
#' Returns the default number of threads for UMAP computations. This is the
#' option `ggumap.n_threads` or the environment variable `GGUMAP_NUM_THREADS`
#' if set, and half of the available cores otherwise. It is limited to 2 when
#' `_R_CHECK_LIMIT_CORES_` is set (as during `R CMD check`).
#'
#' With `flavour = "0.5"` results are only bit-for-bit reproducible when
#' `n_threads = 1`. With `flavour = "0.6"` they are reproducible for a given
#' number of threads.
#'
#' @return A positive integer.
#' @export
#' @examples
#' umap_threads()
#'
#' # Use a single thread for this session:
#' # options(ggumap.n_threads = 1)
umap_threads <- function() {
  available <- umap_rs_info()$max_threads
  n <- getOption("ggumap.n_threads")
  if (is.null(n)) {
    env <- Sys.getenv("GGUMAP_NUM_THREADS")
    n <- if (nzchar(env)) suppressWarnings(as.integer(env)) else NA_integer_
    if (is.na(n)) {
      n <- max(1L, available %/% 2L)
    }
  }
  n <- max(1L, as.integer(n))
  limit <- Sys.getenv("_R_CHECK_LIMIT_CORES_")
  if (nzchar(limit) && !identical(toupper(limit), "FALSE")) {
    n <- min(n, 2L)
  }
  n
}

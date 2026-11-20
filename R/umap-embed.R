#' Compute a UMAP embedding
#'
#' Embeds the rows of a data frame or matrix in a low-dimensional space with
#' Uniform Manifold Approximation and Projection (UMAP). This is the engine
#' behind [stat_umap()], made available for use outside of plots.
#'
#' @param data A data frame or a numeric matrix with observations in rows.
#' @param features <[`tidy-select`][tidyselect::language]> Columns of `data`
#'   to use as input. Defaults to all numeric columns. Ignored when `data` is
#'   a matrix.
#' @param ... These dots are for future extensions and must be empty.
#' @param n_neighbors Size of the local neighbourhood (number of nearest
#'   neighbours). Larger values preserve more global structure.
#' @param n_components Dimension of the embedding.
#' @param min_dist Minimum distance between embedded points. Smaller values
#'   give tighter clusters.
#' @param spread Scale of the embedded points; together with `min_dist` it
#'   determines how clumped the embedding is.
#' @param metric Distance metric in the input space, for example
#'   `"euclidean"` (default), `"cosine"`, `"manhattan"` or `"correlation"`.
#' @param n_epochs Number of optimisation epochs. `NULL` uses the default
#'   (500 for small, 200 for large data sets).
#' @param init Initialisation of the embedding: `"auto"` (spectral for
#'   `flavour = "0.5"`, recursive for `"0.6"`), `"spectral"`, `"tswspectral"`,
#'   `"pca"`, `"random"` or `"recursive"`.
#' @param flavour Which umap-learn pipeline to reproduce. `"0.5"` (default) is
#'   the established algorithm: spectral initialisation and stochastic
#'   gradient descent. `"0.6"` uses recursive initialisation and the Adam
#'   optimiser, and is deterministic for a fixed number of threads.
#' @param scale Standardise each feature to zero mean and unit variance
#'   before embedding? Recommended when features have different units.
#' @param seed Random seed. `NULL` (default) draws one from R's random number
#'   generator, so [set.seed()] makes results reproducible. See
#'   [umap_threads()] for the role of the number of threads.
#' @param n_threads Number of threads. Defaults to [umap_threads()].
#' @param control Advanced parameters created by [umap_control()].
#'
#' @return A data frame with one row per row of `data`, and the columns
#'   `UMAP1`, ..., `UMAP<n_components>` and `knn_dist` (the mean distance of
#'   the observation to its nearest neighbours in input space). Rows with
#'   missing feature values are `NA`.
#' @export
#' @examples
#' emb <- umap_embed(iris, Sepal.Length:Petal.Width, seed = 1, n_threads = 1)
#' head(emb)
#'
#' # Matrices work too
#' emb <- umap_embed(as.matrix(iris[1:4]), seed = 1, n_threads = 1)
umap_embed <- function(
  data,
  features = where(is.numeric),
  ...,
  n_neighbors = 15L,
  n_components = 2L,
  min_dist = 0.1,
  spread = 1,
  metric = "euclidean",
  n_epochs = NULL,
  init = "auto",
  flavour = c("0.5", "0.6"),
  scale = FALSE,
  seed = NULL,
  n_threads = umap_threads(),
  control = umap_control()
) {
  check_dots_empty()
  flavour <- arg_match(flavour)
  if (identical(seed, NA)) {
    cli::cli_abort(
      "{.arg seed} must be a whole number or {.code NULL}, not {.code NA}."
    )
  }
  args <- check_umap_args(
    n_neighbors = n_neighbors,
    n_components = n_components,
    min_dist = min_dist,
    spread = spread,
    metric = metric,
    n_epochs = n_epochs,
    init = init,
    flavour = flavour,
    scale = scale,
    seed = seed,
    n_threads = n_threads,
    control = control
  )

  if (is.matrix(data)) {
    if (!is.numeric(data) && !is.logical(data)) {
      cli::cli_abort("{.arg data} must be a numeric matrix.")
    }
    x <- data
    storage.mode(x) <- "double"
  } else if (is.data.frame(data)) {
    x <- select_features(data, enquo(features))
  } else {
    cli::cli_abort(
      "{.arg data} must be a data frame or a matrix, not {.obj_type_friendly {data}}."
    )
  }

  complete <- stats::complete.cases(x)
  if (!all(complete)) {
    cli::cli_warn(
      "{sum(!complete)} row{?s} with missing feature values {?was/were} not embedded."
    )
  }
  res <- umap_compute(
    x[complete, , drop = FALSE],
    args,
    seed = resolve_seed(seed)
  )

  k <- args$n_components
  out <- matrix(NA_real_, nrow = nrow(x), ncol = k)
  knn_dist <- rep(NA_real_, nrow(x))
  if (!is.null(res)) {
    out[complete, ] <- res$embedding
    knn_dist[complete] <- res$knn_dist
  }
  colnames(out) <- paste0("UMAP", seq_len(k))
  out <- as.data.frame(out)
  out$knn_dist <- knn_dist
  if (is.data.frame(data) && .row_names_info(data) > 0) {
    rownames(out) <- rownames(data)
  } else if (is.matrix(data) && !is.null(rownames(data))) {
    rownames(out) <- rownames(data)
  }
  out
}

#' Advanced UMAP parameters
#'
#' Rarely needed knobs of the UMAP algorithm. Pass the result to the
#' `control` argument of [stat_umap()], [geom_umap()] or [umap_embed()].
#'
#' @param learning_rate Initial learning rate of the layout optimisation.
#' @param negative_sample_rate Number of negative samples per positive sample.
#' @param repulsion_strength Weight of negative samples (`gamma` in umap-learn).
#' @param local_connectivity Number of nearest neighbours assumed to be
#'   connected at a local level.
#' @param set_op_mix_ratio Mix between fuzzy union (`1`) and fuzzy
#'   intersection (`0`) when symmetrising the neighbour graph.
#' @param a,b Parameters of the low-dimensional similarity curve. `NULL`
#'   (default) derives them from `min_dist` and `spread`.
#' @param optimizer `NULL` (default for the chosen `flavour`), `"sgd"`,
#'   `"momentum"` or `"adam"`. Momentum and Adam require `flavour = "0.6"`.
#' @param disconnection_distance Distance at or above which points are
#'   considered disconnected. `NULL` uses the metric's default.
#' @param progress Show a progress bar for long computations? Defaults to the
#'   option `ggumap.progress` (`TRUE` if unset). Bars appear only after a
#'   couple of seconds.
#'
#' @return A list of class `ggumap_control`.
#' @export
#' @examples
#' umap_control(negative_sample_rate = 10)
umap_control <- function(
  learning_rate = 1,
  negative_sample_rate = 5L,
  repulsion_strength = 1,
  local_connectivity = 1,
  set_op_mix_ratio = 1,
  a = NULL,
  b = NULL,
  optimizer = NULL,
  disconnection_distance = NULL,
  progress = getOption("ggumap.progress", TRUE)
) {
  check_number_decimal(learning_rate, min = 0, allow_infinite = FALSE)
  check_number_whole(negative_sample_rate, min = 0)
  check_number_decimal(repulsion_strength, min = 0, allow_infinite = FALSE)
  check_number_decimal(local_connectivity, min = 0, allow_infinite = FALSE)
  check_number_decimal(set_op_mix_ratio, min = 0, max = 1)
  check_number_decimal(a, min = 0, allow_infinite = FALSE, allow_null = TRUE)
  check_number_decimal(b, min = 0, allow_infinite = FALSE, allow_null = TRUE)
  if (!is.null(optimizer)) {
    optimizer <- arg_match0(optimizer, c("sgd", "momentum", "adam"))
  }
  check_number_decimal(
    disconnection_distance,
    min = 0,
    allow_null = TRUE
  )
  check_bool(progress)
  structure(
    list(
      learning_rate = learning_rate,
      negative_sample_rate = negative_sample_rate,
      repulsion_strength = repulsion_strength,
      local_connectivity = local_connectivity,
      set_op_mix_ratio = set_op_mix_ratio,
      a = a,
      b = b,
      optimizer = optimizer,
      disconnection_distance = disconnection_distance,
      progress = progress
    ),
    class = "ggumap_control"
  )
}

#' @export
print.ggumap_control <- function(x, ...) {
  cli::cli_text("{.cls ggumap_control}")
  values <- vapply(
    x,
    function(v) if (is.null(v)) "NULL" else format(v),
    character(1)
  )
  cli::cli_dl(values)
  invisible(x)
}

# Metrics implemented by the Rust NNDescent port (input-space distances).
umap_metrics <- c(
  "euclidean",
  "sqeuclidean",
  "manhattan",
  "chebyshev",
  "minkowski",
  "cosine",
  "correlation",
  "canberra",
  "braycurtis",
  "hellinger",
  "haversine",
  "hamming",
  "jaccard",
  "dice",
  "matching",
  "rogerstanimoto",
  "russellrao",
  "sokalmichener",
  "sokalsneath",
  "yule"
)

umap_inits <- c("auto", "spectral", "tswspectral", "pca", "random", "recursive")

umap_flavours <- c("0.5", "0.6")

# Validate the user-facing arguments shared by stat_umap(), geom_umap() and
# umap_embed(). Returns a list of validated values. `seed` is checked but not
# resolved here, because its meaning differs between the stat and umap_embed().
check_umap_args <- function(
  n_neighbors,
  n_components,
  min_dist,
  spread,
  metric,
  n_epochs,
  init,
  flavour,
  scale,
  seed,
  n_threads,
  control,
  call = caller_env()
) {
  check_number_whole(n_neighbors, min = 2, call = call)
  check_number_whole(n_components, min = 1, call = call)
  check_number_decimal(
    spread,
    min = 0,
    allow_infinite = FALSE,
    call = call
  )
  if (spread == 0) {
    cli::cli_abort("{.arg spread} must be positive.", call = call)
  }
  check_number_decimal(min_dist, min = 0, allow_infinite = FALSE, call = call)
  if (min_dist > spread) {
    cli::cli_abort(
      "{.arg min_dist} ({min_dist}) must not exceed {.arg spread} ({spread}).",
      call = call
    )
  }
  metric <- arg_match0(metric, umap_metrics, error_call = call)
  check_number_whole(n_epochs, min = 1, allow_null = TRUE, call = call)
  init <- arg_match0(init, umap_inits, error_call = call)
  flavour <- arg_match0(flavour, umap_flavours, error_call = call)
  check_bool(scale, call = call)
  if (!is.null(seed) && !identical(seed, NA)) {
    if (
      !is_scalar_double(seed) &&
        !is_scalar_integer(seed) ||
        is.na(seed) ||
        seed < 0 ||
        seed != trunc(seed)
    ) {
      cli::cli_abort(
        "{.arg seed} must be a non-negative whole number, {.code NA} or {.code NULL}, not {.obj_type_friendly {seed}}.",
        call = call
      )
    }
  }
  check_number_whole(n_threads, min = 1, call = call)
  if (!inherits(control, "ggumap_control")) {
    cli::cli_abort(
      "{.arg control} must be created with {.fn umap_control}, not {.obj_type_friendly {control}}.",
      call = call
    )
  }
  if (
    flavour == "0.5" &&
      !is.null(control$optimizer) &&
      control$optimizer != "sgd"
  ) {
    cli::cli_abort(
      c(
        "The {.val {control$optimizer}} optimizer requires {.code flavour = \"0.6\"}.",
        i = "{.code flavour = \"0.5\"} always uses SGD."
      ),
      call = call
    )
  }
  list(
    n_neighbors = as.integer(n_neighbors),
    n_components = as.integer(n_components),
    min_dist = min_dist,
    spread = spread,
    metric = metric,
    n_epochs = if (!is.null(n_epochs)) as.integer(n_epochs),
    init = init,
    flavour = flavour,
    scale = scale,
    seed = seed,
    n_threads = as.integer(n_threads),
    control = control
  )
}

# Flatten validated arguments into the list consumed by the Rust side.
rust_params <- function(args, seed, n_neighbors = args$n_neighbors) {
  ctrl <- args$control
  list(
    n_components = args$n_components,
    n_neighbors = n_neighbors,
    min_dist = args$min_dist,
    spread = args$spread,
    metric = args$metric,
    n_epochs = args$n_epochs,
    init = args$init,
    compatibility_layout = args$flavour == "0.5",
    seed = seed,
    n_threads = args$n_threads,
    learning_rate = ctrl$learning_rate,
    negative_sample_rate = ctrl$negative_sample_rate,
    repulsion_strength = ctrl$repulsion_strength,
    local_connectivity = ctrl$local_connectivity,
    set_op_mix_ratio = ctrl$set_op_mix_ratio,
    a = ctrl$a,
    b = ctrl$b,
    optimizer = ctrl$optimizer,
    disconnection_distance = ctrl$disconnection_distance
  )
}

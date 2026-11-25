#' UMAP embeddings as a ggplot2 layer
#'
#' `stat_umap()` embeds the rows of the layer data in two dimensions with
#' Uniform Manifold Approximation and Projection (UMAP) and positions them at
#' the embedded coordinates. `geom_umap()` is a shortcut for
#' `stat_umap(geom = "point")`. Any other geom can render the embedding, e.g.
#' `stat_umap(geom = "text")` or `stat_umap(geom = "density_2d")`.
#'
#' Feature columns are selected with `features`, using the same syntax as
#' [dplyr::select()], from the layer data. Aesthetics such as `colour`,
#' `shape` or `label` are carried along row by row; they never split the
#' computation into separate embeddings.
#'
#' @section Computed variables:
#' \describe{
#'   \item{`after_stat(UMAP1)`, `after_stat(UMAP2)`}{Embedding coordinates,
#'     mapped to `x` and `y` by default.}
#'   \item{`after_stat(knn_dist)`}{Mean distance of each observation to its
#'     nearest neighbours in input space; large values indicate outliers.}
#'   \item{`after_stat(row)`}{Row number of the observation in the layer data.}
#' }
#'
#' @section Reproducibility and caching:
#' By default (`seed = NA`) the random seed is derived from the data and the
#' parameters. A plot therefore looks the same every time it is drawn, and
#' several layers of the same data share one embedding. Use an integer seed
#' to choose another layout, or `NULL` for a new random layout on every draw.
#'
#' Results are cached in memory (see [umap_cache_clear()]), so printing,
#' resizing or saving a plot does not recompute the embedding.
#'
#' With `flavour = "0.5"` and more than one thread, the optimisation is
#' parallel and not bit-for-bit reproducible across sessions; use
#' `n_threads = 1` or `flavour = "0.6"` if you need exact reproducibility.
#'
#' @inheritParams ggplot2::stat_identity
#' @inheritParams umap_embed
#' @param geom The geometric object to display the embedding, as a string
#'   (e.g. `"point"`, `"text"`, `"label"`) or a `Geom` object.
#' @param features <[`tidy-select`][tidyselect::language]> Columns of the
#'   layer data to use as UMAP input. Defaults to all numeric columns.
#'   Columns used by mapped aesthetics are only included if they are
#'   selected too.
#' @param scope `"layer"` (default) computes one embedding for the whole layer;
#'   facets then show subsets of the same embedding. `"panel"` computes a
#'   separate embedding for every facet panel.
#' @param seed Random seed: `NA` (default) derives it from the data, an
#'   integer fixes it, and `NULL` draws a new one every time the plot is
#'   built.
#' @param na.rm If `FALSE` (default), rows with missing feature values are
#'   removed with a warning. If `TRUE`, they are removed silently.
#' @param ... Other arguments passed on to [ggplot2::layer()], such as
#'   aesthetics like `colour = "red"` or `size = 3`, or geom parameters.
#'
#' @return A ggplot2 layer.
#' @export
#' @examplesIf rlang::is_installed("palmerpenguins")
#' library(ggplot2)
#' penguins <- na.omit(palmerpenguins::penguins)
#'
#' # Select the features (all numeric columns by default), standardise them,
#' # since they are measured in different units, and remove the meaningless
#' # axes
#' ggplot(penguins, aes(colour = species)) +
#'   geom_umap(features = bill_length_mm:body_mass_g, scale = TRUE) +
#'   theme_umap()
#'
#' # One embedding, faceted (reuses the embedding computed above)
#' ggplot(penguins, aes(colour = species)) +
#'   geom_umap(features = bill_length_mm:body_mass_g, scale = TRUE) +
#'   facet_wrap(vars(species))
#'
#' # Several layers share one embedding
#' ggplot(mtcars, aes(label = rownames(mtcars), colour = factor(cyl))) +
#'   geom_umap(scale = TRUE, n_neighbors = 5) +
#'   stat_umap(geom = "text", scale = TRUE, n_neighbors = 5, vjust = -0.6, size = 3)
#'
#' # Geoms with their own statistic (densities, binning) need umap_embed();
#' # see its examples
stat_umap <- function(
  mapping = NULL,
  data = NULL,
  geom = "point",
  position = "identity",
  ...,
  features = where(is.numeric),
  n_neighbors = 15L,
  min_dist = 0.1,
  spread = 1,
  metric = "euclidean",
  n_epochs = NULL,
  init = "auto",
  flavour = c("0.5", "0.6"),
  scale = FALSE,
  scope = c("layer", "panel"),
  seed = NA,
  n_threads = umap_threads(),
  control = umap_control(),
  na.rm = FALSE,
  show.legend = NA,
  inherit.aes = TRUE
) {
  new_umap_layer(
    mapping = mapping,
    data = data,
    geom = geom,
    position = position,
    dots = list2(...),
    features = enquo(features),
    n_neighbors = n_neighbors,
    min_dist = min_dist,
    spread = spread,
    metric = metric,
    n_epochs = n_epochs,
    init = init,
    flavour = flavour,
    scale = scale,
    scope = scope,
    seed = seed,
    n_threads = n_threads,
    control = control,
    na.rm = na.rm,
    show.legend = show.legend,
    inherit.aes = inherit.aes
  )
}

#' @rdname stat_umap
#' @export
geom_umap <- function(
  mapping = NULL,
  data = NULL,
  position = "identity",
  ...,
  features = where(is.numeric),
  n_neighbors = 15L,
  min_dist = 0.1,
  spread = 1,
  metric = "euclidean",
  n_epochs = NULL,
  init = "auto",
  flavour = c("0.5", "0.6"),
  scale = FALSE,
  scope = c("layer", "panel"),
  seed = NA,
  n_threads = umap_threads(),
  control = umap_control(),
  na.rm = FALSE,
  show.legend = NA,
  inherit.aes = TRUE
) {
  new_umap_layer(
    mapping = mapping,
    data = data,
    geom = "point",
    position = position,
    dots = list2(...),
    features = enquo(features),
    n_neighbors = n_neighbors,
    min_dist = min_dist,
    spread = spread,
    metric = metric,
    n_epochs = n_epochs,
    init = init,
    flavour = flavour,
    scale = scale,
    scope = scope,
    seed = seed,
    n_threads = n_threads,
    control = control,
    na.rm = na.rm,
    show.legend = show.legend,
    inherit.aes = inherit.aes
  )
}

# Validate the arguments of stat_umap() / geom_umap() and build the layer.
# Errors are reported in terms of the user-facing constructor (`call`).
new_umap_layer <- function(
  mapping,
  data,
  geom,
  position,
  dots,
  features,
  n_neighbors,
  min_dist,
  spread,
  metric,
  n_epochs,
  init,
  flavour,
  scale,
  scope,
  seed,
  n_threads,
  control,
  na.rm,
  show.legend,
  inherit.aes,
  call = caller_env()
) {
  check_umap_geom(geom, call = call)
  flavour <- arg_match(flavour, umap_flavours, error_call = call)
  scope <- arg_match(scope, c("layer", "panel"), error_call = call)
  check_bool(na.rm, call = call)
  args <- check_umap_args(
    n_neighbors = n_neighbors,
    n_components = 2L,
    min_dist = min_dist,
    spread = spread,
    metric = metric,
    n_epochs = n_epochs,
    init = init,
    flavour = flavour,
    scale = scale,
    seed = seed,
    n_threads = n_threads,
    control = control,
    call = call
  )
  umap_layer(
    mapping = mapping,
    data = data,
    geom = geom,
    position = position,
    show.legend = show.legend,
    inherit.aes = inherit.aes,
    params = c(
      list(features = features, umap = args, scope = scope, na.rm = na.rm),
      dots
    )
  )
}

# Build a regular layer, then derive a LayerUmap from it. The child layer
# selects the feature columns from the raw layer data before the stat runs
# (the stat itself only sees evaluated aesthetics). ggplot2 does not export
# its Layer class, so the instance returned by layer() acts as the parent.
umap_layer <- function(
  mapping,
  data,
  geom,
  position,
  show.legend,
  inherit.aes,
  params
) {
  parent <- ggplot2::layer(
    data = data,
    mapping = mapping,
    stat = StatUmap,
    geom = geom,
    position = position,
    show.legend = show.legend,
    inherit.aes = inherit.aes,
    params = params
  )
  ggplot2::ggproto(
    "LayerUmap",
    parent,
    setup_layer = function(self, data, plot) {
      data <- ggplot2::ggproto_parent(parent, self)$setup_layer(data, plot)
      self$computed_mapping <- drop_position_mapping(
        self$computed_mapping,
        own = names(self$mapping)
      )
      # Tag every row before facets run: a layer without the facet variables
      # is copied into every panel, and each observation must be embedded
      # once, not once per copy.
      if (is.data.frame(data) && nrow(data) > 0) {
        data$.umap_row <- seq_len(nrow(data))
      }
      data
    },
    compute_aesthetics = function(self, data, plot) {
      evaled <- ggplot2::ggproto_parent(parent, self)$compute_aesthetics(
        data,
        plot
      )
      if (nrow(evaled) == 0) {
        return(evaled)
      }
      x <- select_features(
        data,
        self$stat_params$features,
        call = self$constructor %||% call("stat_umap")
      )
      colnames(x) <- paste0(".umap_f", seq_len(ncol(x)))
      evaled[colnames(x)] <- as.data.frame(x)
      evaled$.umap_row <- data$.umap_row %||% seq_len(nrow(data))
      evaled
    }
  )
}

# Geoms that only work with their own statistic (density estimation, binning,
# smoothing, summaries). ggplot2 runs one statistic per layer, so these cannot
# be combined with stat_umap().
stat_dependent_geoms <- c(
  "GeomDensity2d",
  "GeomDensity2dFilled",
  "GeomContour",
  "GeomContourFilled",
  "GeomHex",
  "GeomBin2d",
  "GeomSmooth",
  "GeomBoxplot",
  "GeomViolin"
)

check_umap_geom <- function(geom, call = caller_env()) {
  obj <- geom
  label <- NULL
  if (is_string(geom)) {
    parts <- strsplit(geom, "_", fixed = TRUE)[[1]]
    camel <- paste0(
      toupper(substring(parts, 1, 1)),
      substring(parts, 2),
      collapse = ""
    )
    obj <- get0(
      paste0("Geom", camel),
      envir = asNamespace("ggplot2"),
      inherits = FALSE
    )
    label <- geom
  }
  if (!inherits(obj, stat_dependent_geoms)) {
    return(invisible())
  }
  # Class name to snake case, e.g. GeomDensity2dFilled becomes density_2d_filled
  label <- label %||%
    tolower(gsub(
      "([a-z])([A-Z0-9])",
      "\\1_\\2",
      sub("^Geom", "", class(obj)[[1]])
    ))
  cli::cli_abort(
    c(
      "{.code geom = \"{label}\"} needs its own statistic, which can't be combined with {.fn stat_umap}.",
      i = paste(
        "Compute the embedding with {.fn umap_embed} and plot the result with the regular geom,",
        "e.g. {.code ggplot(umap_embed(data), aes(UMAP1, UMAP2)) + geom_{label}()}."
      )
    ),
    call = call
  )
}

# Position aesthetics are computed by the stat. Drop x and y unless they are
# mapped to computed variables; warn if they were mapped in this very layer.
drop_position_mapping <- function(mapping, own) {
  for (aes in c("x", "y")) {
    value <- mapping[[aes]]
    if (is.null(value) || is_computed_aes(value)) {
      next
    }
    if (aes %in% own) {
      cli::cli_warn(
        c(
          "Ignoring the {.field {aes}} aesthetic of {.fn stat_umap}.",
          i = "Positions come from the embedding; use {.code after_stat(UMAP1)} or {.code after_stat(UMAP2)} to map them explicitly."
        ),
        call = NULL
      )
    }
    mapping[[aes]] <- NULL
  }
  mapping
}

is_computed_aes <- function(x) {
  expr <- if (is_quosure(x)) quo_get_expr(x) else x
  if (is_call(expr, c("after_stat", "stat", "stage", "after_scale"))) {
    return(TRUE)
  }
  if (is_symbol(expr)) {
    return(grepl("^\\.\\.([a-zA-Z._]+)\\.\\.$", as_string(expr)))
  }
  FALSE
}

#' @rdname stat_umap
#' @format NULL
#' @usage NULL
#' @export
StatUmap <- ggplot2::ggproto(
  "StatUmap",
  ggplot2::Stat,
  default_aes = ggplot2::aes(
    x = ggplot2::after_stat(UMAP1),
    y = ggplot2::after_stat(UMAP2)
  ),

  extra_params = c("na.rm", "features", "umap", "scope"),

  compute_layer = function(self, data, params, layout) {
    feature_cols <- grepl("^\\.umap_f[0-9]+$", names(data))
    if (!any(feature_cols)) {
      cli::cli_abort(
        c(
          "{.fn stat_umap} could not find any feature columns.",
          i = "Use {.fn stat_umap} or {.fn geom_umap} rather than {.code stat = \"umap\"}."
        ),
        call = NULL
      )
    }
    # Row number in the layer data, also when facets copied rows to panels.
    data$row <- data$.umap_row %||% seq_len(nrow(data))
    data$.umap_row <- NULL
    if (identical(params$scope, "panel")) {
      panels <- vec_split(data, data$PANEL)
      out <- lapply(panels$val, function(panel) {
        self$compute_panel(
          panel,
          scales = NULL,
          umap = params$umap,
          na.rm = params$na.rm
        )
      })
      return(vec_rbind(!!!out))
    }
    # Embed every observation once, then give all its copies the same
    # coordinates.
    first <- !duplicated(data$row)
    embedded <- self$compute_panel(
      vec_slice(data, first),
      scales = NULL,
      umap = params$umap,
      na.rm = params$na.rm
    )
    if (all(first)) {
      return(embedded)
    }
    match_row <- match(data$row, embedded$row)
    keep <- !is.na(match_row)
    data <- vec_slice(data[!grepl("^\\.umap_f[0-9]+$", names(data))], keep)
    match_row <- match_row[keep]
    data$UMAP1 <- embedded$UMAP1[match_row]
    data$UMAP2 <- embedded$UMAP2[match_row]
    data$knn_dist <- embedded$knn_dist[match_row]
    data
  },

  compute_panel = function(
    data,
    scales,
    umap,
    features = NULL,
    scope = "layer",
    na.rm = FALSE
  ) {
    feature_cols <- grepl("^\\.umap_f[0-9]+$", names(data))
    x <- as.matrix(data[feature_cols])
    data <- data[!feature_cols]
    if (!is.double(x)) {
      storage.mode(x) <- "double"
    }

    complete <- stats::complete.cases(x)
    if (!all(complete)) {
      if (!na.rm) {
        cli::cli_warn(
          "Removed {sum(!complete)} row{?s} containing missing feature values ({.fn stat_umap}).",
          call = NULL
        )
      }
      data <- vec_slice(data, complete)
      x <- x[complete, , drop = FALSE]
    }

    params_key <- rust_params(umap, seed = NULL)
    seed <- resolve_seed(umap$seed, key = list(x, params_key))
    res <- umap_compute(x, umap, seed = seed, call = call("stat_umap"))
    if (is.null(res)) {
      return(vec_slice(data, 0L))
    }
    data$UMAP1 <- res$embedding[, 1]
    data$UMAP2 <- res$embedding[, 2]
    data$knn_dist <- res$knn_dist
    data
  },

  dropped_aes = c("weight")
)

# A small least-recently-used cache of UMAP results, keyed by a hash of the
# feature matrix and all parameters. ggplot2 rebuilds a plot every time it is
# printed, resized or saved, and several layers may embed the same data; the
# cache makes all of those share one computation.

cache <- new.env(parent = emptyenv())
cache$keys <- character()
cache$values <- list()

# Number of calls into Rust; used by the tests to verify cache hits.
counter <- new.env(parent = emptyenv())
counter$calls <- 0L

cache_size <- function() {
  n <- getOption("ggumap.cache_size", 16L)
  max(0L, as.integer(n))
}

cache_get <- function(key) {
  i <- match(key, cache$keys)
  if (is.na(i)) {
    return(NULL)
  }
  # Move to the front (most recently used).
  cache$keys <- c(key, cache$keys[-i])
  value <- cache$values[[i]]
  cache$values <- c(list(value), cache$values[-i])
  value
}

cache_set <- function(key, value) {
  size <- cache_size()
  if (size == 0L) {
    return(invisible(value))
  }
  i <- match(key, cache$keys)
  if (!is.na(i)) {
    cache$keys <- cache$keys[-i]
    cache$values <- cache$values[-i]
  }
  cache$keys <- utils::head(c(key, cache$keys), size)
  cache$values <- utils::head(c(list(value), cache$values), size)
  invisible(value)
}

#' Clear the UMAP cache
#'
#' UMAP results are cached in memory (by default the 16 most recent ones,
#' see the option `ggumap.cache_size`), so that re-drawing a plot, or drawing
#' several layers of the same data, does not recompute the embedding. This
#' function empties the cache.
#'
#' @return The number of removed entries, invisibly.
#' @export
#' @examples
#' umap_cache_clear()
umap_cache_clear <- function() {
  n <- length(cache$keys)
  cache$keys <- character()
  cache$values <- list()
  invisible(n)
}

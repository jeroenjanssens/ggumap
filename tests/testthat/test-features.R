test_that("all numeric columns are used by default", {
  df <- blobs(p = 4)
  df$chr <- "a"
  expect_equal(
    colnames(select_features(df, quo(where(is.numeric)))),
    paste0("f", 1:4)
  )
})

test_that("tidyselect syntax is supported", {
  df <- blobs(p = 4)
  sel <- function(...) colnames(select_features(df, quo(c(...))))
  expect_equal(sel(f1:f3), c("f1", "f2", "f3"))
  expect_equal(sel(starts_with("f") & !f2), c("f1", "f3", "f4"))
  expect_equal(sel(-label), paste0("f", 1:4))
  expect_equal(sel("f4", "f1"), c("f4", "f1"))
  cols <- c("f2", "f3")
  expect_equal(sel(tidyselect::all_of(cols)), cols)
})

test_that("ggplot2 internals are never features", {
  df <- blobs(p = 2)
  df$PANEL <- 1L
  df$group <- 1L
  expect_equal(
    colnames(select_features(df, quo(where(is.numeric)))),
    c("f1", "f2")
  )
})

test_that("features are taken from the layer data", {
  df <- blobs(p = 3)
  other <- blobs(p = 3, seed = 2)
  p <- ggplot2::ggplot(df) + geom_umap(data = other, features = f1:f3, seed = 1)
  ld <- layer_data(p)
  expect_equal(ld$UMAP1, umap_embed(other, f1:f3, seed = 1)$UMAP1)
})

test_that("aesthetics are not features unless selected", {
  df <- blobs(p = 3)
  df$size <- seq_len(nrow(df))
  p1 <- ggplot2::ggplot(df, ggplot2::aes(size = size)) +
    geom_umap(features = f1:f3, seed = 1)
  p2 <- ggplot2::ggplot(df) + geom_umap(features = f1:f3, seed = 1)
  expect_equal(layer_data(p1)$UMAP1, layer_data(p2)$UMAP1)
})

test_that("feature selection uses the inherited plot data", {
  df <- blobs(p = 3)
  p <- ggplot2::ggplot(df) + geom_umap(features = c(f1, f2), seed = 1)
  expect_equal(layer_data(p)$UMAP1, umap_embed(df, c(f1, f2), seed = 1)$UMAP1)
})

test_that("features can come from a function as layer data", {
  df <- blobs(p = 3)
  p <- ggplot2::ggplot(df) +
    geom_umap(
      data = function(d) d[d$label != "c1", ],
      features = f1:f3,
      seed = 1
    )
  expect_equal(nrow(layer_data(p)), sum(df$label != "c1"))
})

test_that("an integer seed is reproducible with one thread", {
  df <- blobs()
  expect_identical(umap_embed(df, seed = 7), umap_embed(df, seed = 7))
  expect_false(isTRUE(all.equal(
    umap_embed(df, seed = 7),
    umap_embed(df, seed = 8)
  )))
})

test_that("umap_embed() follows set.seed() when seed = NULL", {
  df <- blobs()
  a <- withr::with_seed(1, umap_embed(df))
  b <- withr::with_seed(1, umap_embed(df))
  c <- withr::with_seed(2, umap_embed(df))
  expect_identical(a, b)
  expect_false(isTRUE(all.equal(a, c)))
})

test_that("flavour 0.6 is reproducible for a fixed number of threads", {
  df <- blobs(n_per = 100)
  a <- umap_embed(df, flavour = "0.6", seed = 3, n_threads = 2)
  b <- umap_embed(df, flavour = "0.6", seed = 3, n_threads = 2)
  expect_identical(a, b)
})

test_that("the stat's default seed is stable and data-dependent", {
  df <- blobs()
  p <- ggplot2::ggplot(df) + geom_umap()
  a <- layer_data(p)
  b <- withr::with_seed(99, layer_data(p))
  expect_identical(a$x, b$x)
  other <- layer_data(ggplot2::ggplot(blobs(seed = 3)) + geom_umap())
  expect_false(isTRUE(all.equal(a$x, other$x)))
})

test_that("the default seed does not touch the global RNG", {
  df <- blobs()
  p <- ggplot2::ggplot(df) + geom_umap()
  withr::local_seed(1)
  before <- .Random.seed
  layer_data(p)
  expect_identical(.Random.seed, before)
})

test_that("seed = NULL gives a new layout on every build", {
  df <- blobs()
  p <- ggplot2::ggplot(df) + geom_umap(seed = NULL)
  a <- withr::with_seed(1, layer_data(p))
  b <- withr::with_seed(2, layer_data(p))
  expect_false(isTRUE(all.equal(a$x, b$x)))
})

test_that("layers with the same settings share a layout", {
  df <- blobs()
  df$id <- seq_len(nrow(df))
  p <- ggplot2::ggplot(df, ggplot2::aes(label = id)) +
    geom_umap(features = f1:f8) +
    stat_umap(geom = "text", features = f1:f8)
  expect_equal(layer_data(p, 1)$x, layer_data(p, 2)$x)
})

test_that("resolve_seed() handles all cases", {
  expect_equal(resolve_seed(5), 5)
  expect_equal(resolve_seed(NA, key = 1), resolve_seed(NA, key = 1))
  expect_false(resolve_seed(NA, key = 1) == resolve_seed(NA, key = 2))
  withr::local_seed(1)
  expect_true(resolve_seed(NULL) >= 1)
})

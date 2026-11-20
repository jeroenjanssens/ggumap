test_that("repeated builds hit the cache", {
  withr::local_options(ggumap.cache_size = 4L)
  umap_cache_clear()
  df <- blobs()
  p <- ggplot2::ggplot(df) + geom_umap(seed = 1)
  calls <- counter$calls
  first <- layer_data(p)
  expect_equal(counter$calls, calls + 1L)
  second <- layer_data(p)
  ggplot2::ggplotGrob(p)
  expect_equal(counter$calls, calls + 1L)
  expect_identical(first, second)
})

test_that("multiple layers share one computation", {
  withr::local_options(ggumap.cache_size = 4L)
  umap_cache_clear()
  df <- blobs()
  df$id <- seq_len(nrow(df))
  p <- ggplot2::ggplot(df, ggplot2::aes(label = id)) +
    geom_umap() +
    stat_umap(geom = "text")
  calls <- counter$calls
  ggplot2::ggplot_build(p)
  expect_equal(counter$calls, calls + 1L)
})

test_that("changing data or parameters misses the cache", {
  withr::local_options(ggumap.cache_size = 4L)
  umap_cache_clear()
  df <- blobs()
  calls <- counter$calls
  umap_embed(df, seed = 1)
  umap_embed(df, seed = 1, min_dist = 0.5)
  umap_embed(df[-1, ], seed = 1)
  umap_embed(df, seed = 2)
  expect_equal(counter$calls, calls + 4L)
  umap_embed(df, seed = 1)
  expect_equal(counter$calls, calls + 4L)
})

test_that("the cache is bounded and can be cleared", {
  withr::local_options(ggumap.cache_size = 2L)
  umap_cache_clear()
  df <- blobs(n_per = 10)
  for (s in 1:3) {
    umap_embed(df, seed = s)
  }
  expect_equal(length(cache$keys), 2L)
  # Seed 1 was evicted (least recently used).
  calls <- counter$calls
  umap_embed(df, seed = 1)
  expect_equal(counter$calls, calls + 1L)
  expect_equal(umap_cache_clear(), 2L)
  expect_equal(length(cache$keys), 0L)
})

test_that("cache_get() moves hits to the front", {
  withr::local_options(ggumap.cache_size = 3L)
  umap_cache_clear()
  cache_set("a", 1)
  cache_set("b", 2)
  expect_equal(cache_get("a"), 1)
  expect_equal(cache$keys, c("a", "b"))
  cache_set("a", 3)
  expect_equal(cache_get("a"), 3)
  expect_equal(length(cache$keys), 2L)
  expect_null(cache_get("zzz"))
  umap_cache_clear()
})

test_that("a cache size of zero disables caching", {
  withr::local_options(ggumap.cache_size = 0L)
  umap_cache_clear()
  cache_set("a", 1)
  expect_null(cache_get("a"))
})

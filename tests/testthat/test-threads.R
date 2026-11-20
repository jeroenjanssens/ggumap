test_that("umap_threads() respects the option", {
  withr::local_options(ggumap.n_threads = 3L)
  withr::local_envvar(`_R_CHECK_LIMIT_CORES_` = "")
  expect_equal(umap_threads(), 3L)
})

test_that("umap_threads() respects the environment variable", {
  withr::local_options(ggumap.n_threads = NULL)
  withr::local_envvar(GGUMAP_NUM_THREADS = "3", `_R_CHECK_LIMIT_CORES_` = "")
  expect_equal(umap_threads(), 3L)
  withr::local_envvar(GGUMAP_NUM_THREADS = "abc")
  expect_gte(umap_threads(), 1L)
})

test_that("umap_threads() defaults to half the cores", {
  withr::local_options(ggumap.n_threads = NULL)
  withr::local_envvar(GGUMAP_NUM_THREADS = "", `_R_CHECK_LIMIT_CORES_` = "")
  expect_equal(umap_threads(), max(1L, umap_rs_info()$max_threads %/% 2L))
})

test_that("umap_threads() is limited during R CMD check", {
  withr::local_options(ggumap.n_threads = 64L)
  withr::local_envvar(`_R_CHECK_LIMIT_CORES_` = "TRUE")
  expect_equal(umap_threads(), 2L)
  withr::local_envvar(`_R_CHECK_LIMIT_CORES_` = "false")
  expect_equal(umap_threads(), 64L)
})

test_that("multi-threaded runs give valid embeddings", {
  df <- blobs(n_per = 100)
  emb <- as.matrix(umap_embed(df, seed = 1, n_threads = 2)[1:2])
  expect_gt(knn_accuracy(emb, df$label), 0.95)
})

test_that("the Rust library reports its upstream version", {
  info <- umap_rs_info()
  expect_equal(info$upstream, "apple/embedding-atlas")
  expect_match(info$commit, "^[0-9a-f]{40}$")
})

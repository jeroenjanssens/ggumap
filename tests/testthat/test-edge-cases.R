test_that("tiny data sets work or fail gracefully", {
  df <- blobs(n_per = 2, k = 4)
  for (n in 3:8) {
    emb <- suppressWarnings(umap_embed(df[seq_len(n), ], seed = 1))
    expect_true(all(is.finite(emb$UMAP1)), label = paste("n =", n))
  }
  expect_snapshot(emb <- umap_embed(df[1:2, ], seed = 1))
  expect_true(all(is.na(emb$UMAP1)))
})

test_that("n_neighbors is reduced for small data sets", {
  df <- blobs(n_per = 3, k = 3)
  expect_snapshot(emb <- umap_embed(df, seed = 1))
  expect_true(all(is.finite(emb$UMAP1)))
})

test_that("n_components must be smaller than the number of observations", {
  expect_snapshot(
    umap_embed(blobs(n_per = 1, k = 4), n_components = 4, n_neighbors = 2),
    error = TRUE
  )
})

test_that("duplicated rows and constant data are handled", {
  df <- blobs(n_per = 5, k = 2)
  emb <- umap_embed(df[rep(seq_len(10), 5), ], seed = 1)
  expect_true(all(is.finite(emb$UMAP1)))
  emb <- umap_embed(matrix(1, 30, 3), seed = 1)
  expect_true(all(is.finite(emb$UMAP1)))
})

test_that("a single feature works", {
  emb <- umap_embed(blobs(), features = f1, seed = 1)
  expect_true(all(is.finite(emb$UMAP1)))
})

test_that("non-finite and huge values are errors", {
  x <- as.matrix(blobs()[1:8])
  x[1, 1] <- Inf
  expect_snapshot(umap_embed(x), error = TRUE)
  x[1, 1] <- 1e20
  expect_snapshot(umap_embed(x), error = TRUE)
})

test_that("all-missing data gives NA with a warning", {
  df <- data.frame(a = rep(NA_real_, 10), b = 1:10)
  expect_warning(expect_warning(emb <- umap_embed(df, seed = 1)))
  expect_true(all(is.na(emb$UMAP1)))
})

test_that("haversine needs two features", {
  expect_snapshot(umap_embed(blobs(), metric = "haversine"), error = TRUE)
})

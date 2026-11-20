test_that("umap_embed() returns one row per observation", {
  df <- blobs()
  emb <- umap_embed(df, seed = 1)
  expect_s3_class(emb, "data.frame")
  expect_named(emb, c("UMAP1", "UMAP2", "knn_dist"))
  expect_equal(nrow(emb), nrow(df))
  expect_true(all(is.finite(emb$UMAP1)))
  expect_true(all(is.finite(emb$UMAP2)))
  expect_true(all(emb$knn_dist >= 0))
})

test_that("n_components controls the number of columns", {
  emb <- umap_embed(blobs(), n_components = 3, seed = 1)
  expect_named(emb, c("UMAP1", "UMAP2", "UMAP3", "knn_dist"))
  emb <- umap_embed(blobs(), n_components = 1, seed = 1)
  expect_named(emb, c("UMAP1", "knn_dist"))
})

test_that("matrices, tibbles and data frames give the same result", {
  df <- blobs()
  x <- as.matrix(df[1:8])
  from_df <- umap_embed(df, seed = 2)
  from_mat <- umap_embed(x, seed = 2)
  expect_equal(from_df, from_mat, ignore_attr = TRUE)
  skip_if_not_installed("tibble")
  from_tbl <- umap_embed(tibble::as_tibble(df), seed = 2)
  expect_equal(from_df, from_tbl, ignore_attr = TRUE)
})

test_that("integer and logical features are accepted", {
  df <- blobs()
  df$int <- seq_len(nrow(df))
  df$lgl <- df$f1 > 0
  expect_no_error(umap_embed(df, c(f1:f3, int, lgl), seed = 1))
})

test_that("row names are kept", {
  emb <- umap_embed(mtcars, seed = 1, n_neighbors = 5)
  expect_equal(rownames(emb), rownames(mtcars))
  x <- as.matrix(mtcars)
  expect_equal(
    rownames(umap_embed(x, seed = 1, n_neighbors = 5)),
    rownames(mtcars)
  )
})

test_that("rows with missing values are NA and keep their position", {
  df <- blobs()
  df$f2[c(3, 50)] <- NA
  expect_warning(emb <- umap_embed(df, seed = 1), "2 rows with missing")
  expect_equal(nrow(emb), nrow(df))
  expect_true(all(is.na(emb$UMAP1[c(3, 50)])))
  expect_true(all(is.finite(emb$UMAP1[-c(3, 50)])))
})

test_that("knn_dist reflects distances in input space", {
  df <- blobs(n_per = 50, k = 2)
  df[1, 1:8] <- 100 # a clear outlier
  emb <- umap_embed(df, seed = 1)
  expect_equal(which.max(emb$knn_dist), 1L)
})

test_that("embeddings of separated blobs are faithful", {
  df <- blobs(n_per = 50, k = 4, p = 10)
  x <- as.matrix(df[1:10])
  emb <- as.matrix(umap_embed(df, seed = 1)[1:2])
  expect_gt(knn_accuracy(emb, df$label), 0.95)
  expect_gt(trustworthiness(x, emb, k = 10), 0.9)
})

test_that("both flavours give faithful embeddings", {
  df <- blobs(n_per = 50, k = 3, p = 6, seed = 3)
  for (flavour in c("0.5", "0.6")) {
    emb <- as.matrix(umap_embed(df, flavour = flavour, seed = 1)[1:2])
    expect_gt(knn_accuracy(emb, df$label), 0.95)
  }
})

test_that("iris quality is comparable to uwot", {
  skip_if_not_installed("uwot")
  x <- unique(as.matrix(iris[1:4]))
  ours <- as.matrix(umap_embed(x, seed = 1)[1:2])
  theirs <- withr::with_seed(1, uwot::umap(x, n_threads = 1))
  expect_gt(trustworthiness(x, ours), trustworthiness(x, theirs) - 0.03)
})

test_that("scale = TRUE standardises features", {
  df <- blobs(k = 2, p = 2)
  df$noise <- withr::with_seed(9, stats::rnorm(nrow(df), sd = 1000))
  unscaled <- as.matrix(umap_embed(df, seed = 1)[1:2])
  scaled <- as.matrix(umap_embed(df, scale = TRUE, seed = 1)[1:2])
  # Unscaled, the high-variance noise column dominates and the blobs mix.
  expect_gt(knn_accuracy(scaled, df$label), knn_accuracy(unscaled, df$label))
})

test_that("scale_features() handles constant columns", {
  x <- cbind(a = c(1, 2, 3), b = c(5, 5, 5))
  s <- scale_features(x)
  expect_equal(s[, "b"], c(0, 0, 0))
  expect_equal(unname(s[, "a"]), c(-1, 0, 1))
})

test_that("larger min_dist spreads points out", {
  df <- blobs(n_per = 50, k = 2)
  spread_of <- function(min_dist) {
    emb <- as.matrix(umap_embed(df, min_dist = min_dist, seed = 1)[1:2])
    mean(as.matrix(stats::dist(emb))[
      knn_index(emb, 5)[, 1] + (seq_len(nrow(emb)) - 1) * nrow(emb)
    ])
  }
  expect_gt(spread_of(0.9), spread_of(0.01))
})

test_that("every metric runs", {
  df <- blobs(n_per = 20, k = 3, p = 4)
  x <- abs(as.matrix(df[1:4]))
  binary <- (x > stats::median(x)) * 1
  binary_metrics <- c(
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
  for (metric in umap_metrics) {
    input <- if (metric %in% binary_metrics) {
      binary
    } else if (metric == "haversine") {
      x[, 1:2] / 10
    } else {
      x
    }
    emb <- umap_embed(input, metric = metric, seed = 1)
    expect_true(all(is.finite(emb$UMAP1)), label = metric)
  }
})

test_that("every init and optimizer runs", {
  df <- blobs(n_per = 20, k = 3, p = 4)
  for (flavour in c("0.5", "0.6")) {
    for (init in umap_inits) {
      emb <- umap_embed(df, init = init, flavour = flavour, seed = 1)
      expect_true(all(is.finite(emb$UMAP1)), label = paste(init, flavour))
    }
  }
  for (optimizer in c("sgd", "momentum", "adam")) {
    emb <- umap_embed(
      df,
      flavour = "0.6",
      control = umap_control(optimizer = optimizer),
      seed = 1
    )
    expect_true(all(is.finite(emb$UMAP1)), label = optimizer)
  }
})

test_that("advanced control parameters are passed on", {
  df <- blobs(n_per = 20, k = 3, p = 4)
  base <- umap_embed(df, seed = 1)
  tweaked <- umap_embed(
    df,
    seed = 1,
    control = umap_control(
      learning_rate = 0.5,
      negative_sample_rate = 2,
      repulsion_strength = 2,
      local_connectivity = 2,
      set_op_mix_ratio = 0.5,
      a = 1.5,
      b = 0.8,
      disconnection_distance = 50
    )
  )
  expect_false(isTRUE(all.equal(base, tweaked)))
  expect_true(all(is.finite(tweaked$UMAP1)))
})

test_that("n_epochs is passed on", {
  df <- blobs(n_per = 20, k = 3, p = 4)
  expect_false(isTRUE(all.equal(
    umap_embed(df, n_epochs = 5, seed = 1),
    umap_embed(df, n_epochs = 200, seed = 1)
  )))
})

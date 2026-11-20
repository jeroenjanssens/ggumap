test_that("umap_embed() validates its arguments", {
  df <- blobs()
  expect_snapshot(error = TRUE, {
    umap_embed(df, n_neighbors = 1)
    umap_embed(df, n_neighbors = 2.5)
    umap_embed(df, n_components = 0)
    umap_embed(df, min_dist = -1)
    umap_embed(df, min_dist = 2, spread = 1)
    umap_embed(df, spread = 0)
    umap_embed(df, metric = "euclidian")
    umap_embed(df, n_epochs = 0)
    umap_embed(df, init = "spectrall")
    umap_embed(df, flavour = "0.7")
    umap_embed(df, scale = "yes")
    umap_embed(df, seed = -1)
    umap_embed(df, seed = NA)
    umap_embed(df, n_threads = 0)
    umap_embed(df, control = list())
    umap_embed(df, control = umap_control(optimizer = "adam"))
    umap_embed(df, 1, 2)
    umap_embed(list(a = 1))
    umap_embed(matrix("a", 3, 3))
  })
})

test_that("umap_control() validates its arguments", {
  expect_snapshot(error = TRUE, {
    umap_control(learning_rate = -1)
    umap_control(negative_sample_rate = 1.5)
    umap_control(set_op_mix_ratio = 2)
    umap_control(a = "a")
    umap_control(optimizer = "rmsprop")
    umap_control(progress = NA)
  })
})

test_that("umap_control() prints", {
  expect_snapshot(print(umap_control(a = 1)))
})

test_that("feature selection errors are informative", {
  df <- blobs()
  expect_snapshot(error = TRUE, {
    umap_embed(df, features = label)
    umap_embed(df, features = c(f1, label))
    umap_embed(df, features = starts_with("nope"))
    umap_embed(df, features = not_a_column)
  })
})

test_that("stat_umap() validates its arguments at construction", {
  expect_snapshot(error = TRUE, {
    stat_umap(n_neighbors = 0)
    stat_umap(scope = "facet")
    geom_umap(flavour = "1")
    stat_umap(na.rm = "no")
    stat_umap(seed = "a")
  })
})

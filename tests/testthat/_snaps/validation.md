# umap_embed() validates its arguments

    Code
      umap_embed(df, n_neighbors = 1)
    Condition
      Error in `umap_embed()`:
      ! `n_neighbors` must be a whole number larger than or equal to 2, not the number 1.
    Code
      umap_embed(df, n_neighbors = 2.5)
    Condition
      Error in `umap_embed()`:
      ! `n_neighbors` must be a whole number, not the number 2.5.
    Code
      umap_embed(df, n_components = 0)
    Condition
      Error in `umap_embed()`:
      ! `n_components` must be a whole number larger than or equal to 1, not the number 0.
    Code
      umap_embed(df, min_dist = -1)
    Condition
      Error in `umap_embed()`:
      ! `min_dist` must be a number larger than or equal to 0, not the number -1.
    Code
      umap_embed(df, min_dist = 2, spread = 1)
    Condition
      Error in `umap_embed()`:
      ! `min_dist` (2) must not exceed `spread` (1).
    Code
      umap_embed(df, spread = 0)
    Condition
      Error in `umap_embed()`:
      ! `spread` must be positive.
    Code
      umap_embed(df, metric = "euclidian")
    Condition
      Error in `umap_embed()`:
      ! `metric` must be one of "euclidean", "sqeuclidean", "manhattan", "chebyshev", "minkowski", "cosine", "correlation", "canberra", "braycurtis", "hellinger", "haversine", "hamming", "jaccard", "dice", "matching", "rogerstanimoto", "russellrao", "sokalmichener", "sokalsneath", or "yule", not "euclidian".
      i Did you mean "euclidean"?
    Code
      umap_embed(df, n_epochs = 0)
    Condition
      Error in `umap_embed()`:
      ! `n_epochs` must be a whole number larger than or equal to 1 or `NULL`, not the number 0.
    Code
      umap_embed(df, init = "spectrall")
    Condition
      Error in `umap_embed()`:
      ! `init` must be one of "auto", "spectral", "tswspectral", "pca", "random", or "recursive", not "spectrall".
      i Did you mean "spectral"?
    Code
      umap_embed(df, flavour = "0.7")
    Condition
      Error in `umap_embed()`:
      ! `flavour` must be one of "0.5" or "0.6", not "0.7".
      i Did you mean "0.5"?
    Code
      umap_embed(df, scale = "yes")
    Condition
      Error in `umap_embed()`:
      ! `scale` must be `TRUE` or `FALSE`, not the string "yes".
    Code
      umap_embed(df, seed = -1)
    Condition
      Error in `umap_embed()`:
      ! `seed` must be a non-negative whole number, `NA` or `NULL`, not a number.
    Code
      umap_embed(df, seed = NA)
    Condition
      Error in `umap_embed()`:
      ! `seed` must be a whole number or `NULL`, not `NA`.
    Code
      umap_embed(df, n_threads = 0)
    Condition
      Error in `umap_embed()`:
      ! `n_threads` must be a whole number larger than or equal to 1, not the number 0.
    Code
      umap_embed(df, control = list())
    Condition
      Error in `umap_embed()`:
      ! `control` must be created with `umap_control()`, not an empty list.
    Code
      umap_embed(df, control = umap_control(optimizer = "adam"))
    Condition
      Error in `umap_embed()`:
      ! The "adam" optimizer requires `flavour = "0.6"`.
      i `flavour = "0.5"` always uses SGD.
    Code
      umap_embed(df, 1, 2)
    Condition
      Error in `umap_embed()`:
      ! `...` must be empty.
      x Problematic argument:
      * ..1 = 2
      i Did you forget to name an argument?
    Code
      umap_embed(list(a = 1))
    Condition
      Error in `umap_embed()`:
      ! `data` must be a data frame or a matrix, not a list.
    Code
      umap_embed(matrix("a", 3, 3))
    Condition
      Error in `umap_embed()`:
      ! `data` must be a numeric matrix.

# umap_control() validates its arguments

    Code
      umap_control(learning_rate = -1)
    Condition
      Error in `umap_control()`:
      ! `learning_rate` must be a number larger than or equal to 0, not the number -1.
    Code
      umap_control(negative_sample_rate = 1.5)
    Condition
      Error in `umap_control()`:
      ! `negative_sample_rate` must be a whole number, not the number 1.5.
    Code
      umap_control(set_op_mix_ratio = 2)
    Condition
      Error in `umap_control()`:
      ! `set_op_mix_ratio` must be a number between 0 and 1, not the number 2.
    Code
      umap_control(a = "a")
    Condition
      Error in `umap_control()`:
      ! `a` must be a number or `NULL`, not the string "a".
    Code
      umap_control(optimizer = "rmsprop")
    Condition
      Error in `umap_control()`:
      ! `optimizer` must be one of "sgd", "momentum", or "adam", not "rmsprop".
    Code
      umap_control(progress = NA)
    Condition
      Error in `umap_control()`:
      ! `progress` must be `TRUE` or `FALSE`, not `NA`.

# umap_control() prints

    Code
      print(umap_control(a = 1))
    Message
      <ggumap_control>
      learning_rate: 1
      negative_sample_rate: 5
      repulsion_strength: 1
      local_connectivity: 1
      set_op_mix_ratio: 1
      a: 1
      b: NULL
      optimizer: NULL
      disconnection_distance: NULL
      progress: FALSE

# feature selection errors are informative

    Code
      umap_embed(df, features = label)
    Condition
      Error in `umap_embed()`:
      ! Feature columns must be numeric.
      x Column label is not.
      i Convert categorical columns first, e.g. with `model.matrix()`.
    Code
      umap_embed(df, features = c(f1, label))
    Condition
      Error in `umap_embed()`:
      ! Feature columns must be numeric.
      x Column label is not.
      i Convert categorical columns first, e.g. with `model.matrix()`.
    Code
      umap_embed(df, features = starts_with("nope"))
    Condition
      Error in `umap_embed()`:
      ! No feature columns were selected.
      i Use `features` to select the numeric columns to embed.
    Code
      umap_embed(df, features = not_a_column)
    Condition
      Error in `umap_embed()`:
      ! Can't select columns that don't exist.
      x Column `not_a_column` doesn't exist.

# stat_umap() validates its arguments at construction

    Code
      stat_umap(n_neighbors = 0)
    Condition
      Error in `stat_umap()`:
      ! `n_neighbors` must be a whole number larger than or equal to 2, not the number 0.
    Code
      stat_umap(scope = "facet")
    Condition
      Error in `stat_umap()`:
      ! `scope` must be one of "layer" or "panel", not "facet".
    Code
      geom_umap(flavour = "1")
    Condition
      Error in `geom_umap()`:
      ! `flavour` must be one of "0.5" or "0.6", not "1".
    Code
      stat_umap(na.rm = "no")
    Condition
      Error in `stat_umap()`:
      ! `na.rm` must be `TRUE` or `FALSE`, not the string "no".
    Code
      stat_umap(seed = "a")
    Condition
      Error in `stat_umap()`:
      ! `seed` must be a non-negative whole number, `NA` or `NULL`, not a string.


# tiny data sets work or fail gracefully

    Code
      emb <- umap_embed(df[1:2, ], seed = 1)
    Condition
      Warning in `umap_embed()`:
      UMAP needs at least 3 complete observations, not 2.

# n_neighbors is reduced for small data sets

    Code
      emb <- umap_embed(df, seed = 1)
    Condition
      Warning in `umap_embed()`:
      `n_neighbors` (15) must be smaller than the number of observations (9).
      i Using `n_neighbors = 8` instead.

# n_components must be smaller than the number of observations

    Code
      umap_embed(blobs(n_per = 1, k = 4), n_components = 4, n_neighbors = 2)
    Condition
      Error in `umap_embed()`:
      ! `n_components` (4) must be smaller than the number of observations (4).

# non-finite and huge values are errors

    Code
      umap_embed(x)
    Condition
      Error in `umap_embed()`:
      ! Feature values must be finite; found Inf.

---

    Code
      umap_embed(x)
    Condition
      Error in `umap_embed()`:
      ! Feature values are too large for single-precision floating point.
      i Rescale the features, e.g. with `scale = TRUE`.

# haversine needs two features

    Code
      umap_embed(blobs(), metric = "haversine")
    Condition
      Error in `umap_embed()`:
      ! The "haversine" metric needs exactly 2 features (latitude and longitude, in radians), not 8.


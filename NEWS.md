# ggumap 0.1.0

* Initial release.
* `stat_umap()` and `geom_umap()` compute UMAP embeddings inside a ggplot2
  layer, with tidyselect feature selection, data-derived seeds, caching,
  facet scopes, progress bars and interrupt support.
* `umap_embed()` computes embeddings outside of plots. Use it with geoms
  that compute their own statistic (densities, binning), which
  `stat_umap()` rejects with an informative error.
* `umap_control()`, `umap_threads()`, `umap_cache_clear()` and `theme_umap()`.
* Uses Apple's Rust implementation of UMAP from `apple/embedding-atlas`
  (commit a0d0f09).

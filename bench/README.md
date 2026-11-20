# Benchmarks

Compares ggumap with other UMAP implementations available to R users, on speed,
memory and embedding quality. Not part of the package build.

| Contender       | Implementation                                                     |
|-----------------|--------------------------------------------------------------------|
| `ggumap-0.5`    | this package, `flavour = "0.5"` (spectral init + SGD)               |
| `ggumap-0.6`    | this package, `flavour = "0.6"` (recursive init + Adam)             |
| `uwot`          | `uwot::umap()` (C++, Annoy nearest neighbours)                      |
| `umap-naive`    | `umap::umap(method = "naive")`, pure R (what ggpca uses); n ≤ 10k   |
| `umap-learn-0.5`| Python umap-learn 0.5.x via reticulate (environment managed by uv)  |
| `umap-learn-0.6`| Python umap-learn 0.6.x via reticulate (environment managed by uv)  |

All contenders use `n_neighbors = 15`, `min_dist = 0.1`, Euclidean distance,
2 dimensions, default epochs and the same number of threads.

## Running

```sh
# from the package root, with ggumap installed
Rscript bench/run.R --suite=quick      # a few minutes
Rscript bench/run.R --suite=full       # about an hour; downloads MNIST once
Rscript bench/run.R --suite=full --contenders=ggumap-0.5,uwot --reps=5
```

Every measurement runs in a fresh R process (`callr`), so caches, JIT
compilation and thread pools do not leak between runs. Each process first does
an untimed warm-up on up to 5000 rows (umap-learn JIT-compiles its nearest
neighbour code only above 4096 rows), then times one embedding. The parent process polls the child's
resident memory every 20 ms to record the peak.

Quality is measured on a fixed random subsample of at most 5000 points:

* **trustworthiness** (k = 15): are neighbours in the embedding also
  neighbours in the input space?
* **kNN recall** (k = 15): overlap of the input-space and embedding kNN sets.
* **kNN accuracy** (k = 5): accuracy of a kNN vote on the known labels in the
  embedding.

Results are appended to `bench/results/results.csv`, together with the machine
and software versions, and copied to `vignettes/articles/` for the
benchmark article.

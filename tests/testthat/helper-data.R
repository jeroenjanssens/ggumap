# Well-separated Gaussian blobs with known labels.
blobs <- function(n_per = 40, k = 4, p = 8, sep = 10, seed = 1) {
  withr::with_seed(seed, {
    centres <- matrix(stats::rnorm(k * p, sd = sep), k, p)
    label <- rep(seq_len(k), each = n_per)
    x <- centres[label, , drop = FALSE] +
      matrix(stats::rnorm(length(label) * p), length(label), p)
  })
  df <- as.data.frame(x)
  names(df) <- paste0("f", seq_len(p))
  df$label <- factor(paste0("c", label))
  df
}

# Indices of the k nearest neighbours of every row (excluding itself).
knn_index <- function(x, k) {
  d <- as.matrix(stats::dist(x))
  diag(d) <- Inf
  t(apply(d, 1, function(r) order(r)[seq_len(k)]))
}

# Trustworthiness (Venna & Kaski): penalises points that are neighbours in the
# embedding but not in the input space. 1 is perfect.
trustworthiness <- function(x, emb, k = 10) {
  n <- nrow(x)
  dx <- as.matrix(stats::dist(x))
  diag(dx) <- Inf
  ranks <- t(apply(dx, 1, rank, ties.method = "first"))
  nn_emb <- knn_index(emb, k)
  penalty <- 0
  for (i in seq_len(n)) {
    r <- ranks[i, nn_emb[i, ]]
    penalty <- penalty + sum(pmax(r - k, 0))
  }
  1 - 2 / (n * k * (2 * n - 3 * k - 1)) * penalty
}

# Accuracy of a k-nearest-neighbour vote in the embedding.
knn_accuracy <- function(emb, labels, k = 5) {
  nn <- knn_index(emb, k)
  pred <- apply(nn, 1, function(i) names(which.max(table(labels[i]))))
  mean(pred == as.character(labels))
}

# Compute the embedding of a plot layer.
layer_data <- function(p, i = 1) {
  ggplot2::layer_data(p, i)
}

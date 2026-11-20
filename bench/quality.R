# Embedding quality metrics, computed on a subsample of at most `max_points`.

quality_subsample <- function(n, max_points = 5000) {
  withr::with_seed(42, sort(sample.int(n, min(n, max_points))))
}

# Indices of the k nearest neighbours of every row (excluding itself).
exact_knn <- function(x, k) {
  # Squared Euclidean distances via the Gram matrix, in blocks.
  n <- nrow(x)
  sq <- rowSums(x^2)
  out <- matrix(0L, n, k)
  for (start in seq(1, n, by = 1000)) {
    rows <- start:min(n, start + 999)
    d <- outer(sq[rows], sq, "+") - 2 * x[rows, , drop = FALSE] %*% t(x)
    d[cbind(seq_along(rows), rows)] <- Inf
    out[rows, ] <- t(apply(d, 1, function(r) order(r)[seq_len(k)]))
  }
  out
}

# Ranks of all points by distance from each row (1 = nearest, self excluded).
distance_ranks <- function(x) {
  n <- nrow(x)
  sq <- rowSums(x^2)
  ranks <- matrix(0L, n, n)
  for (start in seq(1, n, by = 500)) {
    rows <- start:min(n, start + 499)
    d <- outer(sq[rows], sq, "+") - 2 * x[rows, , drop = FALSE] %*% t(x)
    d[cbind(seq_along(rows), rows)] <- -Inf
    ranks[rows, ] <- t(apply(d, 1, rank, ties.method = "first")) - 1L
  }
  ranks
}

embedding_quality <- function(x, emb, labels = NULL, k = 15) {
  if (!all(is.finite(emb))) {
    return(list(
      trustworthiness = NA_real_,
      knn_recall = NA_real_,
      knn_accuracy = NA_real_
    ))
  }
  n <- nrow(x)
  nn_x <- exact_knn(x, k)
  nn_e <- exact_knn(emb, k)
  recall <- mean(vapply(
    seq_len(n),
    function(i) length(intersect(nn_x[i, ], nn_e[i, ])),
    numeric(1)
  )) /
    k

  ranks <- distance_ranks(x)
  penalty <- sum(vapply(
    seq_len(n),
    function(i) sum(pmax(ranks[i, nn_e[i, ]] - k, 0)),
    numeric(1)
  ))
  trust <- 1 - 2 / (n * k * (2 * n - 3 * k - 1)) * penalty

  accuracy <- NA_real_
  if (!is.null(labels)) {
    vote <- apply(nn_e[, 1:5, drop = FALSE], 1, function(i) {
      tab <- tabulate(
        match(labels[i], unique(labels)),
        nbins = length(unique(labels))
      )
      unique(labels)[which.max(tab)]
    })
    accuracy <- mean(vote == labels)
  }
  list(trustworthiness = trust, knn_recall = recall, knn_accuracy = accuracy)
}

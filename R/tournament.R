#' Execute a round-robin tournament among multiple strategies.
#' @param strategies_list A named list of functions to be evaluated.
#' @param n_rounds Integer specifying how many rounds each match will last.
#' @param include_info Logical indicating whether metadata should be passed during matches.
#' @param payoff_matrix A 2x2 matrix defining the rewards for each interaction.
#' @return A list containing standings, the score matrix, and the cooperation matrix.
#' @export
tournament <- function(strategies_list, n_rounds = 200, include_info = TRUE,
                       payoff_matrix = matrix(c(3, 0, 5, 1), nrow = 2, byrow = TRUE)) {

  if (!is.list(strategies_list)) stop("strategies_list must be a named list.")
  strat_names <- names(strategies_list)
  if (is.null(strat_names))
    stop("strategies_list must be named, e.g., list(TFT = r_tit_for_tat, ...)")

  n <- length(strategies_list)
  score_matrix   <- matrix(0,        n, n, dimnames = list(strat_names, strat_names))
  coop_matrix    <- matrix(NA_real_, n, n, dimnames = list(strat_names, strat_names))

  total_matches <- n * (n + 1) / 2
  done <- 0
  cat(sprintf("Tournament: %d strategies, %d unique matchups\n\n",
              n, total_matches))

  for (idx in seq_len(n)) {
    for (jdx in idx:n) {
      res <- match(
        strategies_list[[idx]],
        strategies_list[[jdx]],
        n_rounds     = n_rounds,
        include_info = include_info,
        payoff_matrix = payoff_matrix
      )

      score_matrix[idx, jdx] <- res$scores["P1"] / n_rounds
      score_matrix[jdx, idx] <- res$scores["P2"] / n_rounds

      h <- res$history
      coop_matrix[idx, jdx] <- mean(h$P1 == "C")
      coop_matrix[jdx, idx] <- mean(h$P2 == "C")

      done <- done + 1
      cat(sprintf("  [%d/%d] %s vs %s\n", done, total_matches,
                  strat_names[idx], strat_names[jdx]))
    }
  }

  avg_score  <- rowMeans(score_matrix)
  avg_coop   <- rowMeans(coop_matrix, na.rm = TRUE)

  standings <- data.frame(
    Rank       = NA_integer_,
    Strategy   = strat_names,
    Avg_Score  = round(avg_score, 3),
    Coop_Rate  = round(avg_coop,  3),
    stringsAsFactors = FALSE
  )
  standings      <- standings[order(-standings$Avg_Score), ]
  standings$Rank <- seq_len(nrow(standings))
  rownames(standings) <- NULL

  cat("\nTournament complete.\n")

  return(list(
    standings    = standings,
    score_matrix = score_matrix,
    coop_matrix  = coop_matrix
  ))
}

#' Run an Axelrod-Style Round Robin Tournament
#'
#' Executes a round robin tournament in which every unique pair of strategies
#' (including self-play) is matched exactly once. Scores are normalised to the
#' average payoff per round, following Axelrod's original ranking criterion.
#'
#' @param strategies_list A named list of strategy functions. Each function must
#'   accept three arguments: \code{my_hist}, \code{opp_hist}, and
#'   \code{game_info}. Names are required and are used to label all output
#'   tables (e.g. \code{list(TFT = r_tit_for_tat, Defect = r_defect)}).
#' @param n_rounds Integer. Number of rounds played per match. Defaults to
#'   \code{200}.
#' @param include_info Logical. If \code{TRUE}, a list containing
#'   \code{total_rounds} and \code{current_round} is passed to each strategy
#'   as \code{game_info}, allowing strategies to condition behaviour on match
#'   length or current position. Defaults to \code{TRUE}.
#' @param payoff_matrix A 2x2 numeric matrix defining the reward structure of
#'   the game. Rows index the focal player's move and columns index the
#'   opponent's move, where row/col 1 = Cooperate and row/col 2 = Defect.
#'   The default is the standard Prisoner's Dilemma matrix:
#'   \code{matrix(c(3, 0, 5, 1), nrow = 2, byrow = TRUE)}, yielding
#'   CC = 3, CD = 0, DC = 5, DD = 1.
#'
#' @return A named list with three elements:
#'   \describe{
#'     \item{\code{standings}}{A data frame with one row per strategy, sorted
#'       by descending \code{Avg_Score}. Contains four columns:
#'       \code{Rank} (integer rank after sorting, 1 = best);
#'       \code{Strategy} (strategy name as supplied in \code{strategies_list});
#'       \code{Avg_Score} (the strategy's average payoff per round, averaged
#'         across all opponents including self — this is the primary Axelrod
#'         ranking criterion and equals the row mean of \code{score_matrix});
#'       \code{Coop_Rate} (the strategy's average cooperation rate across all
#'         opponents, where 1 means always cooperate and 0 means always defect
#'         — equals the row mean of \code{coop_matrix}).}
#'     \item{\code{score_matrix}}{An \code{n x n} numeric matrix of average
#'       payoffs per round. Entry \code{[i, j]} is the average payoff per
#'       round earned by strategy \code{i} when playing against strategy
#'       \code{j}. The matrix is asymmetric: \code{[i, j]} and \code{[j, i]}
#'       reflect each player's own payoff from the same match and will differ
#'       whenever the two strategies do not score equally against each other.
#'       \code{Avg_Score} in \code{standings} is the row mean of this matrix.}
#'     \item{\code{coop_matrix}}{An \code{n x n} numeric matrix of cooperation
#'       rates. Entry \code{[i, j]} is the proportion of rounds in which
#'       strategy \code{i} played C when facing strategy \code{j}, ranging
#'       from 0 (always defect) to 1 (always cooperate). The matrix is
#'       asymmetric: \code{[i, j]} and \code{[j, i]} record each player's own
#'       behaviour in the same match. \code{Coop_Rate} in \code{standings} is
#'       the row mean of this matrix.}
#'   }
#'
#' @export
tournament <- function(strategies_list, n_rounds = 200, include_info = TRUE,
                       payoff_matrix = matrix(c(3, 0, 5, 1), nrow = 2, byrow = TRUE)) {

  if (!is.list(strategies_list)) stop("strategies_list must be a named list.")
  strat_names <- names(strategies_list)
  if (is.null(strat_names))
    stop("strategies_list must be named, e.g., list(TFT = r_tit_for_tat, ...)")

  n <- length(strategies_list)
  coop_matrix <- score_matrix <- matrix(NA, n, n, dimnames = list(strat_names, strat_names))

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
    Rank       = NA,
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

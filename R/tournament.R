#' Run an Axelrod-Style Round Robin Tournament
#'
#' Executes a round robin tournament in which every unique pair of strategies
#' (including self-play) is matched exactly once. Scores are provided both as
#' normalized averages per round and as raw total scores.
#'
#' @param strategies_list A named list of strategy functions. Each function must
#'   accept three arguments: \code{my_hist}, \code{opp_hist}, and
#'   \code{game_info}. Names are required and are used to label all output
#'   tables (e.g. \code{list(TFT = r_tit_for_tat, Defect = r_defect)}).
#' @param n_rounds Integer. Number of rounds played per match. Defaults to
#'   \code{200}.
#' @param include_info Logical. If \code{TRUE}, a list containing
#'   \code{total_rounds} and \code{current_round} is passed to each strategy
#'   as \code{game_info}. Defaults to \code{TRUE}.
#' @param payoff An object of class \code{flkbrg_payoff}. Use \code{flkbrg_payoff()}
#'   to create a custom payoff structure. Defaults to the standard
#'   Prisoner's Dilemma: CC=3, CD=0, DC=5, DD=1.
#'
#' @return A named list with four elements:
#'   \describe{
#'     \item{\code{standings}}{A data frame with one row per strategy, sorted
#'       by descending \code{Avg_Score}. Contains columns: \code{Rank},
#'       \code{Strategy}, \code{Avg_Score} (row mean of avg\_score\_matrix), and
#'       \code{Coop_Rate} (row mean of coop matrix).}
#'     \item{\code{avg_score_matrix}}{An \code{n x n} numeric matrix of average
#'       payoffs per round earned by strategy \code{[i, j]} against \code{[j]}.}
#'     \item{\code{total_score_matrix}}{An \code{n x n} numeric matrix of raw
#'       payoff points earned by strategy \code{[i, j]} against \code{[j]}.}
#'     \item{\code{coop_matrix}}{An \code{n x n} numeric matrix of cooperation
#'       rates (0 to 1) for each player in the matchups.}
#'   }
#'
#' @export
tournament <- function(strategies_list, n_rounds = 200, include_info = TRUE,
                       payoff = flkbrg_payoff()) {
  if (!is.list(strategies_list)) stop("strategies_list must be a named list.")
  strat_names <- names(strategies_list)
  if (is.null(strat_names))
    stop("strategies_list must be named, e.g., list(TFT = r_tit_for_tat, ...)")

  n <- length(strategies_list)

  # Initialize all three matrices
  coop_matrix      <- matrix(NA, n, n, dimnames = list(strat_names, strat_names))
  avg_score_matrix <- matrix(NA, n, n, dimnames = list(strat_names, strat_names))
  total_score_matrix <- matrix(NA, n, n, dimnames = list(strat_names, strat_names))

  total_matches <- n * (n + 1) / 2
  done <- 0
  cat(sprintf("Tournament: %d strategies, %d unique matchups\n\n",
              n, total_matches))

  for (idx in seq_len(n)) {
    for (jdx in idx:n) {
      res <- match(
        strategies_list[[idx]],
        strategies_list[[jdx]],
        n_rounds      = n_rounds,
        include_info  = include_info,
        payoff        = payoff
      )

      # 1. Populate Average Score Matrix (Payoff per round)
      avg_score_matrix[idx, jdx] <- res$scores["P1"] / n_rounds
      avg_score_matrix[jdx, idx] <- res$scores["P2"] / n_rounds

      # 2. Populate Total Score Matrix (Raw points)
      total_score_matrix[idx, jdx] <- res$scores["P1"]
      total_score_matrix[jdx, idx] <- res$scores["P2"]

      # 3. Populate Cooperation Matrix
      h <- res$history
      coop_matrix[idx, jdx] <- mean(h$P1 == "C")
      coop_matrix[jdx, idx] <- mean(h$P2 == "C")

      done <- done + 1
      cat(sprintf("  [%d/%d] %s vs %s\n", done, total_matches,
                  strat_names[idx], strat_names[jdx]))
    }
  }

  # Calculate standings metrics
  avg_scores   <- rowMeans(avg_score_matrix)
  avg_coop     <- rowMeans(coop_matrix, na.rm = TRUE)

  standings <- data.frame(
    Rank        = NA,
    Strategy    = strat_names,
    Avg_Score   = avg_scores,
    Coop_Rate   = avg_coop,
    stringsAsFactors = FALSE
  )

  # Sort by Avg_Score descending (Axelrod's ranking criterion)
  standings      <- standings[order(-standings$Avg_Score), ]
  standings$Rank <- seq_len(nrow(standings))
  rownames(standings) <- NULL

  cat("\nTournament complete.\n")

  return(list(
    standings          = standings,
    avg_score_matrix   = avg_score_matrix,
    total_score_matrix = total_score_matrix,
    coop_matrix        = coop_matrix
  ))
}

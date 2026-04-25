#' Run an Axelrod-Style Round Robin Tournament
#'
#' Executes a round robin tournament in which every unique pair of strategies
#' (including self-play) is matched exactly once. Multiple scores are provided
#' to evaluate the tournament. For details see the description if the returned
#' items.
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
#' @return A named list with the following elements:
#'   \describe{
#'     \item{\code{meta}}{A named list of tournament-level metadata:
#'       \code{strategies_list} (the original list of strategy functions),
#'       \code{n_rounds} (number of rounds played per match),
#'       \code{include_info} (whether game info was passed to strategies), and
#'       \code{payoff} (the \code{flkbrg_payoff} object used).}
#'     \item{\code{standings}}{A data frame with one row per strategy, sorted
#'       by descending \code{Avg_Score}. Contains columns: \code{Rank},
#'       \code{Strategy}, \code{Avg_Score} (row mean of avg\_score\_matrix),
#'       \code{Coop_Rate} (row mean of coop\_matrix), \code{jCoop_Rate} (row
#'       mean of jcoop\_matrix), and \code{wins} (total round-level wins
#'       across all matchups).}
#'     \item{\code{avg_score_matrix}}{An \code{n x n} numeric matrix of average
#'       payoffs per round earned by strategy \code{[i, j]} against \code{[j]}.}
#'     \item{\code{total_score_matrix}}{An \code{n x n} numeric matrix of raw
#'       payoff points earned by strategy \code{[i, j]} against \code{[j]}.}
#'     \item{\code{coop_matrix}}{An \code{n x n} numeric matrix of cooperation
#'       rates (0 to 1) for each player in the matchups.}
#'     \item{\code{jcoop_matrix}}{An \code{n x n} symmetric numeric matrix of
#'       joint cooperation rates (0 to 1), i.e. the proportion of rounds in
#'       which \emph{both} players chose C. Entry \code{[i, j]} equals
#'       \code{[j, i]}.}
#'     \item{\code{wins_matrix}}{An \code{n x n} integer matrix counting the
#'       number of rounds in which strategy \code{[i]} earned a strictly higher
#'       payoff than strategy \code{[j]}.}
#'     \item{\code{match_histories}}{An \code{n x n} matrix of lists. Each cell
#'       \code{[i, j]} contains the full round-by-round history data frame for
#'       that matchup (columns \code{P1}, \code{P2}, \code{P1_Payoff},
#'       \code{P2_Payoff}). The matrix is symmetric: \code{[i, j]} and
#'       \code{[j, i]} point to the same history object.}
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
  coop_matrix        <- matrix(NA, n, n, dimnames = list(strat_names, strat_names))
  jcoop_matrix       <- matrix(NA, n, n, dimnames = list(strat_names, strat_names))
  avg_score_matrix   <- matrix(NA, n, n, dimnames = list(strat_names, strat_names))
  total_score_matrix <- matrix(NA, n, n, dimnames = list(strat_names, strat_names))
  wins_matrix        <- matrix(NA, n, n, dimnames = list(strat_names, strat_names))

  # Initialize the match history matrix, which is a matrix of lists
  match_histories <- matrix(rep(list(),n*n), n, n, dimnames = list(strat_names, strat_names))

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

      # 4. Populate the Joint Cooperation Matrix
      jcoop_rate <- mean(h$P1 == h$P2 & h$P1 == "C" & h$P2 == "C")
      jcoop_matrix[idx, jdx] <- jcoop_matrix[jdx, idx] <- jcoop_rate

      # 5. Save Match Histories
      match_histories[idx, jdx] <- match_histories[jdx, idx] <- list(h)

      # 6. Save Wins
      wins_p1 <- sum(h$P1_Payoff > h$P2_Payoff)
      wins_p2 <- sum(h$P1_Payoff < h$P2_Payoff)
      draws   <- sum(h$P1_Payoff == h$P2_Payoff) # not returned
      wins_matrix[idx, jdx] <- wins_p1
      if (jdx != idx) wins_matrix[jdx, idx] <- wins_p2

      done <- done + 1
      cat(sprintf("  [%d/%d] %s vs %s\n", done, total_matches,
                  strat_names[idx], strat_names[jdx]))
    }
  }

  # Calculate standings metrics
  avg_scores   <- rowMeans(avg_score_matrix)
  avg_coop     <- rowMeans(coop_matrix, na.rm = TRUE)
  avg_jcoop    <- rowMeans(jcoop_matrix, na.rm = TRUE)
  sum_wins         <- rowSums(wins_matrix, na.rm = TRUE)

  standings <- data.frame(
    Rank        = NA,
    Strategy    = strat_names,
    Avg_Score   = avg_scores,
    Coop_Rate   = avg_coop,
    jCoop_Rate = avg_jcoop,
    wins       = sum_wins,
    stringsAsFactors = FALSE
  )

  # Sort by Avg_Score descending
  standings      <- standings[order(-standings$Avg_Score), ]
  standings$Rank <- seq_len(nrow(standings))
  rownames(standings) <- NULL

  cat("\nTournament complete.\n")

  # Gather all the meta information
  meta <- list( strategies_list = strategies_list,
                n_rounds = n_rounds,
                include_info = include_info,
                payoff = payoff)

  return(structure(list(
    meta = meta,
    standings          = standings,
    avg_score_matrix   = avg_score_matrix,
    total_score_matrix = total_score_matrix,
    coop_matrix        = coop_matrix,
    jcoop_matrix       = jcoop_matrix,
    wins_matrix = wins_matrix,
    match_histories    = match_histories
  ), class = "flkbrg_tournament"))
}

#' Print Method for flkbrg_tournament Objects
#'
#' Prints a concise summary of a tournament result, showing the standings
#' table and listing the names of the additional returned items.
#'
#' @param x An object of class \code{flkbrg_tournament}.
#' @param ... Further arguments passed to or from other methods (ignored).
#'
#' @return \code{x}, invisibly.
#' @export
print.flkbrg_tournament <- function(x, ...) {
  cat("=== flkbrg Tournament Summary =======================================\n")
  cat(sprintf(
    "Tournament Details: %d strategies  |  %d rounds per match\n",
    length(x$meta$strategies_list), x$meta$n_rounds))
  cat("=====================================================================\n")

  print(x$standings, row.names = FALSE)

  other_items <- setdiff(names(x), c("standings", "meta"))
  cat("=====================================================================\n")
  cat("Also available:", paste(other_items, collapse = ", "), "\n")
  cat("=====================================================================\n")

  invisible(x)
}

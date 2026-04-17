#' Simulate a single match between two players.
#' @param strategy1 A function representing the first player's decision logic.
#' @param strategy2 A function representing the second player's decision logic.
#' @param n_rounds Integer specifying the number of iterations per match.
#' @param include_info Logical indicating whether metadata should be passed to strategies.
#' @param payoff_matrix A 2x2 matrix where 1,1=CC, 1,2=CD, 2,1=DC, 2,2=DD.
#' @return A list containing names, scores, and a history data frame.
#' @export
match <- function(strategy1, strategy2, n_rounds = 50, include_info = TRUE,
                  payoff_matrix = matrix(c(3, 0, 5, 1), nrow = 2, byrow = TRUE)) {

  s1_name <- deparse(substitute(strategy1))
  s2_name <- deparse(substitute(strategy2))

  move_to_idx <- function(move) { if (move == "C") return(1) else return(2) }
  history1 <- character(0); history2 <- character(0)
  payoffs1 <- numeric(0);   payoffs2 <- numeric(0)
  score1 <- 0; score2 <- 0

  for (round in 1:n_rounds) {
    info_to_pass <- if (include_info) list(total_rounds = n_rounds, current_round = round) else NA

    move1 <- strategy1(history1, history2, info_to_pass)
    move2 <- strategy2(history2, history1, info_to_pass)

    idx1 <- move_to_idx(move1); idx2 <- move_to_idx(move2)
    round_p1 <- payoff_matrix[idx1, idx2]; round_p2 <- payoff_matrix[idx2, idx1]

    score1 <- score1 + round_p1; score2 <- score2 + round_p2
    history1 <- c(history1, move1); history2 <- c(history2, move2)
    payoffs1 <- c(payoffs1, round_p1); payoffs2 <- c(payoffs2, round_p2)
  }

  return(list(
    strategies = c(P1 = s1_name, P2 = s2_name),
    scores     = c(P1 = score1,  P2 = score2),
    history    = data.frame(
      Round     = 1:n_rounds,
      P1        = history1,
      P2        = history2,
      P1_Payoff = payoffs1,
      P2_Payoff = payoffs2
    )
  ))
}



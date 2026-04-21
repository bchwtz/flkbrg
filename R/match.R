#' Simulate a single match between two players using a flkbrg_payoff object.
#'
#' @param strategy1 A function representing the first player's decision logic.
#' @param strategy2 A function representing the second player's decision logic.
#' @param n_rounds Integer specifying the number of iterations per match.
#'                 Defaults to 200, which is the original value from Axelrods
#'                 first tournament.
#' @param include_info Logical indicating whether metadata should be passed to strategies.
#' @param payoff An object of class \code{flkbrg_payoff}. Use flkbrg_payoff() to create one.
#' @return A list containing names, scores, and a history data frame.
#' @export
match <- function(strategy1, strategy2, n_rounds = 200, include_info = TRUE,
                  payoff = flkbrg_payoff()) {

  if (!inherits(payoff, "flkbrg_payoff")) {
    stop("The 'payoff' argument must be of class 'flkbrg_payoff'.")
  }

  s1_name <- deparse(substitute(strategy1))
  s2_name <- deparse(substitute(strategy2))
  history1 <- history2 <- character(0)
  payoffs1 <- payoffs2 <- numeric(0)
  score1 <- score2 <- 0

  for (rdx in 1:n_rounds) {

    # Prepare metadata for strategies
    info_to_pass <- if(include_info == TRUE){
      list(total_rounds = n_rounds, current_round = rdx)
    } else {
      NA
    }

    # Get moves from strategies
    move1 <- strategy1(history1, history2, info_to_pass)
    move2 <- strategy2(history2, history1, info_to_pass)

    # Use the move names ("C" or "D") directly to index the P1 and P2 matrices.
    round_p1 <- payoff$P1[move1, move2]
    round_p2 <- payoff$P2[move1, move2]

    # Update scores and history
    score1 <- score1 + round_p1
    score2 <- score2 + round_p2
    history1 <- c(history1, move1)
    history2 <- c(history2, move2)
    payoffs1 <- c(payoffs1, round_p1)
    payoffs2 <- c(payoffs2, round_p2)
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

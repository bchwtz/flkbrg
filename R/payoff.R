#' Create a Payoff Object
#'
#' Constructs a payoff object from the four outcomes of a two-player
#' game using move-pair notation only:
#' \code{CC}, \code{CD}, \code{DC}, \code{DD}.
#'
#' Each outcome is a numeric vector of length 2 representing
#' the payoffs to Player 1 and Player 2 respectively. The defaults result
#' in the standard Axelrod Payoff Matrix.
#'
#' @param CC Payoff when both cooperate: \code{c(P1, P2)}.
#' @param CD Payoff when P1 cooperates, P2 defects: \code{c(P1, P2)}.
#' @param DC Payoff when P1 defects, P2 cooperates: \code{c(P1, P2)}.
#' @param DD Payoff when both defect: \code{c(P1, P2)}.
#'
#' @return A list of class \code{"flkbrg_payoff"} with elements
#' \code{CC}, \code{CD}, \code{DC}, \code{DD} and payoff matrices
#' \code{P1}, \code{P2}. Rows correspond to P1's moves and columns
#' to P2's moves.
#' @export
flkbrg_payoff <- function(CC = c(3, 3),
                          CD = c(0, 5),
                          DC = c(5, 0),
                          DD = c(1, 1)) {

  moves <- c("C", "D")

  payoff_P1 <- matrix(
    c(CC[1], DC[1], CD[1], DD[1]),
    nrow     = 2,
    dimnames = list(P1 = moves, P2 = moves)
  )

  payoff_P2 <- matrix(
    c(CC[2], DC[2], CD[2], DD[2]),
    nrow     = 2,
    dimnames = list(P1 = moves, P2 = moves)
  )

  structure(
    list(
      CC = CC,
      CD = CD,
      DC = DC,
      DD = DD,
      P1 = payoff_P1,
      P2 = payoff_P2
    ),
    class = "flkbrg_payoff"
  )
}


#' Print method for flkbrg_payoff
#'
#' This is a generic print function to beautify the printing of flkbrg_payoff
#' objects on the console. It is not dynamic and does not react to anything.
#' There is no love in this function. Just a simple helper to not mess up stdout.
#' @export
print.flkbrg_payoff <- function(x, ...) {
  # Header section
  cat(" \\         P2 \n")
  cat("  \\    C       D \n")
  cat("P1 \\ ------  ------\n")

  # Helper to format the (P1, P2) tuples
  fmt_pair <- function(vec) {
    paste0("(", vec[1], ", ", vec[2], ")")
  }

  # Row C: [CC outcome] and [CD outcome]
  cat(sprintf(" C | %s  %s   \n",
              fmt_pair(x$CC),
              fmt_pair(x$CD)))

  # Row D: [DC outcome] and [DD outcome]
  cat(sprintf(" D | %s  %s   \n",
              fmt_pair(x$DC),
              fmt_pair(x$DD)))

  invisible(x)
}

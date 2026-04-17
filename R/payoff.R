#' Standard Axelrod Prisoner's Dilemma payoff matrix.
#'
#' @description
#' Returns a 2x2 numeric matrix representing the classic payoffs used in
#' Robert Axelrod's tournaments, with labeled rows and columns for
#' Cooperation ("C") and Defection ("D").
#'
#' The values correspond to:
#' \itemize{
#'   \item \strong{Reward (R):} Both cooperate -> 3
#'   \item \strong{Temptation (T):} One defects, one cooperates -> 5
#'   \item \strong{Sucker's Payoff (S):} One cooperates, one defects -> 0
#'   \item \strong{Punishment (P):} Both defect -> 1
#' }
#'
#' @return A 2x2 numeric matrix with row and column names "C" and "D".
#' @export
axelrod_payoff <- function() {
  # Define the payoff values
  mat <- matrix(c(3, 0, 5, 1), nrow = 2, byrow = TRUE)

  # Assign names to rows and columns for clarity
  dimnames(mat) <- list(c("C", "D"), c("C", "D"))

  return(mat)
}

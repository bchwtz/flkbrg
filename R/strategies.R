#' Tit-for-Tat strategy.
#' @param my_hist A character vector of the player's own previous moves.
#' @param opp_hist A character vector of the opponent's previous moves.
#' @param game_info A list containing metadata about the current game state.
#' @export
r_tit_for_tat <- function(my_hist, opp_hist, game_info = NA) {
  if (length(opp_hist) == 0) return("C")
  return(tail(opp_hist, 1))
}

#' Traitor strategy.
#' @param my_hist A character vector of the player's own previous moves.
#' @param opp_hist A character vector of the opponent's previous moves.
#' @param game_info A list containing metadata about the current game state.
#' @export
r_traitor <- function(my_hist, opp_hist, game_info = NA) {
  if (all(is.na(game_info)) == 1) stop("The Traitor requires game_info to operate.")
  if (game_info$current_round == game_info$total_rounds) return("D") else return("C")
}

#' Always Defect strategy.
#' @param my_hist A character vector of the player's own previous moves.
#' @param opp_hist A character vector of the opponent's previous moves.
#' @param game_info A list containing metadata about the current game state.
#' @export
r_defect <- function(my_hist, opp_hist, game_info = NA) {
  return("D")
}

#' Always Cooperate strategy.
#' @param my_hist A character vector of the player's own previous moves.
#' @param opp_hist A character vector of the opponent's previous moves.
#' @param game_info A list containing metadata about the current game state.
#' @export
r_coop <- function(my_hist, opp_hist, game_info = NA) {
  return("C")
}






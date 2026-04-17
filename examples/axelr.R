# Load necessary libraries
library(reticulate)
library(Rcpp)

# 1. Load Python strategies
strategy_files_py <- list.files("strategies", pattern = "\\.py$", full.names = TRUE)
for (f in strategy_files_py){
  name <- tools::file_path_sans_ext(basename(f))
  source_python(f)
  assign(paste0("py_", name), py$strategy, envir = .GlobalEnv)
  rm(strategy, name, f)
}

# 2. Load CPP strategies
strategy_files_cpp <- list.files("strategies", pattern = "\\.cpp$", full.names = TRUE)
invisible(lapply(strategy_files_cpp, Rcpp::sourceCpp))

# 3. GAME ENGINE

#' Simulate a single match between two players.
#' @param strategy1 A function representing the first player's decision logic.
#' @param strategy2 A function representing the second player's decision logic.
#' @param n_rounds Integer specifying the number of iterations per match.
#' @param include_info Logical indicating whether metadata should be passed to strategies.
#' @param payoff_matrix A 2x2 matrix where [1,1]=CC, [1,2]=CD, [2,1]=DC, [2,2]=DD.
#' @return A list containing names, scores, and a history data frame.
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

# 4. R STRATEGIES

#' Implement a Tit-for-Tat strategy.
#' @param my_hist A character vector of the player's own previous moves.
#' @param opp_hist A character vector of the opponent's previous moves.
#' @param game_info A list containing metadata about the current game state.
r_tit_for_tat <- function(my_hist, opp_hist, game_info = NA) {
  if (length(opp_hist) == 0) return("C")
  return(tail(opp_hist, 1))
}

#' Implement a Traitor strategy.
#' @param my_hist A character vector of the player's own previous moves.
#' @param opp_hist A character vector of the opponent's previous moves.
#' @param game_info A list containing metadata about the current game state.
r_traitor <- function(my_hist, opp_hist, game_info = NA) {
  if (all(is.na(game_info)) == 1) stop("The Traitor requires game_info to operate.")
  if (game_info$current_round == game_info$total_rounds) return("D") else return("C")
}

#' Implement an Always Defect strategy.
#' @param my_hist A character vector of the player's own previous moves.
#' @param opp_hist A character vector of the opponent's previous moves.
#' @param game_info A list containing metadata about the current game state.
r_defect <- function(my_hist, opp_hist, game_info = NA) {
  return("D")
}

#' Implement an Always Cooperate strategy.
#' @param my_hist A character vector of the player's own previous moves.
#' @param opp_hist A character vector of the opponent's previous moves.
#' @param game_info A list containing metadata about the current game state.
r_coop <- function(my_hist, opp_hist, game_info = NA) {
  return("C")
}

# ─────────────────────────────────────────────────────────────
#  TOURNAMENT  
# ─────────────────────────────────────────────────────────────

#' Execute a round-robin tournament among multiple strategies.
#' @param strategies_list A named list of functions to be evaluated.
#' @param n_rounds Integer specifying how many rounds each match will last.
#' @param include_info Logical indicating whether metadata should be passed during matches.
#' @param payoff_matrix A 2x2 matrix defining the rewards for each interaction.
#' @return A list containing standings, the score matrix, and the cooperation matrix.
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

# ─────────────────────────────────────────────────────────────
#  EVALUATION REPORT  
# ─────────────────────────────────────────────────────────────

#' Print and return formatted tournament results.
#' @param results A list containing the output from a completed tournament.
#' @return Invisibly returns the input results list.
evaluate_tournament <- function(results) {
  
  cat("══════════════════════════════════════════════\n")
  cat("              TOURNAMENT RESULTS              \n")
  cat("══════════════════════════════════════════════\n\n")
  
  cat("── Final Standings ──────────────────────────\n")
  print(results$standings, row.names = FALSE)
  
  cat("\n── Avg Score per Round Matrix ───────────────\n")
  cat("   Row = strategy evaluated | Col = opponent\n\n")
  print(round(results$score_matrix, 3))
  
  cat("\n── Cooperation Rate Matrix ──────────────────\n")
  cat("   Row = strategy evaluated | Col = opponent\n\n")
  print(round(results$coop_matrix, 2))
  
  cat("\n── Head-to-Head Outcomes (+ = row beat col) ─\n")
  score_diff <- results$score_matrix - t(results$score_matrix)
  outcome_matrix <- matrix(
    ifelse(score_diff > 0, "W", ifelse(score_diff < 0, "L", "D")),
    nrow = nrow(score_diff),
    dimnames = dimnames(score_diff)
  )
  print(outcome_matrix)
  
  invisible(results)
}

# ─────────────────────────────────────────────────────────────
#  USAGE 
# ─────────────────────────────────────────────────────────────
my_contestants <- list(
  "R_TFT"     = r_tit_for_tat,
  "R_Traitor" = r_traitor,
  "Py_Defect" = py_defect,
  "Grudger"   = py_grudger,
  "CPP_TFT"   = cpp_tit_for_tat,
  "CPP_Coop"  = cpp_cooperate
)

results <- tournament(my_contestants, n_rounds = 200)
evaluate_tournament(results)

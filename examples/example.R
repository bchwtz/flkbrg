library(flkbrg)

# List internal and load external Strategies
python_strategies   <- load_python_strategies("strategies")
cpp_strategies      <- load_cpp_strategies("strategies")
r_strategies_flkbrg <- c("r_tit_for_tat", "r_traitor",  "r_defect", "r_coop")

# Play a single match
match_result <- match(strategy1 = r_coop,
                      strategy2 = cpp_defect,
                      n_rounds  = 200,
                      include_info = TRUE,
                      payoff_matrix = flkbrg::axelrod_payoff()
                      )

# Manually create a list of strategies for a tournament
cont <- list(
  "R_TFT"     = r_tit_for_tat,
  "CPP_TFT"   = cpp_tit_for_tat,
  "PY_TFT"    = py_tit_for_tat
)

# OR: Automatically create a list of strategies for a tournament
contestants <- c(mget(python_strategies),
                 mget(cpp_strategies),
                 mget(r_strategies_flkbrg, envir = asNamespace("flkbrg")))

# Play the tournament
tournament_result <- tournament(contestants, n_rounds = 200)




#TODO: Create proper Evaluation!
evaluate_tournament(results)
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

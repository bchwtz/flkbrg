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
tournament_result

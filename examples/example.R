library(flkbrg)

# List internal and load external Strategies
python_strategies   <- load_python_strategies("strategies")
cpp_strategies      <- load_cpp_strategies("strategies")
r_strategies_flkbrg <- c("r_tit_for_tat", "r_traitor", "r_defect", "r_coop")

# Check Strategies via File (.py or .cpp) or loaded R-Function
check_strategy(filepath = "strategies/cooperate.py")
check_strategy(FUN = r_tit_for_tat)

# Create a Payoff Matrix
payoff <- flkbrg_payoff(CC = c(3, 3), CD = c(0, 5), DC = c(5, 0), DD = c(1, 1))
payoff <- flkbrg_payoff() # Defaults also to Axelrods original payoff
payoff

# Play a single match
match_result <- match(strategy1 = r_coop,
                      strategy2 = cpp_defect,
                      n_rounds  = 200,
                      include_info = TRUE,
                      payoff = payoff)
match_result

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

# Check all already loaded functions before the tournament
sapply(contestants, function(FUN) check_strategy(FUN=FUN))

# Play the tournament
tournament_result <- tournament(contestants, n_rounds = 200)
tournament_result


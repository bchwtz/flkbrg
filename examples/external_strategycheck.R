#install.packages("devtools)
library(devtools)

devtools::source_url("https://raw.githubusercontent.com/bchwtz/flkbrg/refs/heads/main/R/payoff.R")
devtools::source_url("https://raw.githubusercontent.com/bchwtz/flkbrg/refs/heads/main/R/match.R")
devtools::source_url("https://raw.githubusercontent.com/bchwtz/flkbrg/refs/heads/main/R/check_strategies.R")
devtools::source_url("https://raw.githubusercontent.com/bchwtz/flkbrg/refs/heads/main/R/strategies.R")
rm("print.flkbrg_payoff"); rm("r_defect"); rm("r_tit_for_tat"); rm("r_traitor")

#-------------------------------------------------------------------------------
# The following example checks a strategy wihtout package installation. It loads
# the necessary functions explicitly and then checks a local strategy file for
# which the relative path to a .py or .cpp file must be provided.
#-------------------------------------------------------------------------------

## install.packages("devtools)
# library(devtools)
# source_url('https://strategycheck.flkbrg.de')
# check_strategy("path/to/strategy.py")
## Ex: check_strategy("strategies/grudger.py")
## Ex: check_strategy(FUN=r_tit_for_tat)

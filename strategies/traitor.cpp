#include <Rcpp.h>
using namespace Rcpp;

// [[Rcpp::export]]
CharacterVector cpp_traitor(CharacterVector my_hist,
                            CharacterVector opp_hist,
                            SEXP game_info) {

  if (Rf_isNull(game_info)) stop("game_info required");

  List info(game_info);
  int total = as<int>(info["total_rounds"]);
  int current = as<int>(info["current_round"]);

  if (current == total) return CharacterVector::create("D");
  return CharacterVector::create("C");
}

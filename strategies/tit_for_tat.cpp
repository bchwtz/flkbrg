#include <Rcpp.h>
using namespace Rcpp;

// [[Rcpp::export]]
CharacterVector cpp_tit_for_tat(CharacterVector my_hist,
                                CharacterVector opp_hist,
                                SEXP game_info) {

  if (Rf_isNull(game_info)) stop("game_info required");

  if (opp_hist.size() == 0)
    return CharacterVector::create("C");

  return CharacterVector::create(opp_hist[opp_hist.size() - 1]);
}

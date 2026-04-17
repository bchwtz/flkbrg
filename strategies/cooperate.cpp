#include <Rcpp.h>
using namespace Rcpp;

// [[Rcpp::export]]
CharacterVector cpp_cooperate(CharacterVector my_hist,
                              CharacterVector opp_hist,
                              SEXP game_info) {
  
  return CharacterVector::create("C");
}

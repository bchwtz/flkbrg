#include <Rcpp.h>
using namespace Rcpp;

// [[Rcpp::export]]
CharacterVector cpp_defect(CharacterVector my_hist,
                              CharacterVector opp_hist,
                              SEXP game_info) {
  
  return CharacterVector::create("D");
}

#' Load Python strategies from a specified directory
#'
#' @param directory Character string. The path to the folder containing .py files.
#' @param prefix Character string. A prefix to prepend to the loaded functions (e.g., "py_").
#' @param env An environment where the functions will be assigned (default is .GlobalEnv).
#'
#' @return A character vector containing the names of the strategies successfully loaded.
#' @import reticulate
#' @export
load_python_strategies <- function(directory = "strategies", prefix = "py_", env = .GlobalEnv) {

  if (!requireNamespace("reticulate", quietly = TRUE)) {
    stop("The 'reticulate' package is required.")
  }

  strategy_files <- list.files(directory, pattern = "\\.py$", full.names = TRUE)
  loaded_names   <- character(0)

  if (length(strategy_files) == 0) {
    warning("No Python files found in the specified directory.")
    return(loaded_names)
  }

  for (f in strategy_files) {
    # Define the name once
    name <- paste0(prefix, tools::file_path_sans_ext(basename(f)))

    # Source and assign
    reticulate::source_python(f)
    assign(name, reticulate::py$strategy, envir = env)

    # Track the name
    loaded_names <- c(loaded_names, name)
  }

  message(sprintf("Successfully loaded %d Python strategies.", length(loaded_names)))
  return(loaded_names)
}



#' Load C++ strategies from a specified directory
#'
#' @description
#' This function compiles and sources all .cpp files in a directory.
#' Note that for consistency, it is assumed that the function name exported
#' in the C++ code matches the filename (e.g., 'my_strat.cpp' should
#' export a function named 'my_strat').
#'
#' @param directory Character string. The path to the folder containing .cpp files.
#' @param env An environment where the functions will be loaded (default is .GlobalEnv).
#'
#' @return A character vector containing the names of the strategies successfully compiled.
#'
#' @note This function does not include a `prefix` argument, unlike the Python
#' equivalent. This is because C++ functions are exported with fixed symbol
#' names during the compilation process via `// [[Rcpp::export]]`. While we
#' can capture the filenames for tracking, we cannot programmatically rename
#' the underlying compiled symbols in the same way we can with Python objects.
#' @import Rcpp
#' @export
load_cpp_strategies <- function(directory = "strategies", env = .GlobalEnv) {

  if (!requireNamespace("Rcpp", quietly = TRUE)) {
    stop("The 'Rcpp' package is required to run this function.")
  }

  # 1. Find files in the specified directory
  strategy_files <- list.files(directory, pattern = "\\.cpp$", full.names = TRUE)
  loaded_names   <- character(0)

  if (length(strategy_files) == 0) {
    warning(paste("No C++ files found in:", directory))
    return(loaded_names)
  }

  # 2. Loop through the identified files
  for (f in strategy_files) {
    name <- paste0("cpp_", tools::file_path_sans_ext(basename(f)))

    # Try to compile and source the file
    tryCatch({
      Rcpp::sourceCpp(f, env = env)
      loaded_names <- c(loaded_names, name)
    }, error = function(e) {
      warning(paste("Failed to compile/load", f, ":", e$message))
    })
  }

  message(sprintf("Successfully compiled %d C++ strategies.", length(loaded_names)))
  return(loaded_names)
}

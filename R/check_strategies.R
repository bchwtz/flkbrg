#' Check a Single Strategy File
#'
#' Loads (Python) or compiles and loads (C++) a single strategy file, verifies
#' that the expected symbol is registered, runs a battery of behavioural
#' checks, and prints a formatted pass/fail report to the console.
#'
#' @param filepath Character. Path to a \code{.py} or \code{.cpp} strategy file.
#' @param env Environment. Where the loaded strategy function is assigned.
#'   Defaults to \code{.GlobalEnv}.
#' @param n_test_rounds Integer. Number of rounds used in the integration test
#'   match. Defaults to \code{50}.
#' @param payoff An object of class \code{flkbrg_payoff}. Passed to the
#'   integration test match. Defaults to \code{flkbrg_payoff()}.
#'
#' @details
#' The following checks are performed in order. If a check fails, subsequent
#' checks that depend on it are skipped and marked as \code{SKIP}.
#'
#' \describe{
#'   \item{file_exists}{The file can be found at \code{filepath}.}
#'   \item{extension}{The file extension is \code{.py} or \code{.cpp}.}
#'   \item{load_compile}{The file loads (Python via \code{reticulate::source_python})
#'     or compiles (C++ via \code{Rcpp::sourceCpp}) without error.}
#'   \item{symbol_exists}{The expected symbol (\code{py_<stem>} or
#'     \code{cpp_<stem>}) is present in \code{env} after loading.}
#'   \item{is_callable}{The registered symbol is a function.}
#'   \item{round1_no_info}{The strategy returns \code{"C"} or \code{"D"} on
#'     round 1 (empty histories) when \code{game_info} is absent.}
#'   \item{round1_with_info}{The strategy returns \code{"C"} or \code{"D"} on
#'     round 1 when a valid \code{game_info} object is supplied.}
#'   \item{midgame_call}{The strategy returns \code{"C"} or \code{"D"} with
#'     non-empty histories mid-game.}
#'   \item{integration}{A full \code{match()} against \code{r_coop} completes
#'     without error and returns the expected result structure.}
#' }
#'
#' @return A data frame with columns \code{check}, \code{status}, and
#'   \code{message}, invisibly. The report is always printed to the console.
#'
#' @export
check_strategy <- function(filepath,
                           env           = .GlobalEnv,
                           n_test_rounds = 50L,
                           payoff        = flkbrg_payoff()) {

  # ── Internal state ──────────────────────────────────────────────────────────

  checks <- list()

  pass <- function(name) {
    checks[[name]] <<- list(status = "PASS", message = "")
  }

  fail <- function(name, msg) {
    checks[[name]] <<- list(status = "FAIL", message = msg)
  }

  skip <- function(name) {
    checks[[name]] <<- list(status = "SKIP", message = "skipped due to earlier failure")
  }

  all_check_names <- c(
    "file_exists", "extension", "load_compile", "symbol_exists",
    "is_callable", "round1_no_info", "round1_with_info",
    "midgame_call", "integration"
  )

  skip_remaining <- function(from) {
    idx <- which(all_check_names == from)
    for (nm in all_check_names[seq(idx, length(all_check_names))]) skip(nm)
  }

  # ── Print helper (called once at the end) ───────────────────────────────────

  print_report <- function(lang, expected_name) {
    df       <- make_df()
    all_pass <- all(df$status %in% c("PASS", "SKIP"))
    overall  <- if (all_pass) "OK" else "FAILED"
    symbols  <- c(PASS = "v", FAIL = "x", SKIP = "-")

    cat("---\n")
    cat(sprintf("  flkbrg Strategy Check  |  %s  |  %s\n",
                basename(filepath), overall))
    cat("---\n")
    if (!is.na(lang))
      cat(sprintf("  Language : %s\n", lang))
    if (!is.na(expected_name))
      cat(sprintf("  Symbol   : %s\n", expected_name))
    cat("\n")

    for (i in seq_len(nrow(df))) {
      row <- df[i, ]
      cat(sprintf("  [%s] %s", symbols[row$status], row$check))
      if (nchar(row$message) > 0)
        cat(sprintf("\n       %s", row$message))
      cat("\n")
    }
    cat("---\n")
  }

  make_df <- function() {
    data.frame(
      check   = all_check_names,
      status  = vapply(all_check_names,
                       function(nm) checks[[nm]]$status,  character(1)),
      message = vapply(all_check_names,
                       function(nm) checks[[nm]]$message, character(1)),
      stringsAsFactors = FALSE
    )
  }

  finish <- function(lang = NA_character_, expected_name = NA_character_) {
    print_report(lang, expected_name)
    invisible(make_df())
  }

  # ── Check 1: file exists ────────────────────────────────────────────────────

  if (!file.exists(filepath)) {
    fail("file_exists", paste("file not found:", filepath))
    skip_remaining("extension")
    return(finish())
  }
  pass("file_exists")

  # ── Check 2: extension ─────────────────────────────────────────────────────

  ext  <- tools::file_ext(filepath)
  stem <- tools::file_path_sans_ext(basename(filepath))

  if (!ext %in% c("py", "cpp")) {
    fail("extension", paste0("unsupported extension '.", ext,
                             "' (expected .py or .cpp)"))
    skip_remaining("load_compile")
    return(finish())
  }
  pass("extension")

  lang          <- if (ext == "py") "python" else "cpp"
  prefix        <- if (lang == "python") "py_" else "cpp_"
  expected_name <- paste0(prefix, stem)

  # ── Check 3: load / compile ────────────────────────────────────────────────

  fn <- NULL

  if (lang == "python") {
    load_ok <- tryCatch({
      reticulate::source_python(filepath, envir = env)
      raw <- get("strategy", envir = env, inherits = FALSE)
      assign(expected_name, raw, envir = env)
      fn <- raw
      TRUE
    }, error = function(e) conditionMessage(e))

  } else {
    load_ok <- tryCatch({
      Rcpp::sourceCpp(filepath)
      fn <- get(expected_name, envir = .GlobalEnv)
      if (!identical(env, .GlobalEnv))
        assign(expected_name, fn, envir = env)
      TRUE
    }, error = function(e) conditionMessage(e))
  }

  if (!isTRUE(load_ok)) {
    fail("load_compile", load_ok)
    skip_remaining("symbol_exists")
    return(finish(lang, expected_name))
  }
  pass("load_compile")

  # ── Check 4: symbol exists ─────────────────────────────────────────────────

  if (is.null(fn) || !exists(expected_name, envir = env, inherits = FALSE)) {
    fail("symbol_exists",
         paste("expected symbol", expected_name, "not found after loading"))
    skip_remaining("is_callable")
    return(finish(lang, expected_name))
  }
  pass("symbol_exists")

  # ── Check 5: is callable ───────────────────────────────────────────────────

  if (!is.function(fn)) {
    fail("is_callable", paste(expected_name, "is not a function"))
    skip_remaining("round1_no_info")
    return(finish(lang, expected_name))
  }
  pass("is_callable")

  # ── Shared helpers for behavioural checks ──────────────────────────────────

  absent_info <- if (lang == "cpp") NULL else NA

  call_fn <- function(my_hist, opp_hist, game_info) {
    tryCatch(fn(my_hist, opp_hist, game_info),
             error = function(e) conditionMessage(e))
  }

  is_valid_move <- function(x) {
    is.character(x) && length(x) == 1 && x %in% c("C", "D")
  }

  # ── Check 6: round 1, no game_info ────────────────────────────────────────

  r1_no <- call_fn(character(0), character(0), absent_info)
  if (is_valid_move(r1_no)) {
    pass("round1_no_info")
  } else {
    fail("round1_no_info",
         paste("expected 'C' or 'D', got:", paste(r1_no, collapse = " ")))
  }

  # ── Check 7: round 1, with game_info ──────────────────────────────────────

  r1_yes <- call_fn(character(0), character(0),
                    list(total_rounds = n_test_rounds, current_round = 1L))
  if (is_valid_move(r1_yes)) {
    pass("round1_with_info")
  } else {
    fail("round1_with_info",
         paste("expected 'C' or 'D', got:", paste(r1_yes, collapse = " ")))
  }

  # ── Check 8: mid-game call ─────────────────────────────────────────────────

  hist_so_far <- c("C", "D", "C", "C", "D")
  mid <- call_fn(hist_so_far, rev(hist_so_far),
                 list(total_rounds  = n_test_rounds,
                      current_round = length(hist_so_far) + 1L))
  if (is_valid_move(mid)) {
    pass("midgame_call")
  } else {
    fail("midgame_call",
         paste("expected 'C' or 'D', got:", paste(mid, collapse = " ")))
  }

  # ── Check 9: integration via match() ──────────────────────────────────────

  int_ok <- tryCatch({
    res    <- match(fn, r_coop,
                    n_rounds     = n_test_rounds,
                    include_info = TRUE,
                    payoff       = payoff)
    needed <- c("strategies", "scores", "history")
    if (!all(needed %in% names(res)))
      stop("match() result missing fields: ",
           paste(setdiff(needed, names(res)), collapse = ", "))
    if (nrow(res$history) != n_test_rounds)
      stop("history has ", nrow(res$history), " rows, expected ", n_test_rounds)
    TRUE
  }, error = function(e) conditionMessage(e))

  if (isTRUE(int_ok)) {
    pass("integration")
  } else {
    fail("integration", int_ok)
  }

  finish(lang, expected_name)
}

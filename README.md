# `flkbrg` — Tournament Framework

Note: Watch out, this is mostly generated and needs to be handled with special care.

## Installation and Example

Install the `flkbrg` package using the following code in R:

```r
pak::pkg_install("bchwtz/flkbrg")
```

The [example.R - file](examples/example.R) guides you through your first
tournament using the included strategies coded in R, Python and C++.

## Table of Contents

1. [Overview](#overview)
2. [The Prisoner's Dilemma](#the-prisoners-dilemma)
3. [The Payoff Matrix](#the-payoff-matrix)
   - [Default values](#default-values)
   - [Customising the payoff](#customising-the-payoff)
   - [Validity conditions](#validity-conditions)
4. [Core Functions](#core-functions)
   - [match()](#match)
   - [tournament()](#tournament)
5. [Loading Strategies](#loading-strategies)
   - [load_python_strategies()](#load_python_strategies)
   - [load_cpp_strategies()](#load_cpp_strategies)
6. [Writing a Strategy](#writing-a-strategy)
   - [R skeleton](#r-skeleton)
   - [Python skeleton](#python-skeleton)
   - [C++ skeleton](#c-skeleton)
7. [Built-in Strategies](#built-in-strategies)
8. [Strategy Arguments in Detail](#strategy-arguments-in-detail)
9. [Evaluation Metrics](#evaluation-metrics)

---

## Overview

`flkbrg` is a round-robin tournament framework for iterated Prisoner's Dilemma
strategies. Strategies can be written in **R**, **Python**, or **C++** and
compete against each other on equal terms. The framework is built around three
core components:

- `flkbrg_payoff()` — constructs the payoff structure used by all matches.
- `match()` — runs a single head-to-head game between two strategies.
- `tournament()` — runs a full round-robin across all registered strategies and
  produces a ranked evaluation.

The design follows Robert Axelrod's original computer tournaments (1980–1984),
in which strategies were ranked by their **average payoff per round** across all
opponents, not by win/loss count.

---

## The Prisoner's Dilemma

Each round, both players simultaneously choose to either **Cooperate (C)** or
**Defect (D)**. The payoff each player receives depends on the combination of
both choices, as defined by the payoff matrix.

The structure creates a social dilemma: mutual cooperation yields the best
collective outcome, but each individual is always tempted to defect, and mutual
defection leaves both players worse off than if they had cooperated.

---

## The Payoff Matrix

### Default values

Payoffs are represented as `(Player 1, Player 2)` tuples. The default matrix
uses the values from Axelrod's original tournaments:

```
 \         P2
  \    C           D
P1 \ ------      ------
 C | (3, 3)      (0, 5)
 D | (5, 0)      (1, 1)
```

The four outcomes and their conventional names are:

| Outcome | P1 move | P2 move | P1 payoff | P2 payoff | Name                    |
|---------|---------|---------|-----------|-----------|-------------------------|
| CC      | C       | C       | 3         | 3         | Reward (mutual coop.)   |
| CD      | C       | D       | 0         | 5         | Sucker / Temptation     |
| DC      | D       | C       | 5         | 0         | Temptation / Sucker     |
| DD      | D       | D       | 1         | 1         | Punishment (mutual def.)|

### Customising the payoff

Use `flkbrg_payoff()` to create a payoff object. Each argument is a numeric
vector of length 2 giving the `c(P1, P2)` payoffs for that move combination:

```r
# Default Axelrod payoff (no arguments needed)
p <- flkbrg_payoff()

# Custom payoff
p_custom <- flkbrg_payoff(
  CC = c(3, 3),
  CD = c(0, 5),
  DC = c(5, 0),
  DD = c(1, 1)
)

# Inspect it
print(p)
```

The resulting object has class `"flkbrg_payoff"` and contains named elements
`CC`, `CD`, `DC`, `DD` (the raw tuples) as well as two matrices `P1` and `P2`
that are used internally by `match()` to look up payoffs by move name.

Pass a custom payoff object to `match()` or `tournament()` via the `payoff`
argument. Both functions default to `flkbrg_payoff()`.

### Validity conditions

For the game to constitute a valid Prisoner's Dilemma, payoffs must satisfy:

$$T > R > P > S \quad \text{and} \quad 2R > T + S$$

where **T** = Temptation (DC[1]), **R** = Reward (CC[1]), **P** = Punishment
(DD[1]), and **S** = Sucker (CD[1]). The framework does not enforce these
conditions automatically — it is the user's responsibility to supply a valid
payoff structure.

---

## Core Functions

### `match()`

`match()` simulates a single iterated game between two strategies over a fixed
number of rounds. It is the atomic unit of the framework — `tournament()` is
built entirely on top of it.

**Signature:**

```r
match(strategy1, strategy2, n_rounds = 200, include_info = TRUE,
      payoff = flkbrg_payoff())
```

**Arguments:**

| Argument       | Type               | Default          | Description                                              |
|----------------|--------------------|------------------|----------------------------------------------------------|
| `strategy1`    | function           | —                | Strategy function for Player 1.                          |
| `strategy2`    | function           | —                | Strategy function for Player 2.                          |
| `n_rounds`     | integer            | `200`            | Number of rounds per match (Axelrod's original default). |
| `include_info` | logical            | `TRUE`           | Whether to pass `game_info` metadata to strategies.      |
| `payoff`       | `flkbrg_payoff`    | `flkbrg_payoff()`| Payoff structure. Must be a `flkbrg_payoff` object.      |

**Return value:**

A named list with three elements:

- `strategies` — named character vector `c(P1 = ..., P2 = ...)` with strategy names.
- `scores` — named numeric vector `c(P1 = ..., P2 = ...)` with **raw** cumulative scores.
- `history` — a data frame with one row per round and columns `Round`, `P1`, `P2`, `P1_Payoff`, `P2_Payoff`.

Note that `match()` returns **raw** (un-normalised) scores. Normalisation to
average payoff per round happens inside `tournament()`.

**What it does, step by step:**

1. Initialises empty move histories and scores for both players.
2. For each round, calls both strategy functions with the current game state.
3. Uses the returned moves (`"C"` or `"D"`) to index the `P1` and `P2` payoff matrices.
4. Appends the moves and payoffs to the running history.
5. Returns the cumulative raw scores and the full round-by-round history.

The function is **symmetric**: both strategies receive the same game-state
information, just from their own perspective (`my_hist` is their own history,
`opp_hist` is the opponent's).

---

### `tournament()`

`tournament()` runs a full **round-robin** across all submitted strategies.
Every unique pair of strategies, including a strategy against itself (self-play),
is matched exactly once. For `n` strategies this produces:

$$M = \frac{n(n+1)}{2}$$

unique matches.

**Signature:**

```r
tournament(strategies_list, n_rounds = 200, include_info = TRUE,
           payoff = flkbrg_payoff())
```

**Arguments:**

| Argument          | Type            | Default           | Description                                                    |
|-------------------|-----------------|-------------------|----------------------------------------------------------------|
| `strategies_list` | named list      | —                 | Named list of strategy functions, e.g. `list(TFT = r_tit_for_tat, ...)`. Names are required. |
| `n_rounds`        | integer         | `200`             | Rounds per match.                                              |
| `include_info`    | logical         | `TRUE`            | Whether to pass `game_info` to strategies.                     |
| `payoff`          | `flkbrg_payoff` | `flkbrg_payoff()` | Payoff structure.                                              |

**Return value:**

A named list with four elements:

- `standings` — a data frame sorted by descending `Avg_Score`, with columns `Rank`, `Strategy`, `Avg_Score`, and `Coop_Rate`.
- `avg_score_matrix` — an `n × n` matrix of **average** payoffs per round, where entry `[i, j]` is strategy `i`'s normalised score against strategy `j`.
- `total_score_matrix` — an `n × n` matrix of **raw** cumulative scores across all rounds.
- `coop_matrix` — an `n × n` matrix of cooperation rates (0–1), where entry `[i, j]` is the fraction of rounds strategy `i` played C against strategy `j`.

Progress is printed to the console as each match completes.

---

## Loading Strategies

### `load_python_strategies()`

Scans a directory for `.py` files, sources each one via `reticulate`, and
registers the `strategy` function it defines in the target environment under the
name `py_<filename>`.

```r
load_python_strategies(directory = "strategies", prefix = "py_", env = .GlobalEnv)
```

| Argument    | Default        | Description                                    |
|-------------|----------------|------------------------------------------------|
| `directory` | `"strategies"` | Path to the folder containing `.py` files.     |
| `prefix`    | `"py_"`        | Prefix prepended to each registered name.      |
| `env`       | `.GlobalEnv`   | Environment where functions are assigned.      |

Returns a character vector of successfully loaded strategy names. Each `.py`
file **must** define a top-level function named `strategy` — this is the symbol
the loader looks for after sourcing the file.

### `load_cpp_strategies()`

Scans a directory for `.cpp` files and compiles each one via `Rcpp::sourceCpp`.
The compiled functions are registered in the target environment under the names
declared by their `// [[Rcpp::export]]` annotation (typically `cpp_<name>`).

```r
load_cpp_strategies(directory = "strategies", env = .GlobalEnv)
```

| Argument    | Default        | Description                                     |
|-------------|----------------|-------------------------------------------------|
| `directory` | `"strategies"` | Path to the folder containing `.cpp` files.     |
| `env`       | `.GlobalEnv`   | Environment where functions are loaded.         |

Returns a character vector of successfully compiled strategy names. Unlike the
Python loader, there is no `prefix` argument: the exported symbol name is fixed
at compile time by the `// [[Rcpp::export]]` annotation in the C++ source. By
convention the exported function should be named `cpp_<strategy_name>` to match
the file name (e.g. `tit_for_tat.cpp` exports `cpp_tit_for_tat`). Files that
fail to compile emit a warning and are skipped.

---

## Writing a Strategy

A strategy is a function that observes the history of the game so far and
returns a single move: either `"C"` (cooperate) or `"D"` (defect). All
strategies, regardless of the language they are written in, must conform to the
same three-argument interface.

---

### R skeleton

```r
#' My Strategy
#' @param my_hist  Character vector of this player's own moves so far.
#' @param opp_hist Character vector of the opponent's moves so far.
#' @param game_info A list with $total_rounds and $current_round, or NA
#'   if include_info = FALSE was set in match() / tournament().
#' @return A single character: "C" or "D".
my_strategy <- function(my_hist, opp_hist, game_info = NA) {

  # On the first round both histories are empty (length 0).
  # Implement your logic here and return exactly "C" or "D".

  return("C")
}
```

---

### Python skeleton

```python
# my_strategy.py
# The file name becomes part of the registered name: py_my_strategy

def strategy(my_hist, opp_hist, game_info=None):
    """
    my_hist   : list of this player's own moves, e.g. ["C", "C", "D"]
    opp_hist  : list of the opponent's moves,    e.g. ["C", "D", "C"]
    game_info : dict with keys 'total_rounds' and 'current_round',
                or None if include_info = FALSE was set.

    Must return exactly the string "C" or "D".
    """

    # On the first round both lists are empty.
    # Implement your logic here.

    return "C"
```

The file **must** define a top-level function named `strategy`. The loader
registers it as `py_<filename>` in R.

---

### C++ skeleton

```cpp
// my_strategy.cpp
// The exported function name becomes the R name: cpp_my_strategy

#include <Rcpp.h>
using namespace Rcpp;

// [[Rcpp::export]]
CharacterVector cpp_my_strategy(CharacterVector my_hist,
                                CharacterVector opp_hist,
                                SEXP            game_info) {
  /*
   * my_hist   : CharacterVector of this player's own moves.
   * opp_hist  : CharacterVector of the opponent's moves.
   * game_info : An R list (SEXP) with named elements "total_rounds" and
   *             "current_round" (both integers), or R_NilValue (NULL)
   *             if include_info = FALSE was set.
   *
   * Must return a CharacterVector containing exactly one element: "C" or "D".
   *
   * Always check Rf_isNull(game_info) before casting to List if your
   * strategy depends on round information.
   */

  // On the first round both vectors have size 0.
  // Implement your logic here.

  return CharacterVector::create("C");
}
```

---

## Built-in Strategies

The package ships with strategies in all three supported languages.

### R strategies (`strategies.R`)

| Name            | Description                                                                    |
|-----------------|--------------------------------------------------------------------------------|
| `r_tit_for_tat` | Cooperates on round 1; thereafter mirrors the opponent's last move.            |
| `r_traitor`     | Cooperates every round except the very last, on which it defects. Requires `include_info = TRUE`. |
| `r_defect`      | Always defects.                                                                |
| `r_coop`        | Always cooperates.                                                             |

### Python strategies (`strategies/`)

| File                 | Registered name      | Description                                                  |
|----------------------|----------------------|--------------------------------------------------------------|
| `tit_for_tat.py`     | `py_tit_for_tat`     | Cooperates first; mirrors opponent's last move thereafter.   |
| `grudger.py`         | `py_grudger`         | Cooperates until the opponent defects once, then defects forever. |
| `cooperate.py`       | `py_cooperate`       | Always cooperates.                                           |
| `defect.py`          | `py_defect`          | Always defects.                                              |

### C++ strategies (`strategies/`)

| File                 | Registered name      | Description                                                  |
|----------------------|----------------------|--------------------------------------------------------------|
| `tit_for_tat.cpp`    | `cpp_tit_for_tat`    | Cooperates first; mirrors opponent's last move thereafter.   |
| `traitor.cpp`        | `cpp_traitor`        | Cooperates every round except the last. Requires `game_info`.|
| `cooperate.cpp`      | `cpp_cooperate`      | Always cooperates.                                           |
| `defect.cpp`         | `cpp_defect`         | Always defects.                                              |

---

## Strategy Arguments in Detail

Every strategy receives the same three arguments on every round call.

### `my_hist` — own move history

A sequence of all moves this strategy has played so far in the **current
match**, in chronological order. On round 1 the sequence is empty. Each element
is either `"C"` or `"D"`.

| Language | Type                    | Empty on round 1 |
|----------|-------------------------|------------------|
| R        | `character vector`      | `character(0)`   |
| Python   | `list` of strings       | `[]`             |
| C++      | `Rcpp::CharacterVector` | `.size() == 0`   |

---

### `opp_hist` — opponent move history

Identical in structure to `my_hist`, but contains the **opponent's** moves.
The sequences are always the same length and are always from the perspective of
the receiving strategy: `my_hist[t]` and `opp_hist[t]` are the two moves that
occurred in round `t`.

---

### `game_info` — match metadata

An optional structured object passed only when `include_info = TRUE` is set in
`match()` or `tournament()`. It exposes two values:

| Field           | Type    | Description                                       |
|-----------------|---------|---------------------------------------------------|
| `total_rounds`  | integer | Total number of rounds this match will last.      |
| `current_round` | integer | The round currently being played (1-indexed).     |

When `include_info = FALSE`, the argument is `NA` (R/Python) or `R_NilValue`
(C++). Strategies that require this information (e.g. end-game defectors like
`r_traitor` and `cpp_traitor`) must check for its presence and raise an error
if it is absent. Strategies that do not use it should accept it silently.

---

### Return value

A strategy must return **exactly one string**: either `"C"` or `"D"`. Any other
value will cause `match()` to fail when it attempts to look up the move in the
payoff matrix. There is no error handling for invalid moves by design — the
constraint is part of the strategy contract.

---

## Evaluation Metrics

### Per-match score

After a match of `T` rounds between strategies `i` and `j`, the raw score of
strategy `i` is the sum of its payoffs across all rounds:

$$S_{ij}^{\text{raw}} = \sum_{t=1}^{T} p_t^{(i)}$$

where $p_t^{(i)}$ is the payoff strategy `i` received in round $t$ as
determined by the payoff matrix.

This is normalised to the **average payoff per round** inside `tournament()`:

$$S_{ij} = \frac{S_{ij}^{\text{raw}}}{T}$$

Normalisation makes scores comparable across matches of different lengths and
is the convention used in Axelrod's original tournaments. Note that `match()`
returns raw scores directly; the normalised `avg_score_matrix` is only computed
by `tournament()`.

---

### Score matrices

The tournament produces two `n × n` score matrices:

**Average score matrix** (`avg_score_matrix`): entry $S_{ij}$ is the normalised
(per-round) score of strategy `i` against strategy `j`:

$$\mathbf{S} \in \mathbb{R}^{n \times n}, \quad S_{ij} = \frac{1}{T}\sum_{t=1}^{T} p_t^{(i \text{ vs } j)}$$

**Total score matrix** (`total_score_matrix`): entry $R_{ij}$ is the raw
cumulative score of strategy `i` against strategy `j`:

$$\mathbf{R} \in \mathbb{R}^{n \times n}, \quad R_{ij} = \sum_{t=1}^{T} p_t^{(i \text{ vs } j)}$$

Both matrices are generally **asymmetric** ($S_{ij} \neq S_{ji}$) whenever the
two strategies do not earn equal payoffs against each other. The diagonal
records each strategy's score in self-play.

---

### Cooperation matrix

An `n × n` matrix (`coop_matrix`) records the fraction of rounds in which
strategy `i` played C when facing strategy `j`:

$$C_{ij} = \frac{1}{T}\sum_{t=1}^{T} \mathbf{1}\!\left[m_t^{(i)} = \text{C}\right]$$

A value of 1 means the strategy cooperated every round against that opponent;
0 means it defected every round.

---

### Final ranking criterion: Average Score

Each strategy's overall performance is summarised as the **mean of its row** in
the average score matrix, averaging across all `n` opponents (including
self-play):

$$\bar{S}_i = \frac{1}{n} \sum_{j=1}^{n} S_{ij}$$

Strategies are ranked in descending order of $\bar{S}_i$. This is the primary
ranking criterion from Axelrod (1980) and rewards strategies that perform well
across the **entire field** of opponents, not just against a single adversary.

An equivalent cooperation summary is the row mean of `coop_matrix`:

$$\bar{C}_i = \frac{1}{n} \sum_{j=1}^{n} C_{ij}$$

---

### Interpreting the standings table

| Column       | Formula                   | Interpretation                                               |
|--------------|---------------------------|--------------------------------------------------------------|
| `Rank`       | rank by $\bar{S}_i$ desc  | Overall position; 1 = best average performance.             |
| `Strategy`   | —                         | The name supplied in `strategies_list`.                      |
| `Avg_Score`  | $\bar{S}_i$               | Mean payoff per round across all opponents incl. self-play.  |
| `Coop_Rate`  | $\bar{C}_i$               | Mean cooperation rate across all opponents incl. self-play.  |

A strategy with a high `Avg_Score` and a high `Coop_Rate` achieves good
outcomes through mutual cooperation. A strategy with a high `Avg_Score` but a
low `Coop_Rate` is exploitative — its performance depends on the field
containing cooperative targets. In a field of pure defectors, an exploitative
strategy converges to the punishment payoff (P = 1) and will rank poorly.

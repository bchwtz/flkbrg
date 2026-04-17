# `flkbrg` — Tournament Framework Documentation

## Table of Contents

1. [Overview](#overview)
2. [The Prisoner's Dilemma](#the-prisoners-dilemma)
3. [Core Functions](#core-functions)
   - [match()](#match)
   - [tournament()](#tournament)
4. [Writing a Strategy](#writing-a-strategy)
   - [R skeleton](#r-skeleton)
   - [Python skeleton](#python-skeleton)
   - [C++ skeleton](#c-skeleton)
5. [Strategy Arguments in Detail](#strategy-arguments-in-detail)
6. [Evaluation Metrics](#evaluation-metrics)

---

## Overview

`flkbrg` is a round-robin tournament framework for iterated Prisoner's Dilemma
strategies. Strategies can be written in **R**, **Python**, or **C++** and
compete against each other on equal terms. The framework is built around two
core functions:

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
both choices, as defined by the payoff matrix:

|                  | Opponent: C | Opponent: D |
|------------------|-------------|-------------|
| **Player: C**    | 3 (Reward)  | 0 (Sucker)  |
| **Player: D**    | 5 (Temptation) | 1 (Punishment) |

The structure creates a social dilemma: mutual cooperation yields the best
collective outcome (3 + 3 = 6), but each individual is always tempted to defect
(5 > 3), and mutual defection leaves both players worse off than if they had
cooperated (1 < 3).

The payoff values must satisfy **T > R > P > S** and **2R > T + S** to
constitute a valid Prisoner's Dilemma. The default values (T=5, R=3, P=1, S=0)
are those used by Axelrod.

---

## Core Functions

### `match()`

`match()` simulates a single iterated game between two strategies over a fixed
number of rounds. It is the atomic unit of the framework — `tournament()` is
built entirely on top of it.

**What it does, step by step:**

1. Initialises empty move histories and scores for both players.
2. For each round, calls both strategy functions, passing them the current state
   of the game.
3. Maps each returned move (`"C"` or `"D"`) to its row/column index in the
   payoff matrix and computes both players' payoffs for that round.
4. Appends the moves and payoffs to the running history.
5. Returns the cumulative raw scores and the full round-by-round history.

The function is **symmetric**: both strategies receive exactly the same
information about the game state, just from their own perspective (i.e. their
own history is `my_hist` and the opponent's is `opp_hist`).

---

### `tournament()`

`tournament()` runs a full **round-robin** across all submitted strategies.
Every unique pair of strategies, including a strategy against itself (self-play),
is matched exactly once. For `n` strategies this produces:

$$M = \frac{n(n+1)}{2}$$

unique matches. Each match is delegated to `match()`, and the raw scores are
immediately normalised to **average payoff per round** before being stored.

The result is two `n × n` matrices (scores and cooperation rates) from which a
ranked standings table is derived.

---

## Writing a Strategy

A strategy is a function that observes the history of the game so far and
returns a single move: either `"C"` (cooperate) or `"D"` (defect). All
strategies, regardless of the language they are written in, must conform to the
same three-argument interface.

Strategies are loaded automatically from the `strategies/` directory:

- `.py` files are loaded via `reticulate` and registered as `py_<filename>`.
- `.cpp` files are compiled via `Rcpp::sourceCpp` and registered as
  `cpp_<function_name>` (as declared in the C++ source).
- R strategies are defined directly in the package or sourced manually.

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
renames it to `py_<filename>` when registering it in R.

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

## Strategy Arguments in Detail

Every strategy receives the same three arguments on every round call.

### `my_hist` — own move history

A sequence of all moves this strategy has played so far in the **current
match**, in chronological order. On round 1 the sequence is empty. Each element
is either `"C"` or `"D"`.

| Language | Type                         | Empty on round 1     |
|----------|------------------------------|----------------------|
| R        | `character vector`           | `character(0)`       |
| Python   | `list` of strings            | `[]`                 |
| C++      | `Rcpp::CharacterVector`      | `.size() == 0`       |

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

| Field           | Type    | Description                                      |
|-----------------|---------|--------------------------------------------------|
| `total_rounds`  | integer | Total number of rounds this match will last.     |
| `current_round` | integer | The round currently being played (1-indexed).    |

When `include_info = FALSE`, the argument is `NA` (R/Python) or `R_NilValue`
(C++). Strategies that require this information (e.g. end-game defectors like
`r_traitor`) must check for its presence and raise an error if it is absent.
Strategies that do not use it should accept it silently and ignore it.

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

This is immediately normalised to the **average payoff per round**:

$$S_{ij} = \frac{S_{ij}^{\text{raw}}}{T}$$

Normalisation makes scores comparable across matches of different lengths and
is the convention used in Axelrod's original tournaments.

---

### Score matrix

The tournament produces an `n × n` score matrix **S**, where entry $S_{ij}$
is the normalised score of strategy $i$ against strategy $j$:

$$\mathbf{S} \in \mathbb{R}^{n \times n}, \quad S_{ij} = \frac{1}{T}\sum_{t=1}^{T} p_t^{(i \text{ vs } j)}$$

The matrix is generally **asymmetric**: $S_{ij} \neq S_{ji}$ whenever the two
strategies do not earn equal payoffs against each other (which is the common
case). The diagonal $S_{ii}$ records a strategy's score in self-play.

---

### Cooperation matrix

An equivalent `n × n` matrix **C** records the fraction of rounds in which
strategy $i$ played C when facing strategy $j$:

$$C_{ij} = \frac{1}{T}\sum_{t=1}^{T} \mathbf{1}\!\left[m_t^{(i)} = \text{C}\right]$$

where $\mathbf{1}[\cdot]$ is the indicator function. A value of 1 means the
strategy cooperated every round against that opponent; 0 means it defected
every round. Like the score matrix, **C** is asymmetric.

---

### Final ranking criterion: Average Score

Each strategy's overall performance is summarised as the **mean of its row** in
the score matrix, averaging across all `n` opponents (including self-play):

$$\bar{S}_i = \frac{1}{n} \sum_{j=1}^{n} S_{ij}$$

Strategies are ranked in descending order of $\bar{S}_i$. This is the primary
ranking criterion from Axelrod (1980) and rewards strategies that perform well
across the **entire field** of opponents, not just against a single adversary.

An equivalent cooperation summary is the row mean of **C**:

$$\bar{C}_i = \frac{1}{n} \sum_{j=1}^{n} C_{ij}$$

This is reported alongside $\bar{S}_i$ in the standings table and can be used
to characterise whether high-scoring strategies tend to be cooperative or
exploitative.

---

### Interpreting the standings table

| Column       | Formula                  | Interpretation                                              |
|--------------|--------------------------|-------------------------------------------------------------|
| `Rank`       | rank by $\bar{S}_i$ desc | Overall position; 1 = best average performance.            |
| `Avg_Score`  | $\bar{S}_i$              | Mean payoff per round across all opponents incl. self-play. |
| `Coop_Rate`  | $\bar{C}_i$              | Mean cooperation rate across all opponents incl. self-play. |

A strategy with a high `Avg_Score` and a high `Coop_Rate` achieves good
outcomes through mutual cooperation. A strategy with a high `Avg_Score` but a
low `Coop_Rate` is exploitative — its performance depends on the field
containing cooperative targets. In a field of pure defectors, an exploitative
strategy converges to the punishment payoff (P = 1) and will rank poorly.

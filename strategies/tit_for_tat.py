# tit_for_tat.py
def strategy(my_hist, opp_hist, game_info=None):
    # Cooperate on first move, otherwise mirror opponent's last move
    if len(opp_hist) == 0:
        return "C"
    return opp_hist[-1]

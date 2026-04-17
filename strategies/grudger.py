# grudger.py
def strategy(my_hist, opp_hist, game_info=None):
    # Start cooperating; once opponent defects even once, defect forever
    if "D" in opp_hist:
        return "D"
    return "C"

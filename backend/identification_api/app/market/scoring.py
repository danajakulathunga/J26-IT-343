def calculate_export_score(demand: float, price: float, supply: float, season: float, quality: float, competition: float) -> float:
    # Export Decision Score = demand*0.25 + price*0.20 + supply*0.15 + season*0.15 + quality*0.15 + (100 - competition)*0.10
    score = (demand * 0.25) + (price * 0.20) + (supply * 0.15) + (season * 0.15) + (quality * 0.15) + ((100 - competition) * 0.10)
    return score

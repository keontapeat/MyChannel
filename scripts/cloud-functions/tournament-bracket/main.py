import functions_framework
from flask import jsonify
import math

@functions_framework.http
def tournament_bracket(request):
    """Generate intelligent tournament brackets."""
    data = request.get_json(silent=True) or {}
    
    players = data.get('players', [])
    skills = data.get('skills', {})
    format_type = data.get('format', 'singleElimination')
    
    if not players:
        return jsonify({'error': 'No players provided'}), 400
    
    # Sort players by ELO for seeding
    sorted_players = sorted(players, key=lambda p: skills.get(p, {}).get('eloRating', 1000), reverse=True)
    
    # Generate seeds
    seeds = {player: idx + 1 for idx, player in enumerate(sorted_players)}
    
    # Calculate number of rounds
    num_rounds = int(math.ceil(math.log2(len(players)))) if len(players) > 1 else 1
    
    # Generate first round matchups (1 vs last, 2 vs second-last, etc.)
    first_round = []
    half = len(sorted_players) // 2
    for i in range(half):
        first_round.append(sorted_players[i])
        first_round.append(sorted_players[len(sorted_players) - 1 - i])
    
    # Handle odd number of players
    if len(sorted_players) % 2 == 1:
        first_round.append(sorted_players[half])
    
    # Generate round structure
    rounds = [first_round]
    matches_in_round = half if half > 0 else 1
    for _ in range(1, num_rounds):
        matches_in_round = max(1, matches_in_round // 2)
        rounds.append(['TBD'] * (matches_in_round * 2))
    
    # Calculate fairness score
    total_elo_diff = 0
    match_count = 0
    for i in range(0, len(first_round) - 1, 2):
        p1_elo = skills.get(first_round[i], {}).get('eloRating', 1000)
        p2_elo = skills.get(first_round[i + 1], {}).get('eloRating', 1000)
        total_elo_diff += abs(p1_elo - p2_elo)
        match_count += 1
    
    avg_elo_diff = total_elo_diff / match_count if match_count > 0 else 0
    fairness_score = max(0.5, 1.0 - (avg_elo_diff / 500.0))
    
    # Estimate duration (30 min per match)
    total_matches = len(players) - 1 if len(players) > 1 else 0
    estimated_duration = total_matches * 30 * 60  # seconds
    
    return jsonify({
        'rounds': rounds,
        'seeds': seeds,
        'fairnessScore': fairness_score,
        'estimatedDuration': estimated_duration,
        'totalMatches': total_matches
    })








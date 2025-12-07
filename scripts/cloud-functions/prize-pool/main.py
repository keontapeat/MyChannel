import functions_framework
from flask import jsonify

@functions_framework.http
def prize_pool(request):
    """Optimize prize pool distribution."""
    data = request.get_json(silent=True) or {}
    
    action = data.get('action', 'optimizeMatch')
    
    if action == 'optimizeMatch':
        base_wager = data.get('baseWager', 0)
        total_wager = base_wager * 2
        
        # Dynamic fee based on wager amount
        if base_wager > 1000:
            fee_percentage = 0.08  # 8% for high stakes
        elif base_wager > 500:
            fee_percentage = 0.09  # 9% for medium stakes
        else:
            fee_percentage = 0.10  # 10% for low stakes
        
        platform_fee = total_wager * fee_percentage
        bonus_pool = base_wager * 0.05 if base_wager > 100 else 0
        optimized_amount = total_wager - platform_fee + bonus_pool
        
        return jsonify({
            'baseWager': base_wager,
            'totalWager': total_wager,
            'platformFee': platform_fee,
            'bonusPool': bonus_pool,
            'optimizedAmount': optimized_amount,
            'feePercentage': fee_percentage
        })
    
    elif action == 'optimizeTournament':
        total_prize = data.get('totalPrize', 0)
        player_count = data.get('playerCount', 8)
        format_type = data.get('format', 'singleElimination')
        
        # Prize distribution
        if format_type in ['singleElimination', 'doubleElimination']:
            distribution = {
                '1': total_prize * 0.50,
                '2': total_prize * 0.25,
                '3': total_prize * 0.15,
                '4': total_prize * 0.10
            }
        elif format_type == 'roundRobin':
            distribution = {
                '1': total_prize * 0.40,
                '2': total_prize * 0.25,
                '3': total_prize * 0.20,
                '4': total_prize * 0.15
            }
        else:  # swiss
            distribution = {
                '1': total_prize * 0.35,
                '2': total_prize * 0.25,
                '3': total_prize * 0.20,
                '4': total_prize * 0.12,
                '5': total_prize * 0.08
            }
        
        return jsonify({
            'distribution': distribution,
            'totalPrize': total_prize,
            'playerCount': player_count
        })
    
    return jsonify({'error': 'Unknown action'}), 400








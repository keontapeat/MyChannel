"""
🎯🔥 MILESTONE EMAIL AI - Agent #214 🔥🎯
Celebrate every creator milestone with beautiful emails!

First 100 subs, 1K, 10K, 100K, 1M - every milestone matters!
"""
import functions_framework
from flask import jsonify
import random

@functions_framework.http
def milestone_email_ai(request):
    """Generate beautiful milestone celebration emails"""
    
    if request.method == 'OPTIONS':
        return ('', 204, {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST', 'Access-Control-Allow-Headers': 'Content-Type'})
    
    data = request.get_json(silent=True) or {}
    creator_name = data.get('creatorName', 'Creator')
    milestone_type = data.get('milestoneType', 'subscribers')
    milestone_value = data.get('milestoneValue', 1000)
    
    # Milestone configurations
    milestone_configs = {
        100: {"emoji": "🌱", "title": "First 100!", "color": "#2ecc71", "message": "Your journey has begun!"},
        1000: {"emoji": "🚀", "title": "1K Club!", "color": "#3498db", "message": "You're officially growing!"},
        10000: {"emoji": "⭐", "title": "10K Star!", "color": "#9b59b6", "message": "You're a rising star!"},
        100000: {"emoji": "💎", "title": "100K Diamond!", "color": "#00aaff", "message": "You're in the top 1%!"},
        1000000: {"emoji": "👑", "title": "1M LEGEND!", "color": "#f1c40f", "message": "You're a LEGEND!"},
        10000000: {"emoji": "🔥", "title": "10M ICON!", "color": "#ff0000", "message": "You're an ICON!"}
    }
    
    config = milestone_configs.get(milestone_value, milestone_configs[1000])
    
    milestone_email = {
        "emailType": "milestone",
        "subject": f"{config['emoji']} {creator_name}, you just hit {milestone_value:,} {milestone_type}!",
        "preheader": config['message'],
        
        "htmlTemplate": f'''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif; background-color: #0f0f0f;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background: #0f0f0f;">
        <tr>
            <td align="center" style="padding: 40px 20px;">
                <table role="presentation" width="600" cellspacing="0" cellpadding="0" style="max-width: 600px;">
                    
                    <!-- Logo -->
                    <tr>
                        <td align="center" style="padding-bottom: 30px;">
                            <div style="font-size: 28px; font-weight: 800; color: #ff0000;">MyChannel</div>
                        </td>
                    </tr>
                    
                    <!-- Milestone Card -->
                    <tr>
                        <td style="background: linear-gradient(180deg, #1a1a1a 0%, #252525 100%); border-radius: 24px; padding: 50px 40px; text-align: center; border: 2px solid {config['color']};">
                            
                            <!-- Confetti Animation Effect -->
                            <div style="font-size: 80px; margin-bottom: 20px;">{config['emoji']}</div>
                            
                            <h1 style="color: {config['color']}; font-size: 36px; font-weight: 800; margin: 0 0 10px 0;">
                                {config['title']}
                            </h1>
                            
                            <div style="background: {config['color']}; -webkit-background-clip: text; color: #ffffff; font-size: 64px; font-weight: 900; margin: 20px 0;">
                                {milestone_value:,}
                            </div>
                            
                            <p style="color: rgba(255,255,255,0.7); font-size: 18px; margin: 0 0 30px 0;">
                                {milestone_type.title()}
                            </p>
                            
                            <p style="color: rgba(255,255,255,0.9); font-size: 20px; margin: 0 0 30px 0; font-style: italic;">
                                "{config['message']}"
                            </p>
                            
                            <!-- Share -->
                            <a href="https://mychannel.live/@{creator_name}" style="display: inline-block; background: {config['color']}; color: #ffffff; text-decoration: none; padding: 16px 40px; border-radius: 50px; font-size: 16px; font-weight: 700;">
                                Share Your Achievement →
                            </a>
                            
                        </td>
                    </tr>
                    
                    <!-- Next Goal -->
                    <tr>
                        <td style="padding: 30px; text-align: center;">
                            <div style="background: #1a1a1a; border-radius: 16px; padding: 25px; border: 1px solid #333;">
                                <p style="color: rgba(255,255,255,0.6); font-size: 14px; margin: 0 0 10px 0;">Next Milestone</p>
                                <p style="color: #ffffff; font-size: 28px; font-weight: 800; margin: 0;">{milestone_value * 10:,}</p>
                                <p style="color: rgba(255,255,255,0.6); font-size: 14px; margin: 10px 0 0 0;">Keep going, {creator_name}! 🔥</p>
                            </div>
                        </td>
                    </tr>
                    
                    <!-- Footer -->
                    <tr>
                        <td style="padding: 20px; text-align: center;">
                            <div style="color: rgba(255,255,255,0.4); font-size: 12px;">© 2024 MyChannel • You're crushing it!</div>
                        </td>
                    </tr>
                    
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
        ''',
        
        "milestoneDetails": {
            "type": milestone_type,
            "value": milestone_value,
            "nextMilestone": milestone_value * 10,
            "percentToNext": f"{random.randint(10, 30)}%"
        }
    }
    
    return jsonify({
        "status": f"🎯 MILESTONE EMAIL GENERATED! {config['emoji']}",
        "agent": "milestone-email-ai",
        "agentNumber": 214,
        "email": milestone_email,
        "quality": "CELEBRATION-WORTHY! 🎉"
    })

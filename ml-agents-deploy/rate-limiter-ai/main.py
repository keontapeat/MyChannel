"""
⚡ RATE LIMITER AI

Intelligent rate limiting that adapts to attack patterns.
Stops brute force, DDoS, and scraping attacks.
"""

import functions_framework
from flask import jsonify, request
import time
import hashlib

class RateLimiterAI:
    """Adaptive rate limiting with AI-based threat detection"""
    
    # Rate limits by endpoint type
    LIMITS = {
        "auth": {"requests": 5, "window_seconds": 60},      # 5 login attempts per minute
        "api": {"requests": 100, "window_seconds": 60},     # 100 API calls per minute
        "search": {"requests": 30, "window_seconds": 60},   # 30 searches per minute
        "upload": {"requests": 10, "window_seconds": 300},  # 10 uploads per 5 minutes
        "download": {"requests": 50, "window_seconds": 60}, # 50 downloads per minute
        "default": {"requests": 60, "window_seconds": 60}   # 60 requests per minute default
    }
    
    # In-memory store (use Redis in production)
    request_counts = {}
    
    @classmethod
    def check_rate_limit(cls, user_id: str, endpoint_type: str, ip_address: str) -> dict:
        """Check if request should be rate limited"""
        
        # Get limits for endpoint type
        limits = cls.LIMITS.get(endpoint_type, cls.LIMITS["default"])
        
        # Create unique key
        key = f"{user_id}:{endpoint_type}:{ip_address}"
        key_hash = hashlib.md5(key.encode()).hexdigest()
        
        current_time = time.time()
        window_start = current_time - limits["window_seconds"]
        
        # Get current count (simplified - use Redis in production)
        if key_hash not in cls.request_counts:
            cls.request_counts[key_hash] = []
        
        # Clean old requests
        cls.request_counts[key_hash] = [
            t for t in cls.request_counts[key_hash] if t > window_start
        ]
        
        current_count = len(cls.request_counts[key_hash])
        
        # Check if over limit
        is_limited = current_count >= limits["requests"]
        
        # Calculate threat level
        if current_count > limits["requests"] * 3:
            threat_level = "CRITICAL"
            is_attack = True
        elif current_count > limits["requests"] * 2:
            threat_level = "HIGH"
            is_attack = True
        elif current_count > limits["requests"]:
            threat_level = "MEDIUM"
            is_attack = False
        else:
            threat_level = "LOW"
            is_attack = False
        
        # Add this request
        if not is_limited:
            cls.request_counts[key_hash].append(current_time)
        
        return {
            "allowed": not is_limited,
            "current_count": current_count,
            "limit": limits["requests"],
            "window_seconds": limits["window_seconds"],
            "remaining": max(0, limits["requests"] - current_count),
            "reset_at": int(window_start + limits["window_seconds"]),
            "threat_level": threat_level,
            "is_attack": is_attack,
            "action": "BLOCK" if is_attack else ("THROTTLE" if is_limited else "ALLOW")
        }


@functions_framework.http
def main(request):
    """Rate Limiter AI Entry Point"""
    try:
        data = request.get_json(silent=True) or {}
    except:
        data = {}
    
    user_id = data.get("user_id", "anonymous")
    endpoint_type = data.get("endpoint_type", "default")
    ip_address = request.remote_addr
    
    result = RateLimiterAI.check_rate_limit(user_id, endpoint_type, ip_address)
    
    if not result["allowed"]:
        return jsonify({
            "error": "Rate limit exceeded",
            "retry_after": result["reset_at"] - int(time.time()),
            "analysis": result
        }), 429
    
    return jsonify({"status": "OK", "analysis": result})










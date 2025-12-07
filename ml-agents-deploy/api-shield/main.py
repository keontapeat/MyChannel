"""
🛡️ API SHIELD

Protects all API endpoints from attacks.
Validates requests, checks signatures, prevents abuse.
"""

import functions_framework
from flask import jsonify, request
import hmac
import hashlib
import time
import re

class APIShield:
    """Comprehensive API protection"""
    
    # API secret (in production, use secure secret management)
    API_SECRET = "mychannel-super-secret-key-change-in-production"
    
    @classmethod
    def validate_request(cls, request_data: dict) -> dict:
        """Validate incoming API request"""
        
        validations = {
            "signature_valid": False,
            "timestamp_valid": False,
            "payload_valid": False,
            "headers_valid": False,
            "origin_valid": False
        }
        issues = []
        
        # 1. Validate signature
        provided_sig = request_data.get("signature", "")
        payload = request_data.get("payload", "")
        expected_sig = hmac.new(
            cls.API_SECRET.encode(),
            payload.encode() if isinstance(payload, str) else str(payload).encode(),
            hashlib.sha256
        ).hexdigest()
        
        if hmac.compare_digest(provided_sig, expected_sig):
            validations["signature_valid"] = True
        else:
            issues.append("INVALID_SIGNATURE")
        
        # 2. Validate timestamp (prevent replay attacks)
        timestamp = request_data.get("timestamp", 0)
        current_time = time.time()
        if abs(current_time - timestamp) < 300:  # Within 5 minutes
            validations["timestamp_valid"] = True
        else:
            issues.append("TIMESTAMP_EXPIRED")
        
        # 3. Validate payload (no injection)
        payload_str = str(payload)
        injection_patterns = [r"<script", r"javascript:", r"onerror=", r"onclick="]
        has_injection = any(re.search(p, payload_str, re.I) for p in injection_patterns)
        if not has_injection:
            validations["payload_valid"] = True
        else:
            issues.append("INJECTION_DETECTED")
        
        # 4. Validate headers
        required_headers = ["content-type", "user-agent"]
        headers = request_data.get("headers", {})
        headers_lower = {k.lower(): v for k, v in headers.items()}
        if all(h in headers_lower for h in required_headers):
            validations["headers_valid"] = True
        else:
            issues.append("MISSING_REQUIRED_HEADERS")
        
        # 5. Validate origin
        origin = headers_lower.get("origin", "")
        allowed_origins = ["https://mychannel.live", "https://app.mychannel.live", "http://localhost:3000"]
        if origin in allowed_origins or not origin:
            validations["origin_valid"] = True
        else:
            issues.append("INVALID_ORIGIN")
        
        # Calculate overall validity
        valid_count = sum(validations.values())
        total_checks = len(validations)
        trust_score = valid_count / total_checks
        
        return {
            "is_valid": trust_score >= 0.8,
            "trust_score": round(trust_score, 2),
            "validations": validations,
            "issues": issues,
            "should_allow": trust_score >= 0.8,
            "should_block": trust_score < 0.5,
            "action": "ALLOW" if trust_score >= 0.8 else "CHALLENGE" if trust_score >= 0.5 else "BLOCK"
        }


@functions_framework.http
def main(request):
    """API Shield Entry Point"""
    try:
        data = request.get_json(silent=True) or {}
    except:
        data = {}
    
    # Add request metadata
    data["headers"] = dict(request.headers)
    data["timestamp"] = data.get("timestamp", time.time())
    
    result = APIShield.validate_request(data)
    
    if result["should_block"]:
        return jsonify({
            "error": "Request validation failed",
            "issues": result["issues"]
        }), 403
    
    return jsonify({
        "status": "VALIDATED",
        "shield": "ACTIVE 🛡️",
        "analysis": result
    })










"""
🕵️ INSIDER THREAT DETECTOR

Detects employees or contractors who might be trying to steal data.
Uses behavioral analysis to catch bad actors.
"""

import functions_framework
from flask import jsonify, request
import time

class InsiderThreatDetector:
    """Detect insider threats through behavioral analysis"""
    
    @classmethod
    def analyze_employee_behavior(cls, employee_data: dict) -> dict:
        """Analyze employee behavior for insider threat indicators"""
        
        risk_indicators = []
        risk_score = 0.0
        
        # Check for unusual data access
        data_accessed_today = employee_data.get("records_accessed_today", 0)
        avg_daily_access = employee_data.get("avg_daily_access", 100)
        
        if data_accessed_today > avg_daily_access * 5:
            risk_indicators.append("EXCESSIVE_DATA_ACCESS")
            risk_score += 0.3
        
        # Check for access outside normal hours
        hour = employee_data.get("current_hour", 12)
        if hour < 6 or hour > 22:
            risk_indicators.append("OFF_HOURS_ACCESS")
            risk_score += 0.2
        
        # Check for bulk downloads
        downloads_today = employee_data.get("downloads_today", 0)
        if downloads_today > 100:
            risk_indicators.append("BULK_DOWNLOAD")
            risk_score += 0.35
        
        # Check for access to sensitive areas
        sensitive_access = employee_data.get("sensitive_areas_accessed", [])
        if len(sensitive_access) > 5:
            risk_indicators.append("MULTIPLE_SENSITIVE_AREAS")
            risk_score += 0.25
        
        # Check if employee gave notice
        gave_notice = employee_data.get("resignation_pending", False)
        if gave_notice:
            risk_indicators.append("DEPARTING_EMPLOYEE")
            risk_score += 0.2
        
        # Check for USB/external device usage
        external_devices = employee_data.get("external_devices_connected", 0)
        if external_devices > 0:
            risk_indicators.append("EXTERNAL_DEVICE_USAGE")
            risk_score += 0.15
        
        risk_score = min(risk_score, 1.0)
        
        return {
            "risk_score": round(risk_score, 3),
            "risk_level": "CRITICAL" if risk_score > 0.7 else "HIGH" if risk_score > 0.5 else "MEDIUM" if risk_score > 0.3 else "LOW",
            "risk_indicators": risk_indicators,
            "is_threat": risk_score > 0.5,
            "recommended_action": cls._get_action(risk_score),
            "should_alert_security": risk_score > 0.6,
            "should_revoke_access": risk_score > 0.8
        }
    
    @staticmethod
    def _get_action(score: float) -> str:
        if score > 0.8:
            return "IMMEDIATE_ACCESS_REVOCATION"
        elif score > 0.6:
            return "ALERT_SECURITY_TEAM"
        elif score > 0.4:
            return "ENHANCED_MONITORING"
        elif score > 0.2:
            return "LOG_AND_REVIEW"
        return "NORMAL_MONITORING"


@functions_framework.http
def main(request):
    """Insider Threat Detector Entry Point"""
    try:
        data = request.get_json(silent=True) or {}
    except:
        data = {}
    
    result = InsiderThreatDetector.analyze_employee_behavior(data)
    
    return jsonify({
        "status": "ANALYZED",
        "protection": "INSIDER THREAT DETECTION ACTIVE 🕵️",
        "analysis": result
    })


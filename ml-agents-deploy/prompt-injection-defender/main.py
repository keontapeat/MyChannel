"""
🛡️ PROMPT INJECTION DEFENDER

Specifically designed to stop AI-based prompt injection attacks.
These are the attacks where hackers try to manipulate AI systems
by injecting malicious prompts.

This is the #1 threat from AI hackers - we stop it COLD!
"""

import functions_framework
from flask import jsonify, request
import re
import hashlib
import json

class PromptInjectionDefender:
    """Specialized defense against prompt injection attacks"""
    
    # Comprehensive prompt injection patterns
    INJECTION_PATTERNS = [
        # Direct instruction override
        (r"ignore (all )?(previous|prior|above|earlier) (instructions|prompts|context)", "DIRECT_OVERRIDE", 0.9),
        (r"disregard (everything|all|any) (above|before|prior)", "DIRECT_OVERRIDE", 0.9),
        (r"forget (what|everything) (i|you|we) (said|told|mentioned)", "MEMORY_MANIPULATION", 0.85),
        
        # Role manipulation
        (r"you are (now|actually|really) (a|an)", "ROLE_HIJACK", 0.8),
        (r"pretend (to be|you are|that you)", "ROLE_HIJACK", 0.8),
        (r"act as (if|though|a|an)", "ROLE_HIJACK", 0.75),
        (r"imagine (you are|being|that)", "ROLE_HIJACK", 0.7),
        (r"roleplay as", "ROLE_HIJACK", 0.8),
        
        # System prompt extraction
        (r"(show|reveal|display|print|output) (your|the) (system|initial|original) (prompt|instructions)", "SYSTEM_EXTRACTION", 0.95),
        (r"what (are|were) your (original|initial|system) (instructions|prompts)", "SYSTEM_EXTRACTION", 0.9),
        (r"repeat (your|the) (system|initial) (message|prompt)", "SYSTEM_EXTRACTION", 0.9),
        
        # Jailbreak attempts
        (r"(DAN|developer|god|admin|root|sudo) mode", "JAILBREAK", 0.95),
        (r"jailbreak", "JAILBREAK", 0.95),
        (r"(bypass|disable|ignore|override) (your|the|all) (safety|security|restrictions|filters|guidelines)", "JAILBREAK", 0.95),
        (r"unrestricted mode", "JAILBREAK", 0.9),
        (r"no (rules|restrictions|limits|boundaries)", "JAILBREAK", 0.85),
        
        # Delimiter attacks
        (r"<\|im_start\|>", "DELIMITER_INJECTION", 0.95),
        (r"<\|im_end\|>", "DELIMITER_INJECTION", 0.95),
        (r"\[INST\]", "DELIMITER_INJECTION", 0.9),
        (r"\[/INST\]", "DELIMITER_INJECTION", 0.9),
        (r"### (Human|Assistant|System):", "DELIMITER_INJECTION", 0.85),
        (r"<s>|</s>", "DELIMITER_INJECTION", 0.8),
        (r"<<SYS>>|<</SYS>>", "DELIMITER_INJECTION", 0.9),
        
        # Encoding bypass attempts
        (r"base64:", "ENCODING_BYPASS", 0.7),
        (r"hex:", "ENCODING_BYPASS", 0.7),
        (r"rot13:", "ENCODING_BYPASS", 0.7),
        (r"unicode:", "ENCODING_BYPASS", 0.7),
        
        # Data extraction
        (r"(list|show|dump|export|extract) (all )?(user|customer|admin|password|credential|secret|api.?key)", "DATA_EXTRACTION", 0.9),
        (r"(reveal|expose|leak|share) (sensitive|private|confidential|internal)", "DATA_EXTRACTION", 0.85),
        
        # Code execution
        (r"(execute|run|eval|exec)\s*\(", "CODE_EXECUTION", 0.95),
        (r"__import__", "CODE_EXECUTION", 0.95),
        (r"os\.(system|popen|exec)", "CODE_EXECUTION", 0.95),
        (r"subprocess\.", "CODE_EXECUTION", 0.95),
        
        # Social engineering
        (r"(i am|this is) (the|a|an) (admin|developer|owner|creator|ceo)", "SOCIAL_ENGINEERING", 0.7),
        (r"(emergency|urgent|critical).*(access|override|bypass)", "SOCIAL_ENGINEERING", 0.75),
        (r"for (testing|debugging|development) (purposes|only)", "SOCIAL_ENGINEERING", 0.6),
    ]
    
    # Known attack signatures (hash of known attacks)
    KNOWN_ATTACK_HASHES = set()
    
    @classmethod
    def analyze(cls, text: str) -> dict:
        """Analyze text for prompt injection attempts"""
        
        if not text:
            return {"is_injection": False, "risk_score": 0.0}
        
        text_lower = text.lower()
        detections = []
        max_severity = 0.0
        
        # Check against patterns
        for pattern, attack_type, severity in cls.INJECTION_PATTERNS:
            if re.search(pattern, text_lower, re.IGNORECASE):
                detections.append({
                    "type": attack_type,
                    "pattern": pattern,
                    "severity": severity
                })
                max_severity = max(max_severity, severity)
        
        # Check for known attack signatures
        text_hash = hashlib.sha256(text.encode()).hexdigest()[:16]
        if text_hash in cls.KNOWN_ATTACK_HASHES:
            detections.append({
                "type": "KNOWN_ATTACK_SIGNATURE",
                "severity": 1.0
            })
            max_severity = 1.0
        
        # Additional heuristics
        
        # Check for excessive special characters (encoding attacks)
        special_char_ratio = len(re.findall(r'[<>\[\]{}|\\^`]', text)) / max(len(text), 1)
        if special_char_ratio > 0.1:
            detections.append({
                "type": "SUSPICIOUS_ENCODING",
                "severity": 0.6
            })
            max_severity = max(max_severity, 0.6)
        
        # Check for very long inputs (often used in attacks)
        if len(text) > 5000:
            detections.append({
                "type": "EXCESSIVE_LENGTH",
                "severity": 0.5
            })
            max_severity = max(max_severity, 0.5)
        
        # Check for repeated patterns (fuzzing)
        if cls._is_fuzzing(text):
            detections.append({
                "type": "FUZZING_ATTEMPT",
                "severity": 0.7
            })
            max_severity = max(max_severity, 0.7)
        
        is_injection = max_severity > 0.5
        
        return {
            "is_injection": is_injection,
            "risk_score": round(max_severity, 3),
            "detections": detections,
            "total_patterns_matched": len(detections),
            "recommendation": cls._get_recommendation(max_severity),
            "should_block": max_severity > 0.7,
            "should_alert": max_severity > 0.5,
            "sanitized_input": cls._sanitize(text) if is_injection else text
        }
    
    @staticmethod
    def _is_fuzzing(text: str) -> bool:
        """Detect fuzzing attempts"""
        # Check for repeated substrings
        if len(text) > 100:
            chunks = [text[i:i+10] for i in range(0, len(text)-10, 10)]
            unique_chunks = set(chunks)
            if len(unique_chunks) < len(chunks) * 0.3:
                return True
        return False
    
    @staticmethod
    def _sanitize(text: str) -> str:
        """Sanitize potentially malicious input"""
        # Remove known dangerous patterns
        sanitized = re.sub(r'<\|.*?\|>', '', text)
        sanitized = re.sub(r'\[INST\].*?\[/INST\]', '', sanitized)
        sanitized = re.sub(r'###.*?:', '', sanitized)
        return sanitized[:1000]  # Limit length
    
    @staticmethod
    def _get_recommendation(severity: float) -> str:
        if severity > 0.8:
            return "BLOCK_AND_BAN - Confirmed attack attempt"
        elif severity > 0.6:
            return "BLOCK - High probability of attack"
        elif severity > 0.4:
            return "CHALLENGE - Require additional verification"
        elif severity > 0.2:
            return "LOG_AND_MONITOR - Suspicious but allow"
        else:
            return "ALLOW - No threat detected"


@functions_framework.http
def main(request):
    """
    Prompt Injection Defender - Stops AI hackers cold!
    """
    try:
        data = request.get_json(silent=True) or {}
    except:
        data = {}
    
    text = data.get("text", data.get("input", data.get("prompt", "")))
    
    result = PromptInjectionDefender.analyze(text)
    
    if result["should_block"]:
        return jsonify({
            "status": "BLOCKED",
            "reason": "Prompt injection attack detected",
            "analysis": result
        }), 403
    
    return jsonify({
        "status": "ANALYZED",
        "protection": "ACTIVE 🛡️",
        "analysis": result
    })

"""
🛡️🔥 FILE GUARDIAN OPUS 4.5 - REAL VERTEX AI ML AGENT 🔥🛡️
============================================================
POWERED BY CLAUDE OPUS 4.5 ON GOOGLE CLOUD VERTEX AI

This is a REAL ML agent that uses Claude Opus 4.5 to intelligently
analyze file operations and prevent accidental deletions.

Project: mychannel-ca26d
Region: us-central1
Model: claude-opus-4-5-20250514 (Anthropic on Vertex AI)
============================================================
"""

import functions_framework
from flask import jsonify, request
import json
import os
import re
from datetime import datetime
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, asdict
from enum import Enum
import traceback

# Vertex AI imports
try:
    from anthropic import AnthropicVertex
    VERTEX_AVAILABLE = True
except ImportError:
    VERTEX_AVAILABLE = False
    print("⚠️ AnthropicVertex not available, using rule-based fallback")

# =============================================================================
# CONFIGURATION
# =============================================================================

PROJECT_ID = "mychannel-ca26d"
REGION = "us-east5"  # Opus 4.5 available region
MODEL_ID = "claude-opus-4-5-20250514"

class RiskLevel(Enum):
    SAFE = "safe"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"
    NUCLEAR = "nuclear"

class OperationType(Enum):
    READ = "read"
    WRITE = "write"
    DELETE = "delete"
    MOVE = "move"
    RENAME = "rename"
    BULK_DELETE = "bulk_delete"
    OVERWRITE = "overwrite"

# =============================================================================
# PROTECTED RESOURCES - HARDCODED NUCLEAR PROTECTION
# =============================================================================

NUCLEAR_PROTECTED = {
    "files": [
        "MyChannel/App/MyChannelApp.swift",
        "MyChannel/Core/Config/AppConfig.swift",
        "MyChannel/Core/Config/AppSecrets.swift",
        "MyChannel/Core/Theme/AppTheme.swift",
        "MyChannel.xcodeproj/project.pbxproj",
        "web-v2/package.json",
        "web-v2/next.config.ts",
        "firebase.json",
        "firestore.rules",
        ".cursorrules",
        ".git/HEAD",
        ".git/config",
    ],
    "directories": [
        "MyChannel/Core/",
        "MyChannel/Features/",
        "MyChannel/App/",
        "MyChannel.xcodeproj/",
        "web-v2/app/",
        "web-v2/components/",
        "web-v2/lib/",
        ".git/",
        ".github/",
    ],
    "extensions": [
        ".swift", ".ts", ".tsx", ".js", ".jsx",
        ".json", ".yaml", ".yml", ".plist",
        ".pbxproj", ".xcodeproj", ".entitlements",
    ],
    "dangerous_commands": [
        r"rm\s+-rf",
        r"rm\s+-r\s+",
        r"rm\s+\*",
        r"find.*-delete",
        r"git\s+clean\s+-fd",
        r"git\s+reset\s+--hard",
        r"git\s+push.*--force",
        r"del\s+/s",
        r"rmdir\s+/s",
    ]
}

# =============================================================================
# OPUS 4.5 SYSTEM PROMPT
# =============================================================================

GUARDIAN_SYSTEM_PROMPT = """You are the FILE GUARDIAN AGENT for the MyChannel project - a $1 Trillion video platform.

YOUR MISSION: Protect ALL project files from accidental deletion. NEVER allow critical files to be deleted.

PROTECTED RESOURCES:
- MyChannel/Core/ - Core iOS app infrastructure (NEVER DELETE)
- MyChannel/Features/ - All app features (NEVER DELETE)
- MyChannel/App/ - App entry point (NEVER DELETE)
- MyChannel.xcodeproj/ - Xcode project (NEVER DELETE)
- web-v2/ - Next.js web app (NEVER DELETE)
- services/ - Backend services (NEVER DELETE)
- .git/ - Git repository (NEVER DELETE)

CRITICAL FILES:
- MyChannelApp.swift - App entry point
- AppConfig.swift - Configuration
- AppSecrets.swift - API keys
- AppTheme.swift - UI theme
- project.pbxproj - Xcode project file
- package.json - Web dependencies
- firebase.json - Firebase config
- firestore.rules - Database rules

RULES:
1. NEVER allow deletion of .swift files in MyChannel/
2. NEVER allow deletion of .ts/.tsx files in web-v2/
3. NEVER allow bulk deletions (rm -rf, find -delete)
4. NEVER allow deletion of configuration files
5. NEVER allow AI/Cursor to delete ANY source files
6. Block ANY operation that could cause data loss

When analyzing a request, respond with JSON:
{
    "allowed": false,
    "risk_level": "nuclear|critical|high|medium|low|safe",
    "reason": "Clear explanation",
    "alternative_action": "What to do instead",
    "recovery_command": "git restore <file> or backup command"
}

REMEMBER: When in doubt, BLOCK IT. Files can always be manually deleted later, but accidental deletions are catastrophic."""

# =============================================================================
# FILE GUARDIAN OPUS 4.5 AGENT
# =============================================================================

class FileGuardianOpus:
    """
    🛡️ FILE GUARDIAN OPUS 4.5 🛡️
    
    Real ML Agent powered by Claude Opus 4.5 on Vertex AI.
    Uses advanced reasoning to protect files from accidental deletion.
    """
    
    def __init__(self):
        self.name = "FileGuardianOpus"
        self.version = "1.0.0"
        self.model = MODEL_ID
        self.project_id = PROJECT_ID
        self.region = REGION
        self.client = None
        self.blocked_count = 0
        self.analyzed_count = 0
        
        # Initialize Vertex AI client
        if VERTEX_AVAILABLE:
            try:
                self.client = AnthropicVertex(
                    project_id=PROJECT_ID,
                    region=REGION
                )
                print(f"✅ Opus 4.5 client initialized: {MODEL_ID}")
            except Exception as e:
                print(f"⚠️ Failed to initialize Opus client: {e}")
                self.client = None
    
    def _hardcoded_protection(self, operation: str, file_path: str, context: str = "") -> Optional[Dict]:
        """
        First layer: Hardcoded protection rules (instant, no API call needed)
        These rules ALWAYS apply, even if Opus is unavailable.
        """
        
        # Check nuclear protected files
        for protected_file in NUCLEAR_PROTECTED["files"]:
            if protected_file in file_path or file_path.endswith(protected_file):
                if operation in ["delete", "bulk_delete"]:
                    return {
                        "allowed": False,
                        "risk_level": "nuclear",
                        "reason": f"🚫 NUCLEAR BLOCK: '{file_path}' is a critical system file that cannot be deleted.",
                        "alternative_action": "Use EDIT operations only. Never delete critical files.",
                        "recovery_command": f"git restore {file_path}"
                    }
        
        # Check nuclear protected directories
        for protected_dir in NUCLEAR_PROTECTED["directories"]:
            if file_path.startswith(protected_dir):
                if operation in ["delete", "bulk_delete"]:
                    return {
                        "allowed": False,
                        "risk_level": "nuclear",
                        "reason": f"🚫 NUCLEAR BLOCK: Cannot delete files in protected directory '{protected_dir}'",
                        "alternative_action": "Files in this directory are essential. Use version control instead.",
                        "recovery_command": f"git restore {file_path}"
                    }
        
        # Check dangerous commands
        for pattern in NUCLEAR_PROTECTED["dangerous_commands"]:
            if re.search(pattern, context, re.IGNORECASE):
                return {
                    "allowed": False,
                    "risk_level": "nuclear",
                    "reason": f"🚫 NUCLEAR BLOCK: Dangerous command detected in context. Bulk operations are forbidden.",
                    "alternative_action": "Delete files individually after careful review.",
                    "recovery_command": "./scripts/recover-deleted.sh"
                }
        
        # Check protected extensions for delete operations
        if operation == "delete":
            ext = os.path.splitext(file_path)[1].lower()
            if ext in NUCLEAR_PROTECTED["extensions"]:
                # Check if it's a source file in critical location
                if any(file_path.startswith(d) for d in ["MyChannel/", "web-v2/"]):
                    return {
                        "allowed": False,
                        "risk_level": "critical",
                        "reason": f"🚨 CRITICAL: Cannot delete source file '{file_path}' ({ext})",
                        "alternative_action": "Comment out code or use feature flags instead of deleting.",
                        "recovery_command": f"git restore {file_path}"
                    }
        
        # Check for AI source
        ai_sources = ["cursor", "ai", "copilot", "assistant", "agent", "claude", "gpt"]
        source_lower = context.lower() if context else ""
        if any(ai in source_lower for ai in ai_sources):
            if operation == "delete":
                return {
                    "allowed": False,
                    "risk_level": "critical",
                    "reason": "🚨 AI DELETION BLOCKED: AI assistants cannot delete files without explicit human approval.",
                    "alternative_action": "AI should use EDIT operations only. Human must delete manually.",
                    "recovery_command": f"git restore {file_path}"
                }
        
        return None  # No hardcoded rule matched, proceed to Opus analysis
    
    async def analyze_with_opus(self, operation: str, file_path: str, source: str, context: str = "") -> Dict:
        """
        Second layer: Use Claude Opus 4.5 for intelligent analysis.
        """
        
        if not self.client:
            # Fallback to conservative rule-based decision
            return {
                "allowed": operation in ["read", "write"],
                "risk_level": "medium" if operation == "delete" else "low",
                "reason": "Opus unavailable. Using conservative fallback: blocking deletes.",
                "alternative_action": "Use git for file management.",
                "recovery_command": f"git restore {file_path}"
            }
        
        try:
            # Build the analysis prompt
            analysis_prompt = f"""Analyze this file operation for the MyChannel project:

OPERATION: {operation}
FILE PATH: {file_path}
SOURCE: {source}
CONTEXT: {context or 'None provided'}

Based on the protection rules, should this operation be allowed?
Consider:
1. Is this a critical system file?
2. Is this in a protected directory?
3. Is the source an AI assistant?
4. Could this cause data loss?
5. Is there a safer alternative?

Respond with ONLY valid JSON (no markdown, no explanation outside JSON):
{{
    "allowed": true or false,
    "risk_level": "nuclear|critical|high|medium|low|safe",
    "reason": "explanation",
    "alternative_action": "what to do instead (or null)",
    "recovery_command": "recovery command (or null)"
}}"""

            # Call Opus 4.5
            response = self.client.messages.create(
                model=MODEL_ID,
                max_tokens=1024,
                system=GUARDIAN_SYSTEM_PROMPT,
                messages=[
                    {"role": "user", "content": analysis_prompt}
                ]
            )
            
            # Parse response
            response_text = response.content[0].text.strip()
            
            # Extract JSON from response
            try:
                # Try to find JSON in response
                json_match = re.search(r'\{[\s\S]*\}', response_text)
                if json_match:
                    result = json.loads(json_match.group())
                else:
                    result = json.loads(response_text)
                
                return {
                    "allowed": result.get("allowed", False),
                    "risk_level": result.get("risk_level", "high"),
                    "reason": result.get("reason", "Opus analysis complete"),
                    "alternative_action": result.get("alternative_action"),
                    "recovery_command": result.get("recovery_command"),
                    "opus_analysis": True
                }
                
            except json.JSONDecodeError:
                # If JSON parsing fails, be conservative
                return {
                    "allowed": False,
                    "risk_level": "high",
                    "reason": f"Opus response parsing failed. Being conservative. Raw: {response_text[:200]}",
                    "alternative_action": "Retry the operation or proceed manually.",
                    "recovery_command": f"git restore {file_path}"
                }
                
        except Exception as e:
            return {
                "allowed": False,
                "risk_level": "critical",
                "reason": f"Opus API error: {str(e)}. Blocking for safety.",
                "alternative_action": "Check Vertex AI configuration and retry.",
                "recovery_command": f"git restore {file_path}"
            }
    
    def analyze_sync(self, operation: str, file_path: str, source: str = "unknown", context: str = "") -> Dict:
        """
        Synchronous analysis method (for Cloud Functions).
        """
        
        self.analyzed_count += 1
        
        # Layer 1: Hardcoded protection (instant)
        hardcoded_result = self._hardcoded_protection(operation, file_path, context)
        if hardcoded_result:
            self.blocked_count += 1
            hardcoded_result["analysis_layer"] = "hardcoded_protection"
            return hardcoded_result
        
        # Layer 2: Opus 4.5 analysis (if available and needed)
        if self.client and operation in ["delete", "bulk_delete", "overwrite"]:
            try:
                # Synchronous call to Opus
                analysis_prompt = f"""Analyze this file operation:
OPERATION: {operation}
FILE PATH: {file_path}
SOURCE: {source}
CONTEXT: {context or 'None'}

Should this be allowed? Respond with JSON only:
{{"allowed": bool, "risk_level": "string", "reason": "string", "alternative_action": "string or null", "recovery_command": "string or null"}}"""

                response = self.client.messages.create(
                    model=MODEL_ID,
                    max_tokens=512,
                    system=GUARDIAN_SYSTEM_PROMPT,
                    messages=[{"role": "user", "content": analysis_prompt}]
                )
                
                response_text = response.content[0].text.strip()
                json_match = re.search(r'\{[\s\S]*\}', response_text)
                
                if json_match:
                    result = json.loads(json_match.group())
                    if not result.get("allowed", True):
                        self.blocked_count += 1
                    result["analysis_layer"] = "opus_4.5"
                    return result
                    
            except Exception as e:
                print(f"Opus error: {e}")
        
        # Layer 3: Default safe operations
        if operation == "read":
            return {
                "allowed": True,
                "risk_level": "safe",
                "reason": "Read operations are always safe.",
                "analysis_layer": "default"
            }
        elif operation == "write":
            # Write is generally safe for new files
            return {
                "allowed": True,
                "risk_level": "low",
                "reason": "Write operation allowed. Use StrReplace for existing files.",
                "alternative_action": "Use StrReplace tool for editing existing files.",
                "analysis_layer": "default"
            }
        else:
            # Unknown operation - be conservative
            self.blocked_count += 1
            return {
                "allowed": False,
                "risk_level": "medium",
                "reason": f"Unknown operation '{operation}'. Blocking for safety.",
                "alternative_action": "Use known safe operations: read, write.",
                "recovery_command": f"git restore {file_path}",
                "analysis_layer": "default"
            }
    
    def get_status(self) -> Dict:
        """Get agent status."""
        return {
            "agent": self.name,
            "version": self.version,
            "model": self.model,
            "project_id": self.project_id,
            "region": self.region,
            "opus_available": self.client is not None,
            "status": "ACTIVE" if self.client else "ACTIVE (rule-based fallback)",
            "protection_level": "NUCLEAR",
            "analyzed_operations": self.analyzed_count,
            "blocked_operations": self.blocked_count,
            "protected_files": len(NUCLEAR_PROTECTED["files"]),
            "protected_directories": len(NUCLEAR_PROTECTED["directories"]),
            "message": "🛡️🔥 FILE GUARDIAN OPUS 4.5 ACTIVE - Your files are protected by the world's most intelligent AI! 🔥🛡️"
        }

# =============================================================================
# CLOUD FUNCTION ENTRY POINT
# =============================================================================

guardian = FileGuardianOpus()

@functions_framework.http
def file_guardian_opus(request):
    """
    🛡️ FILE GUARDIAN OPUS 4.5 - VERTEX AI CLOUD FUNCTION 🛡️
    
    Endpoint: https://us-central1-mychannel-ca26d.cloudfunctions.net/file-guardian-opus
    
    Powered by Claude Opus 4.5 - The world's most intelligent AI model.
    
    GET - Returns agent status
    POST - Analyzes file operation
    
    Request body:
    {
        "operation": "delete|write|read|move|rename|bulk_delete|overwrite",
        "file_path": "path/to/file.swift",
        "source": "cursor|user|script|ai",
        "context": "optional context about the operation"
    }
    """
    
    # CORS headers
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Content-Type': 'application/json'
    }
    
    if request.method == 'OPTIONS':
        return ('', 204, headers)
    
    try:
        # GET - Return status
        if request.method == 'GET':
            return jsonify(guardian.get_status()), 200, headers
        
        # POST - Analyze operation
        data = request.get_json(silent=True) or {}
        
        operation = data.get('operation', 'read')
        file_path = data.get('file_path', '')
        source = data.get('source', 'unknown')
        context = data.get('context', '')
        
        if not file_path:
            return jsonify({
                "error": "file_path is required",
                "allowed": False,
                "risk_level": "critical",
                "reason": "No file path provided. Cannot analyze."
            }), 400, headers
        
        # Analyze the operation
        result = guardian.analyze_sync(operation, file_path, source, context)
        
        # Add metadata
        result["agent"] = guardian.name
        result["model"] = guardian.model
        result["timestamp"] = datetime.now().isoformat()
        
        status_code = 200 if result.get("allowed", False) else 403
        return jsonify(result), status_code, headers
        
    except Exception as e:
        return jsonify({
            "error": str(e),
            "allowed": False,
            "risk_level": "critical",
            "reason": f"Agent error: {str(e)}. Blocking for safety.",
            "traceback": traceback.format_exc()
        }), 500, headers

# =============================================================================
# LOCAL TESTING
# =============================================================================

if __name__ == "__main__":
    print("🛡️🔥 FILE GUARDIAN OPUS 4.5 - LOCAL TEST 🔥🛡️")
    print("=" * 60)
    
    agent = FileGuardianOpus()
    print(f"\nStatus: {json.dumps(agent.get_status(), indent=2)}")
    
    # Test cases
    tests = [
        ("delete", "MyChannel/App/MyChannelApp.swift", "cursor", "cleanup"),
        ("delete", "MyChannel/Core/Config/AppConfig.swift", "ai", "refactoring"),
        ("bulk_delete", "MyChannel/Features/", "script", "rm -rf MyChannel/Features/"),
        ("write", "MyChannel/Features/NewFeature.swift", "cursor", "adding feature"),
        ("read", "README.md", "user", "viewing docs"),
        ("delete", "temp_file.txt", "user", "manual cleanup"),
        ("overwrite", "MyChannel/Core/Theme/AppTheme.swift", "cursor", "updating theme"),
    ]
    
    print("\n" + "=" * 60)
    print("TEST RESULTS:")
    print("=" * 60)
    
    for op, path, source, ctx in tests:
        result = agent.analyze_sync(op, path, source, ctx)
        status = "✅ ALLOWED" if result["allowed"] else "🚫 BLOCKED"
        print(f"\n{status}: {op} {path}")
        print(f"   Risk: {result['risk_level']}")
        print(f"   Reason: {result['reason'][:80]}...")
        if result.get("recovery_command"):
            print(f"   Recovery: {result['recovery_command']}")
    
    print("\n" + "=" * 60)
    print(f"Total analyzed: {agent.analyzed_count}")
    print(f"Total blocked: {agent.blocked_count}")
    print("=" * 60)


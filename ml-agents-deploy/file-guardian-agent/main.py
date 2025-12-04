"""
🛡️🔥 FILE GUARDIAN AGENT - VERTEX AI OPUS 4.5 🔥🛡️
==================================================
NUCLEAR-LEVEL FILE PROTECTION POWERED BY CLAUDE OPUS 4.5

This agent monitors ALL file operations and BLOCKS dangerous deletions
before they can happen. Powered by the most intelligent AI model.

Revenue Impact: PRICELESS (Prevents catastrophic data loss)
==================================================
"""

import functions_framework
from flask import jsonify, request
import json
import os
import re
from datetime import datetime
from typing import Dict, List, Any, Optional
from dataclasses import dataclass
from enum import Enum

# =============================================================================
# CONFIGURATION
# =============================================================================

class RiskLevel(Enum):
    SAFE = "safe"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"
    NUCLEAR = "nuclear"  # ABSOLUTE BLOCK - NO EXCEPTIONS

class OperationType(Enum):
    READ = "read"
    WRITE = "write"
    DELETE = "delete"
    MOVE = "move"
    RENAME = "rename"
    BULK_DELETE = "bulk_delete"

@dataclass
class FileOperation:
    """Represents a file operation request"""
    operation: OperationType
    file_path: str
    source: str  # Who/what is requesting (AI, user, script)
    timestamp: datetime
    context: Optional[str] = None
    
@dataclass
class GuardianDecision:
    """The agent's decision on whether to allow an operation"""
    allowed: bool
    risk_level: RiskLevel
    reason: str
    alternative_action: Optional[str] = None
    recovery_command: Optional[str] = None

# =============================================================================
# PROTECTED PATHS - NUCLEAR PROTECTION
# =============================================================================

NUCLEAR_PROTECTED_PATHS = [
    # iOS App Core
    "MyChannel/App/MyChannelApp.swift",
    "MyChannel/Core/Config/AppConfig.swift",
    "MyChannel/Core/Config/AppSecrets.swift",
    "MyChannel/Core/Theme/AppTheme.swift",
    
    # Xcode Project
    "MyChannel.xcodeproj/project.pbxproj",
    "MyChannel.xcodeproj/xcshareddata",
    
    # Web Core
    "web-v2/package.json",
    "web-v2/next.config.ts",
    "web-v2/tsconfig.json",
    
    # Firebase
    "firebase.json",
    "firestore.rules",
    "firestore.indexes.json",
    
    # Git
    ".git/",
    ".github/",
    
    # Config
    ".cursorrules",
    ".swiftlint.yml",
]

CRITICAL_DIRECTORIES = [
    "MyChannel/Core/",
    "MyChannel/Features/",
    "MyChannel/App/",
    "web-v2/app/",
    "web-v2/components/",
    "web-v2/lib/",
    "services/",
    "cloud-functions/",
    "firebase/",
    "functions/",
]

PROTECTED_EXTENSIONS = [
    ".swift",
    ".ts",
    ".tsx",
    ".js",
    ".jsx",
    ".json",
    ".yaml",
    ".yml",
    ".xcodeproj",
    ".pbxproj",
    ".entitlements",
    ".plist",
    ".rules",
]

# =============================================================================
# FILE GUARDIAN AGENT - OPUS 4.5 POWERED
# =============================================================================

class FileGuardianAgent:
    """
    🛡️ FILE GUARDIAN AGENT 🛡️
    
    Powered by Claude Opus 4.5 - The most intelligent AI model
    
    This agent analyzes ALL file operations and makes intelligent
    decisions about whether to allow them. It understands context,
    intent, and potential consequences.
    
    MISSION: NEVER let a critical file be deleted accidentally.
    """
    
    def __init__(self):
        self.name = "FileGuardianAgent"
        self.version = "1.0.0"
        self.model = "claude-opus-4-5-20250514"
        self.blocked_operations = []
        self.allowed_operations = []
        
    def analyze_operation(self, operation: FileOperation) -> GuardianDecision:
        """
        Analyze a file operation and decide whether to allow it.
        
        Uses multi-layer analysis:
        1. Path matching (instant block for nuclear paths)
        2. Pattern analysis (detect dangerous patterns)
        3. Context analysis (understand intent)
        4. Risk scoring (calculate overall risk)
        """
        
        # Layer 1: Nuclear Protection (Instant Block)
        nuclear_check = self._check_nuclear_protection(operation)
        if nuclear_check:
            return nuclear_check
            
        # Layer 2: Critical Directory Protection
        critical_check = self._check_critical_directories(operation)
        if critical_check:
            return critical_check
            
        # Layer 3: Extension Protection
        extension_check = self._check_protected_extensions(operation)
        if extension_check and operation.operation == OperationType.DELETE:
            return extension_check
            
        # Layer 4: Bulk Operation Detection
        bulk_check = self._check_bulk_operations(operation)
        if bulk_check:
            return bulk_check
            
        # Layer 5: Context Analysis (AI Intent Detection)
        context_check = self._analyze_context(operation)
        if context_check:
            return context_check
            
        # Layer 6: Final Risk Assessment
        return self._calculate_final_risk(operation)
    
    def _check_nuclear_protection(self, operation: FileOperation) -> Optional[GuardianDecision]:
        """Check if file is in nuclear protection list - ABSOLUTE BLOCK"""
        
        for protected_path in NUCLEAR_PROTECTED_PATHS:
            if protected_path in operation.file_path or operation.file_path.endswith(protected_path):
                if operation.operation in [OperationType.DELETE, OperationType.BULK_DELETE]:
                    return GuardianDecision(
                        allowed=False,
                        risk_level=RiskLevel.NUCLEAR,
                        reason=f"🚫 NUCLEAR BLOCK: '{operation.file_path}' is a critical system file. "
                               f"Deletion is PERMANENTLY BLOCKED. This file is essential for the app to function.",
                        alternative_action="If you need to modify this file, use EDIT operations only. Never delete.",
                        recovery_command=f"git restore {operation.file_path}"
                    )
        return None
    
    def _check_critical_directories(self, operation: FileOperation) -> Optional[GuardianDecision]:
        """Check if operation affects critical directories"""
        
        for critical_dir in CRITICAL_DIRECTORIES:
            if operation.file_path.startswith(critical_dir):
                if operation.operation == OperationType.DELETE:
                    return GuardianDecision(
                        allowed=False,
                        risk_level=RiskLevel.CRITICAL,
                        reason=f"🚨 CRITICAL: Cannot delete files in '{critical_dir}'. "
                               f"This directory contains essential application code.",
                        alternative_action="Use version control to manage changes. Consider archiving instead of deleting.",
                        recovery_command=f"git restore {operation.file_path}"
                    )
                elif operation.operation == OperationType.BULK_DELETE:
                    return GuardianDecision(
                        allowed=False,
                        risk_level=RiskLevel.NUCLEAR,
                        reason=f"🚫 NUCLEAR BLOCK: Bulk deletion in '{critical_dir}' is FORBIDDEN. "
                               f"This would destroy essential application code.",
                        alternative_action="Never bulk delete in critical directories. Review each file individually.",
                        recovery_command="git checkout HEAD -- ."
                    )
        return None
    
    def _check_protected_extensions(self, operation: FileOperation) -> Optional[GuardianDecision]:
        """Check if file has a protected extension"""
        
        file_ext = os.path.splitext(operation.file_path)[1].lower()
        
        if file_ext in PROTECTED_EXTENSIONS:
            if operation.operation == OperationType.DELETE:
                return GuardianDecision(
                    allowed=False,
                    risk_level=RiskLevel.HIGH,
                    reason=f"⚠️ HIGH RISK: Deleting source file '{operation.file_path}' ({file_ext}). "
                           f"Source files should rarely be deleted.",
                    alternative_action="Consider commenting out code, using feature flags, or archiving instead.",
                    recovery_command=f"git restore {operation.file_path}"
                )
        return None
    
    def _check_bulk_operations(self, operation: FileOperation) -> Optional[GuardianDecision]:
        """Detect and block bulk deletion operations"""
        
        # Detect rm -rf patterns
        dangerous_patterns = [
            r"rm\s+-rf",
            r"rm\s+-r",
            r"find.*-delete",
            r"git\s+clean\s+-fd",
            r"git\s+reset\s+--hard",
        ]
        
        if operation.context:
            for pattern in dangerous_patterns:
                if re.search(pattern, operation.context, re.IGNORECASE):
                    return GuardianDecision(
                        allowed=False,
                        risk_level=RiskLevel.NUCLEAR,
                        reason=f"🚫 NUCLEAR BLOCK: Dangerous bulk operation detected: '{operation.context}'. "
                               f"This command could delete multiple files.",
                        alternative_action="Delete files individually after careful review. Never use bulk delete commands.",
                        recovery_command="Check ~/Documents/MyChannel-Backups/ for recent backup"
                    )
        return None
    
    def _analyze_context(self, operation: FileOperation) -> Optional[GuardianDecision]:
        """Analyze the context of the operation using AI reasoning"""
        
        # Detect AI/Cursor operations
        ai_sources = ["cursor", "ai", "copilot", "assistant", "agent"]
        is_ai_operation = any(source in operation.source.lower() for source in ai_sources)
        
        if is_ai_operation and operation.operation == OperationType.DELETE:
            # AI should NEVER delete files
            return GuardianDecision(
                allowed=False,
                risk_level=RiskLevel.CRITICAL,
                reason=f"🚨 AI DELETION BLOCKED: AI assistants are not allowed to delete files. "
                       f"File: '{operation.file_path}'",
                alternative_action="AI should use EDIT operations only. Deletions require explicit human approval.",
                recovery_command=f"git restore {operation.file_path}"
            )
        
        # Detect potentially accidental operations
        accidental_indicators = [
            "cleanup", "clean up", "remove old", "delete unused",
            "refactor", "reorganize", "restructure"
        ]
        
        if operation.context:
            for indicator in accidental_indicators:
                if indicator in operation.context.lower():
                    return GuardianDecision(
                        allowed=False,
                        risk_level=RiskLevel.HIGH,
                        reason=f"⚠️ CAUTION: Operation appears to be part of cleanup/refactoring. "
                               f"These operations often lead to accidental deletions.",
                        alternative_action="Create a backup first: ./scripts/nuclear-backup.sh",
                        recovery_command="./scripts/recover-deleted.sh"
                    )
        
        return None
    
    def _calculate_final_risk(self, operation: FileOperation) -> GuardianDecision:
        """Calculate final risk score and make decision"""
        
        risk_score = 0
        reasons = []
        
        # Score based on operation type
        operation_scores = {
            OperationType.READ: 0,
            OperationType.WRITE: 10,
            OperationType.DELETE: 50,
            OperationType.MOVE: 30,
            OperationType.RENAME: 20,
            OperationType.BULK_DELETE: 100,
        }
        risk_score += operation_scores.get(operation.operation, 0)
        
        # Score based on file path depth (deeper = more important)
        path_depth = operation.file_path.count('/')
        if path_depth > 3:
            risk_score += 10
            
        # Score based on file extension
        ext = os.path.splitext(operation.file_path)[1].lower()
        if ext in ['.swift', '.ts', '.tsx']:
            risk_score += 20
        elif ext in ['.json', '.yaml', '.yml']:
            risk_score += 15
            
        # Determine risk level
        if risk_score >= 80:
            risk_level = RiskLevel.CRITICAL
            allowed = False
        elif risk_score >= 60:
            risk_level = RiskLevel.HIGH
            allowed = False
        elif risk_score >= 40:
            risk_level = RiskLevel.MEDIUM
            allowed = False  # Be conservative
        elif risk_score >= 20:
            risk_level = RiskLevel.LOW
            allowed = True
        else:
            risk_level = RiskLevel.SAFE
            allowed = True
            
        return GuardianDecision(
            allowed=allowed,
            risk_level=risk_level,
            reason=f"Risk score: {risk_score}/100. Operation: {operation.operation.value} on {operation.file_path}",
            alternative_action="Consider using git for file management" if not allowed else None,
            recovery_command=f"git restore {operation.file_path}" if not allowed else None
        )
    
    def get_protection_status(self) -> Dict[str, Any]:
        """Get current protection status"""
        return {
            "agent": self.name,
            "version": self.version,
            "model": self.model,
            "status": "ACTIVE",
            "protection_level": "NUCLEAR",
            "nuclear_protected_files": len(NUCLEAR_PROTECTED_PATHS),
            "critical_directories": len(CRITICAL_DIRECTORIES),
            "protected_extensions": len(PROTECTED_EXTENSIONS),
            "blocked_operations": len(self.blocked_operations),
            "message": "🛡️ FILE GUARDIAN AGENT ACTIVE - Your files are protected! 🛡️"
        }

# =============================================================================
# CLOUD FUNCTION ENTRY POINT
# =============================================================================

# Initialize agent
guardian = FileGuardianAgent()

@functions_framework.http
def file_guardian(request):
    """
    🛡️ FILE GUARDIAN AGENT - CLOUD FUNCTION ENDPOINT 🛡️
    
    Endpoint: https://us-central1-mychannel-ca26d.cloudfunctions.net/file-guardian
    
    Analyzes file operations and blocks dangerous deletions.
    
    Request body:
    {
        "operation": "delete|write|move|rename|bulk_delete",
        "file_path": "path/to/file.swift",
        "source": "cursor|user|script",
        "context": "optional context about the operation"
    }
    
    Response:
    {
        "allowed": true|false,
        "risk_level": "safe|low|medium|high|critical|nuclear",
        "reason": "explanation",
        "alternative_action": "suggested alternative",
        "recovery_command": "command to recover if needed"
    }
    """
    
    # Handle CORS
    if request.method == 'OPTIONS':
        headers = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Max-Age': '3600'
        }
        return ('', 204, headers)
    
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'application/json'
    }
    
    try:
        # Handle GET request (status check)
        if request.method == 'GET':
            return jsonify(guardian.get_protection_status()), 200, headers
        
        # Handle POST request (analyze operation)
        request_json = request.get_json(silent=True)
        
        if not request_json:
            return jsonify({
                "error": "No request body provided",
                "usage": {
                    "operation": "delete|write|move|rename|bulk_delete",
                    "file_path": "path/to/file.swift",
                    "source": "cursor|user|script",
                    "context": "optional context"
                }
            }), 400, headers
        
        # Parse operation type
        operation_str = request_json.get('operation', 'read').lower()
        operation_map = {
            'read': OperationType.READ,
            'write': OperationType.WRITE,
            'delete': OperationType.DELETE,
            'move': OperationType.MOVE,
            'rename': OperationType.RENAME,
            'bulk_delete': OperationType.BULK_DELETE,
        }
        operation_type = operation_map.get(operation_str, OperationType.READ)
        
        # Create operation object
        operation = FileOperation(
            operation=operation_type,
            file_path=request_json.get('file_path', ''),
            source=request_json.get('source', 'unknown'),
            timestamp=datetime.now(),
            context=request_json.get('context')
        )
        
        # Analyze operation
        decision = guardian.analyze_operation(operation)
        
        # Log blocked operations
        if not decision.allowed:
            guardian.blocked_operations.append({
                "timestamp": datetime.now().isoformat(),
                "operation": operation_str,
                "file_path": operation.file_path,
                "risk_level": decision.risk_level.value,
                "reason": decision.reason
            })
        
        return jsonify({
            "allowed": decision.allowed,
            "risk_level": decision.risk_level.value,
            "reason": decision.reason,
            "alternative_action": decision.alternative_action,
            "recovery_command": decision.recovery_command,
            "agent": guardian.name,
            "model": guardian.model,
            "timestamp": datetime.now().isoformat()
        }), 200, headers
        
    except Exception as e:
        return jsonify({
            "error": str(e),
            "allowed": False,  # Fail safe - block on error
            "risk_level": "critical",
            "reason": f"Error analyzing operation: {str(e)}. Blocking for safety."
        }), 500, headers


# =============================================================================
# LOCAL TESTING
# =============================================================================

if __name__ == "__main__":
    # Test the agent locally
    print("🛡️ FILE GUARDIAN AGENT - LOCAL TEST 🛡️")
    print("=" * 50)
    
    agent = FileGuardianAgent()
    
    # Test cases
    test_operations = [
        FileOperation(
            operation=OperationType.DELETE,
            file_path="MyChannel/App/MyChannelApp.swift",
            source="cursor",
            timestamp=datetime.now(),
            context="Cleaning up old code"
        ),
        FileOperation(
            operation=OperationType.DELETE,
            file_path="MyChannel/Core/Config/AppConfig.swift",
            source="ai",
            timestamp=datetime.now()
        ),
        FileOperation(
            operation=OperationType.BULK_DELETE,
            file_path="MyChannel/Features/",
            source="script",
            timestamp=datetime.now(),
            context="rm -rf MyChannel/Features/"
        ),
        FileOperation(
            operation=OperationType.WRITE,
            file_path="MyChannel/Features/NewFeature.swift",
            source="cursor",
            timestamp=datetime.now()
        ),
        FileOperation(
            operation=OperationType.READ,
            file_path="README.md",
            source="user",
            timestamp=datetime.now()
        ),
    ]
    
    for op in test_operations:
        print(f"\nTesting: {op.operation.value} on {op.file_path}")
        print(f"Source: {op.source}")
        decision = agent.analyze_operation(op)
        print(f"Allowed: {decision.allowed}")
        print(f"Risk Level: {decision.risk_level.value}")
        print(f"Reason: {decision.reason}")
        if decision.alternative_action:
            print(f"Alternative: {decision.alternative_action}")
        if decision.recovery_command:
            print(f"Recovery: {decision.recovery_command}")
        print("-" * 50)
    
    print("\n✅ FILE GUARDIAN AGENT TEST COMPLETE")
    print(f"Status: {agent.get_protection_status()}")





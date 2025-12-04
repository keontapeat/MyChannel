/**
 * 🛡️🔥 FILE GUARDIAN OPUS 4.5 - TypeScript Client 🔥🛡️
 * 
 * Powered by Claude Opus 4.5 on Google Cloud Vertex AI
 * 
 * This client protects your project files from accidental deletion
 * by AI assistants and automated tools.
 */

// =============================================================================
// TYPES
// =============================================================================

export type RiskLevel = 'safe' | 'low' | 'medium' | 'high' | 'critical' | 'nuclear';

export type OperationType = 'read' | 'write' | 'delete' | 'move' | 'rename' | 'bulk_delete' | 'overwrite';

export interface FileGuardianRequest {
  operation: OperationType;
  file_path: string;
  source: string;
  context?: string;
}

export interface FileGuardianResponse {
  allowed: boolean;
  risk_level: RiskLevel;
  reason: string;
  alternative_action?: string;
  recovery_command?: string;
  agent?: string;
  model?: string;
  timestamp?: string;
}

export interface FileGuardianStatus {
  agent: string;
  version: string;
  model: string;
  status: string;
  protection_level: string;
  analyzed_operations: number;
  blocked_operations: number;
  message: string;
}

// =============================================================================
// LOCAL PROTECTION (Instant, no API needed)
// =============================================================================

const NUCLEAR_PROTECTED_FILES = new Set([
  'MyChannelApp.swift',
  'AppConfig.swift',
  'AppSecrets.swift',
  'AppTheme.swift',
  'project.pbxproj',
  'package.json',
  'next.config.ts',
  'firebase.json',
  'firestore.rules',
  '.cursorrules',
]);

const NUCLEAR_PROTECTED_DIRECTORIES = [
  'MyChannel/Core/',
  'MyChannel/Features/',
  'MyChannel/App/',
  'web-v2/app/',
  'web-v2/components/',
  'web-v2/lib/',
  '.git/',
  '.github/',
];

const PROTECTED_EXTENSIONS = new Set([
  '.swift', '.ts', '.tsx', '.js', '.jsx',
  '.json', '.yaml', '.yml', '.plist',
  '.pbxproj', '.xcodeproj',
]);

// =============================================================================
// FILE GUARDIAN CLIENT
// =============================================================================

const BASE_URL = 'https://us-central1-mychannel-ca26d.cloudfunctions.net/file-guardian-opus';

/**
 * 🛡️ File Guardian Opus 4.5 Client
 * 
 * Protects files from accidental deletion using Claude Opus 4.5
 */
export const fileGuardian = {
  /**
   * Check if a file operation should be allowed
   */
  async checkOperation(request: FileGuardianRequest): Promise<FileGuardianResponse> {
    // Layer 1: Local instant protection
    const localBlock = checkLocalProtection(request.operation, request.file_path);
    if (localBlock) {
      return localBlock;
    }

    // Layer 2: Call Opus 4.5 API
    try {
      const response = await fetch(BASE_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(request),
      });

      const data = await response.json();
      return data as FileGuardianResponse;
    } catch (error) {
      // On error, be conservative
      return {
        allowed: request.operation === 'read',
        risk_level: request.operation === 'delete' ? 'critical' : 'medium',
        reason: `Guardian API unavailable: ${error}. Using safe fallback.`,
        alternative_action: 'Try again or proceed manually with caution.',
        recovery_command: `git restore ${request.file_path}`,
        agent: 'FileGuardianClient',
        model: 'local_fallback',
        timestamp: new Date().toISOString(),
      };
    }
  },

  /**
   * Quick check if deletion should be blocked (instant, local)
   */
  shouldBlockDeletion(filePath: string): boolean {
    const fileName = filePath.split('/').pop() || '';

    // Check nuclear protected files
    if (NUCLEAR_PROTECTED_FILES.has(fileName)) {
      return true;
    }

    // Check nuclear protected directories
    for (const dir of NUCLEAR_PROTECTED_DIRECTORIES) {
      if (filePath.includes(dir)) {
        return true;
      }
    }

    // Check protected extensions
    const ext = '.' + (fileName.split('.').pop() || '');
    if (PROTECTED_EXTENSIONS.has(ext)) {
      if (filePath.includes('MyChannel/') || filePath.includes('web-v2/')) {
        return true;
      }
    }

    return false;
  },

  /**
   * Get guardian status
   */
  async getStatus(): Promise<FileGuardianStatus> {
    try {
      const response = await fetch(BASE_URL);
      return await response.json();
    } catch (error) {
      return {
        agent: 'FileGuardianOpus',
        version: '1.0.0',
        model: 'claude-opus-4-5-20250514',
        status: 'OFFLINE',
        protection_level: 'NUCLEAR',
        analyzed_operations: 0,
        blocked_operations: 0,
        message: `API unavailable: ${error}`,
      };
    }
  },

  /**
   * Helper: Check before deleting a file
   */
  async canDelete(filePath: string, source: string = 'web_app'): Promise<FileGuardianResponse> {
    return this.checkOperation({
      operation: 'delete',
      file_path: filePath,
      source,
    });
  },

  /**
   * Helper: Check before overwriting a file
   */
  async canOverwrite(filePath: string, source: string = 'web_app'): Promise<FileGuardianResponse> {
    return this.checkOperation({
      operation: 'overwrite',
      file_path: filePath,
      source,
    });
  },
};

/**
 * Local protection check (instant, no API)
 */
function checkLocalProtection(
  operation: OperationType,
  filePath: string
): FileGuardianResponse | null {
  // Only check for dangerous operations
  if (operation !== 'delete' && operation !== 'bulk_delete') {
    return null;
  }

  const fileName = filePath.split('/').pop() || '';

  // Check nuclear protected files
  if (NUCLEAR_PROTECTED_FILES.has(fileName)) {
    return {
      allowed: false,
      risk_level: 'nuclear',
      reason: `🚫 NUCLEAR BLOCK: '${fileName}' is a critical system file that cannot be deleted.`,
      alternative_action: 'Use EDIT operations only. Never delete critical files.',
      recovery_command: `git restore ${filePath}`,
      agent: 'FileGuardianClient',
      model: 'local_protection',
      timestamp: new Date().toISOString(),
    };
  }

  // Check nuclear protected directories
  for (const dir of NUCLEAR_PROTECTED_DIRECTORIES) {
    if (filePath.includes(dir)) {
      return {
        allowed: false,
        risk_level: 'nuclear',
        reason: `🚫 NUCLEAR BLOCK: Cannot delete files in protected directory '${dir}'`,
        alternative_action: 'Files in this directory are essential. Use version control instead.',
        recovery_command: `git restore ${filePath}`,
        agent: 'FileGuardianClient',
        model: 'local_protection',
        timestamp: new Date().toISOString(),
      };
    }
  }

  return null;
}

// =============================================================================
// RISK LEVEL HELPERS
// =============================================================================

export const riskLevelEmoji: Record<RiskLevel, string> = {
  safe: '✅',
  low: '🟢',
  medium: '🟡',
  high: '🟠',
  critical: '🔴',
  nuclear: '☢️',
};

export const riskLevelDescription: Record<RiskLevel, string> = {
  safe: 'Safe operation',
  low: 'Low risk',
  medium: 'Medium risk - proceed with caution',
  high: 'High risk - review carefully',
  critical: 'Critical - requires approval',
  nuclear: 'BLOCKED - operation forbidden',
};

// =============================================================================
// USAGE EXAMPLE
// =============================================================================

/*
import { fileGuardian } from '@/lib/file-guardian/client';

// Check if deletion is allowed
const result = await fileGuardian.canDelete('MyChannel/Core/Config/AppConfig.swift', 'cursor');

if (!result.allowed) {
  console.error(`🚫 BLOCKED: ${result.reason}`);
  console.log(`Alternative: ${result.alternative_action}`);
  console.log(`Recovery: ${result.recovery_command}`);
} else {
  // Proceed with deletion
}

// Quick local check (instant, no API)
if (fileGuardian.shouldBlockDeletion('MyChannel/App/MyChannelApp.swift')) {
  console.error('🚫 This file cannot be deleted!');
}

// Get guardian status
const status = await fileGuardian.getStatus();
console.log(`${status.message}`);
console.log(`Blocked: ${status.blocked_operations} operations`);
*/

export default fileGuardian;





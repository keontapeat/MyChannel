#!/usr/bin/env python3
"""Update Kiro user settings.json to trust everything for full autonomous vibe coding.

Effects:
  - kiroAgent.trustedCommands  -> ["*"]   (auto-approve every shell command)
  - kiroAgent.trustedTools     -> every known Kiro Agent tool
  - kiroAgent.autopilot        -> true
  - kiroAgent.mcp.autoApproveAll -> true

A timestamped backup of settings.json is created before any change.
"""

import json
import shutil
import time
from pathlib import Path

settings_path = Path.home() / "Library/Application Support/Kiro/User/settings.json"

# Fresh timestamped backup
backup_path = settings_path.with_name(
    settings_path.name + f".bak.before-trust-all.{int(time.time())}"
)
shutil.copy2(settings_path, backup_path)
print(f"Backup written: {backup_path}")

with open(settings_path, "r") as f:
    settings = json.load(f)

old_cmd_count = len(settings.get("kiroAgent.trustedCommands", []))

# 1. Trust every shell command via wildcard
settings["kiroAgent.trustedCommands"] = ["*"]

# 2. Trust every Kiro Agent tool (no per-tool prompts)
all_tools = [
    "execute_bash",
    "control_bash_process",
    "list_processes",
    "get_process_output",
    "list_directory",
    "read_file",
    "read_files",
    "file_search",
    "grep_search",
    "delete_file",
    "fs_write",
    "fs_append",
    "str_replace",
    "semanticRename",
    "smartRelocate",
    "kiroPowers",
    "createHook",
    "remote_web_search",
    "web_fetch",
    "getDiagnostics",
    "readCode",
    "discloseContext",
    "invoke_sub_agent",
]
existing_tools = set(settings.get("kiroAgent.trustedTools", []))
existing_tools.update(all_tools)
settings["kiroAgent.trustedTools"] = sorted(existing_tools)

# 3. Keep autopilot on
settings["kiroAgent.autopilot"] = True

# 4. Auto-approve all MCP tools
settings["kiroAgent.mcp.autoApproveAll"] = True

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=4)
    f.write("\n")

print("Updated:")
print(f"  kiroAgent.trustedCommands     -> ['*']  (was {old_cmd_count} entries)")
print(f"  kiroAgent.trustedTools        -> {len(settings['kiroAgent.trustedTools'])} tools")
print(f"  kiroAgent.autopilot           -> True")
print(f"  kiroAgent.mcp.autoApproveAll  -> True")
print("Done.")

# Project Instructions

## Proactive Flutter Hot Reload

Whenever you edit or modify any `.dart` file under `lib/` in this project:

1. **When to Skip**:
   - **Files Outside `lib/`**: Only trigger hot reload or hot restart for edits under `lib/`. Do not trigger when modifying files in other directories (e.g., `test/**`, `integration_test/**`, `benchmark/**`, `test_driver/**` or `example/**`).
   - **Comments & Documentation**: Do not trigger hot reload or hot restart when changes only affect comments, docstrings, or whitespace.

2. **Discover & Connect**:
   - Discover active running application instances using the `dtd` MCP Tool (or `list_running_apps` / `vm_service`) from the Dart MCP server.

3. **Trigger Hot Reload / Hot Restart**:
   - Execute the `hot_reload` MCP tool immediately after making changes to UI widgets (including `build` methods of stateful widgets) or simple methods.
   - Execute the `hot_restart` MCP tool if fundamental logic, state initialization (e.g., `initState`), global/static state, or `main()` was modified.

## Flutter/Dart AI Tooling

Official Flutter and Dart agent skills are installed in `.agents/skills/` and
recorded in `skills-lock.json`. The Dart/Flutter MCP server is configured in
`opencode.json` (`mcp.dart` -> `dart mcp-server`).

### Updating skills

Run from the repository root:

```bash
# Update all installed skills to their latest versions
npx skills update --project --yes

# Or reinstall the full sets from source
npx skills add flutter/agent-plugins --skill '*' --agent opencode --yes
npx skills add dart-lang/skills      --skill '*' --agent opencode --yes
```

Verify with `npx skills list`, then **restart opencode** — skills and MCP
configuration are loaded once at startup and are not hot-reloaded.

# XcodeBuildMCP (Sentry) — setup (optional)

Goal: enable an AI coding agent to run **repeatable** `xcodebuild`/tests and return structured failures (without “works on my machine” guesswork).

Upstream: https://github.com/getsentry/XcodeBuildMCP

## Install

### Option A — Homebrew (recommended)

```bash
brew tap getsentry/xcodebuildmcp
brew install xcodebuildmcp

# sanity
xcodebuildmcp --help
```

### Option B — npx (no global install)

```bash
# sanity
npx -y xcodebuildmcp@latest --help
```

## Configure as an MCP server

### Codex CLI

```bash
codex mcp add XcodeBuildMCP -- npx -y xcodebuildmcp@latest mcp
```

Or in `~/.codex/config.toml`:

```toml
[mcp_servers.XcodeBuildMCP]
command = "npx"
args = ["-y", "xcodebuildmcp@latest", "mcp"]
```

### Claude Code

```bash
claude mcp add XcodeBuildMCP -- npx -y xcodebuildmcp@latest mcp
```

### Cursor

Add `.cursor/mcp.json` at the workspace root:

```json
{
  "mcpServers": {
    "XcodeBuildMCP": {
      "command": "npx",
      "args": ["-y", "xcodebuildmcp@latest", "mcp"]
    }
  }
}
```

## Smoke test (HackPanel)

Once installed + configured, use your agent client to request an Xcode build/test of this workspace.

Suggested command targets (match what we run locally/CI):
- Open `Package.swift` in Xcode, build `HackPanelApp`
- CLI tests: `swift test`

## Notes / guardrails
- Don’t commit any machine-local MCP config (e.g. `~/.codex/config.toml`) into this repo.
- Prefer least-privilege defaults.
- If the tool requires any credentials/config, keep them out of git and document where they should live (e.g. Keychain / user config directory).

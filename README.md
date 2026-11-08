# MCP gateway lab

A home lab for learning how to secure AI agents' tool access. It runs Kong (open-source API gateway) in front of a toy MCP server, connects Claude Code through the gateway, and gives you ten ways to break it on purpose.

Fake data only. Never use work data, configs or credentials here.

```
Your laptop
┌─────────────────────────────────────────────────────────────┐
│  Claude Code ──┐                      mcpeval (scanner) ──┐ │
│                ▼                                          ▼ │
│  127.0.0.1:18000 ─── Docker ──────────────────────────────┐ │
│  │  Kong 3.9.4 (OSS)                                      │ │
│  │   /mcp/notes         login · roles · tool guard · log  │ │
│  │   /mcp/naked         no protection (exercise 1)        │ │
│  │   /mcp/header-guard  naive header rule (exercise 4)    │ │
│  │   /llm/chat          ai-proxy + ai-prompt-guard        │ │
│  │        │                         │                     │ │
│  │        ▼                         ▼                     │ │
│  │  toy MCP server (notes)     mock LLM (free)            │ │
│  │  not reachable from your laptop except via Kong        │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## What's in it

| Piece | What it is |
|---|---|
| `kong/kong.yml` | All gateway config. Two demo keys (a human and an agent), routes, plugins, and a ~30-line Lua guard that reads each MCP request and blocks destructive tools for agent keys. |
| `toy-mcp/` | A small MCP server with six tools, one per risk level: list/get notes (read), note stats (aggregate), create/delete note (DML), drop notebook (DDL). Write tools ask for confirmation. Runs as a non-root user. |
| `mock-llm/` | A fake Anthropic API so Kong's AI plugins work without spending money. |
| `scripts/test.sh` | 17 automated checks, one or more per exercise. |
| `labs/EXERCISES.md` | The ten exercises. |
| `payloads/` | Empty slot for test content your security team designs (poisoned descriptions, injected note text). |

## Set up (about 10 minutes)

**You need:** Docker Desktop (or another Docker engine) running, Python 3.11+, `git`, and Claude Code (`claude`) if you want the agent part.

```bash
git clone https://github.com/AMishradev/mcp-gateway-lab.git
cd mcp-gateway-lab
make setup        # installs the mcpeval scanner into ./.venv
make up           # builds and starts Kong, the toy server and the mock LLM
make test         # should end with: passed=17 failed=0
```

If `make test` reports a 429 failure, you ran it twice within a minute. The agent's rate limit is working; wait 60 seconds.

## Connect Claude Code through the gateway

```bash
make claude
```

That runs `claude --strict-mcp-config --mcp-config .mcp.json` with the agent key. `--strict-mcp-config` means Claude Code loads only the lab server, not your personal connectors, which matters in a lab where you break things on purpose.

Approve the `lab-notes` server when asked, then try:

- *"List my notes."* → works.
- *"Create a note N0003 titled test."* → the server asks you to confirm.
- *"Reset the notebook."* → the gateway blocks it for the agent key.

To act as the human instead: `LAB_KEY=human-demo-key claude --strict-mcp-config --mcp-config .mcp.json`.

## Everyday commands

| Command | Does |
|---|---|
| `make up` | start, or apply new env vars (`REQUIRE_CONFIRM=false make up`) |
| `make reload` | apply edits to `kong/kong.yml` |
| `make logs` | live audit log from Kong |
| `make scan ROUTE=naked` | scan a route with mcpeval; report in `out/<route>/mcpeval.md` |
| `make baseline` | approve the current tools, so later scans flag changes |
| `make down` / `make clean` | stop / remove everything |

## What this lab can't do (and where to do it)

| Gap | Why | Where to do it |
|---|---|---|
| Attack payloads (tool poisoning, prompt injection) | Deliberately not shipped | `payloads/` with your security team; see `payloads/README.md` |
| Kong's MCP-specific plugins | Enterprise-only (Kong 3.11+); the OSS image stops at 3.9.4 | Kong Enterprise trial (`kong/kong-gateway` image with a trial license). Compare its MCP plugins with the Lua guard here. |
| Real OAuth with PKCE and short-lived tokens | Needs an identity provider; Kong's `openid-connect` is Enterprise | Exercise 6 stretch goal: Keycloak container plus Kong's OSS `jwt` plugin |
| Claude Code's own model traffic through Kong | Claude Code calls Anthropic directly; `ai-proxy` expects chat-format apps | Use `/llm/chat` for apps you write. For Claude Code, look at LLM-gateway setups in the Claude Code docs. |
| Real cost numbers | The mock model returns fake token counts | Point `ai-proxy` at the real Anthropic API with your own key (costs money) |

## How the pieces map to the MCP best practices

| Practice | Where you see it here |
|---|---|
| Least privilege, human vs agent lanes | two consumers with different ACL groups and limits (`kong.yml`) |
| HITL for DML, required for DDL | gateway deny list for agents plus server-side confirmation (exercise 3) |
| Log all authN/authZ | `file-log` with the `mcp` block per request (exercise 5) |
| Short-lived tokens, PKCE | missing on purpose; the scanner fails the gate on it (exercise 6) |
| Input validation | server rejects malformed note ids and sizes (pydantic `Field` limits) |
| Never run as root | both Dockerfiles use `USER app` |
| Environment isolation | only Kong is published, only on 127.0.0.1 (exercise 2) |
| Detect changes after approval | baseline plus re-scan (exercise 9) |

## Versions

Kong 3.9.4 (OSS), FastMCP 4.1.6, MCP protocol 2026-07-28 (older clients also work). Tested on macOS with Docker 28.

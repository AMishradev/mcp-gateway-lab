# Exercises

Each one: break something, watch what happens, understand why the rule exists, put it back.
Run `make test` any time to see the whole lab's current behaviour in one go.

Keys (demo only, lab listens on 127.0.0.1 only):

| Key | Who | Kong role |
|---|---|---|
| `human-demo-key` | alice, a person | `humans` |
| `agent-demo-key` | notes-bot, an autonomous agent | `agents` (tighter rate limit, blocked from destructive tools) |

---

## 1. The forgotten route

**Break:** nothing to do, it's already broken. `/mcp/naked` points at the same server with no login.
```bash
make scan ROUTE=naked
```
**See:** `AUTH-001` (anyone can list and call tools) and `AUTH-006` (any website can reach it).
**Why it matters:** gateways usually fail through a route someone added in a hurry, not a broken plugin.
**Fix:** delete the `notes-naked` route in `kong/kong.yml`, run `make reload`, and re-scan.

## 2. Go around the gateway

**Break:** publish the MCP server's own port.
```bash
docker compose -f docker-compose.yml -f docker-compose.leaky.yml up -d
curl -s -X POST http://127.0.0.1:18080/mcp -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -H 'MCP-Protocol-Version: 2026-07-28' -H 'Mcp-Method: tools/list' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{}}}}'
```
**See:** the full tool list, with no key, no guard and no log line in Kong.
**Why it matters:** a gateway only protects traffic that can't avoid it. In AWS terms, that means the MCP service sits in a private subnet and its security group only allows the gateway.
**Fix:** `make up` (without the leaky file).

## 3. The tool guard, and defence in depth

Start Claude Code as the agent (see the README), then ask it: *"Reset the notebook."*

**See:** Claude reports *"Blocked by the gateway: agent keys may not call lab_drop_notebook"*. The guard is the Lua block under `post-function` in `kong/kong.yml`.

**Break it in two steps:**
1. Remove `lab_drop_notebook = true` from `DENY_FOR_AGENTS`, then `make reload`, and ask again. Now the **server** asks you to confirm, with a message naming what will be deleted. That's the second layer (HITL).
2. Turn that off too: `REQUIRE_CONFIRM=false make up`, and ask again. Nothing stops it.

**Why it matters:** the gateway decides *who may* call a tool, and the server decides *whether this call should happen*. Your best-practices doc wants both for DDL tools.
**Fix:** restore the deny entry, then `make up`.

## 4. Lie in the header

New MCP clients send the tool name twice: in the `Mcp-Name` header and in the JSON body. `/mcp/header-guard` is a naive guard that only reads the header.
```bash
make test   # look at the "Exercise 4" lines
```
**See:** an honest `lab_drop_notebook` call is blocked (403). A call whose header says `lab_list_notes` but whose body says `lab_drop_notebook` gets **past Kong**. It's only stopped by the MCP server's own check (`-32020`, required by the 2026-07-28 spec). The guarded route reads the body, so it rejects the lie itself (400).
**Why it matters:** header-based rules are cheap and fast, but they're only safe when something downstream verifies the body. Ask that of any gateway vendor.

## 5. Rate limits and the audit log

```bash
make logs     # Kong's audit lines, one JSON object per request
```
**See:** every line has `consumer`, `route`, `response.status` and an `mcp` block with `method`, `tool` and `role`. That's the "log all authN/authZ" practice. Run `make test` and watch the agent hit `429` after 30 calls in a minute, while the human limit is 120.
**Try:** lower the agent limit to 5, `make reload`, and ask Claude Code to read every note one by one.

## 6. A static key is not OAuth

```bash
make scan
```
**See:** the gate fails on `BP-PKCE`. `key-auth` is a long-lived shared secret: no expiry, no audience, no PKCE, and no `/.well-known/oauth-protected-resource` metadata for clients to discover.
**Why it matters:** this is the gap between "has a login" and what your doc asks for (short-lived, audience-bound tokens, PKCE).
**Stretch goal (not built):** add a Keycloak container as the identity provider, switch the route to Kong's OSS `jwt` plugin (it checks signature and `exp`, but not audience, so note that gap), and serve the protected-resource metadata JSON from Kong with a `request-termination` route at `/.well-known/oauth-protected-resource/mcp/notes`. Kong's `openid-connect` plugin, which does all of this, is Enterprise-only.

## 7. Kong's AI plugins

`/llm/chat` accepts an OpenAI-style chat request. `ai-proxy` translates it to Anthropic's format and sends it to the mock model.
```bash
curl -s -H 'apikey: human-demo-key' -H 'Content-Type: application/json' http://127.0.0.1:18000/llm/chat \
  -d '{"messages":[{"role":"user","content":"summarize my notes"}]}'
```
**See:**
- `ai-prompt-guard` rejects prompts matching its deny patterns (400) before any model is called.
- `make logs` shows an `ai` block with token counts. That's how you'd log inference cost per team at the gateway.

**Note:** these plugins understand chat traffic, not MCP traffic. Claude Code's own model calls go to Anthropic directly; only its MCP calls go through Kong in this lab.

## 8. A tool that lies about itself

```bash
LYING_ANNOTATIONS=true make up && make scan
```
**See:** `ANNOT-002`. `lab_drop_notebook` claims `readOnlyHint: true`. A client that trusts the hint could skip the confirmation.
**Why it matters:** the MCP spec says annotations are untrusted hints, so the scanner classifies from the name and schema and flags the contradiction.
**Fix:** `make up`.

## 9. The server changes after you approved it

```bash
make baseline                                            # approve today's tools
cp payloads/descriptions.example.json payloads/descriptions.json
make scan                                                # RUG-001 with old and new text
rm payloads/descriptions.json
```
**Why it matters:** with a remote server (like Atlassian's) you never install anything, so the only way to notice a change is to re-scan against an approved baseline on a schedule.

## 10. Your security team's test content

The server reads two optional files on every request, so you can change them while the lab runs:

| File | Effect |
|---|---|
| `payloads/descriptions.json` | replaces tool descriptions: `{"tool_name": "text"}` |
| `payloads/note_bodies.json` | replaces what `lab_get_note` returns: `{"N0001": "text"}` |

That's where test cases go for tool poisoning (in descriptions) and indirect prompt injection (in note content). Both files are git-ignored, so nothing your team writes gets pushed by accident. See `payloads/README.md`.

# Test content slot (for your security team)

This lab ships without any attack payloads on purpose. This folder is where your team adds test content for:

- **Tool poisoning:** text in a tool description that tries to steer the agent. Put it in `descriptions.json`.
- **Indirect prompt injection:** text in data the agent reads. Put it in `note_bodies.json` (returned by `lab_get_note`).

Format: copy the `*.example.json` files and drop the `.example`. The toy server re-reads them on every request, so there's no restart needed.

Then measure each test case three ways:

1. **Scanner:** `make scan`. Do `POISN-*` or `RUG-001` fire?
2. **Gateway:** `make logs`. What did Kong see? (Usually nothing useful, because the content is inside the response.)
3. **Agent:** start Claude Code (`make claude`) and give it a normal task such as "summarize note N0002". Did it do anything you didn't ask for? Did the gateway or the server's confirmation stop it?

For repeatable scoring, use the Inspect AI task in MCPEvalSuite (`evals/inspect_mcp_security.py`) pointed at this server. Published datasets (MCPTox, MCPSecBench) are a good starting set.

Rules: fake data only, never real work systems, configs or credentials. `*.json` here is git-ignored; only `*.example.json` is committed.

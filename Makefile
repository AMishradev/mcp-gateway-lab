# Lab shortcuts. Demo keys only; everything listens on 127.0.0.1.
ROUTE ?= notes
KEY   ?= human-demo-key
SCAN  := .venv/bin/mcpeval

.PHONY: setup up down reload logs test scan baseline claude clean

setup:    ## one-time: install the scanner into ./.venv
	python3 -m venv .venv && .venv/bin/pip install -q "git+https://github.com/AMishradev/MCPEvalSuite"

up:       ## start (or restart with new env vars, e.g. REQUIRE_CONFIRM=false make up)
	docker compose up -d --build --wait

down:     ## stop everything
	docker compose down

reload:   ## apply kong/kong.yml changes
	docker compose restart kong && docker compose up -d --wait kong

logs:     ## Kong audit log, one JSON line per request
	docker compose logs kong --no-log-prefix -f | grep --line-buffered '^{'

test:     ## check every exercise's expected behaviour
	./scripts/test.sh

scan:     ## scan a Kong route with mcpeval: make scan ROUTE=naked
	LAB_KEY=$(KEY) MCPEVAL_HOME=.mcpeval $(SCAN) scan http://127.0.0.1:18000/mcp/$(ROUTE) -H 'apikey: $${LAB_KEY}' --llm off --out out/$(ROUTE) --no-gate --format json,md
	@echo "full report: out/$(ROUTE)/mcpeval.md"

baseline: ## approve the current tool list (exercise 9)
	LAB_KEY=$(KEY) MCPEVAL_HOME=.mcpeval $(SCAN) baseline approve http://127.0.0.1:18000/mcp/$(ROUTE) -H 'apikey: $${LAB_KEY}' --by me

claude:   ## start Claude Code with ONLY the lab server, as the agent
	LAB_KEY=agent-demo-key claude --strict-mcp-config --mcp-config .mcp.json

clean:    ## stop and remove the lab's containers and images, plus scan output
	docker compose down --rmi local -v
	rm -rf ./out ./.mcpeval

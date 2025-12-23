# Codex Prompt for Code Coverage Agent

You are an expert Go engineer. Build a Go CLI that continuously improves test coverage for a local Go repository with minimal human intervention. Use https://github.com/tmc/langgraphgo to orchestrate an iterative agent workflow.

## Requirements

### CLI
- Command: `coverage-agent`
- Flags:
  - `-repo` (required): local repository path.
  - `-target` (default 80.0): target total coverage percentage.
  - `-max-iterations` (default 5): maximum number of improvement loops.
  - `-marginal` (default 0.1): minimum coverage increase (percentage points) to keep iterating.
  - `-plan-limit` (default 20): max functions to include in each plan.
- Fully autonomous: plan ➜ write ➜ run ➜ analyze ➜ loop.

### Agents
1. **Code Coverage Agent**
   - Run `go test ./... -coverprofile` and parse `go tool cover -func`.
   - Produce a JSON report of per-file coverage plus total coverage, excluding `_test.go` files.
   - Store at `.coverage-agent/coverage.json` in the repo.

2. **Plan Agent**
   - Choose low-coverage functions across the lowest-coverage files.
   - Use `cursor-agent` CLI to generate a `plan_1.md` file with this structure per function:
     - `file_name`
     - `function_name`
     - `function_goal` (describe what the function does)
     - `corner_cases` list with at least 2 items
   - The plan becomes input to the Write Agent.

3. **Write Agent**
   - Use `cursor-agent` CLI to generate idiomatic Go unit tests based on `plan_1.md`.
   - If tests fail, retry with the previous test output as additional context.

4. **Run Agent**
   - Run `go test ./...` to validate tests and ensure compilation passes.
   - Capture output for retries.

### Workflow
- Implement a LangGraph (`langgraphgo`) that runs:
  1. Coverage ➜
  2. Plan (only if below target) ➜
  3. Write ➜
  4. Run ➜
  5. Coverage (loop)
- Stop when target coverage reached or improvements are marginal.

### Engineering Details
- Parse `go tool cover -func` output by function and aggregate statements per file.
- Exclude test files from per-file coverage.
- Robust error handling with context.
- Keep all prompts and templates in a `internal/prompts` package.
- Provide a `workflow` package that controls iteration.

### Deliverables
- `go.mod` for module `canvos-automation`.
- CLI entry at `cmd/coverage-agent/main.go`.
- Packages:
  - `internal/coverage`
  - `internal/plan`
  - `internal/writeagent`
  - `internal/runagent`
  - `internal/workflow`
- Document CLI usage in `README.md`.

### Implementation Notes
- Use `exec.CommandContext` for external commands.
- Capture and return combined output on failure.
- Emit a summary line at end: `Completed in X iterations. Final coverage: Y%`.

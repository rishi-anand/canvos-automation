# Coverage Agent

Automated Go test coverage improvement CLI that plans, writes, and runs tests in a loop.

## Usage

```bash
go run ./cmd/coverage-agent -repo /path/to/repo -target 85
```

### Flags
- `-repo`: Local Go repository path (required).
- `-target`: Target coverage percentage (default 80.0).
- `-max-iterations`: Max improvement loops (default 5).
- `-marginal`: Minimum coverage increase to keep iterating (default 0.1).
- `-plan-limit`: Max functions per plan (default 20).

## Outputs
- `.coverage-agent/coverage.json` with per-file and total coverage.
- `plan_1.md` in the target repository, produced by the Plan Agent.

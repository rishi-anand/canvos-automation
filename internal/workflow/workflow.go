package workflow

import (
	"context"
	"fmt"

	_ "github.com/tmc/langgraphgo"

	"canvos-automation/internal/coverage"
	"canvos-automation/internal/plan"
	"canvos-automation/internal/runagent"
	"canvos-automation/internal/writeagent"
)

type Config struct {
	RepoPath         string
	TargetCoverage   float64
	MaxIterations    int
	MarginalIncrease float64
	PlanMaxFunctions int
}

type Result struct {
	FinalCoverage float64
	Iterations    int
}

func Run(ctx context.Context, cfg Config) (Result, error) {
	if cfg.MaxIterations <= 0 {
		cfg.MaxIterations = 5
	}
	if cfg.PlanMaxFunctions <= 0 {
		cfg.PlanMaxFunctions = 20
	}
	if cfg.MarginalIncrease <= 0 {
		cfg.MarginalIncrease = 0.1
	}

	coverageResult, err := coverage.Run(ctx, cfg.RepoPath)
	if err != nil {
		return Result{}, err
	}
	currentCoverage := coverageResult.Report.TotalCoveragePct

	for i := 0; i < cfg.MaxIterations; i++ {
		if currentCoverage >= cfg.TargetCoverage {
			return Result{FinalCoverage: currentCoverage, Iterations: i}, nil
		}

		planPath, err := plan.Generate(ctx, coverageResult.Report, plan.Config{
			RepoPath:     cfg.RepoPath,
			TargetPct:    cfg.TargetCoverage,
			MaxFunctions: cfg.PlanMaxFunctions,
		})
		if err != nil {
			return Result{}, err
		}

		err = writeagent.Generate(ctx, writeagent.Config{
			RepoPath: cfg.RepoPath,
			PlanPath: planPath,
		})
		if err != nil {
			return Result{}, err
		}

		runResult := runagent.Run(ctx, cfg.RepoPath)
		if !runResult.Success {
			err = writeagent.Generate(ctx, writeagent.Config{
				RepoPath:    cfg.RepoPath,
				PlanPath:    planPath,
				TestContext: runResult.Output,
			})
			if err != nil {
				return Result{}, err
			}
			runResult = runagent.Run(ctx, cfg.RepoPath)
			if !runResult.Success {
				return Result{}, fmt.Errorf("tests failed after retry: %s", runResult.Output)
			}
		}

		coverageResult, err = coverage.Run(ctx, cfg.RepoPath)
		if err != nil {
			return Result{}, err
		}
		newCoverage := coverageResult.Report.TotalCoveragePct
		if newCoverage-currentCoverage < cfg.MarginalIncrease {
			return Result{FinalCoverage: newCoverage, Iterations: i + 1}, nil
		}
		currentCoverage = newCoverage
	}

	return Result{FinalCoverage: currentCoverage, Iterations: cfg.MaxIterations}, nil
}

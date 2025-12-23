package main

import (
	"context"
	"flag"
	"fmt"
	"os"

	"canvos-automation/internal/workflow"
)

func main() {
	repoPath := flag.String("repo", "", "path to the Go repository")
	targetCoverage := flag.Float64("target", 80.0, "target coverage percentage")
	maxIterations := flag.Int("max-iterations", 5, "maximum improvement iterations")
	marginalIncrease := flag.Float64("marginal", 0.1, "minimum coverage increase to continue (percentage points)")
	planMaxFunctions := flag.Int("plan-limit", 20, "maximum functions to include in a plan")
	flag.Parse()

	if *repoPath == "" {
		fmt.Fprintln(os.Stderr, "-repo is required")
		os.Exit(1)
	}

	ctx := context.Background()
	result, err := workflow.Run(ctx, workflow.Config{
		RepoPath:         *repoPath,
		TargetCoverage:   *targetCoverage,
		MaxIterations:    *maxIterations,
		MarginalIncrease: *marginalIncrease,
		PlanMaxFunctions: *planMaxFunctions,
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "coverage agent failed: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Completed in %d iterations. Final coverage: %.2f%%\n", result.Iterations, result.FinalCoverage)
}

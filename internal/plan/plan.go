package plan

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"canvos-automation/internal/coverage"
	"canvos-automation/internal/prompts"
)

type Config struct {
	RepoPath     string
	TargetPct    float64
	MaxFunctions int
	PlanPath     string
}

func Generate(ctx context.Context, report coverage.Report, cfg Config) (string, error) {
	coverageJSON, err := json.MarshalIndent(report, "", "  ")
	if err != nil {
		return "", fmt.Errorf("marshal coverage json: %w", err)
	}

	planPath := cfg.PlanPath
	if planPath == "" {
		planPath = filepath.Join(cfg.RepoPath, "plan_1.md")
	}

	prompt := prompts.PlanPrompt(cfg.RepoPath, cfg.TargetPct, cfg.MaxFunctions, string(coverageJSON))
	cmd := exec.CommandContext(ctx, "cursor-agent", "--prompt", prompt, "--output", planPath)
	cmd.Dir = cfg.RepoPath
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("cursor-agent plan failed: %w: %s", err, strings.TrimSpace(string(output)))
	}

	if _, err := os.Stat(planPath); err != nil {
		return "", fmt.Errorf("plan not created: %w", err)
	}

	return planPath, nil
}

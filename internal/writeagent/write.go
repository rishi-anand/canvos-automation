package writeagent

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"canvos-automation/internal/prompts"
)

type Config struct {
	RepoPath    string
	PlanPath    string
	TestContext string
}

func Generate(ctx context.Context, cfg Config) error {
	planBytes, err := os.ReadFile(cfg.PlanPath)
	if err != nil {
		return fmt.Errorf("read plan file: %w", err)
	}

	prompt := prompts.WritePrompt(cfg.RepoPath, string(planBytes), cfg.TestContext)
	cmd := exec.CommandContext(ctx, "cursor-agent", "--prompt", prompt)
	cmd.Dir = cfg.RepoPath
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("cursor-agent write failed: %w: %s", err, strings.TrimSpace(string(output)))
	}

	return nil
}

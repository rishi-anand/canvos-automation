package runagent

import (
	"context"
	"fmt"
	"os/exec"
)

type Result struct {
	Success bool
	Output  string
}

func Run(ctx context.Context, repoPath string) Result {
	cmd := exec.CommandContext(ctx, "go", "test", "./...")
	cmd.Dir = repoPath
	output, err := cmd.CombinedOutput()
	if err != nil {
		return Result{Success: false, Output: fmt.Sprintf("%s", output)}
	}
	return Result{Success: true, Output: fmt.Sprintf("%s", output)}
}

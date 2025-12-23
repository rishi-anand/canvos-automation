package prompts

import "fmt"

const WriteTemplate = `You are a Write Agent tasked with generating idiomatic Go unit tests.

Repository: %s

Use the plan below to create unit tests that increase coverage. Follow Go testing best practices.
If there were previous test failures, fix them while keeping the tests meaningful.

Plan:
%s

Previous test output (if any):
%s
`

func WritePrompt(repoPath, planContent, testOutput string) string {
	return fmt.Sprintf(WriteTemplate, repoPath, planContent, testOutput)
}

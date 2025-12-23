package prompts

import "fmt"

const PlanTemplate = `You are a Plan Agent tasked with increasing Go test coverage.

Repository: %s
Target coverage: %.2f%%

Use the coverage report below (JSON) to pick the most impactful uncovered functions.
Select up to %d functions across the lowest-coverage files.

Coverage report:
%s

Create a markdown file named plan_1.md with the following structure for each function:

file_name
function_name
function_goal - a description of what's being done in the function
corner_cases
- corner_case1
- corner_case2

Only include real functions from the repository and keep the plan concise and actionable.
`

func PlanPrompt(repoPath string, targetCoverage float64, maxFunctions int, coverageJSON string) string {
	return fmt.Sprintf(PlanTemplate, repoPath, targetCoverage, maxFunctions, coverageJSON)
}

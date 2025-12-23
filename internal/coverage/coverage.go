package coverage

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

type FileCoverage struct {
	File        string  `json:"file"`
	CoveragePct float64 `json:"coverage_pct"`
}

type Report struct {
	TotalCoveragePct float64        `json:"total_coverage_pct"`
	Files            []FileCoverage `json:"files"`
}

type Result struct {
	Report     Report
	ReportPath string
}

func Run(ctx context.Context, repoPath string) (Result, error) {
	workDir, err := os.MkdirTemp("", "coverage-agent-*")
	if err != nil {
		return Result{}, fmt.Errorf("create temp dir: %w", err)
	}
	defer os.RemoveAll(workDir)

	coverProfile := filepath.Join(workDir, "cover.out")
	cmd := exec.CommandContext(ctx, "go", "test", "./...", "-coverprofile", coverProfile)
	cmd.Dir = repoPath
	output, err := cmd.CombinedOutput()
	if err != nil {
		return Result{}, fmt.Errorf("go test coverage failed: %w: %s", err, string(output))
	}

	coverCmd := exec.CommandContext(ctx, "go", "tool", "cover", "-func", coverProfile)
	coverCmd.Dir = repoPath
	coverOutput, err := coverCmd.Output()
	if err != nil {
		return Result{}, fmt.Errorf("go tool cover failed: %w", err)
	}

	report, err := parseCoverFunc(string(coverOutput))
	if err != nil {
		return Result{}, err
	}

	reportPath := filepath.Join(repoPath, ".coverage-agent", "coverage.json")
	if err := os.MkdirAll(filepath.Dir(reportPath), 0o755); err != nil {
		return Result{}, fmt.Errorf("create coverage dir: %w", err)
	}

	file, err := os.Create(reportPath)
	if err != nil {
		return Result{}, fmt.Errorf("create coverage report: %w", err)
	}
	defer file.Close()

	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(report); err != nil {
		return Result{}, fmt.Errorf("write coverage report: %w", err)
	}

	return Result{Report: report, ReportPath: reportPath}, nil
}

func parseCoverFunc(output string) (Report, error) {
	scanner := bufio.NewScanner(strings.NewReader(output))
	fileTotals := make(map[string]float64)
	fileCovered := make(map[string]float64)
	var totalCoverage *float64

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		if strings.HasPrefix(line, "total:") {
			fields := strings.Fields(line)
			if len(fields) < 3 {
				return Report{}, fmt.Errorf("unexpected total line: %s", line)
			}
			coverageField := strings.TrimSuffix(fields[len(fields)-1], "%")
			coverageValue, err := strconv.ParseFloat(coverageField, 64)
			if err != nil {
				return Report{}, fmt.Errorf("parse total coverage: %w", err)
			}
			totalCoverage = &coverageValue
			continue
		}

		fields := strings.Fields(line)
		if len(fields) < 3 {
			return Report{}, fmt.Errorf("unexpected line: %s", line)
		}

		fileFunc := fields[0]
		parts := strings.SplitN(fileFunc, ":", 2)
		if len(parts) != 2 {
			return Report{}, fmt.Errorf("unexpected file format: %s", line)
		}
		file := parts[0]
		if strings.HasSuffix(file, "_test.go") {
			continue
		}

		statements, err := strconv.ParseFloat(fields[len(fields)-2], 64)
		if err != nil {
			return Report{}, fmt.Errorf("parse statements: %w", err)
		}
		coverageField := strings.TrimSuffix(fields[len(fields)-1], "%")
		coverageValue, err := strconv.ParseFloat(coverageField, 64)
		if err != nil {
			return Report{}, fmt.Errorf("parse coverage: %w", err)
		}

		fileTotals[file] += statements
		fileCovered[file] += statements * (coverageValue / 100)
	}

	if err := scanner.Err(); err != nil {
		return Report{}, fmt.Errorf("scan coverage output: %w", err)
	}

	if totalCoverage == nil {
		return Report{}, errors.New("total coverage not found")
	}

	files := make([]FileCoverage, 0, len(fileTotals))
	for file, total := range fileTotals {
		covered := fileCovered[file]
		coveragePct := 0.0
		if total > 0 {
			coveragePct = (covered / total) * 100
		}
		files = append(files, FileCoverage{File: file, CoveragePct: coveragePct})
	}

	sort.Slice(files, func(i, j int) bool {
		return files[i].CoveragePct < files[j].CoveragePct
	})

	return Report{
		TotalCoveragePct: *totalCoverage,
		Files:            files,
	}, nil
}

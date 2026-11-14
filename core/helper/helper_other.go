//go:build !windows

package main

import (
	"fmt"
	"os"
)

// The helper exists only on Windows; other builds keep the package testable.
func main() {
	fmt.Fprintln(os.Stderr, "RoutaMiHelperService is Windows-only")
	os.Exit(1)
}

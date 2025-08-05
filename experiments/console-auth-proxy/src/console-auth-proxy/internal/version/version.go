package version

import (
	"fmt"
	"runtime"
)

var (
	// Version is the semantic version (will be overridden by build)
	Version = "dev"
	
	// GitCommit is the git commit hash (will be overridden by build)
	GitCommit = "unknown"
	
	// BuildDate is the build date (will be overridden by build)
	BuildDate = "unknown"
)

// BuildInfo contains build information
type BuildInfo struct {
	Version   string `json:"version"`
	GitCommit string `json:"git_commit"`
	BuildDate string `json:"build_date"`
	GoVersion string `json:"go_version"`
	Platform  string `json:"platform"`
}

// Get returns build information
func Get() BuildInfo {
	return BuildInfo{
		Version:   Version,
		GitCommit: GitCommit,
		BuildDate: BuildDate,
		GoVersion: runtime.Version(),
		Platform:  fmt.Sprintf("%s/%s", runtime.GOOS, runtime.GOARCH),
	}
}

// String returns a formatted version string
func (b BuildInfo) String() string {
	return fmt.Sprintf("console-auth-proxy %s (%s) built on %s with %s for %s",
		b.Version, b.GitCommit, b.BuildDate, b.GoVersion, b.Platform)
}
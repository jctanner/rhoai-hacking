package metrics

import (
	"bytes"
	"fmt"
	"regexp"
	"strings"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/common/expfmt"
)

// RemoveComments removes comments from Prometheus metrics text
func RemoveComments(input string) string {
	lines := strings.Split(input, "\n")
	var result []string
	
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}
		result = append(result, line)
	}
	
	return strings.Join(result, "\n")
}

// FormatMetrics formats Prometheus collectors to text format
func FormatMetrics(collectors ...prometheus.Collector) string {
	registry := prometheus.NewRegistry()
	
	for _, collector := range collectors {
		if err := registry.Register(collector); err != nil {
			// If already registered, create a new registry
			registry = prometheus.NewRegistry()
			registry.Register(collector)
		}
	}
	
	metricFamilies, err := registry.Gather()
	if err != nil {
		return fmt.Sprintf("Error gathering metrics: %v", err)
	}
	
	var buf bytes.Buffer
	encoder := expfmt.NewEncoder(&buf, expfmt.FmtText)
	
	for _, mf := range metricFamilies {
		if err := encoder.Encode(mf); err != nil {
			return fmt.Sprintf("Error encoding metrics: %v", err)
		}
	}
	
	return buf.String()
}

// NormalizeMetrics normalizes metrics text for comparison
func NormalizeMetrics(input string) string {
	// Remove timestamps and other variable data
	re := regexp.MustCompile(`\s+\d+(\.\d+)?\s*$`)
	lines := strings.Split(input, "\n")
	var result []string
	
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" {
			continue
		}
		
		// Remove timestamp from the end of metric lines
		normalized := re.ReplaceAllString(trimmed, "")
		result = append(result, normalized)
	}
	
	return strings.Join(result, "\n")
}
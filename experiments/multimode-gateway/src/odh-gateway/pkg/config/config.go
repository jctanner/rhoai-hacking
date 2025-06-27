package config

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

type Config struct {
	Routes []Route `yaml:"routes"`
}

type Route struct {
	PathPrefix string `yaml:"path"`
	Upstream   string `yaml:"upstream"`
	// Optional future fields:
	// AuthRequired bool   `yaml:"authRequired,omitempty"`
}

func LoadConfig(path string) (*Config, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read config: %w", err)
	}

	var cfg Config
	if err := yaml.Unmarshal(raw, &cfg); err != nil {
		return nil, fmt.Errorf("unmarshal config: %w", err)
	}

	return &cfg, nil
}

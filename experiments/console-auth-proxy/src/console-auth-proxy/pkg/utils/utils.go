package utils

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
)

// RandomString generates a random string of the specified length
func RandomString(length int) (string, error) {
	bytes := make([]byte, length/2+1)
	if _, err := rand.Read(bytes); err != nil {
		return "", fmt.Errorf("failed to generate random string: %w", err)
	}
	
	result := hex.EncodeToString(bytes)
	if len(result) > length {
		result = result[:length]
	}
	
	return result, nil
}
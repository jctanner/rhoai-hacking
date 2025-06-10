package main

import (
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
)

func main() {
	var text string
	flag.StringVar(&text, "text", "Hello from Echo", "Text to display in the response")
	flag.Parse()

	port := os.Getenv("PORT")
	if port == "" {
		port = "5678"
	}

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("---- Incoming %s %s ----", r.Method, r.URL.Path)

		var builder strings.Builder
		builder.WriteString(fmt.Sprintf("%s\n\n", text))
		builder.WriteString(fmt.Sprintf("Method: %s\nPath: %s\n\nHeaders:\n", r.Method, r.URL.Path))

		for name, values := range r.Header {
			for _, value := range values {
				log.Printf("%s: %s", name, value)
				builder.WriteString(fmt.Sprintf("  %s: %s\n", name, value))
			}
		}

		// Decode JWT from cookie if present
		if cookie, err := r.Cookie("id_token"); err == nil {
			builder.WriteString("\nDecoded JWT Claims (id_token):\n")
			claims, err := decodeJWTClaims(cookie.Value)
			if err != nil {
				builder.WriteString(fmt.Sprintf("  [error decoding token]: %v\n", err))
			} else {
				for k, v := range claims {
					builder.WriteString(fmt.Sprintf("  %s: %v\n", k, v))
				}
			}
		} else {
			builder.WriteString("\nNo id_token cookie found.\n")
		}

		w.Header().Set("Content-Type", "text/plain")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(builder.String()))
	})

	log.Printf("Echo server listening on port %s with message: %s\n", port, text)
	http.ListenAndServe(":"+port, nil)
}

func decodeJWTClaims(token string) (map[string]interface{}, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return nil, fmt.Errorf("invalid token format")
	}

	// Decode the payload (claims)
	payload, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return nil, fmt.Errorf("error decoding payload: %w", err)
	}

	var claims map[string]interface{}
	if err := json.Unmarshal(payload, &claims); err != nil {
		return nil, fmt.Errorf("error unmarshaling payload: %w", err)
	}

	return claims, nil
}

package main

import (
    "fmt"
    "log"
    "net/http"
)

func main() {
    http.HandleFunc("/login", func(w http.ResponseWriter, r *http.Request) {
        log.Println("====== Incoming /login request ======")
        for name, values := range r.Header {
            for _, value := range values {
                log.Printf("%s: %s", name, value)
            }
        }

        rd := r.URL.Query().Get("rd")
        cookie, err := r.Cookie("_oauth2_proxy")

        if err != nil {
            log.Println("No session cookie – falling through to oauth2-proxy")
            http.NotFound(w, r)
            return
        }

        log.Printf("Session cookie found: %s", cookie.Value)

        if rd != "" {
            log.Printf("Redirecting to rd=%s", rd)
            http.Redirect(w, r, rd, http.StatusFound)
            return
        }

        log.Println("Session found but no rd. Showing confirmation page.")
        fmt.Fprintln(w, `<html><body><h2>Authenticated</h2></body></html>`)
    })

    addr := ":4181"
    log.Printf("Starting redirect-handler on %s", addr)
    log.Fatal(http.ListenAndServe(addr, nil))
}

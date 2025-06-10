
use proxy_wasm::traits::*;
use proxy_wasm::types::*;
use std::collections::HashMap;

struct JwtRedirect;

impl Context for JwtRedirect {}

impl HttpContext for JwtRedirect {
    fn on_http_request_headers(&mut self, _: usize) -> Action {
        // Check Authorization header
        if let Some(auth_header) = self.get_http_request_header("authorization") {
            if auth_header.starts_with("Bearer ") {
                return Action::Continue;
            }
        }

        // Construct redirect URL to Keycloak login
        let path = self.get_http_request_header(":path").unwrap_or("/".to_string());
        let redirect_uri = format!("http://localhost:8081{}", path);
        let keycloak_login = format!(
            "http://keycloak:8080/realms/myrealm/protocol/openid-connect/auth?client_id=echo-client&response_type=code&scope=openid&redirect_uri={}",
            urlencoding::encode(&redirect_uri)
        );

        let mut headers = HashMap::new();
        headers.insert(":status", "302");
        headers.insert("Location", &keycloak_login);

        self.send_http_response(302, headers, Some(b"Redirecting...".to_vec()));
        Action::Pause
    }
}

impl RootContext for JwtRedirect {
    fn on_configure(&mut self, _size: usize) -> bool {
        true
    }

    fn on_start(&mut self) -> bool {
        true
    }

    fn create_http_context(&self, _context_id: u32) -> Box<dyn HttpContext> {
        Box::new(JwtRedirect)
    }

    fn get_type(&self) -> Option<ContextType> {
        Some(ContextType::HttpContext)
    }
}

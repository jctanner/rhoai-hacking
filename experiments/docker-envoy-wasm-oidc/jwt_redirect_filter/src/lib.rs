use proxy_wasm::traits::*;
use proxy_wasm::types::*;
use std::collections::HashMap;

struct JwtRedirect;

impl Context for JwtRedirect {}

impl HttpContext for JwtRedirect {
    fn on_http_request_headers(&mut self, _: usize, _: bool) -> Action {
        if let Some(auth_header) = self.get_http_request_header("authorization") {
            if auth_header.starts_with("Bearer ") {
                return Action::Continue;
            }
        }

        let path = self.get_http_request_header(":path").unwrap_or("/".to_string());
        let redirect_uri = format!("http://localhost:8081{}", path);
        let keycloak_login = format!(
            "http://keycloak:8080/realms/myrealm/protocol/openid-connect/auth\
?client_id=echo-client&response_type=code&scope=openid&redirect_uri={}",
            urlencoding::encode(&redirect_uri)
        );

        let headers = vec![
            (":status", "302"),
            ("location", &keycloak_login),
        ];

        self.send_http_response(302, headers, Some(b"Redirecting..."));
        Action::Pause
    }
}

impl RootContext for JwtRedirect {
    fn on_configure(&mut self, _: usize) -> bool {
        true
    }

    fn create_http_context(&self, _: u32) -> Option<Box<dyn HttpContext>> {
        Some(Box::new(JwtRedirect))
    }

    fn get_type(&self) -> Option<ContextType> {
        Some(ContextType::HttpContext)
    }
}

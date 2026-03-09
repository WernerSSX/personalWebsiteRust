use actix_web::middleware::DefaultHeaders;

/// Shared headers applied to every response (non-CSP security headers).
pub fn common_headers() -> DefaultHeaders {
    DefaultHeaders::new()
        .add((
            "Strict-Transport-Security",
            "max-age=63072000; includeSubDomains; preload",
        ))
        .add(("X-Content-Type-Options", "nosniff"))
        .add(("Referrer-Policy", "strict-origin-when-cross-origin"))
        .add((
            "Permissions-Policy",
            "camera=(), microphone=(), geolocation=(), payment=()",
        ))
}

/// Strict CSP for normal pages (no eval, no WASM eval, no inline scripts).
pub fn strict_csp() -> DefaultHeaders {
    DefaultHeaders::new()
        .add((
            "Content-Security-Policy",
            "default-src 'self'; \
            script-src 'self'; \
            style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; \
            font-src 'self' https://fonts.gstatic.com; \
            img-src 'self' data:; \
            frame-src 'self'; \
            frame-ancestors 'self'; \
            base-uri 'self'; \
            form-action 'self'",
        ))
}

/// Relaxed CSP for game iframe pages that need WASM execution.
pub fn game_csp() -> DefaultHeaders {
    DefaultHeaders::new()
        .add((
            "Content-Security-Policy",
            "default-src 'self'; \
            script-src 'self' 'wasm-unsafe-eval'; \
            style-src 'self' 'unsafe-inline'; \
            img-src 'self' data: blob:; \
            frame-ancestors 'self'; \
            base-uri 'self'; \
            form-action 'none'",
        ))
}

use actix_web::middleware::DefaultHeaders;

pub fn security_headers() -> DefaultHeaders {
    DefaultHeaders::new()
        .add((
            "Content-Security-Policy",
            "default-src 'self'; \
            script-src 'self' https://unpkg.com 'wasm-unsafe-eval'; \
            style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; \
            font-src 'self' https://fonts.gstatic.com; \
            img-src 'self' data:; \
            connect-src 'self' https://unpkg.com; \
            frame-ancestors 'none'; \
            base-uri 'self'; \
            form-action 'self'",
        ))
        .add((
            "Strict-Transport-Security",
            "max-age=63072000; includeSubDomains; preload",
        ))
        .add(("X-Content-Type-Options", "nosniff"))
        .add(("X-Frame-Options", "DENY"))
        .add(("Referrer-Policy", "strict-origin-when-cross-origin"))
        .add((
            "Permissions-Policy",
            "camera=(), microphone=(), geolocation=(), payment=()",
        ))
}
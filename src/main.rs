use actix_files as fs;
use actix_web::{web, App, HttpServer, HttpResponse, middleware::Logger};
use tera::{Tera, Context};
use std::sync::Arc;

mod games;
mod blog;
mod security;
struct AppState {
    author: String,
    posts: Arc<Vec<blog::Post>>,
    games: Vec<games::Game>,
}

async fn home(tmpl: web::Data<Tera>, state: web::Data<AppState>) -> HttpResponse {
    let mut ctx = Context::new();
    ctx.insert("author", &state.author);

    let body = tmpl.render("home.html", &ctx)
        .expect("Template rendering failed");

    HttpResponse::Ok()
        .content_type("text/html; charset=utf-8")
        .body(body)
}

async fn blog_index(tmpl: web::Data<Tera>, state: web::Data<AppState>) -> HttpResponse {
    let mut ctx = Context::new();
    ctx.insert("author", &state.author);
    ctx.insert("posts", state.posts.as_ref());

    let body = tmpl.render("blog_index.html", &ctx)
        .expect("Template error");

    HttpResponse::Ok()
        .content_type("text/html; charset=utf-8")
        .body(body)
}

async fn blog_post(tmpl: web::Data<Tera>, state: web::Data<AppState>, path: web::Path<String>) -> HttpResponse {
    let slug = path.into_inner();

    // Find the post whose slug matches the URL.
    let post = match state.posts.iter().find(|p| p.slug == slug) {
        Some(p) => p,
        None => {
            return HttpResponse::NotFound()
                .content_type("text/html; charset=utf-8")
                .body("<h1>404</h1><p>Post not found.</p>");
        }
    };

    let mut ctx = Context::new();
    ctx.insert("author", &state.author);
    ctx.insert("post", post);

    let body = tmpl.render("blog_post.html", &ctx)
        .expect("Template error");

    HttpResponse::Ok()
        .content_type("text/html; charset=utf-8")
        .body(body)
}

async fn counter(tmpl: web::Data<Tera>, state: web::Data<AppState>) -> HttpResponse {
    let mut ctx = Context::new();
    ctx.insert("author", &state.author);

    let body = tmpl.render("counter.html", &ctx)
        .expect("Template rendering failed");

    HttpResponse::Ok()
        .content_type("text/html; charset=utf-8")
        .body(body)
}

async fn game_index(
    tmpl: web::Data<Tera>,
    state: web::Data<AppState>,
) -> HttpResponse {
    let mut ctx = Context::new();
    ctx.insert("author", &state.author);
    ctx.insert("games", &state.games);

    let body = tmpl.render("game_index.html", &ctx).expect("Template error");
    HttpResponse::Ok().content_type("text/html; charset=utf-8").body(body)
}

async fn game_play(
    tmpl: web::Data<Tera>,
    state: web::Data<AppState>,
    path: web::Path<String>,
) -> HttpResponse {
    let slug = path.into_inner();

    let game = match state.games.iter().find(|g| g.slug == slug) {
        Some(g) => g,
        None => {
            return HttpResponse::NotFound()
                .content_type("text/html; charset=utf-8")
                .body("<h1>404</h1><p>Game not found.</p>");
        }
    };

    let mut ctx = Context::new();
    ctx.insert("author", &state.author);
    ctx.insert("game", game);

    let body = tmpl.render("game_play.html", &ctx).expect("Template error");
    HttpResponse::Ok().content_type("text/html; charset=utf-8").body(body)
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    env_logger::init_from_env(
        env_logger::Env::default()
            .default_filter_or("info")
    );

    let posts = blog::load_all_posts("content/posts")
        .expect("Failed to load blog posts");
    log::info!("Loaded {} post(s)", posts.len());

    let app_state = web::Data::new(AppState {
        author: "Werner Soon".to_string(),
        posts: Arc::new(posts),
        games: games::game_list(),
    });

    let tera = Tera::new("templates/**/*")
        .expect("Failed to load templates");

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(tera.clone()))
            .app_data(app_state.clone())
            .wrap(security::common_headers())
            .wrap(Logger::default())
            // Game static files get a WASM-permissive CSP
            .service(
                web::scope("/static/games")
                    .wrap(security::game_csp())
                    .service(fs::Files::new("", "static/games"))
            )
            // All other static files get the strict CSP
            .service(
                web::scope("/static")
                    .wrap(security::strict_csp())
                    .service(fs::Files::new("", "static"))
            )
            // Normal pages get the strict CSP
            .service(
                web::scope("")
                    .wrap(security::strict_csp())
                    .route("/", web::get().to(home))
                    .route("/blog", web::get().to(blog_index))
                    .route("/blog/{slug}", web::get().to(blog_post))
                    .route("/counter", web::get().to(counter))
                    .route("/games", web::get().to(game_index))
                    .route("/games/{slug}", web::get().to(game_play))
            )
    })
    .bind("0.0.0.0:3000")?
    .run()
    .await
}


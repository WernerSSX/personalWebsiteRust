use actix_files as fs;
use actix_web::{web, App, HttpServer, HttpResponse, middleware::Logger};
use tera::{Tera, Context};
use std::sync::Arc;

mod blog;
mod games;
mod security;
struct AppState {
    author: String,
    posts: Arc<Vec<blog::Post>>,
    games: Arc<Vec<games::Game>>,
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

async fn game_index(tmpl: web::Data<Tera>, state: web::Data<AppState>) -> HttpResponse {
    let mut ctx = Context::new();
    ctx.insert("author", &state.author);
    ctx.insert("games", state.games.as_ref());

    let body = tmpl.render("game_index.html", &ctx)
        .expect("Template error");
    HttpResponse::Ok()
        .content_type("text/html; charset=utf-8")
        .body(body)
}

async fn game_play(tmpl: web::Data<Tera>, state: web::Data<AppState>, path: web::Path<String>) -> HttpResponse {
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

async fn game_source(
    state: web::Data<AppState>,
    path: web::Path<String>,
) -> HttpResponse {
    let slug = path.into_inner();

    match state.games.iter().find(|g| g.slug == slug) {
        Some(g) => HttpResponse::Ok()
            .content_type("text/plain; charset=utf-8")
            .body(g.lua_source.clone()),
        None => HttpResponse::NotFound().body("Not found"),
    }
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

    let game_list = games::load_all_games("content/games")
        .expect("Failed to load games");
    log::info!("Loaded {} game(s)", game_list.len());

    let app_state = web::Data::new(AppState {
        author: "Werner Soon".to_string(),
        posts: Arc::new(posts),
        games: Arc::new(game_list),
    });

    let tera = Tera::new("templates/**/*")
        .expect("Failed to load templates");

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(tera.clone()))
            .app_data(app_state.clone())
            .wrap(security::security_headers())
            .wrap(Logger::default())
            .route("/", web::get().to(home))
            .route("/blog", web::get().to(blog_index))
            .route("/blog/{slug}", web::get().to(blog_post))
            .route("/games", web::get().to(game_index))
            .route("/games/{slug}", web::get().to(game_play))
            .route("/games/{slug}/source", web::get().to(game_source))
            .service(fs::Files::new("/static", "static"))
    })
    .bind("0.0.0.0:3000")?
    .run()
    .await
}


use chrono::NaiveDate;
use serde::Deserialize;
use std::fs;
use std::path::Path;

/// Front-matter for a game file (parsed from TOML between +++ fences).
#[derive(Clone, Debug, Deserialize)]
pub struct GameMeta {
    pub title: String,
    pub slug: String,
    pub date: NaiveDate,
    #[serde(default)]
    pub summary: String,
    #[serde(default = "default_width")]
    pub width: u32,
    #[serde(default = "default_height")]
    pub height: u32,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(default)]
    pub draft: bool,
}

fn default_width() -> u32 { 512 }
fn default_height() -> u32 { 512 }

/// A game entry. We store the raw Lua source — it gets sent to the
/// browser as-is, where Wasmoon executes it.
///
/// Unlike blog posts, we do NOT convert the content to HTML. The Lua
/// source is served as plain text at a `/games/{slug}/source` endpoint,
/// and the browser-side engine fetches and runs it.
#[derive(Clone, Debug, serde::Serialize)]
pub struct Game {
    pub title: String,
    pub slug: String,
    pub date: String,
    pub date_sort: String,
    pub summary: String,
    pub width: u32,
    pub height: u32,
    pub tags: Vec<String>,
    #[serde(skip)]       // Don't pass the full source to Tera templates
    pub lua_source: String,
}

pub fn parse_game(raw: &str) -> Result<Game, String> {
    let parts: Vec<&str> = raw.splitn(3, "+++").collect();
    if parts.len() < 3 {
        return Err("Missing +++ front-matter fences".to_string());
    }

    let meta: GameMeta = toml::from_str(parts[1].trim())
        .map_err(|e| format!("Bad front-matter: {e}"))?;

    if meta.draft {
        return Err("draft".to_string());
    }

    let lua_source = parts[2].trim().to_string();

    Ok(Game {
        title: meta.title,
        slug: meta.slug,
        date: meta.date.format("%B %-d, %Y").to_string(),
        date_sort: meta.date.to_string(),
        summary: meta.summary,
        width: meta.width,
        height: meta.height,
        tags: meta.tags,
        lua_source,
    })
}

pub fn load_all_games(dir: &str) -> Result<Vec<Game>, String> {
    let path = Path::new(dir);
    if !path.exists() {
        fs::create_dir_all(path).map_err(|e| e.to_string())?;
        return Ok(Vec::new());
    }

    let mut games = Vec::new();

    for entry in fs::read_dir(path).map_err(|e| e.to_string())? {
        let entry = entry.map_err(|e| e.to_string())?;
        let file_path = entry.path();

        if file_path.extension().and_then(|e| e.to_str()) != Some("lua") {
            continue;
        }

        let raw = fs::read_to_string(&file_path).map_err(|e| e.to_string())?;
        match parse_game(&raw) {
            Ok(game) => games.push(game),
            Err(e) if e == "draft" => continue,
            Err(e) => return Err(format!("{}: {e}", file_path.display())),
        }
    }

    games.sort_by(|a, b| b.date_sort.cmp(&a.date_sort));
    Ok(games)
}
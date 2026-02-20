use chrono::NaiveDate;
use pulldown_cmark::{html, Options, Parser};
use serde::Deserialize;
use std::fs;
use std::path::Path;

#[derive(Clone, Debug, Deserialize)]
pub struct FrontMatter {
    pub title: String,
    pub slug: String,
    pub date: NaiveDate,
    #[serde(default)]
    pub summary: String
}

#[derive(Clone, Debug, serde::Serialize)]
pub struct Post {
    pub title: String,
    pub slug: String,
    pub date: String,
    pub date_sort: String,
    pub summary: String,
    pub html_content: String,
    pub reading_time: usize,
}

pub fn parse_post(raw: &str) -> Result<Post, String> {
    let parts: Vec<&str> = raw.splitn(3, "+++").collect();
    if parts.len() < 3 {
        return Err("Missing +++ front-matter fences".to_string());
    }

    let meta: FrontMatter = toml::from_str(parts[1].trim())
        .map_err(|e| format!("Bad front-matter: {e}"))?;

    let markdown_body = parts[2].trim();

    let word_count = markdown_body.split_whitespace().count();
    let reading_time = (word_count / 200).max(1);

    let mut options = Options::empty();
    options.insert(Options::ENABLE_STRIKETHROUGH);
    options.insert(Options::ENABLE_TABLES);

    let parser = Parser::new_ext(markdown_body, options);
    let mut html_content = String::new();
    html::push_html(&mut html_content, parser);

    Ok(Post {
        title: meta.title,
        slug: meta.slug,
        date: meta.date.format("%b %-d, %Y").to_string(),
        date_sort: meta.date.to_string(),
        summary: meta.summary,
        html_content,
        reading_time,
    })
}

pub fn load_all_posts(dir: &str) -> Result<Vec<Post>, String> {
    let path = Path::new(dir);
    if !path.exists() {
        fs::create_dir_all(path).map_err(|e| e.to_string())?;
        return Ok(Vec::new());
    }

    let mut posts = Vec::new();

    for entry in fs::read_dir(path)
        .map_err(|e| e.to_string())? {
            let entry = entry.map_err(|e| e.to_string())?;
            let file_path = entry.path();

            if file_path.extension().and_then(|e| e.to_str()) != Some("md") {
                continue;
            }

            let raw = fs::read_to_string(&file_path)
            .map_err(|e| e.to_string())?;
            let post = parse_post(&raw)
                .map_err(|e| format!("{}: {e}", file_path.display()))?;
            posts.push(post);
        }

        posts.sort_by(|a, b| b.date_sort.cmp(&a.date_sort));
        Ok(posts)
}
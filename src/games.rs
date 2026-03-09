#[derive(Clone, serde::Serialize)]
pub struct Game {
    pub title: String,
    pub slug: String,
    pub summary: String,
}

/// Return the list of available games.
/// Add new entries here when you deploy a new game.
pub fn game_list() -> Vec<Game> {
    vec![
        Game {
            title: "Pong".to_string(),
            slug: "pong".to_string(),
            summary: "The classic. W/S or Arrow keys to move. First to 5 wins.".to_string(),
        },
/*         Game {
            title: "Snake".to_string(),
            slug: "snake".to_string(),
            summary: "Eat the fruit, grow longer, don't crash.".to_string(),
        }, */
    ]
}
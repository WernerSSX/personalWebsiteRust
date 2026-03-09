use macroquad::prelude::*;

// ── Constants ────────────────────────────────────────────────────────

const PADDLE_W: f32 = 10.0;
const PADDLE_H: f32 = 70.0;
const BALL_R: f32 = 6.0;
const PADDLE_SPEED: f32 = 320.0;
const INITIAL_BALL_SPEED: f32 = 280.0;
const WIN_SCORE: i32 = 5;

// Colors that match your site's dark theme.
const BG: Color = Color::new(0.04, 0.04, 0.047, 1.0);
const ACCENT: Color = Color::new(0.83, 0.65, 0.45, 1.0);
const TEXT_COL: Color = Color::new(0.91, 0.89, 0.87, 1.0);
const MUTED: Color = Color::new(0.54, 0.52, 0.49, 1.0);
const LINE_COL: Color = Color::new(0.16, 0.15, 0.14, 1.0);

// ── Game state ───────────────────────────────────────────────────────

struct Ball {
    x: f32,
    y: f32,
    vx: f32,
    vy: f32,
}

struct Paddle {
    x: f32,
    y: f32,
}

fn reset_ball(w: f32, h: f32, dir: f32) -> Ball {
    Ball {
        x: w / 2.0,
        y: h / 2.0,
        vx: INITIAL_BALL_SPEED * dir * (0.6 + rand::gen_range(0.0, 0.4)),
        vy: (rand::gen_range(0.0, 1.0) * 2.0 - 1.0) * INITIAL_BALL_SPEED * 0.6,
    }
}

// ── Main ─────────────────────────────────────────────────────────────

#[macroquad::main("Pong")]
async fn main() {
    // We use a fixed virtual resolution so the game looks the same
    // regardless of the actual canvas size.
    let w: f32 = 512.0;
    let h: f32 = 384.0;

    let mut ball = reset_ball(w, h, 1.0);
    let mut p1 = Paddle { x: 20.0, y: h / 2.0 - PADDLE_H / 2.0 };
    let mut p2 = Paddle { x: w - 20.0 - PADDLE_W, y: h / 2.0 - PADDLE_H / 2.0 };
    let mut score1: i32 = 0;
    let mut score2: i32 = 0;

    loop {
        // Macroquad's camera system lets us work in a fixed coordinate
        // space. The game always thinks the screen is 512×384, even if
        // the browser canvas is a different size.
        set_camera(&Camera2D::from_display_rect(Rect::new(0.0, h, w, -h)));

        let dt = get_frame_time();

        // ── Game over check ──────────────────────────────────────
        if score1 >= WIN_SCORE || score2 >= WIN_SCORE {
            if is_key_pressed(KeyCode::Space) {
                score1 = 0;
                score2 = 0;
                ball = reset_ball(w, h, 1.0);
                p1.y = h / 2.0 - PADDLE_H / 2.0;
                p2.y = h / 2.0 - PADDLE_H / 2.0;
            }
        } else {
            // ── Player input ─────────────────────────────────────
            if is_key_down(KeyCode::W) || is_key_down(KeyCode::Up) {
                p1.y -= PADDLE_SPEED * dt;
            }
            if is_key_down(KeyCode::S) || is_key_down(KeyCode::Down) {
                p1.y += PADDLE_SPEED * dt;
            }
            p1.y = p1.y.clamp(0.0, h - PADDLE_H);

            // ── AI ───────────────────────────────────────────────
            let target = ball.y - PADDLE_H / 2.0;
            let diff = target - p2.y;
            if diff.abs() > 4.0 {
                p2.y += diff.signum() * PADDLE_SPEED * 0.7 * dt;
            }
            p2.y = p2.y.clamp(0.0, h - PADDLE_H);

            // ── Ball physics ─────────────────────────────────────
            ball.x += ball.vx * dt;
            ball.y += ball.vy * dt;

            // Top/bottom bounce.
            if ball.y - BALL_R < 0.0 {
                ball.y = BALL_R;
                ball.vy = -ball.vy;
            }
            if ball.y + BALL_R > h {
                ball.y = h - BALL_R;
                ball.vy = -ball.vy;
            }

            // Paddle collision — player 1.
            if ball.vx < 0.0
                && ball.x - BALL_R < p1.x + PADDLE_W
                && ball.x + BALL_R > p1.x
                && ball.y > p1.y
                && ball.y < p1.y + PADDLE_H
            {
                ball.vx = -ball.vx * 1.05;
                let rel = (ball.y - (p1.y + PADDLE_H / 2.0)) / (PADDLE_H / 2.0);
                ball.vy = rel * INITIAL_BALL_SPEED;
            }

            // Paddle collision — AI.
            if ball.vx > 0.0
                && ball.x + BALL_R > p2.x
                && ball.x - BALL_R < p2.x + PADDLE_W
                && ball.y > p2.y
                && ball.y < p2.y + PADDLE_H
            {
                ball.vx = -ball.vx * 1.05;
                let rel = (ball.y - (p2.y + PADDLE_H / 2.0)) / (PADDLE_H / 2.0);
                ball.vy = rel * INITIAL_BALL_SPEED;
            }

            // Scoring.
            if ball.x < -BALL_R {
                score2 += 1;
                ball = reset_ball(w, h, 1.0);
            }
            if ball.x > w + BALL_R {
                score1 += 1;
                ball = reset_ball(w, h, -1.0);
            }
        }

        // ── Drawing ──────────────────────────────────────────────
        clear_background(BG);

        // Centre line.
        let mut y = 0.0;
        while y < h {
            draw_rectangle(w / 2.0 - 1.0, y, 2.0, 8.0, LINE_COL);
            y += 16.0;
        }

        // Paddles.
        draw_rectangle(p1.x, p1.y, PADDLE_W, PADDLE_H, TEXT_COL);
        draw_rectangle(p2.x, p2.y, PADDLE_W, PADDLE_H, ACCENT);

        // Ball.
        draw_circle(ball.x, ball.y, BALL_R, WHITE);

        // Score.
        draw_text(&score1.to_string(), w / 2.0 - 48.0, 40.0, 40.0, TEXT_COL);
        draw_text(&score2.to_string(), w / 2.0 + 32.0, 40.0, 40.0, ACCENT);

        // Win/lose text.
        if score1 >= WIN_SCORE {
            draw_text("You win!", w / 2.0 - 65.0, h / 2.0, 30.0, TEXT_COL);
            draw_text("Press SPACE to restart", w / 2.0 - 120.0, h / 2.0 + 30.0, 16.0, MUTED);
        } else if score2 >= WIN_SCORE {
            draw_text("AI wins!", w / 2.0 - 58.0, h / 2.0, 30.0, ACCENT);
            draw_text("Press SPACE to restart", w / 2.0 - 120.0, h / 2.0 + 30.0, 16.0, MUTED);
        }

        next_frame().await
    }
}
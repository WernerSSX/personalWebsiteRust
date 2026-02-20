+++
title  = "Pong"
slug   = "pong"
date   = "2025-07-01"
summary = "The classic. Move with W/S or Arrow keys. First to 5 wins."
width  = 512
height = 384
tags   = ["arcade", "classic"]
+++

local W, H
local ball, p1, p2
local score1, score2
local PADDLE_W, PADDLE_H, BALL_R
local SPEED, PADDLE_SPEED

function _init()
    W = gfx.width()
    H = gfx.height()

    PADDLE_W = 10
    PADDLE_H = 70
    BALL_R   = 6
    SPEED    = 280
    PADDLE_SPEED = 320

    score1 = 0
    score2 = 0

    reset_ball(1)
    p1 = { x = 20,                    y = H/2 - PADDLE_H/2 }
    p2 = { x = W - 20 - PADDLE_W,     y = H/2 - PADDLE_H/2 }
end

function reset_ball(dir)
    ball = {
        x  = W / 2,
        y  = H / 2,
        vx = SPEED * dir * (0.6 + math.random() * 0.4),
        vy = (math.random() * 2 - 1) * SPEED * 0.6,
    }
end

function _update(dt)
    if score1 >= 5 or score2 >= 5 then
        if input.key_pressed(" ") then _init() end
        return
    end

    -- Player 1 controls
    if input.key("w") or input.key("arrowup")   then p1.y = p1.y - PADDLE_SPEED * dt end
    if input.key("s") or input.key("arrowdown")  then p1.y = p1.y + PADDLE_SPEED * dt end
    p1.y = math.max(0, math.min(H - PADDLE_H, p1.y))

    -- Simple AI for player 2
    local target = ball.y - PADDLE_H / 2
    local diff   = target - p2.y
    if math.abs(diff) > 4 then
        p2.y = p2.y + (diff > 0 and 1 or -1) * PADDLE_SPEED * 0.7 * dt
    end
    p2.y = math.max(0, math.min(H - PADDLE_H, p2.y))

    -- Ball movement
    ball.x = ball.x + ball.vx * dt
    ball.y = ball.y + ball.vy * dt

    -- Top/bottom bounce
    if ball.y - BALL_R < 0  then ball.y = BALL_R;     ball.vy = -ball.vy end
    if ball.y + BALL_R > H  then ball.y = H - BALL_R; ball.vy = -ball.vy end

    -- Paddle collisions
    if ball.vx < 0 and ball.x - BALL_R < p1.x + PADDLE_W
       and ball.y > p1.y and ball.y < p1.y + PADDLE_H then
        ball.vx = -ball.vx * 1.05
        ball.vy = ((ball.y - (p1.y + PADDLE_H/2)) / (PADDLE_H/2)) * SPEED
    end
    if ball.vx > 0 and ball.x + BALL_R > p2.x
       and ball.y > p2.y and ball.y < p2.y + PADDLE_H then
        ball.vx = -ball.vx * 1.05
        ball.vy = ((ball.y - (p2.y + PADDLE_H/2)) / (PADDLE_H/2)) * SPEED
    end

    -- Scoring
    if ball.x < -BALL_R      then score2 = score2 + 1; reset_ball(1) end
    if ball.x > W + BALL_R   then score1 = score1 + 1; reset_ball(-1) end
end

function _draw()
    gfx.clear(10, 10, 12)

    -- Centre line
    for y = 0, H, 16 do
        gfx.rect(W/2 - 1, y, 2, 8, "#2a2725")
    end

    -- Paddles
    gfx.rect(p1.x, p1.y, PADDLE_W, PADDLE_H, "#e8e4df")
    gfx.rect(p2.x, p2.y, PADDLE_W, PADDLE_H, "#d4a574")

    -- Ball
    gfx.circle(ball.x, ball.y, BALL_R, "#fff")

    -- Score
    gfx.text(tostring(score1), W/2 - 48, 20, "#e8e4df", 32)
    gfx.text(tostring(score2), W/2 + 32, 20, "#d4a574", 32)

    if score1 >= 5 then
        gfx.text("You win!", W/2 - 60, H/2 - 10, "#e8e4df", 24)
        gfx.text("Press SPACE to restart", W/2 - 110, H/2 + 24, "#8a847c", 14)
    elseif score2 >= 5 then
        gfx.text("AI wins!", W/2 - 56, H/2 - 10, "#d4a574", 24)
        gfx.text("Press SPACE to restart", W/2 - 110, H/2 + 24, "#8a847c", 14)
    end
end
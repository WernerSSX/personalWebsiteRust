+++
title   = "Flappy"
slug    = "flappy"
date    = "2025-07-12"
summary = "Tap SPACE or click to flap. Dodge the pipes. How far can you go?"
width   = 288
height  = 512
tags    = ["arcade", "casual"]
+++

-- Flappy – a flappy bird style game

local STATE_READY = 0
local STATE_PLAY  = 1
local STATE_DEAD  = 2

local state
local bird
local pipes
local score
local best
local pipe_timer
local ground_x
local flash_timer

-- tunables
local GRAVITY     = 800
local FLAP_VEL    = -280
local PIPE_SPEED  = 140
local PIPE_GAP    = 120
local PIPE_WIDTH  = 48
local PIPE_INTERVAL = 1.6
local BIRD_X      = 70
local BIRD_R      = 12
local GROUND_H    = 50

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

function _init()
    local H = gfx.height()
    bird = {
        y  = H / 2,
        vy = 0,
        angle = 0,
    }
    pipes = {}
    score = 0
    best  = best or 0
    pipe_timer = PIPE_INTERVAL
    ground_x = 0
    flash_timer = 0
    state = STATE_READY
end

local function flap()
    bird.vy = FLAP_VEL
end

local function spawn_pipe()
    local W = gfx.width()
    local H = gfx.height()
    local min_top = 60
    local max_top = H - GROUND_H - PIPE_GAP - 60
    local top = min_top + math.random() * (max_top - min_top)
    table.insert(pipes, {
        x = W,
        top = top,
        scored = false,
    })
end

local function check_collision()
    local W = gfx.width()
    local H = gfx.height()

    -- ground / ceiling
    if bird.y + BIRD_R > H - GROUND_H then return true end
    if bird.y - BIRD_R < 0 then return true end

    -- pipes
    for _, p in ipairs(pipes) do
        if BIRD_X + BIRD_R > p.x and BIRD_X - BIRD_R < p.x + PIPE_WIDTH then
            if bird.y - BIRD_R < p.top or bird.y + BIRD_R > p.top + PIPE_GAP then
                return true
            end
        end
    end
    return false
end

function _update(dt)
    local W = gfx.width()
    local H = gfx.height()

    -- scrolling ground
    ground_x = ground_x - PIPE_SPEED * dt
    if ground_x <= -24 then ground_x = ground_x + 24 end

    if state == STATE_READY then
        -- bob bird
        bird.y = H / 2 + math.sin(os.clock() * 4) * 8
        if input.key_pressed(" ") or input.mouse_down(0) then
            state = STATE_PLAY
            flap()
        end
        return
    end

    if state == STATE_DEAD then
        flash_timer = flash_timer + dt
        -- bird falls to ground
        bird.vy = bird.vy + GRAVITY * dt
        bird.y  = bird.y + bird.vy * dt
        if bird.y + BIRD_R > H - GROUND_H then
            bird.y  = H - GROUND_H - BIRD_R
            bird.vy = 0
        end
        if flash_timer > 1.0 and (input.key_pressed(" ") or input.mouse_down(0)) then
            _init()
        end
        return
    end

    -- playing
    if input.key_pressed(" ") or input.mouse_down(0) then
        flap()
    end

    -- gravity
    bird.vy = bird.vy + GRAVITY * dt
    bird.y  = bird.y + bird.vy * dt

    -- angle based on velocity
    bird.angle = clamp(bird.vy / 400, -0.5, 1.0)

    -- pipe spawning
    pipe_timer = pipe_timer - dt
    if pipe_timer <= 0 then
        spawn_pipe()
        pipe_timer = PIPE_INTERVAL
    end

    -- move pipes
    for i = #pipes, 1, -1 do
        local p = pipes[i]
        p.x = p.x - PIPE_SPEED * dt

        -- score
        if not p.scored and p.x + PIPE_WIDTH < BIRD_X then
            p.scored = true
            score = score + 1
        end

        -- remove offscreen
        if p.x + PIPE_WIDTH < -10 then
            table.remove(pipes, i)
        end
    end

    -- collision
    if check_collision() then
        state = STATE_DEAD
        flash_timer = 0
        if score > best then best = score end
    end
end

-- drawing ----------------------------------------------------------------

local function draw_pipe(p)
    local H = gfx.height()
    local pipe_col  = "#3a8a3a"
    local pipe_edge = "#2d6e2d"
    local cap_h = 20
    local cap_extra = 6

    -- top pipe body
    gfx.rect(p.x, 0, PIPE_WIDTH, p.top - cap_h, pipe_col)
    -- top pipe cap
    gfx.rect(p.x - cap_extra, p.top - cap_h, PIPE_WIDTH + cap_extra * 2, cap_h, pipe_edge)

    -- bottom pipe body
    local bot_y = p.top + PIPE_GAP
    gfx.rect(p.x, bot_y + cap_h, PIPE_WIDTH, H - GROUND_H - bot_y - cap_h, pipe_col)
    -- bottom pipe cap
    gfx.rect(p.x - cap_extra, bot_y, PIPE_WIDTH + cap_extra * 2, cap_h, pipe_edge)
end

local function draw_bird()
    -- body
    local col = "#f5c842"
    local beak = "#e87830"
    local eye_white = "#ffffff"
    local eye_pupil = "#000000"

    gfx.circle(BIRD_X, bird.y, BIRD_R, col)

    -- wing
    local wing_y = bird.y + math.sin(os.clock() * 20) * 3
    gfx.circle(BIRD_X - 6, wing_y + 2, 7, "#e0b030")

    -- eye
    gfx.circle(BIRD_X + 6, bird.y - 3, 4, eye_white)
    gfx.circle(BIRD_X + 7, bird.y - 3, 2, eye_pupil)

    -- beak
    gfx.rect(BIRD_X + BIRD_R - 2, bird.y - 2, 10, 5, beak)
end

function _draw()
    local W = gfx.width()
    local H = gfx.height()

    -- sky gradient (just a solid color for simplicity)
    gfx.clear(78, 192, 232)

    -- pipes
    for _, p in ipairs(pipes) do
        draw_pipe(p)
    end

    -- ground
    gfx.rect(0, H - GROUND_H, W, GROUND_H, "#ded895")
    gfx.line(0, H - GROUND_H, W, H - GROUND_H, "#5a8c32", 2)
    -- ground stripes
    for x = math.floor(ground_x), W, 24 do
        gfx.line(x, H - GROUND_H + 8, x + 12, H - GROUND_H + 8, "#c8c070", 1)
    end

    -- bird
    draw_bird()

    -- score
    if state == STATE_PLAY or state == STATE_DEAD then
        -- shadow
        gfx.text(tostring(score), W / 2 - 7, 52, "rgba(0,0,0,0.3)", 36)
        gfx.text(tostring(score), W / 2 - 8, 50, "#ffffff", 36)
    end

    -- ready screen
    if state == STATE_READY then
        gfx.text("FLAPPY", W / 2 - 50, H / 3 - 30, "#ffffff", 28)
        gfx.text("Press SPACE or Click to flap", W / 2 - 115, H / 3 + 10, "#ffffff", 12)
    end

    -- death screen
    if state == STATE_DEAD then
        gfx.rect(W / 2 - 80, H / 2 - 60, 160, 120, "rgba(0,0,0,0.75)")
        gfx.rect_line(W / 2 - 80, H / 2 - 60, 160, 120, "#d4a574", 2)

        gfx.text("GAME OVER", W / 2 - 55, H / 2 - 45, "#e8e4df", 18)

        gfx.text("Score", W / 2 - 60, H / 2 - 15, "#8a847c", 14)
        gfx.text(tostring(score), W / 2 + 30, H / 2 - 15, "#e8e4df", 14)

        gfx.text("Best", W / 2 - 60, H / 2 + 5, "#8a847c", 14)
        gfx.text(tostring(best), W / 2 + 30, H / 2 + 5, "#d4a574", 14)

        if flash_timer > 1.0 then
            gfx.text("SPACE to restart", W / 2 - 65, H / 2 + 35, "#8a847c", 12)
        end
    end
end

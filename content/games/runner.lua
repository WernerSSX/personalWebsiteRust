+++
title   = "Lane Dash"
slug    = "runner"
date    = "2025-07-15"
summary = "Endless runner! Arrow keys to switch lanes, SPACE to jump, DOWN to slide. Dodge obstacles!"
width   = 400
height  = 512
tags    = ["endless-runner", "arcade"]
+++

-- Lane Dash – a Subway Surfers inspired 3-lane endless runner

local STATE_RUN  = 0
local STATE_DEAD = 1

local state
local player
local obstacles
local coins
local score
local best
local speed
local spawn_timer
local coin_timer
local distance
local particles
local death_timer

-- lane setup
local LANE_COUNT = 3
local LANE_WIDTH = 90
local TOTAL_LANES_W = LANE_COUNT * LANE_WIDTH
local LANE_START_X  -- set in _init

-- player
local PLAYER_W = 40
local PLAYER_H = 60
local PLAYER_SLIDE_H = 25
local JUMP_VEL    = -500
local GRAVITY     = 1400
local LANE_LERP   = 12

-- obstacles
local OBS_TYPES = { "barrier", "tall", "low" }

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function lane_x(lane)
    return LANE_START_X + (lane - 1) * LANE_WIDTH + LANE_WIDTH / 2
end

function _init()
    local W = gfx.width()
    local H = gfx.height()
    LANE_START_X = (W - TOTAL_LANES_W) / 2

    player = {
        lane     = 2,
        x        = lane_x(2),
        y        = H - 100,
        vy       = 0,
        ground_y = H - 100,
        on_ground = true,
        sliding  = false,
        slide_time = 0,
        jumping  = false,
    }
    obstacles = {}
    coins = {}
    particles = {}
    score = 0
    best = best or 0
    speed = 300
    spawn_timer = 1.2
    coin_timer = 0.8
    distance = 0
    death_timer = 0
    state = STATE_RUN
end

local function spawn_obstacle()
    local lane = math.random(1, LANE_COUNT)
    local otype = OBS_TYPES[math.random(1, #OBS_TYPES)]
    local w, h, y_off = 60, 50, 0
    if otype == "tall" then
        h = 80
    elseif otype == "low" then
        h = 30
        y_off = 30  -- floating obstacle, can slide under
    end
    table.insert(obstacles, {
        lane  = lane,
        x     = lane_x(lane),
        y     = -h,
        w     = w,
        h     = h,
        y_off = y_off,
        otype = otype,
    })
end

local function spawn_coin()
    local lane = math.random(1, LANE_COUNT)
    table.insert(coins, {
        lane = lane,
        x    = lane_x(lane),
        y    = -20,
    })
end

local function add_particles(x, y, col, n)
    for i = 1, n do
        table.insert(particles, {
            x = x, y = y,
            vx = (math.random() - 0.5) * 250,
            vy = -math.random() * 200 - 50,
            life = 0.4 + math.random() * 0.3,
            col = col,
        })
    end
end

local function player_box()
    local pw = PLAYER_W
    local ph = player.sliding and PLAYER_SLIDE_H or PLAYER_H
    local py = player.y - ph
    if player.sliding then
        py = player.ground_y - PLAYER_SLIDE_H  -- slide stays on ground
    end
    return player.x - pw / 2, py, pw, ph
end

local function boxes_overlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

function _update(dt)
    local W = gfx.width()
    local H = gfx.height()

    if state == STATE_DEAD then
        death_timer = death_timer + dt
        -- update particles
        for i = #particles, 1, -1 do
            local p = particles[i]
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vy = p.vy + 500 * dt
            p.life = p.life - dt
            if p.life <= 0 then table.remove(particles, i) end
        end
        if death_timer > 1.5 and input.key_pressed(" ") then
            _init()
        end
        return
    end

    -- increase speed over time
    speed = 300 + distance * 0.15
    if speed > 700 then speed = 700 end
    distance = distance + speed * dt

    -- lane switching
    if input.key_pressed("arrowleft") or input.key_pressed("a") then
        player.lane = math.max(1, player.lane - 1)
    end
    if input.key_pressed("arrowright") or input.key_pressed("d") then
        player.lane = math.min(LANE_COUNT, player.lane + 1)
    end

    -- smooth lane movement
    local target_x = lane_x(player.lane)
    player.x = player.x + (target_x - player.x) * LANE_LERP * dt

    -- jump
    if (input.key_pressed("arrowup") or input.key_pressed("w") or input.key_pressed(" ")) and player.on_ground then
        player.vy = JUMP_VEL
        player.on_ground = false
        player.jumping = true
        player.sliding = false
    end

    -- slide
    if (input.key_pressed("arrowdown") or input.key_pressed("s")) and player.on_ground then
        player.sliding = true
        player.slide_time = 0
    end
    if player.sliding then
        player.slide_time = player.slide_time + dt
        if player.slide_time > 0.6 then
            player.sliding = false
        end
    end

    -- gravity
    if not player.on_ground then
        player.vy = player.vy + GRAVITY * dt
        player.y = player.y + player.vy * dt
        if player.y >= player.ground_y then
            player.y = player.ground_y
            player.vy = 0
            player.on_ground = true
            player.jumping = false
        end
    end

    -- spawn obstacles
    spawn_timer = spawn_timer - dt
    if spawn_timer <= 0 then
        spawn_obstacle()
        local interval = 1.2 - distance * 0.0003
        if interval < 0.5 then interval = 0.5 end
        spawn_timer = interval
    end

    -- spawn coins
    coin_timer = coin_timer - dt
    if coin_timer <= 0 then
        spawn_coin()
        coin_timer = 0.6 + math.random() * 0.5
    end

    -- move obstacles
    local px, py, pw, ph = player_box()
    for i = #obstacles, 1, -1 do
        local o = obstacles[i]
        o.y = o.y + speed * dt

        -- collision
        local ox = o.x - o.w / 2
        local oy = o.y + o.y_off
        if boxes_overlap(px, py, pw, ph, ox, oy, o.w, o.h) then
            state = STATE_DEAD
            death_timer = 0
            if score > best then best = score end
            add_particles(player.x, player.y - PLAYER_H / 2, "#ff4444", 15)
            return
        end

        if o.y > H + 20 then
            table.remove(obstacles, i)
        end
    end

    -- move coins
    for i = #coins, 1, -1 do
        local c = coins[i]
        c.y = c.y + speed * dt

        -- collect
        local dist = math.sqrt((player.x - c.x)^2 + ((player.y - PLAYER_H/2) - c.y)^2)
        if dist < 30 then
            score = score + 1
            add_particles(c.x, c.y, "#ffd700", 5)
            table.remove(coins, i)
        elseif c.y > H + 20 then
            table.remove(coins, i)
        end
    end

    -- update particles
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 500 * dt
        p.life = p.life - dt
        if p.life <= 0 then table.remove(particles, i) end
    end
end

-- drawing ----------------------------------------------------------------

local function draw_road()
    local W = gfx.width()
    local H = gfx.height()

    -- road background
    gfx.rect(LANE_START_X, 0, TOTAL_LANES_W, H, "#2a2a2a")

    -- lane dividers (dashed)
    for lane = 1, LANE_COUNT - 1 do
        local lx = LANE_START_X + lane * LANE_WIDTH
        local offset = (distance * 0.5) % 40
        local y = -40 + offset
        while y < H do
            gfx.rect(lx - 1, y, 2, 20, "#444444")
            y = y + 40
        end
    end

    -- road edges
    gfx.rect(LANE_START_X - 4, 0, 4, H, "#d4a574")
    gfx.rect(LANE_START_X + TOTAL_LANES_W, 0, 4, H, "#d4a574")
end

local function draw_player()
    local pw = PLAYER_W
    local ph = player.sliding and PLAYER_SLIDE_H or PLAYER_H
    local px = player.x - pw / 2
    local py = player.y - ph
    if player.sliding then
        py = player.ground_y - PLAYER_SLIDE_H
    end

    -- body
    gfx.rect(px, py, pw, ph, "#4a9eff")
    -- head
    if not player.sliding then
        gfx.circle(player.x, py + 10, 10, "#e8e4df")
    end
    -- cap
    if not player.sliding then
        gfx.rect(px + 5, py - 2, pw - 10, 6, "#d4a574")
    end
end

local function draw_obstacle(o)
    local cols = {
        barrier = "#cc3333",
        tall    = "#884422",
        low     = "#dd8833",
    }
    local col = cols[o.otype] or "#cc3333"
    local ox = o.x - o.w / 2
    local oy = o.y + o.y_off

    gfx.rect(ox, oy, o.w, o.h, col)
    gfx.rect_line(ox, oy, o.w, o.h, "#000000", 1)

    -- warning marks
    if o.otype == "barrier" then
        gfx.text("!", ox + o.w / 2 - 4, oy + o.h / 2 - 8, "#ffffff", 16)
    end
end

function _draw()
    local W = gfx.width()
    local H = gfx.height()

    -- background
    gfx.clear(18, 18, 24)

    -- side buildings (decorative)
    for i = 0, 8 do
        local by = (i * 60 + distance * 0.3) % (H + 60) - 60
        gfx.rect(5, by, 35, 50, "#1a1520")
        gfx.rect(W - 40, by + 20, 35, 50, "#1a1520")
        -- windows
        gfx.rect(12, by + 8, 6, 6, "#334455")
        gfx.rect(24, by + 8, 6, 6, "#334455")
        gfx.rect(W - 33, by + 28, 6, 6, "#334455")
        gfx.rect(W - 21, by + 28, 6, 6, "#334455")
    end

    draw_road()

    -- coins
    for _, c in ipairs(coins) do
        gfx.circle(c.x, c.y, 8, "#ffd700")
        gfx.circle(c.x, c.y, 5, "#ffaa00")
    end

    -- obstacles
    for _, o in ipairs(obstacles) do
        draw_obstacle(o)
    end

    -- player
    draw_player()

    -- particles
    for _, p in ipairs(particles) do
        gfx.circle(p.x, p.y, 3, p.col)
    end

    -- HUD
    gfx.text("Coins: " .. tostring(score), 16, 16, "#ffd700", 16)
    local dist_display = math.floor(distance / 10)
    gfx.text(tostring(dist_display) .. "m", W - 80, 16, "#e8e4df", 16)

    -- speed indicator
    local spd_pct = math.floor((speed - 300) / 4)
    gfx.text("SPD", W - 80, 38, "#8a847c", 10)
    gfx.rect(W - 52, 40, 40, 6, "#333333")
    gfx.rect(W - 52, 40, clamp(spd_pct * 0.4, 0, 40), 6, "#d4a574")

    -- death screen
    if state == STATE_DEAD then
        gfx.rect(0, 0, W, H, "rgba(0,0,0,0.65)")
        gfx.text("CRASHED!", W / 2 - 55, H / 2 - 50, "#ff4444", 24)
        gfx.text("Coins: " .. tostring(score), W / 2 - 50, H / 2 - 15, "#ffd700", 16)
        gfx.text("Distance: " .. tostring(dist_display) .. "m", W / 2 - 70, H / 2 + 10, "#e8e4df", 16)
        gfx.text("Best: " .. tostring(best) .. " coins", W / 2 - 65, H / 2 + 35, "#d4a574", 14)
        if death_timer > 1.5 then
            gfx.text("Press SPACE to retry", W / 2 - 85, H / 2 + 65, "#8a847c", 13)
        end
    end
end

+++
title   = "Pixel Quest"
slug    = "platformer"
date    = "2025-07-20"
summary = "Classic platformer. Arrow keys / WASD to move, SPACE to jump. Collect gems, reach the flag!"
width   = 512
height  = 384
tags    = ["platformer", "adventure"]
+++

-- Pixel Quest – a multi-level platformer

local STATE_PLAY = 0
local STATE_WIN  = 1
local STATE_DEAD = 2

local state
local player
local platforms
local gems
local spikes
local flag
local camera_y
local score
local total_gems
local level
local max_level
local particles
local death_timer
local win_timer

-- constants
local GRAVITY    = 900
local JUMP_VEL   = -380
local MOVE_SPEED = 180
local PLAYER_W   = 16
local PLAYER_H   = 24
local TILE       = 32

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function add_particles(x, y, col, n)
    for i = 1, n do
        table.insert(particles, {
            x = x, y = y,
            vx = (math.random() - 0.5) * 200,
            vy = -math.random() * 150 - 50,
            life = 0.3 + math.random() * 0.3,
            col = col,
        })
    end
end

local function boxes_overlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

-- level data: each level is a list of platform/gem/spike/flag definitions
-- coordinates are in tile units; y increases downward; level height varies

local function build_level(n)
    platforms = {}
    gems = {}
    spikes = {}
    flag = nil

    local W = gfx.width()

    if n == 1 then
        -- ground
        for x = 0, 15 do
            table.insert(platforms, { x = x * TILE, y = 11 * TILE, w = TILE, h = TILE })
        end
        -- platforms
        table.insert(platforms, { x = 3 * TILE, y = 9 * TILE, w = 3 * TILE, h = TILE })
        table.insert(platforms, { x = 8 * TILE, y = 7 * TILE, w = 3 * TILE, h = TILE })
        table.insert(platforms, { x = 1 * TILE, y = 5 * TILE, w = 3 * TILE, h = TILE })
        table.insert(platforms, { x = 6 * TILE, y = 4 * TILE, w = 2 * TILE, h = TILE })
        table.insert(platforms, { x = 11 * TILE, y = 5 * TILE, w = 3 * TILE, h = TILE })
        table.insert(platforms, { x = 12 * TILE, y = 9 * TILE, w = 2 * TILE, h = TILE })
        -- gems
        table.insert(gems, { x = 4 * TILE + 8, y = 8 * TILE, collected = false })
        table.insert(gems, { x = 9 * TILE + 8, y = 6 * TILE, collected = false })
        table.insert(gems, { x = 2 * TILE + 8, y = 4 * TILE, collected = false })
        table.insert(gems, { x = 12 * TILE + 8, y = 4 * TILE, collected = false })
        table.insert(gems, { x = 12 * TILE + 8, y = 8 * TILE, collected = false })
        -- spikes
        table.insert(spikes, { x = 6 * TILE, y = 10.5 * TILE, w = 2 * TILE, h = TILE * 0.5 })
        -- flag
        flag = { x = 13 * TILE, y = 4 * TILE }

    elseif n == 2 then
        -- ground with gaps
        for x = 0, 3 do
            table.insert(platforms, { x = x * TILE, y = 11 * TILE, w = TILE, h = TILE })
        end
        for x = 6, 9 do
            table.insert(platforms, { x = x * TILE, y = 11 * TILE, w = TILE, h = TILE })
        end
        for x = 12, 15 do
            table.insert(platforms, { x = x * TILE, y = 11 * TILE, w = TILE, h = TILE })
        end
        -- floating platforms
        table.insert(platforms, { x = 4 * TILE, y = 9 * TILE, w = 2 * TILE, h = TILE })
        table.insert(platforms, { x = 10 * TILE, y = 9 * TILE, w = 2 * TILE, h = TILE })
        table.insert(platforms, { x = 2 * TILE, y = 7 * TILE, w = 2 * TILE, h = TILE })
        table.insert(platforms, { x = 7 * TILE, y = 6 * TILE, w = 2 * TILE, h = TILE })
        table.insert(platforms, { x = 12 * TILE, y = 7 * TILE, w = 2 * TILE, h = TILE })
        table.insert(platforms, { x = 5 * TILE, y = 4 * TILE, w = 2 * TILE, h = TILE })
        table.insert(platforms, { x = 10 * TILE, y = 3 * TILE, w = 3 * TILE, h = TILE })
        -- gems
        table.insert(gems, { x = 4.5 * TILE, y = 8 * TILE, collected = false })
        table.insert(gems, { x = 10.5 * TILE, y = 8 * TILE, collected = false })
        table.insert(gems, { x = 3 * TILE, y = 6 * TILE, collected = false })
        table.insert(gems, { x = 7.5 * TILE, y = 5 * TILE, collected = false })
        table.insert(gems, { x = 5.5 * TILE, y = 3 * TILE, collected = false })
        table.insert(gems, { x = 11 * TILE, y = 2 * TILE, collected = false })
        -- spikes at bottom of gaps
        table.insert(spikes, { x = 4 * TILE, y = 11.5 * TILE, w = 2 * TILE, h = TILE * 0.5 })
        table.insert(spikes, { x = 10 * TILE, y = 11.5 * TILE, w = 2 * TILE, h = TILE * 0.5 })
        -- flag
        flag = { x = 11 * TILE, y = 2 * TILE }

    else
        -- level 3: tall climb
        -- scattered platforms going up
        table.insert(platforms, { x = 0, y = 11 * TILE, w = 16 * TILE, h = TILE })
        table.insert(platforms, { x = 2 * TILE, y = 9 * TILE, w = 3 * TILE, h = TILE })
        table.insert(platforms, { x = 7 * TILE, y = 8 * TILE, w = 2 * TILE, h = TILE })
        table.insert(platforms, { x = 12 * TILE, y = 9 * TILE, w = 2 * TILE, h = TILE })
        table.insert(platforms, { x = 10 * TILE, y = 6 * TILE, w = 3 * TILE, h = TILE })
        table.insert(platforms, { x = 5 * TILE, y = 5 * TILE, w = 3 * TILE, h = TILE })
        table.insert(platforms, { x = 1 * TILE, y = 4 * TILE, w = 2 * TILE, h = TILE })
        table.insert(platforms, { x = 8 * TILE, y = 3 * TILE, w = 2 * TILE, h = TILE })
        table.insert(platforms, { x = 13 * TILE, y = 4 * TILE, w = 2 * TILE, h = TILE })
        table.insert(platforms, { x = 4 * TILE, y = 2 * TILE, w = 2 * TILE, h = TILE })
        table.insert(platforms, { x = 11 * TILE, y = 1 * TILE, w = 3 * TILE, h = TILE })
        -- gems everywhere
        table.insert(gems, { x = 3 * TILE, y = 8 * TILE, collected = false })
        table.insert(gems, { x = 7.5 * TILE, y = 7 * TILE, collected = false })
        table.insert(gems, { x = 12.5 * TILE, y = 8 * TILE, collected = false })
        table.insert(gems, { x = 11 * TILE, y = 5 * TILE, collected = false })
        table.insert(gems, { x = 6 * TILE, y = 4 * TILE, collected = false })
        table.insert(gems, { x = 1.5 * TILE, y = 3 * TILE, collected = false })
        table.insert(gems, { x = 8.5 * TILE, y = 2 * TILE, collected = false })
        table.insert(gems, { x = 5 * TILE, y = 1 * TILE, collected = false })
        -- spikes
        table.insert(spikes, { x = 5 * TILE, y = 10.5 * TILE, w = 2 * TILE, h = TILE * 0.5 })
        table.insert(spikes, { x = 9 * TILE, y = 10.5 * TILE, w = TILE, h = TILE * 0.5 })
        -- flag
        flag = { x = 12 * TILE, y = 0 * TILE }
    end

    -- count total gems
    total_gems = #gems
end

function _init()
    level = 1
    max_level = 3
    score = 0
    particles = {}
    death_timer = 0
    win_timer = 0
    state = STATE_PLAY
    build_level(level)
    local H = gfx.height()
    player = {
        x  = 1 * TILE,
        y  = 10 * TILE,
        vx = 0,
        vy = 0,
        on_ground = false,
        facing = 1,
        walk_frame = 0,
    }
    camera_y = 0
end

local function start_level(n)
    build_level(n)
    local H = gfx.height()
    player.x = 1 * TILE
    player.y = 10 * TILE
    player.vx = 0
    player.vy = 0
    player.on_ground = false
    camera_y = 0
    state = STATE_PLAY
    particles = {}
end

function _update(dt)
    local W = gfx.width()
    local H = gfx.height()

    -- update particles
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 400 * dt
        p.life = p.life - dt
        if p.life <= 0 then table.remove(particles, i) end
    end

    if state == STATE_DEAD then
        death_timer = death_timer + dt
        if death_timer > 1.5 and input.key_pressed(" ") then
            start_level(level)
        end
        return
    end

    if state == STATE_WIN then
        win_timer = win_timer + dt
        if win_timer > 2 and input.key_pressed(" ") then
            if level < max_level then
                level = level + 1
                start_level(level)
            else
                _init()
            end
        end
        return
    end

    -- movement
    local moving = false
    if input.key("arrowleft") or input.key("a") then
        player.vx = -MOVE_SPEED
        player.facing = -1
        moving = true
    elseif input.key("arrowright") or input.key("d") then
        player.vx = MOVE_SPEED
        player.facing = 1
        moving = true
    else
        player.vx = 0
    end

    if moving and player.on_ground then
        player.walk_frame = player.walk_frame + dt * 10
    else
        player.walk_frame = 0
    end

    -- jump
    if (input.key_pressed(" ") or input.key_pressed("arrowup") or input.key_pressed("w")) and player.on_ground then
        player.vy = JUMP_VEL
        player.on_ground = false
        add_particles(player.x + PLAYER_W / 2, player.y + PLAYER_H, "#aaaaaa", 4)
    end

    -- gravity
    player.vy = player.vy + GRAVITY * dt

    -- move X
    player.x = player.x + player.vx * dt
    -- collide X with platforms
    for _, plat in ipairs(platforms) do
        if boxes_overlap(player.x, player.y, PLAYER_W, PLAYER_H, plat.x, plat.y, plat.w, plat.h) then
            if player.vx > 0 then
                player.x = plat.x - PLAYER_W
            elseif player.vx < 0 then
                player.x = plat.x + plat.w
            end
            player.vx = 0
        end
    end

    -- move Y
    player.y = player.y + player.vy * dt
    player.on_ground = false
    for _, plat in ipairs(platforms) do
        if boxes_overlap(player.x, player.y, PLAYER_W, PLAYER_H, plat.x, plat.y, plat.w, plat.h) then
            if player.vy > 0 then
                player.y = plat.y - PLAYER_H
                player.vy = 0
                player.on_ground = true
            elseif player.vy < 0 then
                player.y = plat.y + plat.h
                player.vy = 0
            end
        end
    end

    -- clamp to world
    player.x = clamp(player.x, 0, W - PLAYER_W)

    -- fell off bottom
    if player.y > 13 * TILE then
        state = STATE_DEAD
        death_timer = 0
        add_particles(player.x + PLAYER_W / 2, 12 * TILE, "#ff4444", 10)
        return
    end

    -- spike collision
    for _, s in ipairs(spikes) do
        if boxes_overlap(player.x, player.y, PLAYER_W, PLAYER_H, s.x, s.y, s.w, s.h) then
            state = STATE_DEAD
            death_timer = 0
            add_particles(player.x + PLAYER_W / 2, player.y + PLAYER_H / 2, "#ff4444", 12)
            return
        end
    end

    -- gem collection
    for _, g in ipairs(gems) do
        if not g.collected then
            local dist = math.sqrt((player.x + PLAYER_W/2 - g.x)^2 + (player.y + PLAYER_H/2 - g.y)^2)
            if dist < 20 then
                g.collected = true
                score = score + 1
                add_particles(g.x, g.y, "#44ddff", 6)
            end
        end
    end

    -- flag (level complete)
    if flag then
        local dist = math.sqrt((player.x + PLAYER_W/2 - flag.x)^2 + (player.y + PLAYER_H/2 - flag.y)^2)
        if dist < 24 then
            state = STATE_WIN
            win_timer = 0
            add_particles(flag.x, flag.y, "#ffd700", 15)
        end
    end

    -- camera (smooth follow vertically)
    local target_cam = player.y - H / 2
    target_cam = clamp(target_cam, -2 * TILE, 6 * TILE)
    camera_y = camera_y + (target_cam - camera_y) * 4 * dt
end

-- drawing ----------------------------------------------------------------

local function world_to_screen_y(wy)
    return wy - camera_y
end

function _draw()
    local W = gfx.width()
    local H = gfx.height()

    -- sky
    gfx.clear(18, 14, 28)

    -- stars (fixed background)
    math.randomseed(42)
    for i = 1, 30 do
        local sx = math.random() * W
        local sy = math.random() * H
        local brightness = math.random(40, 80)
        local col = "rgb(" .. brightness .. "," .. brightness .. "," .. (brightness + 20) .. ")"
        gfx.circle(sx, sy, 1, col)
    end
    math.randomseed(os.clock() * 1000)

    -- platforms
    for _, plat in ipairs(platforms) do
        local py = world_to_screen_y(plat.y)
        if py > -TILE and py < H + TILE then
            gfx.rect(plat.x, py, plat.w, plat.h, "#5a4a3a")
            -- top grass
            gfx.rect(plat.x, py, plat.w, 4, "#4a8a3a")
            -- edge detail
            gfx.rect_line(plat.x, py, plat.w, plat.h, "#3a3225", 1)
        end
    end

    -- spikes
    for _, s in ipairs(spikes) do
        local sy = world_to_screen_y(s.y)
        local spike_count = math.floor(s.w / 12)
        for i = 0, spike_count - 1 do
            local sx = s.x + i * 12 + 6
            -- triangle spike (draw as a narrow rect + top)
            gfx.rect(sx - 2, sy + 4, 4, s.h - 4, "#cc3333")
            gfx.rect(sx - 4, sy + 2, 8, 3, "#ee4444")
            gfx.rect(sx - 1, sy, 2, 3, "#ff6666")
        end
    end

    -- gems
    for _, g in ipairs(gems) do
        if not g.collected then
            local gy = world_to_screen_y(g.y)
            local bob = math.sin(os.clock() * 4 + g.x) * 3
            gfx.circle(g.x, gy + bob, 7, "#44ddff")
            gfx.circle(g.x - 2, gy + bob - 2, 3, "#aaeeff")
        end
    end

    -- flag
    if flag then
        local fy = world_to_screen_y(flag.y)
        -- pole
        gfx.rect(flag.x, fy, 3, 32, "#aaaaaa")
        -- flag cloth
        gfx.rect(flag.x + 3, fy, 20, 12, "#ffd700")
        gfx.rect(flag.x + 3, fy + 3, 17, 6, "#ffaa00")
    end

    -- player
    if state ~= STATE_DEAD then
        local px = player.x
        local py = world_to_screen_y(player.y)

        -- body
        gfx.rect(px, py + 6, PLAYER_W, PLAYER_H - 6, "#4a9eff")
        -- head
        gfx.circle(px + PLAYER_W / 2, py + 5, 7, "#e8e4df")
        -- eyes
        local eye_x = px + PLAYER_W / 2 + player.facing * 3
        gfx.circle(eye_x, py + 4, 2, "#222222")
        -- legs (animated)
        local leg_off = math.sin(player.walk_frame) * 4
        gfx.rect(px + 2, py + PLAYER_H, 5, 4 + leg_off, "#3a6ecc")
        gfx.rect(px + PLAYER_W - 7, py + PLAYER_H, 5, 4 - leg_off, "#3a6ecc")
    end

    -- particles
    for _, p in ipairs(particles) do
        local py = world_to_screen_y(p.y)
        gfx.circle(p.x, py, 3, p.col)
    end

    -- HUD
    gfx.rect(0, 0, W, 30, "rgba(0,0,0,0.6)")
    gfx.text("Gems: " .. tostring(score) .. "/" .. tostring(total_gems), 12, 8, "#44ddff", 14)
    gfx.text("Level " .. tostring(level) .. "/" .. tostring(max_level), W - 100, 8, "#d4a574", 14)

    -- death screen
    if state == STATE_DEAD then
        gfx.rect(0, 0, W, H, "rgba(0,0,0,0.6)")
        gfx.text("YOU DIED", W / 2 - 50, H / 2 - 20, "#ff4444", 24)
        if death_timer > 1.5 then
            gfx.text("Press SPACE to retry", W / 2 - 90, H / 2 + 15, "#8a847c", 13)
        end
    end

    -- win screen
    if state == STATE_WIN then
        gfx.rect(0, 0, W, H, "rgba(0,0,0,0.6)")
        if level < max_level then
            gfx.text("LEVEL COMPLETE!", W / 2 - 90, H / 2 - 20, "#ffd700", 24)
            if win_timer > 2 then
                gfx.text("Press SPACE for next level", W / 2 - 110, H / 2 + 15, "#8a847c", 13)
            end
        else
            gfx.text("YOU WIN!", W / 2 - 55, H / 2 - 30, "#ffd700", 28)
            gfx.text("All levels complete!", W / 2 - 80, H / 2 + 5, "#e8e4df", 16)
            gfx.text("Gems: " .. tostring(score), W / 2 - 40, H / 2 + 30, "#44ddff", 14)
            if win_timer > 2 then
                gfx.text("Press SPACE to play again", W / 2 - 105, H / 2 + 55, "#8a847c", 13)
            end
        end
    end
end

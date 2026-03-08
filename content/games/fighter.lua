+++
title   = "Street Brawl"
slug    = "fighter"
date    = "2025-07-10"
summary = "2D fighting game. P1: WASD + F/G to punch/kick. P2: Arrows + K/L. First to 0 HP loses."
width   = 512
height  = 384
tags    = ["fighting", "2-player"]
+++

-- Street Brawl – a simple 2-player fighting game

local STATE_FIGHT = 0
local STATE_KO    = 1

local state
local p1, p2
local particles
local round_timer
local ko_timer

-- helpers ----------------------------------------------------------------

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function make_fighter(x, facing, color, name)
    return {
        name   = name,
        x      = x,
        y      = 0,
        vy     = 0,
        facing = facing,   -- 1 = right, -1 = left
        color  = color,
        hp     = 100,
        max_hp = 100,
        w      = 40,
        h      = 80,
        speed  = 200,
        on_ground = true,
        -- attack state
        attacking   = false,
        attack_type = "",   -- "punch" or "kick"
        attack_time = 0,
        attack_dur  = 0.25,
        attack_hit  = false,
        -- hitstun
        stunned     = false,
        stun_time   = 0,
        stun_dur    = 0.3,
        -- blocking
        blocking    = false,
    }
end

local function spawn_particles(x, y, col, n)
    for i = 1, n do
        table.insert(particles, {
            x  = x, y = y,
            vx = (math.random() - 0.5) * 300,
            vy = -math.random() * 200 - 50,
            life = 0.3 + math.random() * 0.3,
            col = col,
        })
    end
end

-- game flow --------------------------------------------------------------

function _init()
    local W = gfx.width()
    p1 = make_fighter(80,  1, "#4a9eff", "P1")
    p2 = make_fighter(W - 120, -1, "#ff4a4a", "P2")
    particles = {}
    state = STATE_FIGHT
    round_timer = 60
    ko_timer = 0
end

local function attack(fighter, a_type)
    if fighter.attacking or fighter.stunned then return end
    fighter.attacking   = true
    fighter.attack_type = a_type
    fighter.attack_time = 0
    fighter.attack_hit  = false
    fighter.attack_dur  = a_type == "punch" and 0.2 or 0.3
end

local function get_attack_box(f)
    local reach = f.attack_type == "punch" and 35 or 45
    local bx = f.facing == 1 and (f.x + f.w) or (f.x - reach)
    local by = f.attack_type == "punch" and (f.y + 15) or (f.y + 45)
    local bh = f.attack_type == "punch" and 20 or 25
    return bx, by, reach, bh
end

local function boxes_overlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

local function handle_attack(attacker, defender, dt)
    if not attacker.attacking then return end
    attacker.attack_time = attacker.attack_time + dt

    -- check hit on the right frame
    if attacker.attack_time > 0.08 and not attacker.attack_hit then
        local ax, ay, aw, ah = get_attack_box(attacker)
        if boxes_overlap(ax, ay, aw, ah, defender.x, defender.y, defender.w, defender.h) then
            attacker.attack_hit = true
            if defender.blocking then
                local dmg = 2
                defender.hp = math.max(0, defender.hp - dmg)
                spawn_particles(defender.x + defender.w / 2, defender.y + 30, "#aaaaaa", 3)
            else
                local dmg = attacker.attack_type == "punch" and 8 or 12
                defender.hp = math.max(0, defender.hp - dmg)
                defender.stunned   = true
                defender.stun_time = 0
                -- knockback
                defender.x = defender.x + attacker.facing * 30
                spawn_particles(defender.x + defender.w / 2, ay + ah / 2, "#ffcc00", 6)
            end
        end
    end

    if attacker.attack_time >= attacker.attack_dur then
        attacker.attacking = false
    end
end

local GRAVITY  = 900
local JUMP_VEL = -400
local GROUND_Y_OFFSET = 60  -- ground is H - offset

local function update_fighter(f, dt, up_key, left_key, right_key, down_key, punch_key, kick_key)
    local W = gfx.width()
    local H = gfx.height()
    local ground = H - GROUND_Y_OFFSET

    -- stun
    if f.stunned then
        f.stun_time = f.stun_time + dt
        if f.stun_time >= f.stun_dur then f.stunned = false end
        -- still apply gravity while stunned
        if not f.on_ground then
            f.vy = f.vy + GRAVITY * dt
            f.y  = f.y + f.vy * dt
            if f.y + f.h >= ground then
                f.y = ground - f.h
                f.vy = 0
                f.on_ground = true
            end
        end
        return
    end

    -- blocking (hold down)
    f.blocking = input.key(down_key) and f.on_ground and not f.attacking

    -- movement
    if not f.attacking or not f.on_ground then
        if input.key(left_key) then  f.x = f.x - f.speed * dt end
        if input.key(right_key) then f.x = f.x + f.speed * dt end
    end

    -- jump
    if input.key_pressed(up_key) and f.on_ground then
        f.vy = JUMP_VEL
        f.on_ground = false
    end

    -- gravity
    if not f.on_ground then
        f.vy = f.vy + GRAVITY * dt
        f.y  = f.y + f.vy * dt
        if f.y + f.h >= ground then
            f.y = ground - f.h
            f.vy = 0
            f.on_ground = true
        end
    end

    -- clamp to screen
    f.x = clamp(f.x, 0, W - f.w)
    f.y = clamp(f.y, 0, ground - f.h)

    -- attacks
    if input.key_pressed(punch_key) then attack(f, "punch") end
    if input.key_pressed(kick_key)  then attack(f, "kick")  end
end

function _update(dt)
    local W = gfx.width()

    if state == STATE_KO then
        ko_timer = ko_timer + dt
        if ko_timer > 3 and input.key_pressed(" ") then _init() end
        -- update particles
        for i = #particles, 1, -1 do
            local p = particles[i]
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vy = p.vy + 400 * dt
            p.life = p.life - dt
            if p.life <= 0 then table.remove(particles, i) end
        end
        return
    end

    -- update round timer
    round_timer = round_timer - dt
    if round_timer <= 0 then round_timer = 0 end

    -- update fighters
    update_fighter(p1, dt, "w", "a", "d", "s", "f", "g")
    update_fighter(p2, dt, "arrowup", "arrowleft", "arrowright", "arrowdown", "k", "l")

    -- face each other
    if p1.x < p2.x then
        p1.facing = 1; p2.facing = -1
    else
        p1.facing = -1; p2.facing = 1
    end

    -- handle attacks
    handle_attack(p1, p2, dt)
    handle_attack(p2, p1, dt)

    -- update particles
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 400 * dt
        p.life = p.life - dt
        if p.life <= 0 then table.remove(particles, i) end
    end

    -- check KO
    if p1.hp <= 0 or p2.hp <= 0 or round_timer <= 0 then
        state = STATE_KO
        ko_timer = 0
    end
end

-- drawing ----------------------------------------------------------------

local function draw_hp_bar(x, y, w, h, hp, max_hp, col)
    gfx.rect(x, y, w, h, "#222222")
    local fill = (hp / max_hp) * (w - 4)
    gfx.rect(x + 2, y + 2, fill, h - 4, col)
    gfx.rect_line(x, y, w, h, "#555555", 1)
end

local function draw_fighter(f)
    local shade = f.stunned and "#888888" or f.color

    -- body
    if f.blocking then
        -- crouching block pose
        gfx.rect(f.x + 5, f.y + 25, f.w - 10, f.h - 25, shade)
        -- shield
        local sx = f.facing == 1 and (f.x + f.w - 8) or (f.x - 4)
        gfx.rect(sx, f.y + 20, 12, 40, "#aaaaaa")
    else
        -- torso
        gfx.rect(f.x + 8, f.y + 20, f.w - 16, 35, shade)
        -- legs
        gfx.rect(f.x + 10, f.y + 55, 8, 25, shade)
        gfx.rect(f.x + f.w - 18, f.y + 55, 8, 25, shade)
    end

    -- head
    gfx.circle(f.x + f.w / 2, f.y + 12, 12, shade)

    -- attacking arm / leg
    if f.attacking then
        local ax, ay, aw, ah = get_attack_box(f)
        local acol = f.attack_type == "punch" and "#ffdd44" or "#ff8800"
        gfx.rect(ax, ay, aw, ah, acol)
    end
end

function _draw()
    local W = gfx.width()
    local H = gfx.height()
    local ground = H - GROUND_Y_OFFSET

    -- sky
    gfx.clear(15, 12, 20)

    -- ground
    gfx.rect(0, ground, W, GROUND_Y_OFFSET, "#1a1714")
    gfx.line(0, ground, W, ground, "#2a2725", 2)

    -- HP bars
    draw_hp_bar(16, 16, 180, 18, p1.hp, p1.max_hp, "#4a9eff")
    draw_hp_bar(W - 196, 16, 180, 18, p2.hp, p2.max_hp, "#ff4a4a")

    -- labels
    gfx.text("P1", 16, 38, "#4a9eff", 14)
    gfx.text("P2", W - 40, 38, "#ff4a4a", 14)

    -- timer
    local t_str = tostring(math.floor(round_timer))
    gfx.text(t_str, W / 2 - 8, 16, "#e8e4df", 24)

    -- fighters
    draw_fighter(p1)
    draw_fighter(p2)

    -- particles
    for _, p in ipairs(particles) do
        local a = clamp(p.life / 0.3, 0, 1)
        gfx.circle(p.x, p.y, 3, p.col)
    end

    -- KO screen
    if state == STATE_KO then
        gfx.rect(0, 0, W, H, "rgba(0,0,0,0.6)")
        local winner = ""
        if p1.hp <= 0 and p2.hp <= 0 then
            winner = "DRAW!"
        elseif p1.hp <= 0 then
            winner = "P2 WINS!"
        elseif p2.hp <= 0 then
            winner = "P1 WINS!"
        else
            -- time out: higher HP wins
            if p1.hp > p2.hp then
                winner = "P1 WINS!"
            elseif p2.hp > p1.hp then
                winner = "P2 WINS!"
            else
                winner = "DRAW!"
            end
        end
        gfx.text(winner, W / 2 - 60, H / 2 - 20, "#d4a574", 32)
        if ko_timer > 3 then
            gfx.text("Press SPACE to restart", W / 2 - 110, H / 2 + 24, "#8a847c", 14)
        end
    end

    -- controls hint
    if state == STATE_FIGHT then
        gfx.text("P1: WASD + F/G", 16, H - 18, "#555555", 10)
        gfx.text("P2: Arrows + K/L", W - 140, H - 18, "#555555", 10)
    end
end

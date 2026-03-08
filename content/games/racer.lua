+++
title   = "Night Racer"
slug    = "racer"
date    = "2025-07-18"
summary = "Top-down racing. Arrow keys or WASD to steer and accelerate. Dodge traffic, chase the high score."
width   = 400
height  = 512
tags    = ["racing", "arcade"]
+++

-- Night Racer – top-down arcade racing with traffic

local STATE_RACE = 0
local STATE_DEAD = 1

local state
local car
local traffic
local road_marks
local score
local best
local speed
local max_speed
local death_timer
local particles
local scenery

-- tunables
local ROAD_LEFT   = 60
local ROAD_RIGHT  = 340
local ROAD_W      = 280
local LANE_COUNT  = 4
local LANE_W      = 70  -- ROAD_W / LANE_COUNT
local CAR_W       = 32
local CAR_H       = 56
local ACCEL       = 200
local DECEL       = 150
local STEER_SPEED = 250
local TRAFFIC_MIN_SPEED = 100
local TRAFFIC_MAX_SPEED = 200

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function lane_center(lane)
    return ROAD_LEFT + (lane - 0.5) * LANE_W
end

function _init()
    local W = gfx.width()
    local H = gfx.height()

    car = {
        x = W / 2,
        y = H - 100,
        vx = 0,
    }
    traffic = {}
    road_marks = {}
    particles = {}
    scenery = {}
    score = 0
    best = best or 0
    speed = 150
    max_speed = 400
    death_timer = 0
    state = STATE_RACE

    -- pre-populate road markings
    for i = 0, 20 do
        table.insert(road_marks, { y = i * 40 })
    end

    -- pre-populate scenery
    for i = 0, 15 do
        table.insert(scenery, {
            side = math.random() > 0.5 and 1 or -1,
            y = math.random() * H,
            kind = math.random(1, 3),
        })
    end
end

local function spawn_traffic()
    local lane = math.random(1, LANE_COUNT)
    local cols = { "#cc4444", "#4488cc", "#44aa44", "#ccaa44", "#aa44cc", "#ffffff" }
    local col = cols[math.random(1, #cols)]
    local t_speed = TRAFFIC_MIN_SPEED + math.random() * (TRAFFIC_MAX_SPEED - TRAFFIC_MIN_SPEED)
    table.insert(traffic, {
        x = lane_center(lane),
        y = -CAR_H,
        w = CAR_W,
        h = CAR_H,
        speed = t_speed,
        col = col,
    })
end

local function add_particles(x, y, col, n)
    for i = 1, n do
        table.insert(particles, {
            x = x, y = y,
            vx = (math.random() - 0.5) * 300,
            vy = (math.random() - 0.5) * 300,
            life = 0.3 + math.random() * 0.4,
            col = col,
        })
    end
end

local function boxes_overlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

local spawn_timer = 0

function _update(dt)
    local W = gfx.width()
    local H = gfx.height()

    if state == STATE_DEAD then
        death_timer = death_timer + dt
        -- slow particles
        for i = #particles, 1, -1 do
            local p = particles[i]
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.life = p.life - dt
            if p.life <= 0 then table.remove(particles, i) end
        end
        if death_timer > 1.5 and input.key_pressed(" ") then
            _init()
        end
        return
    end

    -- accelerate / brake
    if input.key("arrowup") or input.key("w") then
        speed = speed + ACCEL * dt
    elseif input.key("arrowdown") or input.key("s") then
        speed = speed - DECEL * dt
    end
    -- natural speed increase over time
    max_speed = 400 + score * 0.5
    if max_speed > 800 then max_speed = 800 end
    speed = clamp(speed, 80, max_speed)

    -- steer
    if input.key("arrowleft") or input.key("a") then
        car.x = car.x - STEER_SPEED * dt
    end
    if input.key("arrowright") or input.key("d") then
        car.x = car.x + STEER_SPEED * dt
    end

    -- clamp to road
    car.x = clamp(car.x, ROAD_LEFT + CAR_W / 2 + 4, ROAD_RIGHT - CAR_W / 2 - 4)

    -- road markings scroll
    for _, m in ipairs(road_marks) do
        m.y = m.y + speed * dt
        if m.y > H + 40 then
            m.y = m.y - (21 * 40)
        end
    end

    -- scenery scroll
    for _, s in ipairs(scenery) do
        s.y = s.y + speed * 0.6 * dt
        if s.y > H + 40 then
            s.y = s.y - H - 80
            s.kind = math.random(1, 3)
        end
    end

    -- spawn traffic
    spawn_timer = spawn_timer - dt
    if spawn_timer <= 0 then
        spawn_traffic()
        local interval = 1.0 - speed * 0.001
        if interval < 0.3 then interval = 0.3 end
        spawn_timer = interval
    end

    -- move traffic
    local car_left  = car.x - CAR_W / 2
    local car_top   = car.y - CAR_H / 2
    for i = #traffic, 1, -1 do
        local t = traffic[i]
        -- traffic moves down relative to player (player speed - traffic speed)
        t.y = t.y + (speed - t.speed) * dt

        -- collision
        local tx = t.x - t.w / 2
        local ty = t.y - t.h / 2
        if boxes_overlap(car_left, car_top, CAR_W, CAR_H, tx, ty, t.w, t.h) then
            state = STATE_DEAD
            death_timer = 0
            if score > best then best = score end
            add_particles(car.x, car.y, "#ff8800", 20)
            add_particles(car.x, car.y, "#ffcc00", 10)
            return
        end

        -- remove offscreen
        if t.y > H + 100 or t.y < -200 then
            if t.y > H + 50 then
                score = score + 1
            end
            table.remove(traffic, i)
        end
    end

    -- road edge collision
    if car.x - CAR_W / 2 <= ROAD_LEFT + 2 or car.x + CAR_W / 2 >= ROAD_RIGHT - 2 then
        -- scraping the edge - sparks!
        add_particles(
            car.x < W / 2 and (car.x - CAR_W / 2) or (car.x + CAR_W / 2),
            car.y + CAR_H / 2 - 5,
            "#ffaa00", 2
        )
    end

    -- update particles
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        if p.life <= 0 then table.remove(particles, i) end
    end

    -- score based on distance
    -- (score incremented when traffic passes)
end

-- drawing ----------------------------------------------------------------

local function draw_car_shape(x, y, w, h, col, is_player)
    -- body
    gfx.rect(x - w/2, y - h/2, w, h, col)
    -- windshield
    local ws_col = is_player and "#88ccff" or "#aaddff"
    gfx.rect(x - w/2 + 4, y - h/2 + 6, w - 8, 14, ws_col)
    -- rear window
    gfx.rect(x - w/2 + 4, y + h/2 - 16, w - 8, 10, ws_col)

    if is_player then
        -- headlights
        gfx.rect(x - w/2 + 2, y - h/2 - 3, 8, 4, "#ffffaa")
        gfx.rect(x + w/2 - 10, y - h/2 - 3, 8, 4, "#ffffaa")
        -- tail lights
        gfx.rect(x - w/2 + 2, y + h/2, 8, 3, "#ff2222")
        gfx.rect(x + w/2 - 10, y + h/2, 8, 3, "#ff2222")
    end
end

function _draw()
    local W = gfx.width()
    local H = gfx.height()

    -- background (grass / dark ground)
    gfx.clear(12, 18, 12)

    -- scenery (trees, posts)
    for _, s in ipairs(scenery) do
        local sx = s.side == 1 and (ROAD_RIGHT + 15 + s.kind * 8) or (ROAD_LEFT - 15 - s.kind * 8)
        if s.kind == 1 then
            -- tree
            gfx.rect(sx - 3, s.y - 5, 6, 18, "#3a2a1a")
            gfx.circle(sx, s.y - 12, 10, "#1a4a1a")
        elseif s.kind == 2 then
            -- post
            gfx.rect(sx - 2, s.y - 10, 4, 20, "#555555")
            gfx.circle(sx, s.y - 12, 4, "#dddd44")
        else
            -- bush
            gfx.circle(sx, s.y, 8, "#1a3a1a")
        end
    end

    -- road surface
    gfx.rect(ROAD_LEFT, 0, ROAD_W, H, "#2a2a2a")

    -- road edges
    gfx.rect(ROAD_LEFT, 0, 3, H, "#dddddd")
    gfx.rect(ROAD_RIGHT - 3, 0, 3, H, "#dddddd")

    -- lane markings (dashed)
    for lane = 1, LANE_COUNT - 1 do
        local lx = ROAD_LEFT + lane * LANE_W
        for _, m in ipairs(road_marks) do
            gfx.rect(lx - 1, m.y, 2, 20, "#555555")
        end
    end

    -- traffic
    for _, t in ipairs(traffic) do
        draw_car_shape(t.x, t.y, t.w, t.h, t.col, false)
    end

    -- player car
    if state == STATE_RACE then
        draw_car_shape(car.x, car.y, CAR_W, CAR_H, "#4a9eff", true)
    end

    -- particles
    for _, p in ipairs(particles) do
        gfx.circle(p.x, p.y, 3, p.col)
    end

    -- HUD
    gfx.rect(0, 0, W, 40, "rgba(0,0,0,0.5)")
    gfx.text("Score: " .. tostring(score), 16, 12, "#e8e4df", 16)

    local spd_display = math.floor(speed)
    gfx.text(tostring(spd_display) .. " km/h", W - 110, 12, "#d4a574", 16)

    -- speed bar
    local bar_w = 80
    local bar_fill = (speed - 80) / (max_speed - 80) * bar_w
    gfx.rect(W / 2 - bar_w / 2, 28, bar_w, 5, "#333333")
    gfx.rect(W / 2 - bar_w / 2, 28, clamp(bar_fill, 0, bar_w), 5, "#44cc44")

    -- death screen
    if state == STATE_DEAD then
        gfx.rect(0, 0, W, H, "rgba(0,0,0,0.65)")

        gfx.text("WRECKED!", W / 2 - 60, H / 2 - 50, "#ff4444", 24)
        gfx.text("Score: " .. tostring(score), W / 2 - 50, H / 2 - 10, "#e8e4df", 18)
        gfx.text("Best: " .. tostring(best), W / 2 - 40, H / 2 + 18, "#d4a574", 16)

        if death_timer > 1.5 then
            gfx.text("Press SPACE to retry", W / 2 - 88, H / 2 + 55, "#8a847c", 13)
        end
    end
end

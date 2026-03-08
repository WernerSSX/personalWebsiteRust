+++
title   = "Horse Derby"
slug    = "horses"
date    = "2025-08-05"
summary = "Uma Uma Kitchen"
width   = 512
height  = 420
tags    = ["racing", "casino"]
+++

local STATE_BET    = 0
local STATE_RACE   = 1
local STATE_FINISH = 2

local NUM_HORSES = 6
local TRACK_X    = 60
local TRACK_H    = 42
local TRACK_GAP  = 6
local FINISH_X   = 470

local HORSE_NAMES  = { "Thunder", "Blaze", "Shadow", "Storm", "Spirit", "Flash" }
local HORSE_COLORS = { "#ff4444", "#44aaff", "#44cc44", "#ffaa00", "#cc44cc", "#ff8866" }
local JOCKEY_COLORS = { "#ffffff", "#ffff00", "#00ff00", "#ff00ff", "#00ffff", "#ff8800" }

local horses
local state
local chips
local bet
local pick       -- which horse (1-6)
local winner
local finish_order
local result_timer
local race_time
local crowd_anim

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function track_y(i)
    local total_h = NUM_HORSES * TRACK_H + (NUM_HORSES - 1) * TRACK_GAP
    local start_y = 120
    return start_y + (i - 1) * (TRACK_H + TRACK_GAP)
end

function _init()
    chips = 100
    bet = 0
    pick = 0
    state = STATE_BET
    winner = 0
    finish_order = {}
    result_timer = 0
    race_time = 0
    crowd_anim = 0

    horses = {}
    for i = 1, NUM_HORSES do
        table.insert(horses, {
            x = TRACK_X + 10,
            speed = 0,
            base_speed = 80 + math.random() * 40,
            energy = 1.0,
            finished = false,
            finish_pos = 0,
            bob = math.random() * 6.28,
            name = HORSE_NAMES[i],
            color = HORSE_COLORS[i],
            jockey_color = JOCKEY_COLORS[i],
        })
    end
end

local function start_race()
    for i, h in ipairs(horses) do
        h.x = TRACK_X + 10
        h.speed = 0
        h.base_speed = 80 + math.random() * 40
        h.energy = 0.8 + math.random() * 0.4
        h.finished = false
        h.finish_pos = 0
        h.bob = math.random() * 6.28
    end
    winner = 0
    finish_order = {}
    race_time = 0
    state = STATE_RACE
end

function _update(dt)
    crowd_anim = crowd_anim + dt

    if state == STATE_BET then
        if chips <= 0 then
            if input.key_pressed(" ") then
                chips = 100
            end
            return
        end

        -- pick horse with 1-6
        for i = 1, NUM_HORSES do
            if input.key_pressed(tostring(i)) then
                pick = i
            end
        end

        -- click to pick
        if input.mouse_down(0) then
            local mx = input.mouse_x()
            local my = input.mouse_y()
            for i = 1, NUM_HORSES do
                local ty = track_y(i)
                if my >= ty and my <= ty + TRACK_H and mx >= TRACK_X and mx <= FINISH_X then
                    pick = i
                end
            end
        end

        -- bet amount
        if input.key_pressed("arrowup") or input.key_pressed("w") then
            bet = bet + 5
        end
        if input.key_pressed("arrowdown") or input.key_pressed("s") then
            bet = bet - 5
        end
        if bet < 5 then bet = 5 end
        if bet > chips then bet = chips end

        -- start race
        if pick > 0 and bet > 0 and input.key_pressed(" ") then
            chips = chips - bet
            start_race()
        end
        return
    end

    if state == STATE_RACE then
        race_time = race_time + dt

        local all_done = true
        for i, h in ipairs(horses) do
            if not h.finished then
                all_done = false

                -- vary speed with randomness
                local burst = math.sin(race_time * (2 + i * 0.3) + h.bob) * 30
                local random_kick = (math.random() - 0.5) * 60
                h.speed = h.base_speed * h.energy + burst + random_kick

                -- energy changes
                h.energy = h.energy + (math.random() - 0.48) * dt * 0.5
                h.energy = clamp(h.energy, 0.5, 1.5)

                -- final stretch boost
                if h.x > FINISH_X - 80 then
                    h.speed = h.speed + math.random() * 40
                end

                h.x = h.x + h.speed * dt
                h.bob = h.bob + h.speed * dt * 0.1

                if h.x >= FINISH_X then
                    h.x = FINISH_X
                    h.finished = true
                    table.insert(finish_order, i)
                    h.finish_pos = #finish_order
                    if #finish_order == 1 then
                        winner = i
                    end
                end
            end
        end

        if all_done then
            state = STATE_FINISH
            result_timer = 0

            -- pay out
            if winner == pick then
                local payout = bet * NUM_HORSES
                chips = chips + payout
            end
        end
        return
    end

    if state == STATE_FINISH then
        result_timer = result_timer + dt
        if result_timer > 2 and input.key_pressed(" ") then
            bet = 0
            pick = 0
            state = STATE_BET
        end
        return
    end
end

-- drawing ----------------------------------------------------------------

local function draw_horse(h, ty)
    local hx = h.x
    local bob_y = math.sin(h.bob) * 3
    local body_y = ty + TRACK_H / 2 + bob_y

    -- legs (animated)
    local leg_phase = h.bob
    local leg1 = math.sin(leg_phase) * 5
    local leg2 = math.sin(leg_phase + 3.14) * 5

    gfx.line(hx - 6, body_y + 4, hx - 6 + leg1, body_y + 14, h.color, 2)
    gfx.line(hx - 2, body_y + 4, hx - 2 + leg2, body_y + 14, h.color, 2)
    gfx.line(hx + 6, body_y + 4, hx + 6 + leg1, body_y + 14, h.color, 2)
    gfx.line(hx + 10, body_y + 4, hx + 10 + leg2, body_y + 14, h.color, 2)

    -- body
    gfx.rect(hx - 10, body_y - 6, 24, 12, h.color)

    -- head
    gfx.rect(hx + 14, body_y - 10, 8, 10, h.color)
    -- ear
    gfx.rect(hx + 16, body_y - 14, 3, 5, h.color)

    -- eye
    gfx.circle(hx + 19, body_y - 7, 1, "#000000")

    -- tail
    local tail_swing = math.sin(h.bob * 2) * 4
    gfx.line(hx - 10, body_y - 2, hx - 18, body_y - 6 + tail_swing, h.color, 2)

    -- jockey
    gfx.circle(hx + 2, body_y - 12, 5, h.jockey_color)
    gfx.rect(hx - 2, body_y - 9, 8, 4, h.jockey_color)
end

function _draw()
    local W = gfx.width()
    local H = gfx.height()

    gfx.clear(22, 18, 14)

    -- title
    gfx.text("HORSE DERBY", W / 2 - 65, 8, "#d4a574", 20)
    gfx.text("Chips: " .. tostring(chips), 16, 10, "#ffd700", 14)

    -- tracks
    for i = 1, NUM_HORSES do
        local ty = track_y(i)

        -- track background (alternating shades)
        local bg = (i % 2 == 0) and "#2a2620" or "#24201c"
        gfx.rect(TRACK_X, ty, FINISH_X - TRACK_X, TRACK_H, bg)

        -- track borders
        gfx.line(TRACK_X, ty, FINISH_X, ty, "#3a3530", 1)
        gfx.line(TRACK_X, ty + TRACK_H, FINISH_X, ty + TRACK_H, "#3a3530", 1)

        -- lane number + name
        local label_col = "#8a847c"
        if state == STATE_BET and pick == i then label_col = "#ffd700" end
        gfx.text(tostring(i), 16, ty + TRACK_H / 2 - 6, HORSE_COLORS[i], 14)
        gfx.text(HORSE_NAMES[i], 26, ty + TRACK_H / 2 - 5, label_col, 10)

        -- horse
        draw_horse(horses[i], ty)

        -- finish position
        if horses[i].finish_pos > 0 then
            local pos_str = "#" .. tostring(horses[i].finish_pos)
            gfx.text(pos_str, FINISH_X + 6, ty + TRACK_H / 2 - 6, "#e8e4df", 12)
        end
    end

    -- start line
    gfx.line(TRACK_X + 10, track_y(1), TRACK_X + 10, track_y(NUM_HORSES) + TRACK_H, "#ffffff", 1)

    -- finish line (checkered pattern)
    for i = 1, NUM_HORSES do
        local ty = track_y(i)
        for row = 0, TRACK_H - 4, 4 do
            for col = 0, 6, 4 do
                local black = ((row / 4 + col / 4) % 2 == 0)
                local fc = black and "#000000" or "#ffffff"
                gfx.rect(FINISH_X - 2 + col, ty + row, 4, 4, fc)
            end
        end
    end

    -- crowd (animated dots at top)
    local crowd_y = 92
    math.randomseed(1234)
    for i = 0, 30 do
        local cx = 70 + i * 13
        local cy = crowd_y + math.sin(crowd_anim * 3 + i * 0.7) * 3
        local cc = math.random() > 0.5 and "#aaaaaa" or "#888888"
        gfx.circle(cx, cy, 4, cc)
        gfx.circle(cx, cy - 6, 3, "#e8c8a0")
    end
    math.randomseed(1000)

    -- bet UI
    if state == STATE_BET then
        local by = H - 70

        if chips <= 0 then
            gfx.text("BROKE! Press SPACE to rebuy", W / 2 - 120, H / 2, "#ff4444", 16)
            return
        end

        -- pick info
        if pick > 0 then
            gfx.text("Your horse: " .. HORSE_NAMES[pick], 16, by, HORSE_COLORS[pick], 14)
        else
            gfx.text("Press 1-6 or click to pick a horse", 16, by, "#8a847c", 13)
        end

        -- bet
        gfx.text("Bet: $" .. tostring(bet), 16, by + 20, "#ffd700", 14)
        gfx.text("UP/DOWN to change", 120, by + 20, "#555555", 10)

        if pick > 0 and bet > 0 then
            gfx.text("Press SPACE to race!", W / 2 - 75, by + 44, "#e8e4df", 14)
        end

        -- odds info
        gfx.text("Win pays " .. tostring(NUM_HORSES) .. "x", W - 120, by, "#d4a574", 12)
    end

    -- race timer
    if state == STATE_RACE then
        local t_str = string.format("%.1fs", race_time)
        gfx.text(t_str, W / 2 - 15, H - 30, "#e8e4df", 14)
    end

    -- results
    if state == STATE_FINISH then
        gfx.rect(W / 2 - 150, 40, 300, 50, "rgba(0,0,0,0.85)")
        gfx.rect_line(W / 2 - 150, 40, 300, 50, "#d4a574", 2)

        local win_name = HORSE_NAMES[winner]
        gfx.text(win_name .. " WINS!", W / 2 - 65, 46, HORSE_COLORS[winner], 20)

        if winner == pick then
            local payout = bet * NUM_HORSES
            gfx.text("You won $" .. tostring(payout) .. "!", W / 2 - 55, 68, "#ffd700", 14)
        else
            gfx.text("You lost $" .. tostring(bet), W / 2 - 50, 68, "#ff6666", 14)
        end

        if result_timer > 2 then
            gfx.text("Press SPACE for next race", W / 2 - 100, H - 25, "#8a847c", 13)
        end
    end
end

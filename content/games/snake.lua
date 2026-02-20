+++
title  = "Snake"
slug   = "snake"
date   = "2025-07-05"
summary = "Eat the fruit, grow longer, don't crash. Arrow keys or WASD."
width  = 480
height = 480
tags   = ["arcade", "classic"]
+++

local W, H, TILE
local snake, dir, next_dir
local food
local score, high_score
local dead, timer, TICK

function _init()
    W = gfx.width()
    H = gfx.height()
    TILE = 20
    TICK = 0.1

    high_score = high_score or 0
    score  = 0
    dead   = false
    timer  = 0

    local cx = math.floor(W / TILE / 2)
    local cy = math.floor(H / TILE / 2)
    snake = { {x=cx, y=cy}, {x=cx-1, y=cy}, {x=cx-2, y=cy} }
    dir      = "right"
    next_dir = "right"

    place_food()
end

function place_food()
    local cols = math.floor(W / TILE)
    local rows = math.floor(H / TILE)
    while true do
        food = { x = math.random(0, cols-1), y = math.random(0, rows-1) }
        local ok = true
        for _, s in ipairs(snake) do
            if s.x == food.x and s.y == food.y then ok = false; break end
        end
        if ok then return end
    end
end

function _update(dt)
    if dead then
        if input.key_pressed(" ") then _init() end
        return
    end

    if (input.key_pressed("arrowup")    or input.key_pressed("w")) and dir ~= "down"  then next_dir = "up"    end
    if (input.key_pressed("arrowdown")  or input.key_pressed("s")) and dir ~= "up"    then next_dir = "down"  end
    if (input.key_pressed("arrowleft")  or input.key_pressed("a")) and dir ~= "right" then next_dir = "left"  end
    if (input.key_pressed("arrowright") or input.key_pressed("d")) and dir ~= "left"  then next_dir = "right" end

    timer = timer + dt
    if timer < TICK then return end
    timer = timer - TICK
    dir = next_dir

    local head = snake[1]
    local nx, ny = head.x, head.y
    if     dir == "up"    then ny = ny - 1
    elseif dir == "down"  then ny = ny + 1
    elseif dir == "left"  then nx = nx - 1
    elseif dir == "right" then nx = nx + 1 end

    local cols = math.floor(W / TILE)
    local rows = math.floor(H / TILE)
    if nx < 0 or nx >= cols or ny < 0 or ny >= rows then dead = true; return end

    for _, s in ipairs(snake) do
        if s.x == nx and s.y == ny then dead = true; return end
    end

    table.insert(snake, 1, { x = nx, y = ny })

    if nx == food.x and ny == food.y then
        score = score + 1
        TICK = math.max(0.04, TICK - 0.002)
        place_food()
    else
        table.remove(snake)
    end
end

function _draw()
    gfx.clear(10, 10, 12)

    -- Food
    gfx.rect(food.x * TILE + 2, food.y * TILE + 2, TILE - 4, TILE - 4, "#c0392b")

    -- Snake
    for i, s in ipairs(snake) do
        local c = (i == 1) and "#d4a574" or "#8a7a60"
        gfx.rect(s.x * TILE + 1, s.y * TILE + 1, TILE - 2, TILE - 2, c)
    end

    -- Score
    gfx.text("Score: " .. score, 8, 8, "#e8e4df", 14)
    if high_score > 0 then
        gfx.text("Best: " .. high_score, W - 90, 8, "#8a847c", 14)
    end

    if dead then
        if score > high_score then high_score = score end
        gfx.rect(0, H/2 - 40, W, 80, "rgba(0,0,0,0.8)")
        gfx.text("Game Over", W/2 - 65, H/2 - 24, "#c0392b", 24)
        gfx.text("Score: " .. score .. "  ·  Press SPACE", W/2 - 110, H/2 + 10, "#8a847c", 14)
    end
end
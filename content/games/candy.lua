+++
title   = "Gem Crush"
slug    = "candy"
date    = "2025-07-22"
summary = "Match-3 puzzle! Click a gem, then click a neighbor to swap. Match 3+ in a row to score."
width   = 384
height  = 480
tags    = ["puzzle", "match-3"]
+++

-- Gem Crush – a Candy Crush style match-3 game

local COLS = 8
local ROWS = 8
local CELL = 44
local BOARD_X = 6
local BOARD_Y = 60
local NUM_TYPES = 6

local STATE_IDLE    = 0
local STATE_SWAP    = 1
local STATE_CHECK   = 2
local STATE_FALL    = 3
local STATE_REFILL  = 4

local board       -- [row][col] = { type, x, y, target_x, target_y, alpha, scale }
local selected    -- { row, col } or nil
local state
local score
local moves
local max_moves
local combo
local particles
local swap_from, swap_to
local swap_timer
local check_timer
local fall_timer
local game_over

local GEM_COLORS = {
    "#ff4444",  -- red
    "#44cc44",  -- green
    "#4488ff",  -- blue
    "#ffcc00",  -- yellow
    "#cc44cc",  -- purple
    "#ff8833",  -- orange
}

local GEM_SHAPES = { "circle", "diamond", "square", "circle", "diamond", "square" }

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function cell_screen(row, col)
    return BOARD_X + (col - 1) * CELL + CELL / 2,
           BOARD_Y + (row - 1) * CELL + CELL / 2
end

local function screen_to_cell(mx, my)
    local col = math.floor((mx - BOARD_X) / CELL) + 1
    local row = math.floor((my - BOARD_Y) / CELL) + 1
    if row >= 1 and row <= ROWS and col >= 1 and col <= COLS then
        return row, col
    end
    return nil, nil
end

local function random_type()
    return math.random(1, NUM_TYPES)
end

local function make_cell(row, col, gem_type)
    local sx, sy = cell_screen(row, col)
    return {
        type = gem_type,
        x = sx, y = sy,
        target_x = sx, target_y = sy,
        alpha = 1,
        scale = 1,
    }
end

local function init_board()
    board = {}
    for r = 1, ROWS do
        board[r] = {}
        for c = 1, COLS do
            -- avoid initial matches
            local t
            repeat
                t = random_type()
                -- check left
                local match_left = (c >= 3 and board[r][c-1].type == t and board[r][c-2].type == t)
                -- check up
                local match_up = (r >= 3 and board[r-1][c].type == t and board[r-2][c].type == t)
            until not (match_left or match_up)
            board[r][c] = make_cell(r, c, t)
        end
    end
end

local function add_particles(x, y, col, n)
    for i = 1, n do
        table.insert(particles, {
            x = x, y = y,
            vx = (math.random() - 0.5) * 250,
            vy = (math.random() - 0.5) * 250 - 80,
            life = 0.4 + math.random() * 0.3,
            col = col,
        })
    end
end

-- find all matches on the board; returns list of {row, col} to remove
local function find_matches()
    local to_remove = {}
    local marked = {}
    local function mark(r, c)
        local key = r * 100 + c
        if not marked[key] then
            marked[key] = true
            table.insert(to_remove, { r = r, c = c })
        end
    end

    -- horizontal
    for r = 1, ROWS do
        local c = 1
        while c <= COLS do
            local t = board[r][c].type
            if t > 0 then
                local run = 1
                while c + run <= COLS and board[r][c + run].type == t do
                    run = run + 1
                end
                if run >= 3 then
                    for i = 0, run - 1 do mark(r, c + i) end
                end
                c = c + run
            else
                c = c + 1
            end
        end
    end

    -- vertical
    for c = 1, COLS do
        local r = 1
        while r <= ROWS do
            local t = board[r][c].type
            if t > 0 then
                local run = 1
                while r + run <= ROWS and board[r + run][c].type == t do
                    run = run + 1
                end
                if run >= 3 then
                    for i = 0, run - 1 do mark(r + i, c) end
                end
                r = r + run
            else
                r = r + 1
            end
        end
    end

    return to_remove
end

function _init()
    particles = {}
    selected = nil
    score = 0
    moves = 0
    max_moves = 30
    combo = 0
    game_over = false
    state = STATE_IDLE
    swap_timer = 0
    check_timer = 0
    fall_timer = 0
    init_board()
end

local SWAP_DUR  = 0.15
local CHECK_DUR = 0.25
local FALL_SPEED = 600

local function do_swap(r1, c1, r2, c2)
    local temp = board[r1][c1]
    board[r1][c1] = board[r2][c2]
    board[r2][c2] = temp

    -- update targets
    local sx1, sy1 = cell_screen(r1, c1)
    local sx2, sy2 = cell_screen(r2, c2)
    board[r1][c1].target_x = sx1
    board[r1][c1].target_y = sy1
    board[r2][c2].target_x = sx2
    board[r2][c2].target_y = sy2
end

function _update(dt)
    local W = gfx.width()
    local H = gfx.height()

    -- update particles
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 300 * dt
        p.life = p.life - dt
        if p.life <= 0 then table.remove(particles, i) end
    end

    if game_over then
        if input.key_pressed(" ") then _init() end
        return
    end

    -- animate cells toward targets
    for r = 1, ROWS do
        for c = 1, COLS do
            local cell = board[r][c]
            local dx = cell.target_x - cell.x
            local dy = cell.target_y - cell.y
            if math.abs(dx) > 0.5 or math.abs(dy) > 0.5 then
                cell.x = cell.x + dx * 12 * dt
                cell.y = cell.y + dy * 12 * dt
            else
                cell.x = cell.target_x
                cell.y = cell.target_y
            end
        end
    end

    if state == STATE_SWAP then
        swap_timer = swap_timer + dt
        if swap_timer >= SWAP_DUR then
            -- check if the swap created matches
            local matches = find_matches()
            if #matches == 0 then
                -- swap back
                do_swap(swap_from.r, swap_from.c, swap_to.r, swap_to.c)
                state = STATE_IDLE
            else
                combo = 0
                state = STATE_CHECK
                check_timer = 0
            end
        end
        return
    end

    if state == STATE_CHECK then
        check_timer = check_timer + dt
        if check_timer >= CHECK_DUR then
            local matches = find_matches()
            if #matches > 0 then
                combo = combo + 1
                local points = #matches * 10 * combo
                score = score + points
                for _, m in ipairs(matches) do
                    local cell = board[m.r][m.c]
                    add_particles(cell.x, cell.y, GEM_COLORS[cell.type], 4)
                    cell.type = 0
                end
                state = STATE_FALL
                fall_timer = 0
            else
                state = STATE_IDLE
                combo = 0
                if moves >= max_moves then game_over = true end
            end
        end
        return
    end

    if state == STATE_FALL then
        fall_timer = fall_timer + dt
        -- drop gems down to fill gaps
        local still_falling = false
        for c = 1, COLS do
            for r = ROWS, 2, -1 do
                if board[r][c].type == 0 then
                    -- find gem above
                    for above = r - 1, 1, -1 do
                        if board[above][c].type ~= 0 then
                            -- swap
                            board[r][c].type = board[above][c].type
                            board[above][c].type = 0
                            local sx, sy = cell_screen(r, c)
                            board[r][c].target_x = sx
                            board[r][c].target_y = sy
                            -- keep old position for animation
                            board[r][c].x = board[above][c].x
                            board[r][c].y = board[above][c].y
                            still_falling = true
                            break
                        end
                    end
                end
            end
        end

        -- fill top rows with new gems
        for c = 1, COLS do
            for r = 1, ROWS do
                if board[r][c].type == 0 then
                    board[r][c].type = random_type()
                    local sx, sy = cell_screen(r, c)
                    board[r][c].target_x = sx
                    board[r][c].target_y = sy
                    board[r][c].x = sx
                    board[r][c].y = BOARD_Y - CELL  -- start above board
                    still_falling = true
                end
            end
        end

        if fall_timer > 0.2 then
            -- check for chain matches
            state = STATE_CHECK
            check_timer = 0
        end
        return
    end

    -- STATE_IDLE: handle input
    if input.mouse_down(0) then
        local mx = input.mouse_x()
        local my = input.mouse_y()
        local r, c = screen_to_cell(mx, my)
        if r and c then
            if selected then
                local dr = math.abs(r - selected.row)
                local dc = math.abs(c - selected.col)
                if (dr == 1 and dc == 0) or (dr == 0 and dc == 1) then
                    -- valid swap
                    swap_from = { r = selected.row, c = selected.col }
                    swap_to   = { r = r, c = c }
                    do_swap(swap_from.r, swap_from.c, swap_to.r, swap_to.c)
                    moves = moves + 1
                    state = STATE_SWAP
                    swap_timer = 0
                    selected = nil
                elseif r == selected.row and c == selected.col then
                    selected = nil  -- deselect
                else
                    selected = { row = r, col = c }
                end
            else
                selected = { row = r, col = c }
            end
        else
            selected = nil
        end
    end
end

-- drawing ----------------------------------------------------------------

local function draw_gem(x, y, gem_type, scale)
    if gem_type <= 0 then return end
    local col = GEM_COLORS[gem_type]
    local r = 14 * scale
    local shape = GEM_SHAPES[gem_type]

    if shape == "circle" then
        gfx.circle(x, y, r, col)
        gfx.circle(x - 3, y - 3, r * 0.4, "rgba(255,255,255,0.3)")
    elseif shape == "diamond" then
        -- draw diamond as rotated square (approximate with rects)
        local s = r * 0.9
        gfx.rect(x - s/2, y - s/2, s, s, col)
        gfx.rect(x - s/3, y - s/3, s * 0.3, s * 0.3, "rgba(255,255,255,0.25)")
    else
        -- square with rounded feel
        local s = r * 1.5
        gfx.rect(x - s/2, y - s/2, s, s, col)
        gfx.rect(x - s/2 + 2, y - s/2 + 2, s * 0.35, s * 0.35, "rgba(255,255,255,0.2)")
    end
end

function _draw()
    local W = gfx.width()
    local H = gfx.height()

    gfx.clear(18, 14, 24)

    -- title bar
    gfx.text("GEM CRUSH", W / 2 - 55, 8, "#d4a574", 20)
    gfx.text("Score: " .. tostring(score), 12, 36, "#e8e4df", 14)
    gfx.text("Moves: " .. tostring(max_moves - moves), W - 110, 36, "#d4a574", 14)

    -- combo indicator
    if combo > 1 and state ~= STATE_IDLE then
        gfx.text("COMBO x" .. tostring(combo), W / 2 - 40, 36, "#ffcc00", 14)
    end

    -- board background
    gfx.rect(BOARD_X - 2, BOARD_Y - 2, COLS * CELL + 4, ROWS * CELL + 4, "#1a1520")
    gfx.rect_line(BOARD_X - 2, BOARD_Y - 2, COLS * CELL + 4, ROWS * CELL + 4, "#2a2725", 1)

    -- grid lines
    for r = 0, ROWS do
        local y = BOARD_Y + r * CELL
        gfx.line(BOARD_X, y, BOARD_X + COLS * CELL, y, "#222222", 1)
    end
    for c = 0, COLS do
        local x = BOARD_X + c * CELL
        gfx.line(x, BOARD_Y, x, BOARD_Y + ROWS * CELL, "#222222", 1)
    end

    -- selected highlight
    if selected then
        local sx, sy = cell_screen(selected.row, selected.col)
        gfx.rect_line(sx - CELL/2 + 2, sy - CELL/2 + 2, CELL - 4, CELL - 4, "#ffffff", 2)
    end

    -- gems
    for r = 1, ROWS do
        for c = 1, COLS do
            local cell = board[r][c]
            if cell.type > 0 then
                draw_gem(cell.x, cell.y, cell.type, cell.scale)
            end
        end
    end

    -- particles
    for _, p in ipairs(particles) do
        gfx.circle(p.x, p.y, 3, p.col)
    end

    -- game over
    if game_over then
        gfx.rect(0, 0, W, H, "rgba(0,0,0,0.7)")
        gfx.text("GAME OVER", W / 2 - 65, H / 2 - 40, "#d4a574", 24)
        gfx.text("Final Score: " .. tostring(score), W / 2 - 70, H / 2, "#e8e4df", 18)
        gfx.text("Press SPACE to restart", W / 2 - 95, H / 2 + 35, "#8a847c", 13)
    end
end

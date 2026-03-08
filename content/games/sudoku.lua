+++
title   = "Sudoku"
slug    = "sudoku"
date    = "2025-07-25"
summary = "Classic 9x9 Sudoku. Click a cell, type 1-9 to fill. Backspace to clear. Can you solve it?"
width   = 420
height  = 500
tags    = ["puzzle", "logic"]
+++

-- Sudoku – click cells and type numbers

local GRID_SIZE = 9
local CELL = 42
local BOARD_X = 21
local BOARD_Y = 55
local BOARD_W = GRID_SIZE * CELL
local BOARD_H = GRID_SIZE * CELL

local puzzle    -- [row][col] = number (0 = empty)
local solution  -- [row][col] = number (the answer)
local given     -- [row][col] = true if pre-filled
local errors    -- [row][col] = true if wrong
local sel_row, sel_col
local solved
local timer
local difficulty

-- Sudoku generator / solver -----------------------------------------------

-- check if placing n at (r,c) is valid in grid g
local function is_valid(g, r, c, n)
    for i = 1, 9 do
        if g[r][i] == n then return false end
        if g[i][c] == n then return false end
    end
    local br = math.floor((r - 1) / 3) * 3
    local bc = math.floor((c - 1) / 3) * 3
    for dr = 1, 3 do
        for dc = 1, 3 do
            if g[br + dr][bc + dc] == n then return false end
        end
    end
    return true
end

-- solve grid in-place; returns true if solvable
local function solve(g)
    for r = 1, 9 do
        for c = 1, 9 do
            if g[r][c] == 0 then
                for n = 1, 9 do
                    if is_valid(g, r, c, n) then
                        g[r][c] = n
                        if solve(g) then return true end
                        g[r][c] = 0
                    end
                end
                return false
            end
        end
    end
    return true
end

-- deep copy a 9x9 grid
local function copy_grid(g)
    local ng = {}
    for r = 1, 9 do
        ng[r] = {}
        for c = 1, 9 do ng[r][c] = g[r][c] end
    end
    return ng
end

-- generate a completed grid by filling with randomized backtracking
local function generate_full()
    local g = {}
    for r = 1, 9 do
        g[r] = {}
        for c = 1, 9 do g[r][c] = 0 end
    end

    local function fill(g)
        for r = 1, 9 do
            for c = 1, 9 do
                if g[r][c] == 0 then
                    -- shuffled 1-9
                    local nums = {1,2,3,4,5,6,7,8,9}
                    for i = 9, 2, -1 do
                        local j = math.random(1, i)
                        nums[i], nums[j] = nums[j], nums[i]
                    end
                    for _, n in ipairs(nums) do
                        if is_valid(g, r, c, n) then
                            g[r][c] = n
                            if fill(g) then return true end
                            g[r][c] = 0
                        end
                    end
                    return false
                end
            end
        end
        return true
    end

    fill(g)
    return g
end

-- remove cells to create puzzle; keeps `keep` cells
local function make_puzzle(full, keep)
    local puz = copy_grid(full)
    local cells = {}
    for r = 1, 9 do
        for c = 1, 9 do
            table.insert(cells, { r = r, c = c })
        end
    end
    -- shuffle
    for i = #cells, 2, -1 do
        local j = math.random(1, i)
        cells[i], cells[j] = cells[j], cells[i]
    end

    local removed = 0
    local target = 81 - keep
    for _, cell in ipairs(cells) do
        if removed >= target then break end
        puz[cell.r][cell.c] = 0
        removed = removed + 1
    end
    return puz
end

function _init()
    sel_row = 0
    sel_col = 0
    solved = false
    timer = 0
    difficulty = 35  -- number of given cells

    -- generate
    local full = generate_full()
    solution = copy_grid(full)
    puzzle = make_puzzle(full, difficulty)

    -- mark givens
    given = {}
    errors = {}
    for r = 1, 9 do
        given[r] = {}
        errors[r] = {}
        for c = 1, 9 do
            given[r][c] = (puzzle[r][c] ~= 0)
            errors[r][c] = false
        end
    end
end

local function check_solved()
    for r = 1, 9 do
        for c = 1, 9 do
            if puzzle[r][c] ~= solution[r][c] then return false end
        end
    end
    return true
end

local function validate_errors()
    for r = 1, 9 do
        for c = 1, 9 do
            if not given[r][c] and puzzle[r][c] ~= 0 then
                errors[r][c] = (puzzle[r][c] ~= solution[r][c])
            else
                errors[r][c] = false
            end
        end
    end
end

function _update(dt)
    if solved then
        if input.key_pressed(" ") then _init() end
        return
    end

    timer = timer + dt

    -- click to select cell
    if input.mouse_down(0) then
        local mx = input.mouse_x()
        local my = input.mouse_y()
        local c = math.floor((mx - BOARD_X) / CELL) + 1
        local r = math.floor((my - BOARD_Y) / CELL) + 1
        if r >= 1 and r <= 9 and c >= 1 and c <= 9 then
            if not given[r][c] then
                sel_row = r
                sel_col = c
            end
        else
            sel_row = 0
            sel_col = 0
        end
    end

    -- keyboard navigation
    if input.key_pressed("arrowup") or input.key_pressed("w") then
        if sel_row > 1 then sel_row = sel_row - 1 end
    end
    if input.key_pressed("arrowdown") or input.key_pressed("s") then
        if sel_row < 9 then sel_row = sel_row + 1 end
        if sel_row == 0 then sel_row = 1; sel_col = math.max(1, sel_col) end
    end
    if input.key_pressed("arrowleft") or input.key_pressed("a") then
        if sel_col > 1 then sel_col = sel_col - 1 end
    end
    if input.key_pressed("arrowright") or input.key_pressed("d") then
        if sel_col < 9 then sel_col = sel_col + 1 end
        if sel_col == 0 then sel_col = 1; sel_row = math.max(1, sel_row) end
    end

    -- number input
    if sel_row >= 1 and sel_row <= 9 and sel_col >= 1 and sel_col <= 9 then
        if not given[sel_row][sel_col] then
            for n = 1, 9 do
                if input.key_pressed(tostring(n)) then
                    puzzle[sel_row][sel_col] = n
                    validate_errors()
                    if check_solved() then solved = true end
                end
            end
            -- backspace / delete to clear
            if input.key_pressed("backspace") or input.key_pressed("delete") then
                puzzle[sel_row][sel_col] = 0
                errors[sel_row][sel_col] = false
            end
        end
    end
end

-- drawing ----------------------------------------------------------------

function _draw()
    local W = gfx.width()
    local H = gfx.height()

    gfx.clear(18, 14, 24)

    -- title
    gfx.text("SUDOKU", W / 2 - 40, 10, "#d4a574", 20)

    -- timer
    local mins = math.floor(timer / 60)
    local secs = math.floor(timer % 60)
    local time_str = string.format("%d:%02d", mins, secs)
    gfx.text(time_str, W - 70, 14, "#8a847c", 14)

    -- board background
    gfx.rect(BOARD_X, BOARD_Y, BOARD_W, BOARD_H, "#1e1a26")

    -- selected cell highlight
    if sel_row >= 1 and sel_row <= 9 and sel_col >= 1 and sel_col <= 9 then
        -- highlight row and column
        gfx.rect(BOARD_X, BOARD_Y + (sel_row - 1) * CELL, BOARD_W, CELL, "rgba(100,100,200,0.1)")
        gfx.rect(BOARD_X + (sel_col - 1) * CELL, BOARD_Y, CELL, BOARD_H, "rgba(100,100,200,0.1)")
        -- highlight cell
        gfx.rect(BOARD_X + (sel_col - 1) * CELL, BOARD_Y + (sel_row - 1) * CELL, CELL, CELL, "rgba(100,150,255,0.25)")
    end

    -- highlight same number
    if sel_row >= 1 and sel_col >= 1 and puzzle[sel_row][sel_col] ~= 0 then
        local sn = puzzle[sel_row][sel_col]
        for r = 1, 9 do
            for c = 1, 9 do
                if puzzle[r][c] == sn and not (r == sel_row and c == sel_col) then
                    gfx.rect(BOARD_X + (c-1)*CELL, BOARD_Y + (r-1)*CELL, CELL, CELL, "rgba(200,200,100,0.12)")
                end
            end
        end
    end

    -- cell lines (thin)
    for i = 0, 9 do
        local y = BOARD_Y + i * CELL
        local x = BOARD_X + i * CELL
        gfx.line(BOARD_X, y, BOARD_X + BOARD_W, y, "#333333", 1)
        gfx.line(x, BOARD_Y, x, BOARD_Y + BOARD_H, "#333333", 1)
    end

    -- thick 3x3 box lines
    for i = 0, 3 do
        local y = BOARD_Y + i * 3 * CELL
        local x = BOARD_X + i * 3 * CELL
        gfx.line(BOARD_X, y, BOARD_X + BOARD_W, y, "#888888", 2)
        gfx.line(x, BOARD_Y, x, BOARD_Y + BOARD_H, "#888888", 2)
    end

    -- numbers
    for r = 1, 9 do
        for c = 1, 9 do
            local n = puzzle[r][c]
            if n ~= 0 then
                local nx = BOARD_X + (c - 1) * CELL + CELL / 2 - 5
                local ny = BOARD_Y + (r - 1) * CELL + CELL / 2 - 8
                local col
                if given[r][c] then
                    col = "#e8e4df"
                elseif errors[r][c] then
                    col = "#ff4444"
                else
                    col = "#4a9eff"
                end
                gfx.text(tostring(n), nx, ny, col, 18)
            end
        end
    end

    -- selected cell border
    if sel_row >= 1 and sel_row <= 9 and sel_col >= 1 and sel_col <= 9 then
        gfx.rect_line(
            BOARD_X + (sel_col - 1) * CELL + 1,
            BOARD_Y + (sel_row - 1) * CELL + 1,
            CELL - 2, CELL - 2, "#d4a574", 2
        )
    end

    -- instructions
    gfx.text("Click cell, type 1-9. Backspace to clear.", 12, H - 22, "#555555", 10)

    -- solved overlay
    if solved then
        gfx.rect(0, 0, W, H, "rgba(0,0,0,0.7)")
        gfx.text("SOLVED!", W / 2 - 50, H / 2 - 30, "#ffd700", 28)
        gfx.text("Time: " .. time_str, W / 2 - 40, H / 2 + 10, "#e8e4df", 16)
        gfx.text("Press SPACE for new puzzle", W / 2 - 110, H / 2 + 40, "#8a847c", 13)
    end
end

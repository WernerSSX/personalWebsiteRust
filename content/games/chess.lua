+++
title   = "Chess"
slug    = "chess"
date    = "2025-07-28"
summary = "Two-player chess. Click a piece to select, click a highlighted square to move. Full rules."
width   = 480
height  = 520
tags    = ["strategy", "board"]
+++

-- Chess – full two-player chess with legal move validation

local CELL = 56
local BOARD_X = 16
local BOARD_Y = 48
local BOARD_W = 8 * CELL
local BOARD_H = 8 * CELL

-- piece types
local EMPTY  = 0
local PAWN   = 1
local KNIGHT = 2
local BISHOP = 3
local ROOK   = 4
local QUEEN  = 5
local KING   = 6

-- colors
local WHITE = 1
local BLACK = 2

local board       -- [row][col] = { type, color } or nil
local turn        -- WHITE or BLACK
local selected    -- { row, col } or nil
local valid_moves -- list of { row, col }
local captured_w  -- pieces captured from white
local captured_b  -- pieces captured from black
local game_over
local winner
local last_move   -- { from_r, from_c, to_r, to_c }
local check_flag
-- castling rights
local can_castle  -- [color][side] = true/false  side: "king" or "queen"
-- en passant target
local en_passant  -- { row, col } or nil

local PIECE_CHARS = {
    [PAWN]   = "P",
    [KNIGHT] = "N",
    [BISHOP] = "B",
    [ROOK]   = "R",
    [QUEEN]  = "Q",
    [KING]   = "K",
}

local function make_piece(ptype, color)
    return { type = ptype, color = color }
end

local function init_board()
    board = {}
    for r = 1, 8 do
        board[r] = {}
        for c = 1, 8 do
            board[r][c] = nil
        end
    end

    -- black pieces (top, rows 1-2)
    board[1][1] = make_piece(ROOK, BLACK)
    board[1][2] = make_piece(KNIGHT, BLACK)
    board[1][3] = make_piece(BISHOP, BLACK)
    board[1][4] = make_piece(QUEEN, BLACK)
    board[1][5] = make_piece(KING, BLACK)
    board[1][6] = make_piece(BISHOP, BLACK)
    board[1][7] = make_piece(KNIGHT, BLACK)
    board[1][8] = make_piece(ROOK, BLACK)
    for c = 1, 8 do
        board[2][c] = make_piece(PAWN, BLACK)
    end

    -- white pieces (bottom, rows 7-8)
    board[8][1] = make_piece(ROOK, WHITE)
    board[8][2] = make_piece(KNIGHT, WHITE)
    board[8][3] = make_piece(BISHOP, WHITE)
    board[8][4] = make_piece(QUEEN, WHITE)
    board[8][5] = make_piece(KING, WHITE)
    board[8][6] = make_piece(BISHOP, WHITE)
    board[8][7] = make_piece(KNIGHT, WHITE)
    board[8][8] = make_piece(ROOK, WHITE)
    for c = 1, 8 do
        board[7][c] = make_piece(PAWN, WHITE)
    end
end

local function in_bounds(r, c)
    return r >= 1 and r <= 8 and c >= 1 and c <= 8
end

local function opponent(color)
    return color == WHITE and BLACK or WHITE
end

-- find king position
local function find_king(color)
    for r = 1, 8 do
        for c = 1, 8 do
            local p = board[r][c]
            if p and p.type == KING and p.color == color then
                return r, c
            end
        end
    end
    return nil, nil
end

-- check if a square is attacked by `attacker_color`
local function is_attacked(r, c, attacker_color)
    -- pawn attacks
    local pawn_dir = attacker_color == WHITE and 1 or -1
    for _, dc in ipairs({-1, 1}) do
        local pr, pc = r + pawn_dir, c + dc
        if in_bounds(pr, pc) then
            local p = board[pr][pc]
            if p and p.type == PAWN and p.color == attacker_color then return true end
        end
    end

    -- knight attacks
    local knight_moves = {{-2,-1},{-2,1},{-1,-2},{-1,2},{1,-2},{1,2},{2,-1},{2,1}}
    for _, km in ipairs(knight_moves) do
        local nr, nc = r + km[1], c + km[2]
        if in_bounds(nr, nc) then
            local p = board[nr][nc]
            if p and p.type == KNIGHT and p.color == attacker_color then return true end
        end
    end

    -- king attacks (adjacent)
    for dr = -1, 1 do
        for dc = -1, 1 do
            if not (dr == 0 and dc == 0) then
                local nr, nc = r + dr, c + dc
                if in_bounds(nr, nc) then
                    local p = board[nr][nc]
                    if p and p.type == KING and p.color == attacker_color then return true end
                end
            end
        end
    end

    -- sliding pieces (rook/queen for straight, bishop/queen for diagonal)
    -- straight directions
    local dirs_straight = {{-1,0},{1,0},{0,-1},{0,1}}
    for _, d in ipairs(dirs_straight) do
        local nr, nc = r + d[1], c + d[2]
        while in_bounds(nr, nc) do
            local p = board[nr][nc]
            if p then
                if p.color == attacker_color and (p.type == ROOK or p.type == QUEEN) then
                    return true
                end
                break
            end
            nr = nr + d[1]
            nc = nc + d[2]
        end
    end

    -- diagonal directions
    local dirs_diag = {{-1,-1},{-1,1},{1,-1},{1,1}}
    for _, d in ipairs(dirs_diag) do
        local nr, nc = r + d[1], c + d[2]
        while in_bounds(nr, nc) do
            local p = board[nr][nc]
            if p then
                if p.color == attacker_color and (p.type == BISHOP or p.type == QUEEN) then
                    return true
                end
                break
            end
            nr = nr + d[1]
            nc = nc + d[2]
        end
    end

    return false
end

local function is_in_check(color)
    local kr, kc = find_king(color)
    if not kr then return false end
    return is_attacked(kr, kc, opponent(color))
end

-- generate pseudo-legal moves for piece at (r,c), returns list of {row, col}
local function pseudo_legal_moves(r, c)
    local p = board[r][c]
    if not p then return {} end
    local moves = {}
    local color = p.color

    local function add_if_valid(nr, nc)
        if in_bounds(nr, nc) then
            local target = board[nr][nc]
            if not target or target.color ~= color then
                table.insert(moves, { row = nr, col = nc })
            end
        end
    end

    local function add_slide(dr, dc)
        local nr, nc = r + dr, c + dc
        while in_bounds(nr, nc) do
            local target = board[nr][nc]
            if target then
                if target.color ~= color then
                    table.insert(moves, { row = nr, col = nc })
                end
                break
            end
            table.insert(moves, { row = nr, col = nc })
            nr = nr + dr
            nc = nc + dc
        end
    end

    if p.type == PAWN then
        local dir = color == WHITE and -1 or 1
        local start_row = color == WHITE and 7 or 2

        -- forward
        if in_bounds(r + dir, c) and not board[r + dir][c] then
            table.insert(moves, { row = r + dir, col = c })
            -- double push from start
            if r == start_row and not board[r + 2*dir][c] then
                table.insert(moves, { row = r + 2*dir, col = c })
            end
        end
        -- captures
        for _, dc in ipairs({-1, 1}) do
            local nr, nc = r + dir, c + dc
            if in_bounds(nr, nc) then
                local target = board[nr][nc]
                if target and target.color ~= color then
                    table.insert(moves, { row = nr, col = nc })
                end
                -- en passant
                if en_passant and en_passant.row == nr and en_passant.col == nc then
                    table.insert(moves, { row = nr, col = nc })
                end
            end
        end

    elseif p.type == KNIGHT then
        local km = {{-2,-1},{-2,1},{-1,-2},{-1,2},{1,-2},{1,2},{2,-1},{2,1}}
        for _, m in ipairs(km) do add_if_valid(r + m[1], c + m[2]) end

    elseif p.type == BISHOP then
        add_slide(-1,-1); add_slide(-1,1); add_slide(1,-1); add_slide(1,1)

    elseif p.type == ROOK then
        add_slide(-1,0); add_slide(1,0); add_slide(0,-1); add_slide(0,1)

    elseif p.type == QUEEN then
        add_slide(-1,0); add_slide(1,0); add_slide(0,-1); add_slide(0,1)
        add_slide(-1,-1); add_slide(-1,1); add_slide(1,-1); add_slide(1,1)

    elseif p.type == KING then
        for dr = -1, 1 do
            for dc = -1, 1 do
                if not (dr == 0 and dc == 0) then add_if_valid(r + dr, c + dc) end
            end
        end
        -- castling
        if can_castle[color]["king"] and not is_in_check(color) then
            local row = color == WHITE and 8 or 1
            if r == row and c == 5 then
                if not board[row][6] and not board[row][7] and board[row][8]
                   and board[row][8].type == ROOK and board[row][8].color == color then
                    if not is_attacked(row, 6, opponent(color)) and not is_attacked(row, 7, opponent(color)) then
                        table.insert(moves, { row = row, col = 7 })
                    end
                end
            end
        end
        if can_castle[color]["queen"] and not is_in_check(color) then
            local row = color == WHITE and 8 or 1
            if r == row and c == 5 then
                if not board[row][4] and not board[row][3] and not board[row][2] and board[row][1]
                   and board[row][1].type == ROOK and board[row][1].color == color then
                    if not is_attacked(row, 4, opponent(color)) and not is_attacked(row, 3, opponent(color)) then
                        table.insert(moves, { row = row, col = 3 })
                    end
                end
            end
        end
    end

    return moves
end

-- filter moves that leave own king in check
local function legal_moves(r, c)
    local p = board[r][c]
    if not p then return {} end
    local pmoves = pseudo_legal_moves(r, c)
    local result = {}

    for _, m in ipairs(pmoves) do
        -- simulate move
        local captured = board[m.row][m.col]
        local ep_captured = nil
        board[m.row][m.col] = p
        board[r][c] = nil

        -- en passant capture
        if p.type == PAWN and en_passant and m.row == en_passant.row and m.col == en_passant.col then
            local cap_r = p.color == WHITE and m.row + 1 or m.row - 1
            ep_captured = board[cap_r][m.col]
            board[cap_r][m.col] = nil
        end

        if not is_in_check(p.color) then
            table.insert(result, m)
        end

        -- undo
        board[r][c] = p
        board[m.row][m.col] = captured
        if ep_captured then
            local cap_r = p.color == WHITE and m.row + 1 or m.row - 1
            board[cap_r][m.col] = ep_captured
        end
    end

    return result
end

-- check if color has any legal moves
local function has_legal_moves(color)
    for r = 1, 8 do
        for c = 1, 8 do
            local p = board[r][c]
            if p and p.color == color then
                local moves = legal_moves(r, c)
                if #moves > 0 then return true end
            end
        end
    end
    return false
end

function _init()
    init_board()
    turn = WHITE
    selected = nil
    valid_moves = {}
    captured_w = {}
    captured_b = {}
    game_over = false
    winner = nil
    last_move = nil
    check_flag = false
    en_passant = nil
    can_castle = {
        [WHITE] = { king = true, queen = true },
        [BLACK] = { king = true, queen = true },
    }
end

local function make_move(from_r, from_c, to_r, to_c)
    local p = board[from_r][from_c]
    local captured_piece = board[to_r][to_c]

    -- en passant capture
    if p.type == PAWN and en_passant and to_r == en_passant.row and to_c == en_passant.col then
        local cap_r = p.color == WHITE and to_r + 1 or to_r - 1
        captured_piece = board[cap_r][to_c]
        board[cap_r][to_c] = nil
    end

    -- track captures
    if captured_piece then
        if captured_piece.color == WHITE then
            table.insert(captured_w, captured_piece)
        else
            table.insert(captured_b, captured_piece)
        end
    end

    -- update en passant
    en_passant = nil
    if p.type == PAWN and math.abs(to_r - from_r) == 2 then
        en_passant = { row = (from_r + to_r) / 2, col = from_c }
    end

    -- castling: move rook too
    if p.type == KING and math.abs(to_c - from_c) == 2 then
        local row = from_r
        if to_c == 7 then
            -- kingside
            board[row][6] = board[row][8]
            board[row][8] = nil
        elseif to_c == 3 then
            -- queenside
            board[row][4] = board[row][1]
            board[row][1] = nil
        end
    end

    -- update castling rights
    if p.type == KING then
        can_castle[p.color]["king"] = false
        can_castle[p.color]["queen"] = false
    end
    if p.type == ROOK then
        if from_c == 1 then can_castle[p.color]["queen"] = false end
        if from_c == 8 then can_castle[p.color]["king"] = false end
    end
    -- if rook captured
    if captured_piece and captured_piece.type == ROOK then
        if to_c == 1 then can_castle[captured_piece.color]["queen"] = false end
        if to_c == 8 then can_castle[captured_piece.color]["king"] = false end
    end

    -- move piece
    board[to_r][to_c] = p
    board[from_r][from_c] = nil

    -- pawn promotion (auto-queen)
    local promo_row = p.color == WHITE and 1 or 8
    if p.type == PAWN and to_r == promo_row then
        board[to_r][to_c] = make_piece(QUEEN, p.color)
    end

    last_move = { from_r = from_r, from_c = from_c, to_r = to_r, to_c = to_c }

    -- switch turn
    turn = opponent(turn)

    -- check for check / checkmate / stalemate
    check_flag = is_in_check(turn)
    if not has_legal_moves(turn) then
        game_over = true
        if check_flag then
            winner = opponent(turn)
        else
            winner = nil -- stalemate
        end
    end
end

function _update(dt)
    if game_over then
        if input.key_pressed(" ") then _init() end
        return
    end

    if input.mouse_down(0) then
        local mx = input.mouse_x()
        local my = input.mouse_y()
        local c = math.floor((mx - BOARD_X) / CELL) + 1
        local r = math.floor((my - BOARD_Y) / CELL) + 1

        if in_bounds(r, c) then
            if selected then
                -- check if clicking a valid move
                local is_valid_target = false
                for _, m in ipairs(valid_moves) do
                    if m.row == r and m.col == c then
                        is_valid_target = true
                        break
                    end
                end

                if is_valid_target then
                    make_move(selected.row, selected.col, r, c)
                    selected = nil
                    valid_moves = {}
                else
                    -- select new piece
                    local p = board[r][c]
                    if p and p.color == turn then
                        selected = { row = r, col = c }
                        valid_moves = legal_moves(r, c)
                    else
                        selected = nil
                        valid_moves = {}
                    end
                end
            else
                local p = board[r][c]
                if p and p.color == turn then
                    selected = { row = r, col = c }
                    valid_moves = legal_moves(r, c)
                end
            end
        else
            selected = nil
            valid_moves = {}
        end
    end
end

-- drawing ----------------------------------------------------------------

local LIGHT_SQ = "#b8a07a"
local DARK_SQ  = "#7a6248"

local function draw_piece(r, c, piece)
    local sx = BOARD_X + (c - 1) * CELL + CELL / 2
    local sy = BOARD_Y + (r - 1) * CELL + CELL / 2
    local ch = PIECE_CHARS[piece.type] or "?"

    -- piece background circle
    local bg = piece.color == WHITE and "#e8e4df" or "#2a2220"
    local fg = piece.color == WHITE and "#1a1a1a" or "#d4c8b8"
    local border = piece.color == WHITE and "#aaa8a0" or "#555050"

    gfx.circle(sx, sy, 18, bg)
    gfx.circle_line(sx, sy, 18, border, 1)
    gfx.text(ch, sx - 6, sy - 8, fg, 18)
end

function _draw()
    local W = gfx.width()
    local H = gfx.height()

    gfx.clear(18, 14, 24)

    -- turn indicator
    local turn_text = turn == WHITE and "White to move" or "Black to move"
    local turn_col = turn == WHITE and "#e8e4df" or "#8a847c"
    gfx.text(turn_text, 16, 14, turn_col, 16)

    if check_flag and not game_over then
        gfx.text("CHECK!", W / 2 + 30, 14, "#ff4444", 16)
    end

    -- board squares
    for r = 1, 8 do
        for c = 1, 8 do
            local light = ((r + c) % 2 == 0)
            local col = light and LIGHT_SQ or DARK_SQ
            gfx.rect(BOARD_X + (c-1)*CELL, BOARD_Y + (r-1)*CELL, CELL, CELL, col)
        end
    end

    -- last move highlight
    if last_move then
        gfx.rect(BOARD_X + (last_move.from_c-1)*CELL, BOARD_Y + (last_move.from_r-1)*CELL,
                 CELL, CELL, "rgba(200,200,50,0.25)")
        gfx.rect(BOARD_X + (last_move.to_c-1)*CELL, BOARD_Y + (last_move.to_r-1)*CELL,
                 CELL, CELL, "rgba(200,200,50,0.25)")
    end

    -- selected highlight
    if selected then
        gfx.rect(BOARD_X + (selected.col-1)*CELL, BOARD_Y + (selected.row-1)*CELL,
                 CELL, CELL, "rgba(100,180,255,0.35)")
    end

    -- valid move dots
    for _, m in ipairs(valid_moves) do
        local mx = BOARD_X + (m.col - 1) * CELL + CELL / 2
        local my = BOARD_Y + (m.row - 1) * CELL + CELL / 2
        local target = board[m.row][m.col]
        if target then
            -- capture: ring
            gfx.circle_line(mx, my, 22, "rgba(200,50,50,0.6)", 3)
        else
            -- empty: dot
            gfx.circle(mx, my, 7, "rgba(0,0,0,0.3)")
        end
    end

    -- king in check highlight
    if check_flag and not game_over then
        local kr, kc = find_king(turn)
        if kr then
            gfx.rect(BOARD_X + (kc-1)*CELL, BOARD_Y + (kr-1)*CELL,
                     CELL, CELL, "rgba(255,0,0,0.3)")
        end
    end

    -- pieces
    for r = 1, 8 do
        for c = 1, 8 do
            if board[r][c] then
                draw_piece(r, c, board[r][c])
            end
        end
    end

    -- board border
    gfx.rect_line(BOARD_X, BOARD_Y, BOARD_W, BOARD_H, "#555555", 2)

    -- rank and file labels
    for i = 1, 8 do
        local file_char = string.char(96 + i)  -- a-h
        gfx.text(file_char, BOARD_X + (i-1)*CELL + CELL/2 - 3, BOARD_Y + BOARD_H + 4, "#555555", 11)
        gfx.text(tostring(9 - i), BOARD_X - 14, BOARD_Y + (i-1)*CELL + CELL/2 - 5, "#555555", 11)
    end

    -- captured pieces display
    local cap_y = BOARD_Y + BOARD_H + 20
    gfx.text("Captured:", 16, cap_y, "#8a847c", 10)
    for i, cp in ipairs(captured_b) do
        local ch = PIECE_CHARS[cp.type] or "?"
        gfx.text(ch, 16 + (i-1) * 16, cap_y + 14, "#888888", 12)
    end
    for i, cp in ipairs(captured_w) do
        local ch = PIECE_CHARS[cp.type] or "?"
        gfx.text(ch, W/2 + (i-1) * 16, cap_y + 14, "#cccccc", 12)
    end

    -- game over overlay
    if game_over then
        gfx.rect(0, 0, W, H, "rgba(0,0,0,0.7)")
        if winner then
            local wt = winner == WHITE and "White wins!" or "Black wins!"
            gfx.text(wt, W / 2 - 65, H / 2 - 25, "#ffd700", 24)
            gfx.text("Checkmate", W / 2 - 50, H / 2 + 5, "#e8e4df", 16)
        else
            gfx.text("Stalemate!", W / 2 - 60, H / 2 - 25, "#d4a574", 24)
            gfx.text("Draw", W / 2 - 22, H / 2 + 5, "#e8e4df", 16)
        end
        gfx.text("Press SPACE for new game", W / 2 - 105, H / 2 + 40, "#8a847c", 13)
    end
end

+++
title   = "Video Poker"
slug    = "poker"
date    = "2025-08-03"
summary = "Jacks or Better video poker. Draw 5 cards, hold the best, redraw. Aim for the best hand!"
width   = 512
height  = 400
tags    = ["cards", "casino"]
+++

-- Video Poker – Jacks or Better

local STATE_BET   = 0
local STATE_DEAL  = 1
local STATE_HOLD  = 2
local STATE_DRAW  = 3
local STATE_RESULT = 4

local SUITS = { "S", "H", "D", "C" }
local RANKS = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" }

local SUIT_COLORS = { S = "#e8e4df", H = "#ff4444", D = "#ff4444", C = "#e8e4df" }
local SUIT_SYMBOLS = { S = "s", H = "h", D = "d", C = "c" }

-- rank value for comparison (Ace high)
local RANK_VAL = {}
for i, r in ipairs(RANKS) do RANK_VAL[r] = i end

local deck
local hand       -- 5 cards
local held       -- [1..5] = true/false
local state
local chips
local bet
local result_text
local payout
local result_timer
local deal_anim
local draw_anim

-- pay table (multiplied by bet)
local PAY_TABLE = {
    { name = "Royal Flush",    mult = 250 },
    { name = "Straight Flush", mult = 50 },
    { name = "Four of a Kind", mult = 25 },
    { name = "Full House",     mult = 9 },
    { name = "Flush",          mult = 6 },
    { name = "Straight",       mult = 4 },
    { name = "Three of a Kind",mult = 3 },
    { name = "Two Pair",       mult = 2 },
    { name = "Jacks or Better",mult = 1 },
}

-- helpers ----------------------------------------------------------------

local function make_deck()
    local d = {}
    for _, s in ipairs(SUITS) do
        for _, r in ipairs(RANKS) do
            table.insert(d, { rank = r, suit = s })
        end
    end
    for i = #d, 2, -1 do
        local j = math.random(1, i)
        d[i], d[j] = d[j], d[i]
    end
    return d
end

local function draw_from_deck()
    if #deck == 0 then deck = make_deck() end
    return table.remove(deck)
end

local function get_rank_counts(h)
    local counts = {}
    for _, c in ipairs(h) do
        counts[c.rank] = (counts[c.rank] or 0) + 1
    end
    return counts
end

local function is_flush(h)
    local s = h[1].suit
    for i = 2, 5 do
        if h[i].suit ~= s then return false end
    end
    return true
end

local function sorted_values(h)
    local vals = {}
    for _, c in ipairs(h) do
        table.insert(vals, RANK_VAL[c.rank])
    end
    table.sort(vals)
    return vals
end

local function is_straight(h)
    local vals = sorted_values(h)
    -- normal straight
    local normal = true
    for i = 2, 5 do
        if vals[i] ~= vals[i-1] + 1 then normal = false; break end
    end
    if normal then return true end
    -- ace-high straight: 1(A),10,11,12,13
    if vals[1] == 1 and vals[2] == 10 and vals[3] == 11 and vals[4] == 12 and vals[5] == 13 then
        return true
    end
    return false
end

local function is_royal(h)
    if not is_flush(h) then return false end
    local vals = sorted_values(h)
    return vals[1] == 1 and vals[2] == 10 and vals[3] == 11 and vals[4] == 12 and vals[5] == 13
end

local function evaluate_hand(h)
    local counts = get_rank_counts(h)
    local flush = is_flush(h)
    local straight = is_straight(h)

    -- count pairs, trips, quads
    local pairs_list = {}
    local trips = false
    local quads = false
    for rank, cnt in pairs(counts) do
        if cnt == 4 then quads = true end
        if cnt == 3 then trips = true end
        if cnt == 2 then table.insert(pairs_list, rank) end
    end

    if is_royal(h) then return 1, PAY_TABLE[1] end
    if straight and flush then return 2, PAY_TABLE[2] end
    if quads then return 3, PAY_TABLE[3] end
    if trips and #pairs_list == 1 then return 4, PAY_TABLE[4] end
    if flush then return 5, PAY_TABLE[5] end
    if straight then return 6, PAY_TABLE[6] end
    if trips then return 7, PAY_TABLE[7] end
    if #pairs_list == 2 then return 8, PAY_TABLE[8] end
    -- jacks or better: pair of J, Q, K, or A
    if #pairs_list == 1 then
        local pr = pairs_list[1]
        if pr == "J" or pr == "Q" or pr == "K" or pr == "A" then
            return 9, PAY_TABLE[9]
        end
    end

    return 0, nil
end

function _init()
    chips = 100
    bet = 5
    deck = make_deck()
    hand = {}
    held = { false, false, false, false, false }
    state = STATE_BET
    result_text = ""
    payout = 0
    result_timer = 0
    deal_anim = 0
    draw_anim = 0
end

local function deal_cards()
    deck = make_deck()
    hand = {}
    held = { false, false, false, false, false }
    for i = 1, 5 do
        table.insert(hand, draw_from_deck())
    end
    deal_anim = 0
    state = STATE_DEAL
end

local function draw_new_cards()
    for i = 1, 5 do
        if not held[i] then
            hand[i] = draw_from_deck()
        end
    end
    draw_anim = 0
    state = STATE_DRAW
end

function _update(dt)
    if state == STATE_BET then
        if chips <= 0 then
            if input.key_pressed(" ") then chips = 100 end
            return
        end

        if input.key_pressed("arrowup") or input.key_pressed("w") then
            bet = bet + 5
            if bet > chips then bet = chips end
        end
        if input.key_pressed("arrowdown") or input.key_pressed("s") then
            bet = bet - 5
            if bet < 5 then bet = 5 end
        end
        if bet > chips then bet = chips end

        if input.key_pressed(" ") then
            chips = chips - bet
            deal_cards()
        end
        return
    end

    if state == STATE_DEAL then
        deal_anim = deal_anim + dt
        if deal_anim > 0.5 then
            state = STATE_HOLD
        end
        return
    end

    if state == STATE_HOLD then
        -- toggle hold with 1-5
        for i = 1, 5 do
            if input.key_pressed(tostring(i)) then
                held[i] = not held[i]
            end
        end

        -- click to toggle hold
        if input.mouse_down(0) then
            local mx = input.mouse_x()
            local my = input.mouse_y()
            for i = 1, 5 do
                local cx = 16 + (i - 1) * 96
                local cy = 180
                if mx >= cx and mx <= cx + 80 and my >= cy and my <= cy + 110 then
                    held[i] = not held[i]
                end
            end
        end

        -- SPACE to draw
        if input.key_pressed(" ") then
            draw_new_cards()
        end
        return
    end

    if state == STATE_DRAW then
        draw_anim = draw_anim + dt
        if draw_anim > 0.5 then
            -- evaluate
            local rank, pay_entry = evaluate_hand(hand)
            if pay_entry then
                payout = pay_entry.mult * bet
                chips = chips + payout
                result_text = pay_entry.name .. "! +" .. tostring(payout)
            else
                payout = 0
                result_text = "No win"
            end
            result_timer = 0
            state = STATE_RESULT
        end
        return
    end

    if state == STATE_RESULT then
        result_timer = result_timer + dt
        if result_timer > 2 and input.key_pressed(" ") then
            state = STATE_BET
        end
        return
    end
end

-- drawing ----------------------------------------------------------------

local CARD_W = 80
local CARD_H = 110

local function draw_card_face(x, y, card, dim)
    local bg = dim and "#c0b8a8" or "#f5f0e8"
    gfx.rect(x, y, CARD_W, CARD_H, bg)
    gfx.rect_line(x, y, CARD_W, CARD_H, "#888888", 1)

    local col = SUIT_COLORS[card.suit]
    local suit_ch = SUIT_SYMBOLS[card.suit]

    gfx.text(card.rank, x + 6, y + 6, col, 18)
    gfx.text(suit_ch, x + 6, y + 24, col, 14)

    gfx.text(card.rank, x + CARD_W / 2 - 8, y + CARD_H / 2 - 14, col, 28)
    gfx.text(suit_ch, x + CARD_W / 2 - 5, y + CARD_H / 2 + 14, col, 16)
end

local function draw_card_back(x, y)
    gfx.rect(x, y, CARD_W, CARD_H, "#2244aa")
    gfx.rect_line(x, y, CARD_W, CARD_H, "#888888", 1)
    gfx.rect(x + 6, y + 6, CARD_W - 12, CARD_H - 12, "#1a3388")
end

function _draw()
    local W = gfx.width()
    local H = gfx.height()

    gfx.clear(20, 60, 30)

    -- felt lines
    for i = 0, H, 20 do
        gfx.line(0, i, W, i, "rgba(0,0,0,0.04)", 1)
    end

    -- pay table (right side)
    gfx.text("PAY TABLE", W - 155, 8, "#d4a574", 12)
    for i, entry in ipairs(PAY_TABLE) do
        local y = 22 + (i - 1) * 14
        local col = "#8a847c"
        -- highlight if we have a result matching
        if state == STATE_RESULT and payout > 0 then
            local rank, _ = evaluate_hand(hand)
            if rank == i then col = "#ffd700" end
        end
        gfx.text(entry.name, W - 165, y, col, 10)
        gfx.text("x" .. tostring(entry.mult), W - 30, y, col, 10)
    end

    -- chips + bet
    gfx.text("Chips: " .. tostring(chips), 16, 10, "#ffd700", 16)

    if state == STATE_BET then
        if chips <= 0 then
            gfx.text("BROKE!", W / 2 - 40, H / 2 - 30, "#ff4444", 28)
            gfx.text("Press SPACE to rebuy ($100)", W / 2 - 120, H / 2 + 10, "#e8e4df", 14)
            return
        end

        gfx.text("Bet: $" .. tostring(bet), W / 2 - 35, H / 2 - 40, "#ffd700", 20)
        gfx.text("UP/DOWN to change bet", W / 2 - 90, H / 2, "#8a847c", 13)
        gfx.text("Press SPACE to deal", W / 2 - 80, H / 2 + 25, "#e8e4df", 14)
        return
    end

    gfx.text("Bet: $" .. tostring(bet), 16, 30, "#d4a574", 14)

    -- cards
    local card_y = 180
    for i = 1, 5 do
        local cx = 16 + (i - 1) * 96

        if state == STATE_DEAL and deal_anim < i * 0.08 then
            draw_card_back(cx, card_y)
        elseif state == STATE_DRAW and not held[i] and draw_anim < i * 0.08 then
            draw_card_back(cx, card_y)
        else
            draw_card_face(cx, card_y, hand[i], false)
        end

        -- hold indicator
        if held[i] then
            gfx.rect(cx, card_y - 22, CARD_W, 18, "#d4a574")
            gfx.text("HELD", cx + 22, card_y - 20, "#0c0b0a", 12)
        end

        -- key label
        gfx.text("[" .. tostring(i) .. "]", cx + CARD_W / 2 - 8, card_y + CARD_H + 8, "#8a847c", 12)
    end

    -- instructions
    if state == STATE_HOLD then
        gfx.text("Press 1-5 or click to HOLD cards", W / 2 - 130, 150, "#e8e4df", 14)
        gfx.text("Press SPACE to draw", W / 2 - 80, 168, "#d4a574", 13)
    end

    -- result
    if state == STATE_RESULT then
        local col = payout > 0 and "#ffd700" or "#ff6666"
        gfx.rect(W / 2 - 140, H / 2 - 80, 280, 40, "rgba(0,0,0,0.8)")
        gfx.rect_line(W / 2 - 140, H / 2 - 80, 280, 40, "#d4a574", 2)
        gfx.text(result_text, W / 2 - 120, H / 2 - 70, col, 18)

        if result_timer > 2 then
            gfx.text("Press SPACE to continue", W / 2 - 100, H - 30, "#8a847c", 12)
        end
    end
end

+++
title   = "Blackjack"
slug    = "blackjack"
date    = "2025-08-01"
summary = "Classic 21. Hit or Stand against the dealer. Get closest to 21 without busting!"
width   = 480
height  = 400
tags    = ["cards", "casino"]
+++

-- Blackjack – player vs dealer

local STATE_BET     = 0
local STATE_PLAY    = 1
local STATE_DEALER  = 2
local STATE_RESULT  = 3

local SUITS = { "S", "H", "D", "C" }  -- spades, hearts, diamonds, clubs
local RANKS = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" }

local SUIT_SYMBOLS = { S = "s", H = "h", D = "d", C = "c" }
local SUIT_COLORS  = { S = "#e8e4df", H = "#ff4444", D = "#ff4444", C = "#e8e4df" }

local deck
local player_hand
local dealer_hand
local state
local chips
local bet
local result_text
local result_timer
local dealer_reveal
local dealer_timer

-- helpers ----------------------------------------------------------------

local function make_deck()
    local d = {}
    for _, s in ipairs(SUITS) do
        for _, r in ipairs(RANKS) do
            table.insert(d, { rank = r, suit = s })
        end
    end
    -- shuffle
    for i = #d, 2, -1 do
        local j = math.random(1, i)
        d[i], d[j] = d[j], d[i]
    end
    return d
end

local function draw_card()
    if #deck == 0 then deck = make_deck() end
    return table.remove(deck)
end

local function card_value(card)
    local r = card.rank
    if r == "A" then return 11
    elseif r == "K" or r == "Q" or r == "J" then return 10
    else return tonumber(r)
    end
end

local function hand_value(hand)
    local total = 0
    local aces = 0
    for _, c in ipairs(hand) do
        local v = card_value(c)
        total = total + v
        if c.rank == "A" then aces = aces + 1 end
    end
    while total > 21 and aces > 0 do
        total = total - 10
        aces = aces - 1
    end
    return total
end

local function hand_is_blackjack(hand)
    return #hand == 2 and hand_value(hand) == 21
end

function _init()
    chips = 100
    bet = 0
    deck = make_deck()
    player_hand = {}
    dealer_hand = {}
    state = STATE_BET
    result_text = ""
    result_timer = 0
    dealer_reveal = false
    dealer_timer = 0
end

local function start_round()
    if #deck < 15 then deck = make_deck() end
    player_hand = {}
    dealer_hand = {}
    dealer_reveal = false
    dealer_timer = 0

    table.insert(player_hand, draw_card())
    table.insert(dealer_hand, draw_card())
    table.insert(player_hand, draw_card())
    table.insert(dealer_hand, draw_card())

    -- check naturals
    local p_bj = hand_is_blackjack(player_hand)
    local d_bj = hand_is_blackjack(dealer_hand)

    if p_bj or d_bj then
        dealer_reveal = true
        state = STATE_RESULT
        result_timer = 0
        if p_bj and d_bj then
            result_text = "Both Blackjack! Push."
            -- return bet
        elseif p_bj then
            result_text = "BLACKJACK! You win!"
            chips = chips + math.floor(bet * 1.5)
        else
            result_text = "Dealer Blackjack!"
            chips = chips - bet
        end
        bet = 0
    else
        state = STATE_PLAY
    end
end

local function finish_round(txt, win_mult)
    result_text = txt
    result_timer = 0
    if win_mult > 0 then
        chips = chips + math.floor(bet * win_mult)
    elseif win_mult < 0 then
        chips = chips + win_mult * bet  -- lose bet
    end
    -- win_mult == 0 means push
    bet = 0
    state = STATE_RESULT
end

function _update(dt)
    local W = gfx.width()

    if state == STATE_BET then
        if chips <= 0 then
            -- broke: reset
            if input.key_pressed(" ") then
                chips = 100
            end
            return
        end

        -- bet with number keys
        if input.key_pressed("1") then bet = 5 end
        if input.key_pressed("2") then bet = 10 end
        if input.key_pressed("3") then bet = 25 end
        if input.key_pressed("4") then bet = 50 end

        if bet > chips then bet = chips end

        if bet > 0 and input.key_pressed(" ") then
            start_round()
        end
        return
    end

    if state == STATE_PLAY then
        -- H to hit
        if input.key_pressed("h") then
            table.insert(player_hand, draw_card())
            if hand_value(player_hand) > 21 then
                dealer_reveal = true
                finish_round("BUST! You lose.", -1)
            end
        end
        -- S to stand
        if input.key_pressed("s") then
            dealer_reveal = true
            state = STATE_DEALER
            dealer_timer = 0
        end
        -- D to double down (only with 2 cards)
        if input.key_pressed("d") and #player_hand == 2 then
            local extra = bet
            if extra > chips - bet then extra = chips - bet end
            bet = bet + extra
            table.insert(player_hand, draw_card())
            if hand_value(player_hand) > 21 then
                dealer_reveal = true
                finish_round("BUST! You lose.", -1)
            else
                dealer_reveal = true
                state = STATE_DEALER
                dealer_timer = 0
            end
        end
        return
    end

    if state == STATE_DEALER then
        dealer_timer = dealer_timer + dt
        if dealer_timer >= 0.6 then
            dealer_timer = 0
            local dv = hand_value(dealer_hand)
            if dv < 17 then
                table.insert(dealer_hand, draw_card())
            else
                -- resolve
                local pv = hand_value(player_hand)
                dv = hand_value(dealer_hand)
                if dv > 21 then
                    finish_round("Dealer busts! You win!", 1)
                elseif pv > dv then
                    finish_round("You win!", 1)
                elseif pv < dv then
                    finish_round("Dealer wins.", -1)
                else
                    finish_round("Push.", 0)
                end
            end
        end
        return
    end

    if state == STATE_RESULT then
        result_timer = result_timer + dt
        if result_timer > 2 and input.key_pressed(" ") then
            state = STATE_BET
            bet = 0
        end
        return
    end
end

-- drawing ----------------------------------------------------------------

local CARD_W = 52
local CARD_H = 72

local function draw_card_face(x, y, card)
    -- card background
    gfx.rect(x, y, CARD_W, CARD_H, "#f5f0e8")
    gfx.rect_line(x, y, CARD_W, CARD_H, "#888888", 1)

    local col = SUIT_COLORS[card.suit]
    local suit_ch = SUIT_SYMBOLS[card.suit]

    -- rank top-left
    gfx.text(card.rank, x + 4, y + 4, col, 14)
    -- suit below rank
    gfx.text(suit_ch, x + 4, y + 18, col, 12)

    -- center rank
    gfx.text(card.rank, x + CARD_W / 2 - 6, y + CARD_H / 2 - 10, col, 20)

    -- suit bottom-right
    gfx.text(suit_ch, x + CARD_W - 16, y + CARD_H - 22, col, 12)
end

local function draw_card_back(x, y)
    gfx.rect(x, y, CARD_W, CARD_H, "#2244aa")
    gfx.rect_line(x, y, CARD_W, CARD_H, "#888888", 1)
    gfx.rect(x + 4, y + 4, CARD_W - 8, CARD_H - 8, "#1a3388")
    -- pattern
    for i = 0, 3 do
        for j = 0, 5 do
            gfx.circle(x + 12 + i * 10, y + 10 + j * 10, 2, "#3355cc")
        end
    end
end

local function draw_hand(hand, x, y, hide_first)
    for i, card in ipairs(hand) do
        local cx = x + (i - 1) * (CARD_W + 8)
        if hide_first and i == 2 then
            draw_card_back(cx, y)
        else
            draw_card_face(cx, y, card)
        end
    end
end

function _draw()
    local W = gfx.width()
    local H = gfx.height()

    gfx.clear(20, 60, 30)

    -- felt texture lines
    for i = 0, H, 20 do
        gfx.line(0, i, W, i, "rgba(0,0,0,0.05)", 1)
    end

    -- chips display
    gfx.text("Chips: " .. tostring(chips), 16, 10, "#ffd700", 16)

    if state == STATE_BET then
        if chips <= 0 then
            gfx.text("BROKE!", W / 2 - 40, H / 2 - 30, "#ff4444", 28)
            gfx.text("Press SPACE to rebuy ($100)", W / 2 - 120, H / 2 + 10, "#e8e4df", 14)
            return
        end

        gfx.text("PLACE YOUR BET", W / 2 - 80, H / 2 - 60, "#e8e4df", 20)

        -- bet options
        local opts = { { key = "1", val = 5 }, { key = "2", val = 10 }, { key = "3", val = 25 }, { key = "4", val = 50 } }
        for i, o in ipairs(opts) do
            local bx = W / 2 - 140 + (i - 1) * 75
            local by = H / 2 - 15
            local sel = (bet == o.val)
            local bg = sel and "#d4a574" or "#1a3a1a"
            local fg = sel and "#0c0b0a" or "#e8e4df"
            gfx.rect(bx, by, 65, 36, bg)
            gfx.rect_line(bx, by, 65, 36, "#8a847c", 1)
            gfx.text("[" .. o.key .. "] $" .. tostring(o.val), bx + 6, by + 10, fg, 13)
        end

        if bet > 0 then
            gfx.text("Bet: $" .. tostring(bet), W / 2 - 30, H / 2 + 40, "#ffd700", 16)
            gfx.text("Press SPACE to deal", W / 2 - 80, H / 2 + 65, "#8a847c", 13)
        end
        return
    end

    -- bet display
    if bet > 0 then
        gfx.text("Bet: $" .. tostring(bet), W - 110, 10, "#ffd700", 16)
    end

    -- dealer hand
    gfx.text("Dealer", 16, 42, "#8a847c", 14)
    local hide = not dealer_reveal
    draw_hand(dealer_hand, 16, 60, hide)
    if dealer_reveal then
        local dv = hand_value(dealer_hand)
        gfx.text(tostring(dv), 16 + #dealer_hand * (CARD_W + 8) + 10, 85, "#e8e4df", 18)
    end

    -- player hand
    gfx.text("You", 16, H - CARD_H - 38, "#8a847c", 14)
    draw_hand(player_hand, 16, H - CARD_H - 18, false)
    local pv = hand_value(player_hand)
    gfx.text(tostring(pv), 16 + #player_hand * (CARD_W + 8) + 10, H - CARD_H + 10, "#e8e4df", 18)

    -- action buttons
    if state == STATE_PLAY then
        local by = H / 2 - 10
        gfx.rect(W - 150, by, 60, 30, "#1a5a1a")
        gfx.rect_line(W - 150, by, 60, 30, "#4a8a4a", 1)
        gfx.text("[H]it", W - 142, by + 8, "#e8e4df", 14)

        gfx.rect(W - 80, by, 70, 30, "#5a1a1a")
        gfx.rect_line(W - 80, by, 70, 30, "#8a4a4a", 1)
        gfx.text("[S]tand", W - 74, by + 8, "#e8e4df", 14)

        if #player_hand == 2 then
            gfx.rect(W - 150, by + 38, 140, 26, "#3a3a1a")
            gfx.rect_line(W - 150, by + 38, 140, 26, "#8a8a4a", 1)
            gfx.text("[D]ouble Down", W - 142, by + 44, "#e8e4df", 12)
        end
    end

    -- result overlay
    if state == STATE_RESULT then
        gfx.rect(W / 2 - 130, H / 2 - 28, 260, 56, "rgba(0,0,0,0.8)")
        gfx.rect_line(W / 2 - 130, H / 2 - 28, 260, 56, "#d4a574", 2)
        gfx.text(result_text, W / 2 - 110, H / 2 - 12, "#ffd700", 18)
        if result_timer > 2 then
            gfx.text("Press SPACE to continue", W / 2 - 100, H / 2 + 40, "#8a847c", 12)
        end
    end

    -- dealer thinking
    if state == STATE_DEALER then
        gfx.text("Dealer draws...", W / 2 - 55, H / 2, "#d4a574", 14)
    end
end

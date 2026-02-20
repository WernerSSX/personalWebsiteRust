/**
 * engine.js — Browser-side Lua game runtime.
 *
 * Uses Wasmoon (Lua 5.4 compiled to WebAssembly) to run Lua game
 * scripts with a simple, PICO-8-inspired drawing and input API.
 *
 * YOUR LUA SCRIPT DEFINES THREE CALLBACKS:
 *
 *   function _init()        — called once at startup
 *   function _update(dt)    — called every frame (dt = seconds since last frame)
 *   function _draw()        — called every frame after _update
 *
 * AVAILABLE LUA FUNCTIONS:
 *
 *   Graphics (gfx):
 *     gfx.clear(r, g, b)                   — fill canvas with RGB color (0-255)
 *     gfx.rect(x, y, w, h, color)          — filled rectangle
 *     gfx.rect_line(x, y, w, h, color, lw) — outlined rectangle
 *     gfx.circle(x, y, r, color)           — filled circle
 *     gfx.circle_line(x, y, r, color, lw)  — outlined circle
 *     gfx.line(x1, y1, x2, y2, color, lw)  — line segment
 *     gfx.text(str, x, y, color, size)     — draw text
 *     gfx.width()  / gfx.height()          — canvas dimensions
 *
 *   Input:
 *     input.key(name)         — true if key is held down right now
 *     input.key_pressed(name) — true only on the frame the key went down
 *     input.mouse_x()         — mouse X relative to canvas
 *     input.mouse_y()         — mouse Y relative to canvas
 *     input.mouse_down(btn)   — true if mouse button held (0=left)
 *
 *   Color strings: any CSS color — "#ff0000", "rgb(255,0,0)",
 *   "hsl(0,100%,50%)", "red", "rgba(0,0,0,0.5)", etc.
 */

let canvas, ctx;
let luaEngine = null;
let luaState  = null;
let running   = false;
let lastTime  = 0;

// Key tracking.
const keysHeld    = new Set();
const keysPressed = new Set();
const mouseState  = { x: 0, y: 0, buttons: new Set() };

// ── Boot the engine ──────────────────────────────────────────────────

async function bootEngine(canvasId, luaSourceUrl) {
    canvas = document.getElementById(canvasId);
    ctx    = canvas.getContext("2d");

    showStatus("Loading Lua VM…");

    try {
        // Load Wasmoon from a CDN. This downloads a ~300KB WASM
        // file containing the entire Lua 5.4 interpreter. It's
        // cached by the browser after the first load.
        //
        // Wasmoon ships as a UMD bundle, so dynamic import() won't
        // produce ES named exports — instead the library registers
        // itself on the global `wasmoon` object.
        await import("https://unpkg.com/wasmoon@1.16.0/dist/index.js");
        const { LuaFactory } = globalThis.wasmoon;

        const factory = new LuaFactory();
        luaEngine = await factory.createEngine();
        luaState  = luaEngine.global;

        // Register our drawing/input API so Lua code can call it.
        registerApi();

        // Fetch the Lua source code from the server.
        showStatus("Downloading game…");
        const resp = await fetch(luaSourceUrl);
        if (!resp.ok) throw new Error("HTTP " + resp.status);
        const src = await resp.text();

        // Execute the Lua script (this defines _init, _update, _draw).
        await luaEngine.doString(src);

        // Call _init() if the script defined it.
        const initFn = luaState.get("_init");
        if (typeof initFn === "function") await initFn();

        // Hide the status overlay and start the game loop.
        showStatus(null);
        running  = true;
        lastTime = performance.now();
        requestAnimationFrame(loop);

    } catch (err) {
        showStatus("Error: " + err.message);
        console.error(err);
    }
}

// ── Game loop ────────────────────────────────────────────────────────

function loop(now) {
    if (!running) return;

    const dt = (now - lastTime) / 1000;   // Convert ms to seconds.
    lastTime = now;

    try {
        const updateFn = luaState.get("_update");
        if (typeof updateFn === "function") updateFn(dt);

        const drawFn = luaState.get("_draw");
        if (typeof drawFn === "function") drawFn();
    } catch (err) {
        showStatus("Runtime error: " + err.message);
        console.error(err);
        running = false;
        return;
    }

    // Clear the "just pressed this frame" set so key_pressed only
    // fires once per key-down event.
    keysPressed.clear();
    requestAnimationFrame(loop);
}

// ── Register the Lua API ─────────────────────────────────────────────

function registerApi() {
    // Create the `gfx` and `input` tables in Lua.
    luaEngine.doStringSync("gfx = {}");
    luaEngine.doStringSync("input = {}");

    // ── gfx functions ────────────────────────────────────────────

    luaState.set("__gfx_clear", (r, g, b) => {
        ctx.fillStyle = "rgb(" + (r||0) + "," + (g||0) + "," + (b||0) + ")";
        ctx.fillRect(0, 0, canvas.width, canvas.height);
    });
    luaEngine.doStringSync("function gfx.clear(r,g,b) __gfx_clear(r,g,b) end");

    luaState.set("__gfx_rect", (x, y, w, h, c) => {
        ctx.fillStyle = c || "#fff";
        ctx.fillRect(x, y, w, h);
    });
    luaEngine.doStringSync('function gfx.rect(x,y,w,h,c) __gfx_rect(x,y,w,h,c or "#fff") end');

    luaState.set("__gfx_rect_line", (x, y, w, h, c, lw) => {
        ctx.strokeStyle = c || "#fff";
        ctx.lineWidth = lw || 1;
        ctx.strokeRect(x, y, w, h);
    });
    luaEngine.doStringSync('function gfx.rect_line(x,y,w,h,c,lw) __gfx_rect_line(x,y,w,h,c or "#fff",lw or 1) end');

    luaState.set("__gfx_circle", (x, y, r, c) => {
        ctx.fillStyle = c || "#fff";
        ctx.beginPath();
        ctx.arc(x, y, r, 0, Math.PI * 2);
        ctx.fill();
    });
    luaEngine.doStringSync('function gfx.circle(x,y,r,c) __gfx_circle(x,y,r,c or "#fff") end');

    luaState.set("__gfx_circle_line", (x, y, r, c, lw) => {
        ctx.strokeStyle = c || "#fff";
        ctx.lineWidth = lw || 1;
        ctx.beginPath();
        ctx.arc(x, y, r, 0, Math.PI * 2);
        ctx.stroke();
    });
    luaEngine.doStringSync('function gfx.circle_line(x,y,r,c,lw) __gfx_circle_line(x,y,r,c or "#fff",lw or 1) end');

    luaState.set("__gfx_line", (x1, y1, x2, y2, c, lw) => {
        ctx.strokeStyle = c || "#fff";
        ctx.lineWidth = lw || 1;
        ctx.beginPath();
        ctx.moveTo(x1, y1);
        ctx.lineTo(x2, y2);
        ctx.stroke();
    });
    luaEngine.doStringSync('function gfx.line(x1,y1,x2,y2,c,lw) __gfx_line(x1,y1,x2,y2,c or "#fff",lw or 1) end');

    luaState.set("__gfx_text", (s, x, y, c, sz) => {
        ctx.fillStyle = c || "#fff";
        ctx.font = (sz || 16) + 'px monospace';
        ctx.textBaseline = "top";
        ctx.fillText(s, x, y);
    });
    luaEngine.doStringSync('function gfx.text(s,x,y,c,sz) __gfx_text(tostring(s),x,y,c or "#fff",sz or 16) end');

    luaState.set("__gfx_width",  () => canvas.width);
    luaState.set("__gfx_height", () => canvas.height);
    luaEngine.doStringSync("function gfx.width()  return __gfx_width()  end");
    luaEngine.doStringSync("function gfx.height() return __gfx_height() end");

    // ── input functions ──────────────────────────────────────────

    luaState.set("__input_key", (n) => keysHeld.has(n.toLowerCase()));
    luaEngine.doStringSync("function input.key(n) return __input_key(n) end");

    luaState.set("__input_key_pressed", (n) => keysPressed.has(n.toLowerCase()));
    luaEngine.doStringSync("function input.key_pressed(n) return __input_key_pressed(n) end");

    luaState.set("__input_mx", () => mouseState.x);
    luaState.set("__input_my", () => mouseState.y);
    luaEngine.doStringSync("function input.mouse_x() return __input_mx() end");
    luaEngine.doStringSync("function input.mouse_y() return __input_my() end");

    luaState.set("__input_md", (b) => mouseState.buttons.has(b));
    luaEngine.doStringSync("function input.mouse_down(b) return __input_md(b or 0) end");

    // Redirect Lua's print() to console.log.
    luaState.set("__js_print", (...args) => console.log("[lua]", ...args));
    luaEngine.doStringSync(`
        function print(...)
            local parts = {}
            for i = 1, select("#", ...) do
                parts[#parts+1] = tostring(select(i, ...))
            end
            __js_print(table.concat(parts, "\\t"))
        end
    `);
}

// ── Input event listeners ────────────────────────────────────────────

function initInput(canvasEl) {
    canvasEl.setAttribute("tabindex", "0");
    canvasEl.style.outline = "none";
    canvasEl.focus();

    canvasEl.addEventListener("keydown", (e) => {
        const k = e.key.toLowerCase();
        if (!keysHeld.has(k)) keysPressed.add(k);
        keysHeld.add(k);
        if (["arrowup","arrowdown","arrowleft","arrowright"," "].includes(k)) {
            e.preventDefault();
        }
    });

    canvasEl.addEventListener("keyup", (e) => keysHeld.delete(e.key.toLowerCase()));

    canvasEl.addEventListener("mousemove", (e) => {
        const r = canvasEl.getBoundingClientRect();
        mouseState.x = e.clientX - r.left;
        mouseState.y = e.clientY - r.top;
    });

    canvasEl.addEventListener("mousedown", (e) => {
        mouseState.buttons.add(e.button);
        canvasEl.focus();
    });

    canvasEl.addEventListener("mouseup", (e) => mouseState.buttons.delete(e.button));

    canvasEl.addEventListener("blur", () => {
        keysHeld.clear();
        keysPressed.clear();
        mouseState.buttons.clear();
    });
}

// ── Status overlay ───────────────────────────────────────────────────

function showStatus(msg) {
    const el = document.getElementById("game-status");
    if (!el) return;
    el.style.display = msg ? "flex" : "none";
    if (msg) el.textContent = msg;
}

// ── Public API ───────────────────────────────────────────────────────

window.GameEngine = { boot: bootEngine, initInput: initInput };
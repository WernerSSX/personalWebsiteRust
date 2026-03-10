# Multiplayer Macroquad Game — Implementation Guide

This guide shows how to add a multiplayer game to your website using macroquad (client) and Actix-web WebSockets (server).

---

## Architecture

```
Browser A (macroquad WASM)  ←→  Actix-web WebSocket Server  ←→  Browser B (macroquad WASM)
         |                           (your existing server)                |
     ws://wernersoon.com/ws/game/room1                    ws://wernersoon.com/ws/game/room1
```

Players connect to a shared room via WebSocket. The server relays messages between all clients in the same room. Each client runs the game locally and sends its input/state to others.

---

## Step 1: Add Dependencies

In `Cargo.toml`, add:

```toml
actix-web-actors = "4"
actix = "0.13"
serde_json = "1"
```

---

## Step 2: Create `src/ws.rs` — WebSocket Server Module

```rust
use actix::{Actor, StreamHandler, Handler, Message, Addr, AsyncContext, ActorContext};
use actix_web_actors::ws;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

// A message relayed between players
#[derive(Message, Clone)]
#[rtype(result = "()")]
pub struct GameMsg(pub String);

// Per-connection actor
pub struct WsSession {
    pub room: String,
    pub rooms: Arc<Mutex<HashMap<String, Vec<Addr<WsSession>>>>>,
}

impl Actor for WsSession {
    type Context = ws::WebsocketContext<Self>;

    fn started(&mut self, ctx: &mut Self::Context) {
        let addr = ctx.address();
        let mut rooms = self.rooms.lock().unwrap();
        rooms.entry(self.room.clone())
            .or_insert_with(Vec::new)
            .push(addr);
    }

    fn stopped(&mut self, ctx: &mut Self::Context) {
        let addr = ctx.address();
        let mut rooms = self.rooms.lock().unwrap();
        if let Some(members) = rooms.get_mut(&self.room) {
            members.retain(|a| a != &addr);
            if members.is_empty() {
                rooms.remove(&self.room);
            }
        }
    }
}

impl Handler<GameMsg> for WsSession {
    type Result = ();
    fn handle(&mut self, msg: GameMsg, ctx: &mut Self::Context) {
        ctx.text(msg.0);
    }
}

impl StreamHandler<Result<ws::Message, ws::ProtocolError>> for WsSession {
    fn handle(&mut self, msg: Result<ws::Message, ws::ProtocolError>, ctx: &mut Self::Context) {
        if let Ok(ws::Message::Text(text)) = msg {
            // Relay to all other players in the same room
            let rooms = self.rooms.lock().unwrap();
            if let Some(members) = rooms.get(&self.room) {
                let my_addr = ctx.address();
                for member in members {
                    if member != &my_addr {
                        member.do_send(GameMsg(text.to_string()));
                    }
                }
            }
        }
    }
}
```

---

## Step 3: Add WebSocket Route to `src/main.rs`

```rust
mod ws;

use actix_web::{web, HttpRequest, HttpResponse};
use actix_web_actors::ws as actix_ws;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

// Create shared room state (add to main() before HttpServer::new)
let rooms: Arc<Mutex<HashMap<String, Vec<Addr<ws::WsSession>>>>> =
    Arc::new(Mutex::new(HashMap::new()));

// WebSocket handler
async fn ws_handler(
    req: HttpRequest,
    stream: web::Payload,
    path: web::Path<String>,
    rooms: web::Data<Arc<Mutex<HashMap<String, Vec<actix::Addr<ws::WsSession>>>>>>,
) -> Result<HttpResponse, actix_web::Error> {
    let room_id = path.into_inner();
    let session = ws::WsSession {
        room: room_id,
        rooms: rooms.get_ref().clone(),
    };
    actix_ws::start(session, &req, stream)
}

// In HttpServer::new, add:
.app_data(web::Data::new(rooms.clone()))
// And in your route scope:
.route("/ws/game/{room_id}", web::get().to(ws_handler))
```

---

## Step 4: Update CSP for WebSocket

In `src/security.rs`, update `game_csp()` to allow WebSocket connections:

```rust
// Add to connect-src in game_csp():
connect-src 'self' https://cloudflareinsights.com ws://localhost:3000 wss://wernersoon.com;
```

---

## Step 5: Macroquad Client with WebSocket

Create a new macroquad game project:

```bash
cargo new multiplayer-pong
cd multiplayer-pong
```

In `Cargo.toml`:

```toml
[dependencies]
macroquad = "0.4"

[target.'cfg(target_arch = "wasm32")'.dependencies]
web-sys = { version = "0.3", features = ["WebSocket", "MessageEvent", "ErrorEvent"] }
wasm-bindgen = "0.2"
```

Basic game structure (`src/main.rs`):

```rust
use macroquad::prelude::*;

// WebSocket wrapper for WASM
#[cfg(target_arch = "wasm32")]
mod net {
    use wasm_bindgen::prelude::*;
    use web_sys::WebSocket;
    use std::cell::RefCell;
    use std::rc::Rc;

    pub struct GameSocket {
        ws: WebSocket,
        messages: Rc<RefCell<Vec<String>>>,
    }

    impl GameSocket {
        pub fn connect(url: &str) -> Self {
            let ws = WebSocket::new(url).unwrap();
            let messages = Rc::new(RefCell::new(Vec::new()));

            // Set up onmessage callback
            let msgs = messages.clone();
            let onmessage = Closure::wrap(Box::new(move |e: web_sys::MessageEvent| {
                if let Ok(text) = e.data().dyn_into::<js_sys::JsString>() {
                    msgs.borrow_mut().push(String::from(text));
                }
            }) as Box<dyn FnMut(_)>);
            ws.set_onmessage(Some(onmessage.as_ref().unchecked_ref()));
            onmessage.forget();

            GameSocket { ws, messages }
        }

        pub fn send(&self, msg: &str) {
            let _ = self.ws.send_with_str(msg);
        }

        pub fn recv(&self) -> Vec<String> {
            self.messages.borrow_mut().drain(..).collect()
        }
    }
}

#[macroquad::main("Multiplayer Pong")]
async fn main() {
    // Connect to WebSocket
    #[cfg(target_arch = "wasm32")]
    let socket = net::GameSocket::connect("ws://localhost:3000/ws/game/pong-room");

    let mut my_y: f32 = 300.0;
    let mut opponent_y: f32 = 300.0;

    loop {
        clear_background(BLACK);

        // Local input
        if is_key_down(KeyCode::W) { my_y -= 5.0; }
        if is_key_down(KeyCode::S) { my_y += 5.0; }

        // Send position to server
        #[cfg(target_arch = "wasm32")]
        {
            let msg = format!(r#"{{"y":{}}}"#, my_y);
            socket.send(&msg);

            // Receive opponent position
            for msg in socket.recv() {
                if let Ok(val) = serde_json::from_str::<serde_json::Value>(&msg) {
                    if let Some(y) = val["y"].as_f64() {
                        opponent_y = y as f32;
                    }
                }
            }
        }

        // Draw paddles
        draw_rectangle(20.0, my_y - 40.0, 10.0, 80.0, WHITE);      // left
        draw_rectangle(770.0, opponent_y - 40.0, 10.0, 80.0, WHITE); // right

        next_frame().await
    }
}
```

---

## Step 6: Build and Deploy

```bash
# Build the WASM binary
cargo build --target wasm32-unknown-unknown --release

# Copy files to your website's static directory
mkdir -p static/games/multiplayer-pong
cp target/wasm32-unknown-unknown/release/multiplayer_pong.wasm static/games/multiplayer-pong/

# You also need the macroquad JS loader (same mq_js_bundle.js used by your pong game)
cp static/games/pong/mq_js_bundle.js static/games/multiplayer-pong/
```

Create `static/games/multiplayer-pong/index.html`:

```html
<!DOCTYPE html>
<html><head><meta charset="utf-8"></head>
<body style="margin:0; background:#000;">
<canvas id="glcanvas" tabindex="1" style="width:100%;height:100%;"></canvas>
<script src="../mq_js_bundle.js"></script>
<script src="boot.js"></script>
</body></html>
```

Create `static/games/multiplayer-pong/boot.js`:

```js
load("multiplayer_pong.wasm");
```

---

## Step 7: Register the Game

In `src/games.rs`, add:

```rust
Game {
    title: "Multiplayer Pong".to_string(),
    slug: "multiplayer-pong".to_string(),
    summary: "Play pong with a friend! Share the URL to play together.".to_string(),
},
```

---

## Step 8: Caddy Configuration

Caddy automatically proxies WebSocket connections — no changes needed to your Caddyfile. The `reverse_proxy localhost:3000` directive already handles the `Upgrade: websocket` header.

---

## Message Protocol

Use simple JSON messages between clients:

```json
// Player move
{ "type": "move", "y": 250.5 }

// Ball state (if one client is authoritative)
{ "type": "ball", "x": 400, "y": 200, "vx": 3, "vy": -2 }

// Score update
{ "type": "score", "left": 2, "right": 1 }
```

---

## Alternative: Matchbox P2P

If you prefer peer-to-peer (no server relay), use [matchbox](https://github.com/johanhelsing/matchbox):

```toml
matchbox_socket = "0.10"
```

Matchbox uses WebRTC with a lightweight signaling server. Better for latency-sensitive games, but requires running a separate signaling server (or using a hosted one). The Actix-web WebSocket approach above is simpler since it reuses your existing server.

---

## Summary

| Component | File | Purpose |
|-----------|------|---------|
| WebSocket server | `src/ws.rs` | Room management, message relay |
| WebSocket route | `src/main.rs` | `/ws/game/{room_id}` endpoint |
| CSP update | `src/security.rs` | Allow `ws://` and `wss://` in connect-src |
| Game client | `multiplayer-pong/` | Macroquad game with WebSocket networking |
| Game loader | `static/games/multiplayer-pong/` | WASM + HTML wrapper |
| Game registry | `src/games.rs` | Add game entry |

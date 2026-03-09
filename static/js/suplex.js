/**
 * suplex.js — A pixel-art animation of a character suplexing a train.
 * Inspired by FFVI's iconic Sabin Phantom Train suplex scene.
 *
 * Draws on a <canvas> element using simple pixel-grid sprites.
 * Call initSuplex("canvas-id") to start the animation.
 */

function initSuplex(canvasId) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) return;

    const ctx = canvas.getContext("2d");
    const W = canvas.width;
    const H = canvas.height;
    const S = 3; // pixel scale factor

    // ── Color palette ──────────────────────────────────────────
    const C = {
        _: null,         // transparent
        K: "#1a1a2e",    // black/outline
        S: "#f5c542",    // skin
        H: "#e6a800",    // hair (blonde)
        B: "#2563eb",    // blue (outfit)
        D: "#1d4ed8",    // dark blue
        W: "#ffffff",    // white
        G: "#6b7280",    // grey (train body)
        T: "#374151",    // dark grey (train detail)
        R: "#dc2626",    // red (train accent)
        Y: "#f59e0b",    // yellow (headlight/sparks)
        L: "#9ca3af",    // light grey (wheels)
        F: "#f97316",    // flash/impact orange
    };

    // ── Character sprite (12w × 16h) ───────────────────────────
    // Standing pose
    const charStand = [
        "____HHHH____",
        "___HHHHHH___",
        "__HHSSSHH___",
        "__HSSWSSH___",
        "__HSSSSSH___",
        "___SSSSS____",
        "____BBB_____",
        "___BBBBB____",
        "__SBBBBBS___",
        "__S_BBB_S___",
        "____BBB_____",
        "____B_B_____",
        "___BB_BB____",
        "___BB_BB____",
        "___KK_KK____",
        "___KK_KK____",
    ];

    // Walk frame 1
    const charWalk1 = [
        "____HHHH____",
        "___HHHHHH___",
        "__HHSSSHH___",
        "__HSSWSSH___",
        "__HSSSSSH___",
        "___SSSSS____",
        "____BBB_____",
        "___BBBBB____",
        "__SBBBBBS___",
        "__S_BBB_S___",
        "____BBB_____",
        "___B___B____",
        "__BB____BB__",
        "__KK____KK__",
        "____________",
        "____________",
    ];

    // Walk frame 2
    const charWalk2 = [
        "____HHHH____",
        "___HHHHHH___",
        "__HHSSSHH___",
        "__HSSWSSH___",
        "__HSSSSSH___",
        "___SSSSS____",
        "____BBB_____",
        "___BBBBB____",
        "__SBBBBBS___",
        "__S_BBB_S___",
        "____BBB_____",
        "____B_B_____",
        "____B_B_____",
        "___KK_KK____",
        "____________",
        "____________",
    ];

    // Arms up (lifting)
    const charLift = [
        "__S_HHHH_S__",
        "__S_HHHH_S__",
        "__SHHSSSH_S_",
        "__SHSSWSSH__",
        "___HSSSSSH__",
        "____SSSSS___",
        "____BBB_____",
        "____BBBBB___",
        "____BBBBB___",
        "____BBB_____",
        "____BBB_____",
        "____B_B_____",
        "___BB_BB____",
        "___BB_BB____",
        "___KK_KK____",
        "___KK_KK____",
    ];

    // ── Train sprite (26w × 12h) ──────────────────────────────
    const train = [
        "__TTTTTTTTTTTTTTTTTTTTTTTT__",
        "_TRRRRRRRRRRRRRRRRRRRRRRRT_",
        "TGGGGGGGGGGGGGGGGGGGGGGGGGT",
        "TGGGTTTGGGGTTTGGGGTTTGGGGT_",
        "TGGGTTTGGGGTTTGGGGTTTGGGGT_",
        "TGGGGGGGGGGGGGGGGGGGGGGGGGT",
        "TTTTTTTTTTTTTTTTTTTTTTTTTTT",
        "YTKKKKKKKKKKKKKKKKKKKKKKKTY",
        "__TTTTTTTTTTTTTTTTTTTTTTT__",
        "__L_LL___LL____LL___LL_L__",
        "___LLLL_LLLL__LLLL_LLLL___",
        "____LL___LL____LL___LL____",
    ];

    // ── Parse a sprite string grid into pixel data ─────────────
    function parseSprite(rows) {
        return rows.map(function(row) {
            var pixels = [];
            for (var i = 0; i < row.length; i++) {
                pixels.push(row[i]);
            }
            return pixels;
        });
    }

    // ── Draw a sprite at (x, y) with scale S ──────────────────
    function drawSprite(sprite, x, y, flipX) {
        var parsed = parseSprite(sprite);
        for (var row = 0; row < parsed.length; row++) {
            for (var col = 0; col < parsed[row].length; col++) {
                var ch = parsed[row][col];
                var color = C[ch];
                if (!color) continue;
                ctx.fillStyle = color;
                var px = flipX ? x + (parsed[row].length - 1 - col) * S : x + col * S;
                ctx.fillRect(px, y + row * S, S, S);
            }
        }
    }

    // ── Draw ground line ───────────────────────────────────────
    function drawGround(groundY) {
        ctx.fillStyle = "#d1d5db";
        ctx.fillRect(0, groundY, W, 2);
    }

    // ── Animation state ────────────────────────────────────────
    var phase = 0;        // 0=run, 1=grab, 2=lift, 3=suplex arc, 4=impact, 5=pause
    var tick = 0;
    var charX = -40;
    var charY = 0;
    var trainX = 0;
    var trainY = 0;
    var trainAngle = 0;
    var groundY = H - 30;
    var flashAlpha = 0;

    // Train resting position
    var trainRestX = W * 0.5;
    var trainRestY = groundY - 12 * S;

    // Character target X (to the left of the train)
    var charTargetX = trainRestX - 16 * S;

    // ── Main animation loop ────────────────────────────────────
    function frame() {
        ctx.clearRect(0, 0, W, H);
        drawGround(groundY);

        tick++;

        if (phase === 0) {
            // ── Phase 0: Character runs toward train ───────────
            charX += 2.5;
            charY = groundY - 16 * S;
            trainX = trainRestX;
            trainY = trainRestY;

            var walkFrame = (Math.floor(tick / 6) % 2 === 0) ? charWalk1 : charWalk2;
            drawSprite(train, trainX, trainY, false);
            drawSprite(walkFrame, charX, charY, false);

            if (charX >= charTargetX) {
                charX = charTargetX;
                phase = 1;
                tick = 0;
            }
        } else if (phase === 1) {
            // ── Phase 1: Grab (brief pause) ────────────────────
            drawSprite(train, trainRestX, trainRestY, false);
            drawSprite(charStand, charX, groundY - 16 * S, false);

            if (tick > 30) {
                phase = 2;
                tick = 0;
            }
        } else if (phase === 2) {
            // ── Phase 2: Lift train overhead ───────────────────
            var liftProgress = Math.min(tick / 40, 1);
            var liftHeight = liftProgress * 14 * S;

            trainX = trainRestX;
            trainY = trainRestY - liftHeight;

            drawSprite(train, trainX, trainY, false);
            drawSprite(charLift, charX, groundY - 16 * S, false);

            if (liftProgress >= 1) {
                phase = 3;
                tick = 0;
            }
        } else if (phase === 3) {
            // ── Phase 3: Suplex arc ────────────────────────────
            var arcProgress = Math.min(tick / 35, 1);
            // Character and train arc over
            var angle = arcProgress * Math.PI;
            var arcRadius = 12 * S;

            // Pivot point above character's head
            var pivotX = charX + 6 * S;
            var pivotY = groundY - 16 * S - 12 * S;

            // Train follows arc from above to behind
            trainX = pivotX + Math.sin(angle) * 8 * S;
            trainY = pivotY - Math.cos(angle) * arcRadius;

            // Character stays, but leans back
            var charDrawX = charX - arcProgress * 3 * S;
            drawSprite(charLift, charDrawX, groundY - 16 * S, false);

            // Draw train rotated conceptually (we just move it in the arc)
            drawSprite(train, trainX, trainY, false);

            if (arcProgress >= 1) {
                phase = 4;
                tick = 0;
                flashAlpha = 1.0;
            }
        } else if (phase === 4) {
            // ── Phase 4: Impact flash ──────────────────────────
            flashAlpha = Math.max(0, 1.0 - tick / 15);

            // Train on ground (crashed)
            trainX = charX + 6 * S + 8 * S;
            trainY = groundY - 12 * S;
            drawSprite(train, trainX, trainY, false);

            // Character standing victorious
            drawSprite(charStand, charX - 3 * S, groundY - 16 * S, false);

            // White flash overlay
            if (flashAlpha > 0) {
                ctx.fillStyle = "rgba(255, 255, 255, " + flashAlpha + ")";
                ctx.fillRect(0, 0, W, H);
            }

            // Draw impact sparks
            if (tick < 12) {
                ctx.fillStyle = C.Y;
                for (var i = 0; i < 6; i++) {
                    var sparkX = trainX + Math.random() * 26 * S;
                    var sparkY = trainY + Math.random() * 12 * S;
                    ctx.fillRect(sparkX, sparkY, S * 2, S);
                }
            }

            if (tick > 60) {
                phase = 5;
                tick = 0;
            }
        } else if (phase === 5) {
            // ── Phase 5: Pause then reset ──────────────────────
            trainX = charX + 6 * S + 8 * S;
            trainY = groundY - 12 * S;
            drawSprite(train, trainX, trainY, false);
            drawSprite(charStand, charX - 3 * S, groundY - 16 * S, false);

            if (tick > 90) {
                // Reset everything
                phase = 0;
                tick = 0;
                charX = -40;
                flashAlpha = 0;
            }
        }

        requestAnimationFrame(frame);
    }

    requestAnimationFrame(frame);
}

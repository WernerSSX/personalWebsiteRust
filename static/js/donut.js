/**
 * donut.js — A 3D spinning donut rendered to an HTML canvas.
 *
 * Based on the famous "donut math" by Andy Sloane, adapted to draw
 * on a <canvas> element with smooth shading and color.
 */

// This function initializes the donut and starts the animation loop.
// It's called from the HTML template once the page loads.
function initDonut(canvasId) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) return;

    const ctx = canvas.getContext("2d");
    const width = canvas.width;
    const height = canvas.height;

    // Rotation angles — these increase every frame to spin the donut.
    let A = 0;   // Rotation around the X axis
    let B = 0;   // Rotation around the Z axis

    // Donut geometry parameters.
    const R1 = 1.0;    // Radius of the tube (the small circle)
    const R2 = 2.0;    // Radius of the ring (the large circle)
    const K2 = 5.0;    // Distance from the viewer to the donut

    // K1 controls how large the donut appears on screen.
    // It's derived from the canvas size so the donut fills the space.
    const K1 = width * K2 * 3 / (8 * (R1 + R2));

    // ── The rendering function (called every frame) ──────────────
    function frame() {
        // Clear the canvas to a fully transparent state, so the
        // page background shows through.
        ctx.clearRect(0, 0, width, height);

        // A "z-buffer" tracks the depth of the closest point at each
        // pixel. If a new point is closer than what's already drawn,
        // we overwrite it. This handles occlusion (the front of the
        // donut hides the back).
        const zBuffer = new Float32Array(width * height);

        // Precompute the sines and cosines of the rotation angles.
        // Calling Math.sin/cos is expensive, and we use these values
        // many times, so computing them once saves a lot of work.
        const sinA = Math.sin(A), cosA = Math.cos(A);
        const sinB = Math.sin(B), cosB = Math.cos(B);

        // ── Sample points on the donut surface ───────────────────
        // theta goes around the tube cross-section.
        for (let theta = 0; theta < 6.28; theta += 0.07) {
            const sinT = Math.sin(theta), cosT = Math.cos(theta);

            // phi goes around the ring.
            for (let phi = 0; phi < 6.28; phi += 0.02) {
                const sinP = Math.sin(phi), cosP = Math.cos(phi);

                // ── Compute the 3D position of this point ────────
                // Start with a circle of radius R1 in the xz-plane,
                // centered at distance R2 from the origin.
                const circleX = R2 + R1 * cosT;
                const circleY = R1 * sinT;

                // Rotate by phi around the Y axis (this sweeps the
                // tube around the ring to form the torus).
                // Then rotate by A around the X axis and B around
                // the Z axis (this tumbles the whole donut).
                const x = circleX * (cosB * cosP + sinA * sinB * sinP)
                        - circleY * cosA * sinB;
                const y = circleX * (sinB * cosP - sinA * cosB * sinP)
                        + circleY * cosA * cosB;
                const z = K2 + cosA * circleX * sinP + circleY * sinA;

                // ── Project to 2D screen coordinates ─────────────
                const ooz = 1 / z;   // "one over z" — the perspective divide
                const xp = Math.floor(width / 2 + K1 * ooz * x);
                const yp = Math.floor(height / 2 - K1 * ooz * y);

                // ── Compute lighting ─────────────────────────────
                // The surface normal at this point, after rotation,
                // dotted with a light direction pointing roughly
                // toward the viewer and slightly up-left.
                const L = cosP * cosT * sinB
                        - cosA * cosT * sinP
                        - sinA * sinT
                        + cosB * (cosA * sinT - cosT * sinA * sinP);

                // Only draw if the point is on the lit side (L > 0)
                // and within canvas bounds.
                if (L > 0 && xp >= 0 && xp < width && yp >= 0 && yp < height) {
                    const idx = xp + yp * width;

                    // Z-buffer test: only draw if this point is
                    // closer than whatever was previously at this pixel.
                    if (ooz > zBuffer[idx]) {
                        zBuffer[idx] = ooz;

                        // Map the brightness (0 to ~1) to a color.
                        // We'll use a warm amber tone that matches
                        // the site's accent color.
                        const brightness = L * 0.8;  // scale down slightly
                        const r = Math.floor(212 * brightness);
                        const g = Math.floor(165 * brightness);
                        const b = Math.floor(116 * brightness);

                        ctx.fillStyle = `rgb(${r},${g},${b})`;
                        ctx.fillRect(xp, yp, 1.5, 1.5);
                    }
                }
            }
        }

        // Increment the rotation angles for the next frame.
        A += 0.025;
        B += 0.015;

        // Request the next frame. The browser calls `frame()` again
        // at ~60fps. This is much better than setInterval because it
        // pauses when the tab is hidden, saving CPU.
        requestAnimationFrame(frame);
    }

    // Start the animation.
    requestAnimationFrame(frame);
}
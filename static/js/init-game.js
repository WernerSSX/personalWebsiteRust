document.addEventListener("DOMContentLoaded", function() {
    var status = document.getElementById("game-status");
    var canvas = document.getElementById("game-canvas");

    if (!status || !canvas) return;

    status.addEventListener("click", function() {
        status.textContent = "Loading…";
        GameEngine.initInput(canvas);

        // The slug is embedded in the page URL.
        // /games/pong → source URL is /games/pong/source
        var slug = window.location.pathname.split("/").pop();
        GameEngine.boot("game-canvas", "/games/" + slug + "/source");
    }, { once: true });
});
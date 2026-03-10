document.addEventListener("DOMContentLoaded", function () {
    var btn = document.getElementById("nav-hamburger");
    var nav = document.getElementById("side-nav");
    if (!btn || !nav) return;

    btn.addEventListener("click", function () {
        nav.classList.toggle("open");
        btn.textContent = nav.classList.contains("open") ? "\u2715" : "\u2630";
    });

    // Close nav when clicking outside on mobile
    document.addEventListener("click", function (e) {
        if (!nav.contains(e.target) && e.target !== btn && nav.classList.contains("open")) {
            nav.classList.remove("open");
            btn.textContent = "\u2630";
        }
    });
});

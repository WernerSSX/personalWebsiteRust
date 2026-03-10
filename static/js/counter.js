document.addEventListener("DOMContentLoaded", function () {
    var display = document.getElementById("counter-display");
    var btn = document.getElementById("counter-btn");
    if (!display || !btn) return;

    var count = parseInt(localStorage.getItem("counter") || "0", 10);
    display.textContent = count;

    btn.addEventListener("click", function () {
        count++;
        display.textContent = count;
        localStorage.setItem("counter", count);

        // Quick press animation
        btn.style.transform = "translateY(4px)";
        btn.style.boxShadow = "0 0 0 #1d4ed8, 0 2px 6px rgba(0,0,0,0.2)";
        setTimeout(function () {
            btn.style.transform = "";
            btn.style.boxShadow = "";
        }, 100);
    });
});

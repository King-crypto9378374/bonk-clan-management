
// BCMS - Bonk.io Clan Management System

document.addEventListener("DOMContentLoaded", () => {
  console.log("BCMS successfully loaded.");

  // Smooth navigation
  document.querySelectorAll('a[href^="#"]').forEach(link => {
    link.addEventListener("click", event => {
      const target = document.querySelector(link.getAttribute("href"));

      if (target) {
        event.preventDefault();
        target.scrollIntoView({ behavior: "smooth" });
      }
    });
  });
});

// Copy buttons, and this year in the footer.
document.querySelectorAll("[data-copy]").forEach((button) => {
  button.addEventListener("click", async () => {
    const text = document.getElementById(button.dataset.copy)?.textContent ?? "";
    try {
      await navigator.clipboard.writeText(text);
      button.textContent = "Copied";
    } catch {
      button.textContent = "Select and copy";
    }
    setTimeout(() => (button.textContent = "Copy"), 1600);
  });
});
const year = document.getElementById("year");
if (year) year.textContent = String(new Date().getFullYear());

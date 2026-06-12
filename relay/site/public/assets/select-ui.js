(() => {
  function closeAll(except) {
    document.querySelectorAll(".custom-select.open").forEach((el) => {
      if (el !== except) el.classList.remove("open");
    });
  }

  function enhanceSelect(select) {
    if (!select || select.dataset.enhanced === "1") return;
    select.dataset.enhanced = "1";

    const wrap = select.closest(".select-wrap") || select.parentElement;
    if (!wrap) return;
    wrap.classList.add("select-wrap-enhanced");

    const shell = document.createElement("div");
    shell.className = "custom-select";

    const trigger = document.createElement("button");
    trigger.type = "button";
    trigger.className = "custom-select-trigger";
    trigger.setAttribute("aria-haspopup", "listbox");

    const menu = document.createElement("div");
    menu.className = "custom-select-menu";
    menu.setAttribute("role", "listbox");

    select.classList.add("custom-select-native");
    select.tabIndex = -1;

    function labelFor(value) {
      const opt = [...select.options].find((o) => o.value === value);
      return opt ? opt.textContent : "Select…";
    }

    function rebuildMenu() {
      menu.innerHTML = "";
      [...select.options].forEach((opt) => {
        const item = document.createElement("button");
        item.type = "button";
        item.className = "custom-select-option";
        item.dataset.value = opt.value;
        item.textContent = opt.textContent;
        item.setAttribute("role", "option");
        item.setAttribute("aria-selected", opt.selected ? "true" : "false");
        if (opt.selected) item.classList.add("selected");
        item.addEventListener("click", (e) => {
          e.stopPropagation();
          select.value = opt.value;
          select.dispatchEvent(new Event("change", { bubbles: true }));
          sync();
          shell.classList.remove("open");
        });
        menu.appendChild(item);
      });
    }

    function sync() {
      trigger.textContent = labelFor(select.value);
      menu.querySelectorAll(".custom-select-option").forEach((el) => {
        const on = el.dataset.value === select.value;
        el.classList.toggle("selected", on);
        el.setAttribute("aria-selected", on ? "true" : "false");
      });
    }

    trigger.addEventListener("click", (e) => {
      e.stopPropagation();
      const open = shell.classList.toggle("open");
      if (open) closeAll(shell);
    });

    select.addEventListener("change", sync);
    rebuildMenu();
    sync();

    shell.appendChild(trigger);
    shell.appendChild(menu);
    wrap.appendChild(shell);
  }

  document.addEventListener("click", () => closeAll(null));

  window.AlleralSelect = {
    enhance(root = document) {
      root.querySelectorAll("select.field-select").forEach(enhanceSelect);
    },
    refresh(selectEl) {
      if (!selectEl) return;
      const wrap = selectEl.closest(".select-wrap-enhanced");
      const shell = wrap?.querySelector(".custom-select");
      if (shell) {
        shell.remove();
        selectEl.dataset.enhanced = "0";
        selectEl.classList.remove("custom-select-native");
      }
      enhanceSelect(selectEl);
    },
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", () => window.AlleralSelect.enhance());
  } else {
    window.AlleralSelect.enhance();
  }
})();

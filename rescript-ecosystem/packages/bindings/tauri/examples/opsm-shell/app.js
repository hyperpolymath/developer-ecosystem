const modeSelect = document.getElementById("mode");
const input = document.querySelector(".input");
const planPanel = document.querySelector(".plan");
const planButton = document.querySelector(".panel-footer button");
const capabilities = document.querySelector(".cap-list");
const cliOutput = document.querySelector(".cli-output");

const backendStatus = {
  "rpm-ostree": "unknown",
  toolbox: "unknown",
  distrobox: "unknown",
  container: "unknown",
  native: "available",
  git: "available",
  source: "available",
  auto: "unknown",
};

async function detectBackends() {
  if (!window.__TAURI__ || !window.__TAURI__.invoke) {
    return;
  }
  const keys = Object.keys(backendStatus);
  for (const key of keys) {
    try {
      const status = await window.__TAURI__.invoke("check_backend", { backend: key });
      backendStatus[key] = status;
    } catch (err) {
      backendStatus[key] = "unknown";
    }
  }
}

function renderCapabilities() {
  const entries = Object.entries(backendStatus)
    .filter(([, status]) => status === "available")
    .map(([backend]) => backend);
  capabilities.textContent = entries.length ? entries.join(", ") : "none detected";
}

function setMode(value) {
  document.body.setAttribute("data-mode", value);
  modeSelect.value = value;
}

function tokenizePlan(text) {
  const tokens = [];
  let current = "";
  let inBracket = false;

  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (ch === "[") {
      if (current.trim()) {
        tokens.push(current.trim());
      }
      current = "";
      inBracket = true;
      continue;
    }
    if (ch === "]") {
      if (current.trim()) {
        tokens.push("[" + current.trim() + "]");
      }
      current = "";
      inBracket = false;
      continue;
    }
    if (!inBracket && /\s/.test(ch)) {
      if (current.trim()) {
        tokens.push(current.trim());
        current = "";
      }
      continue;
    }
    current += ch;
  }
  if (current.trim()) {
    tokens.push(inBracket ? "[" + current.trim() + "]" : current.trim());
  }
  return tokens;
}

function parsePlan(text) {
  const backends = new Set([
    "rpm-ostree",
    "toolbox",
    "distrobox",
    "container",
    "native",
    "git",
    "source",
    "auto",
  ]);

  const tokens = tokenizePlan(text);
  let current = "auto";
  const plan = {};

  tokens.forEach((token) => {
    if (token.startsWith("[") && token.endsWith("]")) {
      const inner = token.slice(1, -1).trim();
      const parts = inner.split(":");
      const backend = parts[0].toLowerCase();
      const resolved = backends.has(backend) ? backend : "auto";
      const rest = parts.slice(1).join(":").trim();
      if (rest.length > 0) {
        rest.split(/\s+/).forEach((pkg) => {
          if (!pkg) return;
          plan[resolved] = plan[resolved] || [];
          plan[resolved].push(pkg);
        });
      }
      current = resolved;
      return;
    }

    const parts = token.split(":");
    if (parts.length > 1) {
      const backend = parts[0].toLowerCase();
      const rest = parts.slice(1).join(":").trim();
      const resolved = backends.has(backend) ? backend : "auto";
      if (rest.length === 0) {
        current = resolved;
        return;
      }
      plan[resolved] = plan[resolved] || [];
      plan[resolved].push(rest);
      current = resolved;
      return;
    }

    const target = current || "auto";
    plan[target] = plan[target] || [];
    plan[target].push(token);
  });

  return plan;
}

function renderPlan(plan) {
  planPanel.innerHTML = "";
  const entries = Object.entries(plan);
  if (entries.length === 0) {
    planPanel.innerHTML = "<div>No items parsed.</div>";
    return;
  }
  entries.forEach(([backend, pkgs]) => {
    const status = backendStatus[backend] || "unknown";
    const row = document.createElement("div");
    row.innerHTML = `
      <strong>${backend}:</strong> ${pkgs.join(", ")}
      <span class="status status-${status}">${status}</span>
    `;
    planPanel.appendChild(row);
  });
}

async function runCliDryRun() {
  if (!window.__TAURI__ || !window.__TAURI__.invoke) {
    cliOutput.textContent = "CLI integration requires Tauri.";
    return;
  }
  const text = input.value || "";
  try {
    const output = await window.__TAURI__.invoke("opsm_dry_run", { args: text });
    cliOutput.textContent = output;
  } catch (err) {
    cliOutput.textContent = String(err);
  }
}

modeSelect.addEventListener("change", (event) => {
  setMode(event.target.value);
});

planButton.addEventListener("click", async () => {
  await detectBackends();
  renderCapabilities();
  const text = input.value || "";
  const plan = parsePlan(text);
  renderPlan(plan);
  await runCliDryRun();
});

// Optional Tauri menu integration
if (window.__TAURI__ && window.__TAURI__.event) {
  window.__TAURI__.event.listen("opsm:mode", (event) => {
    if (event && event.payload) {
      setMode(event.payload);
    }
  });

  window.__TAURI__.event.listen("opsm:dry-run", () => {
    if (input) {
      input.focus();
    }
  });
}

// initial capabilities render
renderCapabilities();

async function startupDetect() {
  await detectBackends();
  renderCapabilities();
}

startupDetect();

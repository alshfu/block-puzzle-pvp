import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./ui/App";
import "./ui/styles.css";
import { isPilotEnabled } from "./ui/pilot/flag";

const root = document.getElementById("root");
if (!root) throw new Error("Missing #root in index.html");
createRoot(root).render(
  <StrictMode>
    <App />
  </StrictMode>
);

// UI-пилот для E2E-тестирования. Активируется через ?pilot=1 в URL.
// Lazy-import: в обычной prod-сборке весь pilot-модуль не попадает в bundle.
if (isPilotEnabled()) {
  void import("./ui/pilot").then((m) => m.initPilot());
}

import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import pkg from "./package.json";

// На GitHub Pages сайт лежит по адресу /block-puzzle-pvp/, а в dev-сервере — на /.
export default defineConfig(({ command }) => ({
  plugins: [react()],
  base: command === "build" ? "/block-puzzle-pvp/" : "/",
  define: {
    // Версия из package.json пробрасывается в код — Settings → About.
    __APP_VERSION__: JSON.stringify(pkg.version),
  },
  server: {
    port: 5173,
    open: false,
  },
  build: {
    rollupOptions: {
      output: {
        // Vite 8 (Rolldown) принимает только функциональную форму manualChunks.
        manualChunks(id) {
          if (/node_modules\/(react|react-dom|scheduler)\//.test(id)) return "react";
          return undefined;
        },
      },
    },
  },
}));

import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// На GitHub Pages сайт лежит по адресу /block-puzzle-pvp/, а в dev-сервере — на /.
export default defineConfig(({ command }) => ({
  plugins: [react()],
  base: command === "build" ? "/block-puzzle-pvp/" : "/",
  server: {
    port: 5173,
    open: false,
  },
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          react: ["react", "react-dom"],
        },
      },
    },
  },
}));

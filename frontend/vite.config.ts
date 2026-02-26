import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    proxy: {
      "/auth": { target: "http://auth:8001", changeOrigin: true },
      "/catalog": { target: "http://catalog:8002", changeOrigin: true },
      "/orders": { target: "http://orders:8003", changeOrigin: true },
    },
  },
  build: {
    outDir: "dist",
  },
});

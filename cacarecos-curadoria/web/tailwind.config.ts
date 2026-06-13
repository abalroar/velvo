import type { Config } from "tailwindcss";

// Paleta herdada do estudo do antoniooo.com: monocromia editorial, a cor vem das peças.
const config: Config = {
  content: ["./app/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        tinta: "#0a0a0a",
        papel: "#ffffff",
        nevoa: "#fafafa",
        linha: "#e5e5e5",
        esgotado: "#999999",
        keep: "#1a7f5a",
        pass: "#b23b3b",
        maybe: "#b8860b",
      },
      fontFamily: {
        sans: ["'Golos Text'", "system-ui", "sans-serif"],
      },
    },
  },
  plugins: [],
};
export default config;

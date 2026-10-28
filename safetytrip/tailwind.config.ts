import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        brand: { DEFAULT: "#1f6feb", ink: "#0b2e63" },
      },
    },
  },
  plugins: [],
};

export default config;

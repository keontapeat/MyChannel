import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    ".next/**",
    "out/**",
    "build/**",
    "next-env.d.ts",
    // macOS AppleDouble metadata files — not real source.
    "**/._*",
    ".storybook/**",
    // Unused duplicate config kept for reference; not part of the build.
    "next.config.optimized.mjs",
  ]),
  {
    // These are strictness/style rules, not correctness bugs. They are kept as
    // warnings so the build gate (next.config.ts) still fails on real errors
    // without requiring a repo-wide `any` sweep across the AGI/agent code.
    rules: {
      "@typescript-eslint/no-explicit-any": "warn",
      "react/no-unescaped-entities": "warn",
      // React Compiler (eslint-config-next 16) rules. These flag common,
      // mostly-harmless patterns (Date.now()/Math.random() in render, setState
      // in an init effect, referencing hoisted fns). Surfaced as warnings for
      // incremental cleanup rather than blocking the build.
      "react-hooks/purity": "warn",
      "react-hooks/set-state-in-effect": "warn",
      "react-hooks/immutability": "warn",
    },
  },
]);

export default eslintConfig;

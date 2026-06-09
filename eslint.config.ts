import { configDirFromImportMetaUrl, core } from "@chiubaka/eslint-config";
import type { Linter } from "eslint";

const configDir = configDirFromImportMetaUrl(import.meta.url);

const config: Linter.Config[] = [
  {
    ignores: ["node_modules/**"],
  },
  ...(core as Linter.Config[]),
  {
    files: ["eslint.config.ts"],
    languageOptions: {
      parserOptions: {
        tsconfigRootDir: configDir,
        project: "./tsconfig.eslint.json",
      },
    },
    rules: {
      // simple-import-sort uses context.getSourceCode(), which ESLint 10 removed.
      "simple-import-sort/exports": "off",
      "simple-import-sort/imports": "off",
    },
  },
];

/** Default export required by ESLint flat config loader. */
// eslint-disable-next-line import/no-default-export
export default config;

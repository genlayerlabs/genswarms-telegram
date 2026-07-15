import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import tags from "../priv/preview/tags.mjs";

test("tags.json is the generated twin of tags.mjs", () => {
  const json = JSON.parse(
    readFileSync(fileURLToPath(new URL("../priv/tags.json", import.meta.url)), "utf8")
  );
  assert.deepEqual(json, JSON.parse(JSON.stringify(tags)));
});

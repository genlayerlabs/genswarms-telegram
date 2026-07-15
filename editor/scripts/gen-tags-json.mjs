import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import tags from "../priv/preview/tags.mjs";

const out = fileURLToPath(new URL("../priv/tags.json", import.meta.url));
writeFileSync(out, JSON.stringify(tags, null, 2) + "\n");
console.log(`wrote ${out}`);

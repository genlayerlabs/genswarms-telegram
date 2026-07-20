import test from "node:test";
import assert from "node:assert/strict";
import { buildRenderRequest, applyRenderResponse } from "../priv/preview/editor_shell.mjs";

test("buildRenderRequest parses card JSON", () => {
  const req = buildRenderRequest('{"blocks":[{"kind":"paragraph","text":"hi"}]}');
  assert.equal(req.ok, true);
  assert.deepEqual(JSON.parse(req.body).card.blocks[0].kind, "paragraph");
});

test("buildRenderRequest reports parse errors without throwing", () => {
  const req = buildRenderRequest("{nope");
  assert.equal(req.ok, false);
  assert.match(req.error, /JSON/);
});

test("applyRenderResponse renders html and clears errors on success", () => {
  const out = applyRenderResponse({ ok: true, html: "<p>x</p>", buttons: [] });
  assert.ok(out.html.includes("<p>x</p>"));
  assert.equal(out.errorsHtml, "");
});

test("applyRenderResponse renders path-oriented errors", () => {
  const out = applyRenderResponse({
    ok: false,
    errors: [{ path: "card.blocks[0].url", reason: "media URL must be http or https" }]
  });
  assert.equal(out.html, null);
  assert.ok(out.errorsHtml.includes("card.blocks[0].url"));
  assert.ok(out.errorsHtml.includes("media URL must be http or https"));
});

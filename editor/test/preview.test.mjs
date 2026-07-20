import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import tags from "../priv/preview/tags.mjs";
import { renderPreviewHtml, CLASSIC_TAGS } from "../priv/preview/telegram_preview.mjs";

const fixtures = JSON.parse(
  readFileSync(fileURLToPath(new URL("./fixtures/examples.json", import.meta.url)), "utf8")
);

test("round-trip: every example renders with zero escaped-fallback tags", () => {
  for (const fixture of fixtures) {
    const out = renderPreviewHtml(fixture.html, { profile: "rich" });
    // An unhandled tag would surface as visible escaped markup: &lt;tag
    const leaked = out.match(/&lt;[a-zA-Z][a-zA-Z0-9-]*/g) || [];
    assert.deepEqual(leaked, [], `${fixture.name} leaked: ${leaked.join(", ")}`);
  }
});

test("contract: every element in tags.mjs has a rendering rule", () => {
  const all = [...tags.block_elements, ...tags.inline_elements, ...tags.void_elements];
  for (const name of all) {
    const probe =
      tags.void_elements.includes(name) ? `<${name}/>` : `<${name}>x</${name}>`;
    const out = renderPreviewHtml(probe, { profile: "rich" });
    assert.ok(!out.includes("&lt;" + name), `no rule for <${name}>`);
  }
});

test("unknown tags stay escaped-visible", () => {
  const out = renderPreviewHtml("<tg-future>x</tg-future>", { profile: "rich" });
  assert.ok(out.includes("&lt;tg-future&gt;"));
});

test("tg-emoji keeps its emoji-id as a data attribute on the preview span", () => {
  const out = renderPreviewHtml(
    '<tg-emoji emoji-id="5217822164362463825">🟢</tg-emoji>',
    { profile: "rich" }
  );
  assert.ok(
    out.includes('<span class="preview-emoji" data-emoji-id="5217822164362463825">🟢</span>'),
    out
  );
  // The attribute value is escaped on the way out.
  const hostile = renderPreviewHtml('<tg-emoji emoji-id=\'a"b\'>x</tg-emoji>', { profile: "rich" });
  assert.ok(hostile.includes('data-emoji-id="a&quot;b"'), hostile);
  // An id-less tg-emoji renders the plain span, no empty data attribute.
  const bare = renderPreviewHtml("<tg-emoji>x</tg-emoji>", { profile: "rich" });
  assert.ok(bare.includes('<span class="preview-emoji">x</span>'), bare);
});

test("classic profile rejects rich-only tags but keeps Bot API HTML", () => {
  const classic = renderPreviewHtml(
    '<b>b</b> <tg-spoiler>s</tg-spoiler> <blockquote expandable>q</blockquote>' +
      '<pre><code class="language-js">1</code></pre><table><tr><td>x</td></tr></table>',
    { profile: "classic" }
  );
  assert.ok(classic.includes("<b>b</b>"));
  assert.ok(classic.includes('class="preview-spoiler'));
  assert.ok(classic.includes("preview-quote-expandable"));
  assert.ok(classic.includes("language-js"));
  assert.ok(classic.includes("&lt;table&gt;"), "table is rich-only");
  assert.ok(!CLASSIC_TAGS.has("table"));
});

test("media are no-fetch frames by default, real elements with loadMedia", () => {
  const html = '<img src="https://example.com/a.jpg"/>';
  const framed = renderPreviewHtml(html, { profile: "rich" });
  assert.ok(!framed.includes("src="), "no fetch by default");
  assert.ok(framed.includes("preview-media-frame"));
  const loaded = renderPreviewHtml(html, { profile: "rich", loadMedia: true });
  assert.ok(loaded.includes('src="https://example.com/a.jpg"'));
});

test("unsafe href schemes are stripped; tg/mailto/tel/#fragment survive", () => {
  const out = renderPreviewHtml(
    '<a href="javascript:alert(1)">bad</a><a href="tg://user?id=1">u</a>' +
      '<a href="#sec">jump</a>',
    { profile: "rich" }
  );
  assert.ok(!out.includes("javascript:"));
  assert.ok(out.includes('data-preview-href="tg://user?id=1"'));
  assert.ok(out.includes('data-anchor-target="sec"'));
});

test("structural fidelity samples", () => {
  const spoiler = renderPreviewHtml("<tg-spoiler>hidden</tg-spoiler>", { profile: "rich" });
  assert.ok(spoiler.includes('class="preview-spoiler" data-behavior="spoiler"'));

  const quote = renderPreviewHtml("<blockquote expandable>q</blockquote>", { profile: "rich" });
  assert.ok(quote.includes('data-behavior="expandable"'));

  const slides = renderPreviewHtml(
    '<tg-slideshow><img src="https://e.com/1.jpg"/><img src="https://e.com/2.jpg"/></tg-slideshow>',
    { profile: "rich" }
  );
  assert.ok(slides.includes('data-behavior="slideshow"'));

  const map = renderPreviewHtml('<tg-map lat="41.4" long="2.2" zoom="12"/>', { profile: "rich" });
  assert.ok(map.includes("41.4") && map.includes("2.2") && map.includes("12"));

  const time = renderPreviewHtml('<tg-time unix="1800000000">then</tg-time>', { profile: "rich" });
  assert.ok(time.includes("datetime="));

  const check = renderPreviewHtml('<ul><li><input type="checkbox" checked/>x</li></ul>', {
    profile: "rich"
  });
  assert.ok(check.includes("checked") && check.includes("disabled"));
});

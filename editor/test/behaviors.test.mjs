import test from "node:test";
import assert from "node:assert/strict";
import { decideBehavior, renderPreviewHtml } from "../priv/preview/telegram_preview.mjs";

function stub(behavior, extra = {}) {
  return {
    closest(selector) {
      if (selector === "[data-behavior]" && behavior)
        return { dataset: { behavior, ...extra.dataset }, ...extra.node };
      if (selector === ".preview-slide-nav" && extra.nav) return extra.nav;
      return null;
    },
    dataset: extra.dataset || {}
  };
}

test("spoiler tap toggles reveal", () => {
  const d = decideBehavior(stub("spoiler"));
  assert.equal(d.type, "spoiler");
  assert.equal(d.toggleClass, "revealed");
});

test("expandable quote toggles expansion", () => {
  const d = decideBehavior(stub("expandable"));
  assert.equal(d.type, "expandable");
  assert.equal(d.toggleClass, "expanded");
});

test("slideshow nav steps by data-slide", () => {
  const nav = { dataset: { slide: "1" } };
  const d = decideBehavior(stub("slideshow", { nav }));
  assert.equal(d.type, "slideshow");
  assert.equal(d.step, 1);
});

test("anchor jump targets the named anchor", () => {
  const d = decideBehavior(stub("anchor-jump", { dataset: { anchorTarget: "sec" } }));
  assert.equal(d.type, "anchor-jump");
  assert.equal(d.target, "anchor-sec");
});

test("clicks outside behaviors decide nothing", () => {
  assert.equal(decideBehavior(stub(null)), null);
});

test("NUL bytes in input cannot corrupt token substitution", () => {
  const out = renderPreviewHtml("a\x000b <b>x</b>", { profile: "rich" });
  assert.ok(out.includes("<b>x</b>"));
  assert.ok(!out.includes("\x00"));
});

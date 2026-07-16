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

test("NUL payload colliding with a real token index cannot duplicate markup", () => {
  // "\x000\x00" is exactly the sentinel for token index 0 (<b>'s open tag);
  // if the guard were missing, substitution would inject that markup twice.
  const out = renderPreviewHtml("\x000\x00<b>x</b>", { profile: "rich" });
  assert.equal(out.split("<b>").length - 1, 1);
  assert.equal(out.split("</b>").length - 1, 1);
  assert.ok(out.includes("<b>x</b>"));
  assert.ok(!out.includes("\x00"));
});

test("slideshow markup puts nav buttons AFTER the slides", () => {
  const out = renderPreviewHtml(
    `<tg-slideshow><img src="https://a.example/1.png"><img src="https://a.example/2.png"></tg-slideshow>`,
    { profile: "rich" }
  );
  const firstNav = out.indexOf("preview-slide-nav");
  const firstSlide = out.indexOf("preview-media");
  assert.ok(firstNav >= 0, "nav buttons present");
  assert.ok(firstSlide >= 0, "slide media present");
  assert.ok(firstSlide < firstNav,
    "first slide must precede the first nav button so :first-child shows a slide");
});

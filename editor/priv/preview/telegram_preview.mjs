// Faithful preview renderer for Telegram rich-message HTML (Bot API 10.1)
// as emitted by Genswarms.Telegram.Card.to_rich_message/2. Contract:
// tags.mjs -- every element there must have a rule here; anything else is
// escaped and stays VISIBLE so generator/preview drift is loud.
//
// Design note: rather than chaining many broad regex.replace() passes over
// the whole string (order-dependent, and easy to mis-pair open/close tags
// for elements whose close markup depends on how the open tag was decided
// -- e.g. an <a> with an unsafe href), this walks the input once with a
// single "any tag" regex and dispatches each tag occurrence in source
// order. Rendered output for a tag is stashed behind a sentinel token and
// substituted back in after the surrounding text is escaped. The token
// uses a NUL byte (0x00) as delimiter rather than the naive " N " (space,
// index, space) scheme, because real card text can plausibly contain a
// literal " 1 " (prices, counts, list numbers) and a space-delimited token
// would collide with that and corrupt the render. A NUL byte cannot occur
// in Telegram message text, and escapeHtml only touches & < > ", so the
// token passes through the final escaping pass unchanged and can't
// collide with real content.
import tags from "./tags.mjs";

export const CLASSIC_TAGS = new Set([
  "b", "i", "u", "s", "a", "code", "pre",
  "blockquote", "tg-spoiler", "tg-emoji"
]);

const RICH_TAGS = new Set([
  ...tags.block_elements, ...tags.inline_elements, ...tags.void_elements
]);

// Elements that are always fully rendered from their opening tag alone
// (attributes only, no meaningful child content in the Bot API model). A
// stray/explicit closing tag for one of these is consumed as a no-op so it
// never leaks as raw text.
const SELF_CONTAINED = new Set(["hr", "input", "tg-map", "img", "video", "audio"]);

// Simple structural/inline tags: open renders as <name> (attrs dropped
// except where noted below), close renders as </name>.
const SIMPLE_TAGS = new Set([
  "h1", "h2", "h3", "h4", "h5", "h6", "p", "ul", "li",
  "caption", "tr", "th", "td", "summary", "cite",
  "b", "i", "u", "s", "mark", "sub", "sup", "figure", "figcaption"
]);

// Wrapping tags whose close markup is fixed regardless of the open tag's
// attributes (only the open side varies -- see openMarkup below).
const FIXED_CLOSE = {
  blockquote: "</blockquote>",
  details: "</details>",
  aside: "</aside>",
  footer: "</footer>",
  pre: "</pre>",
  code: "</code>",
  ol: "</ol>",
  table: "</table>",
  "tg-spoiler": "</span>",
  "tg-thinking": "</div>",
  "tg-math-block": "</div>",
  "tg-math": "</span>",
  "tg-collage": "</div>",
  "tg-slideshow": "</div>",
  "tg-reference": "</div>",
  "tg-emoji": "</span>",
  "tg-time": "</time>"
};

export function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;").replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;").replaceAll('"', "&quot;");
}

// Wire text arrives Telegram-HTML-escaped; re-permit entities post-escape.
// Idempotent by construction: escapeText(escapeText(x)) === escapeText(x),
// which lets us safely feed already-escaped fragments back through the
// single final escaping pass.
function escapeText(value) {
  return escapeHtml(value).replace(/&amp;(amp|lt|gt|quot|#\d+|#x[0-9a-f]+);/gi, "&$1;");
}

function attrsOf(raw) {
  const out = {};
  const re = /([a-zA-Z-]+)(?:=(["'])(.*?)\2)?/g;
  for (const m of (raw || "").matchAll(re)) out[m[1].toLowerCase()] = m[3] ?? "";
  return out;
}

function safeHref(value) {
  if (typeof value === "string" && value.startsWith("#")) return value;
  try {
    const url = new URL(value);
    const scheme = url.protocol.replace(":", "");
    return tags.href_schemes.includes(scheme) ? url.href : "";
  } catch {
    return "";
  }
}

function renderSelfContained(name, a, loadMedia) {
  if (name === "hr") return "<hr>";
  if (name === "tg-map") {
    return `<div class="preview-map"><span class="preview-map-pin"></span>` +
      `<span class="preview-map-meta">${escapeHtml(a.lat)}, ${escapeHtml(a.long)}` +
      ` -- zoom ${escapeHtml(a.zoom)}</span></div>`;
  }
  if (name === "input") {
    // The contract only defines type="checkbox"; treat a missing/unknown
    // type the same way rather than leaking the raw tag.
    return `<input type="checkbox" disabled${"checked" in a ? " checked" : ""}>`;
  }
  // media: img, video, audio
  const src = safeHref(a.src);
  const spoiled = "tg-spoiler" in a ? " preview-media-spoiler" : "";
  if (loadMedia && src && name === "img")
    return `<img class="preview-media${spoiled}" src="${escapeHtml(src)}" alt="">`;
  if (loadMedia && src)
    return `<${name} class="preview-media${spoiled}" src="${escapeHtml(src)}" controls></${name}>`;
  let host = "media";
  try { host = new URL(src).hostname; } catch {}
  return `<div class="preview-media-frame${spoiled}" data-media="${escapeHtml(name)}">` +
    `<strong>${escapeHtml(name)}</strong><span>${escapeHtml(host)}</span></div>`;
}

function openMarkup(name, rawAttrs) {
  const a = attrsOf(rawAttrs);
  if (SIMPLE_TAGS.has(name) && name !== "li") return `<${name}>`;
  switch (name) {
    case "li":
      return a.value ? `<li value="${escapeHtml(a.value)}">` : "<li>";
    case "ol": {
      const extra = [
        "reversed" in a ? " reversed" : "",
        a.start ? ` start="${escapeHtml(a.start)}"` : "",
        a.type ? ` type="${escapeHtml(a.type)}"` : ""
      ].join("");
      return `<ol${extra}>`;
    }
    case "table": {
      const classes = ["preview-table", "bordered" in a ? "bordered" : "", "striped" in a ? "striped" : ""]
        .filter(Boolean).join(" ");
      return `<table class="${classes}">`;
    }
    case "blockquote": {
      const expandable = "expandable" in a;
      return expandable
        ? `<blockquote class="preview-quote preview-quote-expandable" data-behavior="expandable">` +
          `<button type="button" class="preview-quote-toggle" aria-label="Expand"></button>`
        : `<blockquote class="preview-quote">`;
    }
    case "details":
      return `<details${"open" in a ? " open" : ""}>`;
    case "aside":
      return `<aside class="preview-pullquote">`;
    case "footer":
      return `<footer class="preview-footer">`;
    case "pre":
      return `<pre class="preview-pre">`;
    case "code": {
      const lang = (a.class || "").match(/language-([\w+-]+)/);
      return lang
        ? `<code class="language-${escapeHtml(lang[1])}" data-lang="${escapeHtml(lang[1])}">`
        : "<code>";
    }
    case "tg-spoiler":
      return `<span class="preview-spoiler" data-behavior="spoiler">`;
    case "tg-thinking":
      return `<div class="preview-thinking">`;
    case "tg-math-block":
      return `<div class="preview-math-block">`;
    case "tg-math":
      return `<span class="preview-math">`;
    case "tg-collage":
      return `<div class="preview-collage">`;
    case "tg-slideshow":
      return `<div class="preview-slideshow" data-behavior="slideshow">` +
        `<button type="button" class="preview-slide-nav" data-slide="-1">‹</button>` +
        `<button type="button" class="preview-slide-nav" data-slide="1">›</button>`;
    case "tg-reference":
      return `<div class="preview-reference" id="anchor-${escapeHtml(a.name ?? "")}">`;
    case "tg-emoji":
      return `<span class="preview-emoji">`;
    case "tg-time": {
      const dt = a.unix ? new Date(Number(a.unix) * 1000).toISOString() : "";
      return `<time class="preview-time" datetime="${escapeHtml(dt)}"` +
        ` title="${escapeHtml(dt)}${a.format ? " -- " + escapeHtml(a.format) : ""}">`;
    }
    default:
      return `<${name}>`;
  }
}

function closeMarkup(name) {
  if (SIMPLE_TAGS.has(name)) return `</${name}>`;
  return FIXED_CLOSE[name] ?? `</${name}>`;
}

// Any well-formed tag: opening, closing, or self-closed. Content and stray
// text between matches is left untouched here and escaped in one shot at
// the end.
const TAG_RE = /<(\/)?([a-zA-Z][a-zA-Z0-9-]*)((?:\s+[^<>]*)?)\s*(\/)?>/g;

export function renderPreviewHtml(html, { profile = "rich", loadMedia = false } = {}) {
  const allowed = profile === "classic" ? CLASSIC_TAGS : RICH_TAGS;
  const tokens = [];
  const TOKEN_DELIM = "\u0000";
  const keep = (markup) => {
    tokens.push(markup);
    return `${TOKEN_DELIM}${tokens.length - 1}${TOKEN_DELIM}`;
  };

  const src = String(html ?? "");
  const aStack = [];
  let out = "";
  let last = 0;
  let m;
  TAG_RE.lastIndex = 0;
  while ((m = TAG_RE.exec(src)) !== null) {
    const [full, slashGroup, rawName, rawAttrs] = m;
    out += src.slice(last, m.index);
    last = m.index + full.length;
    const name = rawName.toLowerCase();
    const isClose = Boolean(slashGroup);

    if (!allowed.has(name)) {
      // Unknown or profile-disallowed tag: leave it as raw text so the
      // final escape pass renders it visibly (drift alarm / classic guard).
      out += full;
      continue;
    }

    if (name === "a") {
      if (!isClose) {
        const a = attrsOf(rawAttrs);
        if (a.name !== undefined && a.href === undefined) {
          aStack.push("stub");
          out += keep(`<span class="preview-anchor" id="anchor-${escapeHtml(a.name)}"></span>`);
          continue;
        }
        const href = safeHref(a.href);
        if (!href) {
          // Unsafe/invalid href: render neither the open nor close tag --
          // the label text flows through as plain (escaped) text instead
          // of a dead/dangerous link.
          aStack.push("skip");
          out += keep("");
          continue;
        }
        if (href.startsWith("#")) {
          aStack.push("link");
          out += keep(
            `<a class="preview-link" href="#" data-behavior="anchor-jump"` +
            ` data-anchor-target="${escapeHtml(href.slice(1))}">`
          );
          continue;
        }
        if (href.startsWith("http")) {
          aStack.push("link");
          out += keep(
            `<a class="preview-link" href="${escapeHtml(href)}" target="_blank"` +
            ` rel="noopener noreferrer">`
          );
          continue;
        }
        // tg:// mailto: tel: -- real clients handle these natively; preview shows them inert.
        aStack.push("link");
        out += keep(
          `<a class="preview-link preview-link-native" href="#" data-behavior="native-link"` +
          ` data-preview-href="${escapeHtml(href)}" title="${escapeHtml(href)}">`
        );
        continue;
      } else {
        const state = aStack.pop();
        out += keep(state === "link" ? "</a>" : "");
        continue;
      }
    }

    if (SELF_CONTAINED.has(name)) {
      if (isClose) {
        // A stray/explicit close for a self-contained element: no-op.
        out += keep("");
        continue;
      }
      out += keep(renderSelfContained(name, attrsOf(rawAttrs), loadMedia));
      continue;
    }

    out += keep(isClose ? closeMarkup(name) : openMarkup(name, rawAttrs));
  }
  out += src.slice(last);

  const escaped = escapeText(out);
  const tokenRe = new RegExp(`${TOKEN_DELIM}(\\d+)${TOKEN_DELIM}`, "g");
  return escaped.replace(tokenRe, (_m, i) => tokens[Number(i)]);
}

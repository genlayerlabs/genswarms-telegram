// Single source of truth for the generator↔preview contract.
// priv/tags.json is GENERATED from this file (editor/scripts/gen-tags-json.mjs);
// the main package's card_editor_contract_test.exs consumes the JSON copy.
export default {
  schema_version: "1",
  bot_api_version: "10.1",
  // Block-level elements Card.to_rich_message can emit.
  block_elements: [
    "h1", "h2", "h3", "h4", "h5", "h6", "p", "ul", "ol", "li",
    "table", "caption", "tr", "th", "td",
    "details", "summary", "blockquote", "cite", "aside",
    "pre", "footer", "hr", "figure", "figcaption",
    "tg-math-block", "tg-collage", "tg-slideshow", "tg-reference",
    "tg-thinking", "img", "video", "audio", "input"
  ],
  // Inline elements (may appear inside any text run).
  inline_elements: [
    "b", "i", "u", "s", "mark", "code", "sub", "sup", "a",
    "tg-spoiler", "tg-emoji", "tg-time", "tg-math"
  ],
  // Elements emitted self-closed.
  void_elements: ["hr", "img", "input", "tg-map"],
  // Allowed attributes per element (everything else is dropped on render).
  attributes: {
    a: ["href", "name"],
    blockquote: ["expandable"],
    code: ["class"],
    details: ["open"],
    img: ["src", "tg-spoiler"],
    video: ["src", "tg-spoiler"],
    audio: ["src", "tg-spoiler"],
    input: ["type", "checked"],
    ol: ["reversed", "start", "type"],
    li: ["value"],
    table: ["bordered", "striped"],
    "tg-emoji": ["emoji-id"],
    "tg-map": ["lat", "long", "zoom"],
    "tg-reference": ["name"],
    "tg-time": ["unix", "format"]
  },
  // URL schemes a[href] may carry (plus in-card "#fragment" links).
  href_schemes: ["http", "https", "tg", "mailto", "tel"]
};

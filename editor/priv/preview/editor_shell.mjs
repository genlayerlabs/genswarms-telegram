// Pure logic for editor.html (node-testable; no DOM).
import { renderPreviewHtml, escapeHtml } from "./telegram_preview.mjs";

export function buildRenderRequest(cardJsonText) {
  try {
    const card = JSON.parse(cardJsonText);
    return { ok: true, body: JSON.stringify({ card }) };
  } catch (error) {
    return { ok: false, error: `Invalid JSON: ${error.message}` };
  }
}

export function applyRenderResponse(response, { loadMedia = false } = {}) {
  if (response.ok) {
    return {
      html: renderPreviewHtml(response.html, { profile: "rich", loadMedia }),
      errorsHtml: ""
    };
  }
  const rows = (response.errors || [{ path: "card", reason: "render failed" }])
    .map((e) => `<li><code>${escapeHtml(e.path)}</code> ${escapeHtml(e.reason)}</li>`)
    .join("");
  return { html: null, errorsHtml: `<ul class="editor-errors">${rows}</ul>` };
}

# Visual parity calibration — Bot API 10.1

Ground truth for the preview CSS. Once per Bot API version bump:

1. Run `mix editor.fixtures` and send every example card through a dev bot
   to a real private chat (send_card via the sender object, or curl
   sendRichMessage with the fixture html).
2. Screenshot each card on iOS Telegram and Telegram Desktop, light + dark.
   Save as `<example-name>.<client>.<theme>.png` in this directory.
3. Open `editor.html` with the same card and compare against the screenshot:
   quote bar color/inset, spoiler blur, expandable chevron placement,
   collage grid, slideshow controls, table borders, checklist ticks,
   time underline, map frame, math styling, footer size/color.
4. Fix CSS with the screenshot open. Do not restyle from memory.

Screenshots are committed here so CSS reviews can diff against them.
Status: screenshots PENDING — capture before tagging the release.

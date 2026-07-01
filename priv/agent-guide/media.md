# Media

Card media blocks render inside rich cards:

```json
{"kind": "media", "media_type": "photo", "url": "https://example.com/photo.jpg", "caption": "Image"}
```

Supported card `media_type` values are `photo`, `video`, `animation`, `audio`, and `voice_note`. Card media URLs must be absolute `http` or `https` URLs.

Native media actions:

- `send_media`: send one photo, video, animation, audio, voice note, or document using `media_type` plus `media`.
- `send_media_group`: send 2 to 10 media items. Photo/video groups can mix photo and video; audio groups can contain only audio; document groups can contain only documents.
- `send_sticker`: send a non-empty sticker file id, attach reference, or supported URL.
- `send_poll`: send a poll or quiz. Polls require a question and 1 to 12 options.
- `send_location`: requires numeric `latitude` and `longitude`.
- `send_venue`: requires coordinates, `title`, and `address`.
- `send_contact`: requires `phone_number` and `first_name`.
- `send_dice`: sends a Telegram dice emoji.

Use captions when the media carries the main answer. Use a card when the answer needs mixed structure, buttons, tables, or references around the media.

#!/bin/sh
set -eu

usage() {
  printf '%s\n' 'usage: reply [--to MESSAGE_ID] MESSAGE | reply [--to MESSAGE_ID] -f -' >&2
}

cid="${GENSWARMS_TELEGRAM_CONVERSATION_ID:-}"
sender="${GENSWARMS_TELEGRAM_SENDER_OBJECT:-telegram_sender}"

if [ -z "$cid" ]; then
  printf '%s\n' 'reply: missing GENSWARMS_TELEGRAM_CONVERSATION_ID' >&2
  exit 65
fi

to=""
if [ "${1:-}" = "--to" ]; then
  case "${2:-}" in (""|*[!0-9]*) to="" ;; (*) to="$2" ;; esac
  shift 2
fi

case "${1:-}" in
  "")
    usage
    exit 64
    ;;
  -f)
    if [ "${2:-}" != "-" ]; then
      usage
      exit 64
    fi
    text="$(cat)"
    ;;
  --)
    shift
    text="${1:-}"
    ;;
  -*)
    usage
    exit 64
    ;;
  *)
    text="$1"
    ;;
esac

out="$(mktemp)"
trap 'rm -f "$out"' EXIT HUP INT TERM
if [ -n "$to" ]; then
  printf '%s' "$text" | jq -Rs --argjson m "$to" \
    '{action:"reply",reply_to_message_id:$m,text:.}' > "$out"
else
  printf '%s' "$text" | jq -Rs \
    '{action:"reply",text:.}' > "$out"
fi

swarm-msg send "$sender" -f "$out"

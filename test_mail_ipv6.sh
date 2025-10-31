#!/usr/bin/env bash
# Functional test for IPv6 literal mail delivery.
set -euo pipefail

RECIPIENT_LITERAL=${1:-"alice@[IPv6:af49::10]"}
SENDER_LITERAL=${2:-"alice@[IPv6:af49::10]"}
MAILDIR_ROOT=${MAILDIR_ROOT:-/var/mail/vhosts/internal.invalid}

canonical_local=$(python3 - <<'PY'
import re, sys
recipient = sys.argv[1]
match = re.match(r'^(.+)@\[(?:IPv6:)?af49::([0-9A-Fa-f:]+)\]$', recipient)
if not match:
    sys.exit("Recipient must be in the form user@[IPv6:af49::xxxx]")
localpart = f"{match.group(1)}+IPv6-af49--{match.group(2)}"
print(localpart)
PY
"$RECIPIENT_LITERAL") || exit 1

maildir="${MAILDIR_ROOT}/${canonical_local}/Maildir"
mkdir -p "${maildir}/cur" "${maildir}/new" "${maildir}/tmp"

# Track existing messages to detect the new delivery.
mapfile -t before < <(find "${maildir}/new" -type f -printf '%f\n' 2>/dev/null | sort)

timestamp=$(date -u +%Y%m%d%H%M%S)
message_id="ipv6-test-${timestamp}@mail-gw.af49.local"

cat <<MSG | /usr/sbin/sendmail -f "$SENDER_LITERAL" "$RECIPIENT_LITERAL"
From: "IPv6 Test" <$SENDER_LITERAL>
To: <$RECIPIENT_LITERAL>
Subject: IPv6 literal delivery self-test $timestamp
Message-ID: <$message_id>
Date: $(LC_ALL=C date -R)
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 8bit

This is an automated test message ensuring IPv6 literal recipients are
rewritten to ${canonical_local}@internal.invalid and delivered to
${maildir}.
MSG

# Wait for delivery.
new_file=""
for _ in {1..10}; do
  sleep 1
  mapfile -t after < <(find "${maildir}/new" -type f -printf '%T@ %p\n' 2>/dev/null | sort)
  for entry in "${after[@]}"; do
    path=${entry#* }
    name=${path##*/}
    skip=false
    for existing in "${before[@]}"; do
      if [[ "$existing" == "$name" ]]; then
        skip=true
        break
      fi
    done
    if ! $skip; then
      new_file="$path"
    fi
  done
  [[ -n "$new_file" ]] && break
done

if [[ -z "$new_file" ]]; then
  echo "Message not delivered to ${maildir}/new within timeout" >&2
  exit 2
fi

echo "Delivered message: $new_file"

grep -E '^(X-Original-To|Delivered-To|To):' "$new_file" || true

echo "Body excerpt:"
sed -n '1,5p' "$new_file"

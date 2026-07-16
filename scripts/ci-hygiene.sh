#!/usr/bin/env bash
#
# Repo hygiene checks for a public, open-source repository.
#
# Scans TRACKED, TEXT files only. It uses `git grep -I`, which:
#   * searches only files tracked by git (so untracked/ignored files are skipped), and
#   * skips binary files (`-I`) such as PNGs, so image byte-noise never trips a check.
#
# Checks:
#   1. No real GUIDs                — only the all-zero placeholder is allowed.
#   2. No public IPv4 addresses     — private/reserved/documentation ranges are fine.
#   3. No secret/state files staged — *.tfstate, tfplan, talosconfig, kubeconfig,
#                                     real *.tfvars, keys/certs.
#
# Run it locally exactly as CI does:
#   ./scripts/ci-hygiene.sh
#
set -uo pipefail

cd "$(git rev-parse --show-toplevel)"

fail=0
PLACEHOLDER='00000000-0000-0000-0000-000000000000'

# Exclude this script directory from content scans so its own examples
# (the placeholder GUID, documentation IPs) never self-trigger.
EXCLUDE=(':(exclude)scripts/**')

# ---------------------------------------------------------------------------
# 1. Real GUIDs (anything that is not the all-zero placeholder)
# ---------------------------------------------------------------------------
echo "==> [1/3] Checking for real GUIDs (non-placeholder)..."
guid_re='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
guid_hits=$(git grep -nIE "$guid_re" -- . "${EXCLUDE[@]}" 2>/dev/null \
              | grep -vE "$PLACEHOLDER" || true)
if [ -n "$guid_hits" ]; then
  echo "    FAIL: real GUID(s) found. Use ${PLACEHOLDER} or a <subscription-id> placeholder:"
  printf '%s\n' "$guid_hits" | sed 's/^/      /'
  fail=1
else
  echo "    OK — only the all-zero placeholder is present."
fi

# ---------------------------------------------------------------------------
# 2. Public IPv4 addresses (private / reserved / documentation ranges are OK)
# ---------------------------------------------------------------------------
echo "==> [2/3] Checking for public IPv4 addresses..."
ip_hits=$(git grep -nIE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' -- . "${EXCLUDE[@]}" 2>/dev/null || true)
# NOTE: the classifier is passed via `python3 -c` (not `python3 - <<EOF`) so that
# stdin stays free to carry the grep output. With a `<<EOF` heredoc, stdin would
# be the program text and $ip_hits would never reach the script.
public_ips=$(printf '%s\n' "$ip_hits" | python3 -c '
import sys, re, ipaddress

# RFC 5737 documentation ranges and RFC 6598 CGNAT are treated as non-public.
ALLOW = [ipaddress.ip_network(n) for n in (
    "192.0.2.0/24", "198.51.100.0/24", "203.0.113.0/24",  # TEST-NET-1/2/3
    "100.64.0.0/10",                                       # CGNAT
)]
pat = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")

for line in sys.stdin:
    for token in pat.findall(line):
        try:
            ip = ipaddress.ip_address(token)
        except ValueError:
            continue  # e.g. 999.1.1.1 or a version-like quad with an octet > 255
        if (ip.is_private or ip.is_loopback or ip.is_link_local
                or ip.is_multicast or ip.is_reserved or ip.is_unspecified):
            continue
        if any(ip in net for net in ALLOW):
            continue
        print(line.rstrip())
        break
')
if [ -n "$public_ips" ]; then
  echo "    FAIL: public IPv4 address(es) found. Use RFC 5737 ranges (e.g. 203.0.113.0/24) in examples:"
  printf '%s\n' "$public_ips" | sed 's/^/      /'
  fail=1
else
  echo "    OK — no public IPv4 addresses."
fi

# ---------------------------------------------------------------------------
# 3. Secret / state files that must never be committed
# ---------------------------------------------------------------------------
echo "==> [3/3] Checking for committed secret/state files..."
tracked=$(git ls-files)
forbidden=$(printf '%s\n' "$tracked" | grep -E \
  '\.tfstate($|\.)|(^|/)tfplan$|\.tfplan$|(^|/)talosconfig$|(^|/)kubeconfig(-direct)?$|\.(pem|key|crt)$' \
  || true)
tfvars=$(printf '%s\n' "$tracked" | grep -E '\.tfvars(\.json)?$' \
           | grep -vE '\.tfvars(\.json)?\.example$' || true)
if [ -n "$forbidden$tfvars" ]; then
  echo "    FAIL: files that must not be committed are tracked:"
  printf '%s\n' "$forbidden" "$tfvars" | grep -v '^$' | sed 's/^/      /'
  echo "      (ship *.tfvars.example instead of *.tfvars; state/credentials are gitignored)"
  fail=1
else
  echo "    OK — no state, plan, credential, or real *.tfvars files tracked."
fi

echo
if [ "$fail" -ne 0 ]; then
  echo "Hygiene checks FAILED."
  exit 1
fi
echo "All hygiene checks passed."

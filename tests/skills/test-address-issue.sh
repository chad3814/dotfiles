#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091  # dynamic path; see tests/skills/helpers.sh
. "$(cd "$(dirname "$0")" && pwd -P)/helpers.sh"

AI="$SKILLS_DIR/address-issue/address-issue.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# Stub gh: emit "bug" for the labels query, the title otherwise.
bin="$tmp/bin"; mkdir -p "$bin"
cat > "$bin/gh" <<'STUB'
#!/usr/bin/env bash
for a in "$@"; do
  if [ "$a" = "labels" ]; then echo "bug"; exit 0; fi
done
echo "Add Dark Mode Toggle!"
STUB
chmod +x "$bin/gh"

seed="$tmp/seed"; make_seed "$seed"
proj="$tmp/proj"; bare_project "$proj" "$seed"

cd "$proj"
PATH="$bin:$PATH" bash "$AI" 21 >/dev/null

assert_dir "$proj/worktrees/21-add-dark-mode-toggle" "issue worktree created"
assert_eq  "$(git -C worktrees/21-add-dark-mode-toggle rev-parse --abbrev-ref HEAD)" \
           "fix/21-add-dark-mode-toggle" "branch prefixed fix/ from bug label"

echo "test-address-issue: OK"

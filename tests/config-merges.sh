#!/usr/bin/env bash
# These checks use disposable settings, never the user's app files or accounts.
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
export HOME="$test_dir/home with spaces"
export XDG_STATE_HOME="$HOME/state"
mkdir -p "$HOME"
for tool in json5 yq jq; do
  command -v "$tool" > /dev/null || { printf 'Missing test tool: %s\n' "$tool" >&2; exit 1; }
done
merge() { bash "$repo/scripts/merge-settings.sh" "$@"; }

# Managed nested preferences change; local models, tokens and URLs survive.
cat > "$test_dir/local.json" <<'EOF'
{
  // Keep the user's selected model and adapter options.
  "agent": {"default_model": {"provider": "local", "model": "example"}, "default_profile": "write"},
  "agent_servers": {"adapter": {"default_config_options": {"model": "example-adapter"}}},
  "account": {"token": "fixture-token", "url": "https://example.test/a//b"},
}
EOF
cp "$test_dir/local.json" "$test_dir/original.json"
printf '%s\n' '{"agent":{"default_profile":"ask"},"agent_servers":{"adapter":{"type":"registry"}}}' > "$test_dir/defaults.json"
merge json "$test_dir/defaults.json" "$test_dir/local.json"
jq -e '.agent.default_profile == "ask" and .agent.default_model.model == "example" and
  .agent_servers.adapter.default_config_options.model == "example-adapter" and
  .agent_servers.adapter.type == "registry" and .account.token == "fixture-token" and
  .account.url == "https://example.test/a//b"' "$test_dir/local.json" > /dev/null
[[ $(stat -c %a "$test_dir/local.json") == 600 ]]
backup=$(find "$XDG_STATE_HOME/home-manager/config-backups" -type f -print -quit)
cmp "$test_dir/original.json" "$backup"
[[ $(stat -c %a "$backup") == 600 ]]
[[ $(stat -c %a "$(dirname "$backup")") == 700 ]]

# Reapplying is a byte-for-byte no-op, including comments in unchanged JSONC.
printf '// Local comment\n' > "$test_dir/repeat.json"
cat "$test_dir/local.json" >> "$test_dir/repeat.json"
cp "$test_dir/repeat.json" "$test_dir/expected.json"
before=$(find "$XDG_STATE_HOME/home-manager/config-backups" -type f | wc -l)
merge json "$test_dir/defaults.json" "$test_dir/repeat.json"
cmp "$test_dir/expected.json" "$test_dir/repeat.json"
[[ $(find "$XDG_STATE_HOME/home-manager/config-backups" -type f | wc -l) == "$before" ]]

# TOML keeps provider tables, arrays, dates and large integers in native form.
cat > "$test_dir/local.toml" <<'EOF'
model = "local-model"
issued = 2025-10-01T10:00:00Z
big = 9223372036854775807
[ui]
permission_mode = "ask"
color = "blue"
[providers."example.local"]
token = "fixture-token"
args = ["serve", "--port", "1234"]
EOF
printf '[ui]\npermission_mode = "always-approve"\n' > "$test_dir/defaults.toml"
merge toml "$test_dir/defaults.toml" "$test_dir/local.toml"
yq -e -p toml -o yaml '.ui.permission_mode == "always-approve" and .ui.color == "blue" and
  .model == "local-model" and .providers."example.local".token == "fixture-token" and
  .providers."example.local".args[1] == "--port" and .big == 9223372036854775807' "$test_dir/local.toml" > /dev/null
# A quoted value would change the date into a string.
grep -Eq '^issued = 2025-10-01T10:00:00(Z|[+]00:00)$' "$test_dir/local.toml"
cp "$test_dir/local.toml" "$test_dir/expected.toml"
merge toml "$test_dir/defaults.toml" "$test_dir/local.toml"
cmp "$test_dir/expected.toml" "$test_dir/local.toml"

# Whole policy replacement does not erase unrelated app settings.
printf '%s\n' '{"permission":{"webfetch":"deny"},"model":"local-model"}' > "$test_dir/policy.json"
printf '%s\n' '{"permission":{"*":"allow","bash":{"git push *":"ask"}}}' > "$test_dir/policy-defaults.json"
merge json "$test_dir/policy-defaults.json" "$test_dir/policy.json" '.[0] + .[1]'
jq -e '.model == "local-model" and .permission.webfetch == null and
  .permission.bash["git push *"] == "ask"' "$test_dir/policy.json" > /dev/null

# Obsidian resets sidebars while retaining open notes, active pane and history.
printf '%s\n' '{"main":{"note":"open-note"},"active":"open-pane","lastOpenFiles":["note.md"],"left":{"old":true},"right":{"old":true}}' > "$test_dir/workspace.json"
printf '%s\n' '{"main":{"note":"seed"},"active":"seed-pane","lastOpenFiles":[],"left":{"new":true},"right":{"new":true}}' > "$test_dir/workspace-defaults.json"
merge json "$test_dir/workspace-defaults.json" "$test_dir/workspace.json" '.[1] + .[0] + {left: .[1].left, right: .[1].right}'
jq -e '.main.note == "open-note" and .active == "open-pane" and .lastOpenFiles == ["note.md"] and
  .left == {"new":true} and .right == {"new":true}' "$test_dir/workspace.json" > /dev/null

# Invalid local/default files and non-object JSON fail without changes or leaks.
for format in json toml; do
  printf 'fixture-private-value = [\n' > "$test_dir/broken.$format"
  cp "$test_dir/broken.$format" "$test_dir/expected-broken"
  if merge "$format" "$test_dir/defaults.$format" "$test_dir/broken.$format" 2> "$test_dir/errors"; then exit 1; fi
  cmp "$test_dir/expected-broken" "$test_dir/broken.$format"
  if [[ $(< "$test_dir/errors") == *fixture-private-value* ]]; then exit 1; fi
  cp "$test_dir/local.$format" "$test_dir/expected-valid"
  if merge "$format" "$test_dir/broken.$format" "$test_dir/local.$format" 2> "$test_dir/errors"; then exit 1; fi
  cmp "$test_dir/expected-valid" "$test_dir/local.$format"
done
: > "$test_dir/empty.toml"
merge toml "$test_dir/defaults.toml" "$test_dir/empty.toml"
yq -e -p toml -o yaml '.ui.permission_mode == "always-approve"' "$test_dir/empty.toml" > /dev/null
printf '[]\n' > "$test_dir/array.json"
if merge json "$test_dir/defaults.json" "$test_dir/array.json" 2> "$test_dir/errors"; then exit 1; fi
[[ $(cat "$test_dir/array.json") == '[]' ]]

# A symlink must not overwrite a checkout or a Home Manager store file.
ln -s "$test_dir/expected.json" "$test_dir/linked.json"
if merge json "$test_dir/defaults.json" "$test_dir/linked.json" 2> "$test_dir/errors"; then exit 1; fi
[[ -L "$test_dir/linked.json" ]]
cmp "$test_dir/repeat.json" "$test_dir/expected.json"

# New files work in paths with spaces and remain writable regular files.
for format in json toml; do
  merge "$format" "$test_dir/defaults.$format" "$HOME/new folder/settings.$format"
  [[ -f "$HOME/new folder/settings.$format" && ! -L "$HOME/new folder/settings.$format" ]]
  [[ $(stat -c %a "$HOME/new folder/settings.$format") == 600 ]]
done

# Simulate an app writing after the snapshot; the app's new contents must survive.
mkdir -p "$test_dir/bin"
export SETTINGS_TEST_JQ
SETTINGS_TEST_JQ=$(command -v jq)
export SETTINGS_TEST_TARGET="$test_dir/concurrent.json"
printf '{}\n' > "$SETTINGS_TEST_TARGET"
cat > "$test_dir/bin/jq" <<'EOF'
#!/usr/bin/env bash
if [[ ${1:-} == -e && ${2:-} == -s && ${3:-} == '.[0] * .[1]' ]]; then
  printf '{"written_by_app":true}\n' > "$SETTINGS_TEST_TARGET"
fi
exec "$SETTINGS_TEST_JQ" "$@"
EOF
chmod +x "$test_dir/bin/jq"
if PATH="$test_dir/bin:$PATH" merge json "$test_dir/defaults.json" "$SETTINGS_TEST_TARGET" 2> "$test_dir/errors"; then exit 1; fi
jq -e '.written_by_app == true' "$SETTINGS_TEST_TARGET" > /dev/null
[[ -z $(find "$test_dir" -name '.home-manager-settings.*' -print -quit) ]]
printf '%s\n' 'Settings merge checks passed.'

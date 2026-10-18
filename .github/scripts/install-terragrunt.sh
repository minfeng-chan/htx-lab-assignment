#!/usr/bin/env bash
set -euo pipefail
version=1.1.6
tool_dir="$(mktemp -d)"
trap 'rm -rf "$tool_dir"' EXIT
base="https://github.com/gruntwork-io/terragrunt/releases/download/v${version}"
curl --fail --silent --show-error --location "$base/terragrunt_linux_amd64" -o "$tool_dir/terragrunt_linux_amd64"
curl --fail --silent --show-error --location "$base/SHA256SUMS" -o "$tool_dir/SHA256SUMS"
(cd "$tool_dir" && grep ' terragrunt_linux_amd64$' SHA256SUMS | sha256sum --check --strict)
mkdir -p "$HOME/.local/bin"
install -m 0755 "$tool_dir/terragrunt_linux_amd64" "$HOME/.local/bin/terragrunt"
echo "$HOME/.local/bin" >> "$GITHUB_PATH"

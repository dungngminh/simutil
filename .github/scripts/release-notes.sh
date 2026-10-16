#!/usr/bin/env bash
# Usage: release-notes.sh <tag> <config> <tag-glob>...
# Prints GitHub's generated notes for <tag> using the label config <config>,
# counted from the newest earlier tag matching one of <tag-glob>. CLI and app
# releases share this repo, so GitHub's own pick of the previous release
# could be the other product.
set -euo pipefail
tag=$1 config=$2
shift 2
previous=$(git tag -l "$@" --sort=-creatordate | grep -vxF "$tag" | head -n 1 || true)
args=(-f tag_name="$tag" -f configuration_file_path="$config")
[[ -n $previous ]] && args+=(-f previous_tag_name="$previous")
gh api "repos/$GITHUB_REPOSITORY/releases/generate-notes" "${args[@]}" --jq .body

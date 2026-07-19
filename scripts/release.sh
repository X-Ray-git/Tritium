#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/release.sh <version> -m "<message>" [--push] [--allow-literal-backslash-n]

Example:
  scripts/release.sh 0.2.0 -m $'- feat: read-only navigation\n- fix: pagination' --push

The script increments the pubspec build number, records the reproducible
command in docs/history/releases.md, creates an annotated v<version> tag, and
optionally pushes master and the tag. Releases must be created from master.
EOF
}

if [[ $# -lt 3 ]]; then
  usage
  exit 1
fi

version="$1"
shift
message=""
push_remote=false
allow_literal_backslash_n=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--message)
      [[ $# -ge 2 ]] || { echo "Missing release message." >&2; exit 1; }
      message="$2"
      shift 2
      ;;
    --allow-literal-backslash-n)
      allow_literal_backslash_n=true
      shift
      ;;
    --push)
      push_remote=true
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must look like 1.2.3, got: $version" >&2
  exit 1
fi

if [[ -z "$message" ]]; then
  echo "A non-empty release message is required." >&2
  exit 1
fi

literal_backslash_n='\n'
if [[ "$allow_literal_backslash_n" != true && "$message" == *"$literal_backslash_n"* ]]; then
  echo 'Release notes contain literal \n. Use $'"'"'line one\nline two'"'"' quoting or pass --allow-literal-backslash-n.' >&2
  exit 1
fi

current_branch="$(git branch --show-current)"
if [[ "$current_branch" != "master" ]]; then
  echo "Releases must be created from master, current branch: ${current_branch:-detached HEAD}" >&2
  exit 1
fi

if [[ -n "$(git status --short)" ]]; then
  echo "Working tree is not clean. Commit or stash changes before releasing." >&2
  exit 1
fi

current_line="$(grep -E '^version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$' pubspec.yaml || true)"
if [[ -z "$current_line" ]]; then
  echo "Could not parse pubspec.yaml version line." >&2
  exit 1
fi

current_build="${current_line##*+}"
next_build=$((current_build + 1))
tag="v$version"

if git rev-parse "$tag" >/dev/null 2>&1; then
  echo "Tag already exists locally: $tag" >&2
  exit 1
fi

if git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1; then
  echo "Tag already exists on origin: $tag" >&2
  exit 1
fi

perl -0pi -e "s/^version:\s*\d+\.\d+\.\d+\+\d+$/version: $version+$next_build/m" pubspec.yaml

release_history="docs/history/releases.md"
printf -v message_arg '%q' "$message"
release_flags=""
if [[ "$allow_literal_backslash_n" == true ]]; then
  release_flags+=" --allow-literal-backslash-n"
fi
if [[ "$push_remote" == true ]]; then
  release_flags+=" --push"
fi
{
  printf '\n## %s\n\n```bash\n' "$tag"
  printf './scripts/release.sh %s -m %s%s\n' "$version" "$message_arg" "$release_flags"
  printf '```\n'
} >> "$release_history"

git add pubspec.yaml "$release_history"
git commit -m "chore: bump version to $version+$next_build"
git tag -a "$tag" -m "$message"

echo "Created $tag with pubspec version $version+$next_build."

if [[ "$push_remote" == true ]]; then
  git push origin master
  git push origin "$tag"
else
  echo "Next steps: git push origin master && git push origin $tag"
fi

#!/usr/bin/env bash

set -uo pipefail
repo_to_check="https://github.com/jamieduk/Bash_Cheat_Sheet" # Change Repo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_VERSION="${CURRENT_VERSION:-1.0.0}"
if [[ -f "$SCRIPT_DIR/package.json" ]]; then
  LOCAL_VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$SCRIPT_DIR/package.json")"
  [[ -n "$LOCAL_VERSION" ]] && CURRENT_VERSION="$LOCAL_VERSION"
fi

GH_TOKEN="${GITHUB_TOKEN:-}"

api_get() {
  local url="$1"
  if [[ -n "$GH_TOKEN" ]]; then
    curl -fsSL -H "Authorization: token ${GH_TOKEN}" "$url" 2>/dev/null
  else
    curl -fsSL "$url" 2>/dev/null
  fi
}

ver_gt() {
  local a b
  a="${1//[vV]/}"
  b="${2//[vV]/}"
  local IFS=.
  local -a aa ab
  read -r -a aa <<<"${a//[^0-9.]/}"
  read -r -a ab <<<"${b//[^0-9.]/}"
  local i
  for ((i = 0; i < ${#aa[@]} && i < ${#ab[@]}; i++)); do
    if ((10#${aa[i]:-0} > 10#${ab[i]:-0})); then
      return 0
    elif ((10#${aa[i]:-0} < 10#${ab[i]:-0})); then
      return 1
    fi
  done
  ((${#aa[@]} > ${#ab[@]}))
}

latest_release_tag() {
  local repo="$1" json tag
  json="$(api_get "https://api.github.com/repos/${repo}/releases/latest")"
  tag="$(printf '%s' "$json" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  printf '%s' "$tag"
}

latest_tag() {
  local repo="$1" json tag
  json="$(api_get "https://api.github.com/repos/${repo}/tags")"
  [[ -z "$json" ]] && return
  tag="$(printf '%s' "$json" | sed -n 's/.*\[[[:space:]]*{"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  printf '%s' "$tag"
}

default_branch() {
  local repo="$1" json branch
  json="$(api_get "https://api.github.com/repos/${repo}")"
  branch="$(printf '%s' "$json" | sed -n 's/.*"default_branch"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  printf '%s' "$branch"
}

package_version() {
  local repo="$1" branch="$2" raw v
  raw="$(curl -fsSL "https://raw.githubusercontent.com/${repo}/${branch}/package.json" 2>/dev/null)"
  v="$(printf '%s' "$raw" | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  printf '%s' "$v"
}

check_github_update() {
  local repo latest current tag branch url
  repo="$1"
  repo="${repo%/}"
  repo="${repo#https://}"
  repo="${repo#http://}"
  repo="${repo#www.}"
  repo="${repo#github.com/}"
  repo="${repo#github.com:}"
  repo="${repo%.git}"

  latest=""
  tag="$(latest_release_tag "$repo")"
  if [[ -n "$tag" ]]; then
    latest="$tag"
  else
    tag="$(latest_tag "$repo")"
    if [[ -n "$tag" ]]; then
      latest="$tag"
    else
      branch="$(default_branch "$repo")"
      if [[ -n "$branch" ]]; then
        latest="$(package_version "$repo" "$branch")"
        if [[ -z "$latest" ]]; then
          echo "No version file is included in the repo (${repo}), if you own this repo please add package.json to root of the repo with a version number for example \"version\":\"1.2.0\""
          return 0
        fi
      else
        echo "Could not reach GitHub for repo ${repo} (unauthenticated requests are rate limited)."
        return 1
      fi
    fi
  fi

  latest="${latest#v}"
  latest="${latest#V}"
  current="${CURRENT_VERSION#v}"
  current="${current#V}"

  echo "Current version : ${current}"
  echo "Latest version  : ${latest}"

  if ver_gt "$latest" "$current"; then
    url="https://github.com/${repo}"
    echo "An update is available (${current} -> ${latest})."
    printf 'Do you want to visit the repository link? [y/N] '
    read -r -n 1 ans
    echo
    if [[ "${ans,,}" == "y" ]]; then
      if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$url" >/dev/null 2>&1 &
        echo "Opening ${url}"
      elif command -v open >/dev/null 2>&1; then
        open "$url" >/dev/null 2>&1 &
        echo "Opening ${url}"
      else
        echo "Repository: ${url}"
      fi
    else
      echo "Repository: ${url}"
    fi
  else
    echo "No update version is available"
  fi
}

check_github_update "${1:-$repo_to_check}"

#!/usr/bin/env bash
#
# Opens one of the scenarios under scenarios/ as a pull request: a branch off origin/main, named
# after the scenario and holding the scenario's files, is pushed, and a pull request is created
# with `gh` - or, without it, the address to create one at is printed.
#
#   scripts/open-scenario.sh clinics
set -euo pipefail

cd "$(dirname "$0")/.."

scenario="${1:-}"
if [ -z "$scenario" ] || [ ! -d "scenarios/$scenario" ]; then
  echo "Usage: $0 <scenario>, one of:" >&2
  ls scenarios >&2
  exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
  echo "The working tree is not clean: commit or stash what is in it first." >&2
  exit 1
fi
if git show-ref --quiet --verify "refs/heads/$scenario"; then
  echo "A branch named '$scenario' exists already: delete it first (git branch -D $scenario)." >&2
  exit 1
fi

title=$(head -n 1 "scenarios/$scenario/PULL_REQUEST.md")
body=$(tail -n +3 "scenarios/$scenario/PULL_REQUEST.md")

git fetch -q origin main
git switch -q -c "$scenario" origin/main
# The scenario's files, laid over the repository; macOS's tar is told to leave file attributes out.
COPYFILE_DISABLE=1 tar -C "scenarios/$scenario" --exclude PULL_REQUEST.md -cf - . | tar -xf -
git add -A
git commit -q -m "$title" -m "$body"
git push -q -u origin "$scenario"
git switch -q main

if command -v gh >/dev/null 2>&1; then
  gh pr create --base main --head "$scenario" --title "$title" --body "$body"
else
  repository=$(git remote get-url origin | sed -E 's#^git@github\.com:#https://github.com/#; s#\.git$##')
  echo "Pushed '$scenario'. Open the pull request at"
  echo "  $repository/compare/main...$scenario?expand=1"
  echo "with the title: $title"
fi

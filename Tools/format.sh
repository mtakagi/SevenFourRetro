#!/bin/zsh
# Formats the Objective-C sources (SevenFour/, Tests/) with clang-format
# and the repository's .clang-format (#71).
#
#   Tools/format.sh           format the files in place
#   Tools/format.sh --check   only check; fail and list what isn't formatted (CI)
#
# Other versions of clang-format format some code differently, so the one CI
# uses is required: 22.1.2. Install it with, e.g.,
#   pipx install clang-format==22.1.2      (or: pip install clang-format==22.1.2)
# or set CLANG_FORMAT to its path.
set -eu

VERSION=22.1.2
CLANG_FORMAT=${CLANG_FORMAT:-clang-format}
ROOT=${0:A:h:h}
cd "$ROOT"

if ! command -v "$CLANG_FORMAT" >/dev/null; then
  echo "clang-format not found. Install clang-format $VERSION (pipx install clang-format==$VERSION) or set CLANG_FORMAT." >&2
  exit 1
fi
if ! "$CLANG_FORMAT" --version | grep -q "version $VERSION"; then
  echo "clang-format $VERSION is needed, not: $("$CLANG_FORMAT" --version)" >&2
  echo "Install it with: pipx install clang-format==$VERSION (or set CLANG_FORMAT)." >&2
  exit 1
fi

files=(${(f)"$(git ls-files 'SevenFour/*.h' 'SevenFour/*.m' 'Tests/*.h' 'Tests/*.m')"})

if [[ ${1:-} == --check ]]; then
  if ! "$CLANG_FORMAT" --dry-run --Werror "${files[@]}"; then
    echo "Some files aren't formatted. Run Tools/format.sh (clang-format $VERSION) and commit the result." >&2
    exit 1
  fi
  echo "All ${#files[@]} files are formatted."
else
  "$CLANG_FORMAT" -i "${files[@]}"
fi

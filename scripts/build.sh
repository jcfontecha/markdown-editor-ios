#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

verbose=false
targets=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    markdown-editor|demo-app)
      targets+=("$1")
      shift
      ;;
    --verbose)
      verbose=true
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [markdown-editor] [demo-app] [--verbose]" >&2
      exit 1
      ;;
  esac
done

if ! command -v xcbeautify >/dev/null 2>&1; then
  echo "xcbeautify is required. Install it before building." >&2
  exit 1
fi

if [[ ${#targets[@]} -eq 0 ]]; then
  targets=("markdown-editor" "demo-app")
fi

run_build() {
  local target="$1"
  local -a command

  case "$target" in
    markdown-editor)
      command=(
        xcodebuild build
        -workspace .swiftpm/xcode/package.xcworkspace
        -scheme MarkdownEditor
        -destination "generic/platform=iOS"
        -configuration Debug
        -skipMacroValidation
      )
      ;;
    demo-app)
      command=(
        xcodebuild build
        -project Demo/MarkdownEditor.xcodeproj
        -scheme MarkdownEditorDemo
        -destination "generic/platform=iOS Simulator"
        -configuration Debug
        -skipMacroValidation
      )
      ;;
    *)
      echo "Unsupported build target: $target" >&2
      exit 1
      ;;
  esac

  if [[ "$verbose" == true ]]; then
    "${command[@]}" | xcbeautify --disable-logging
  else
    "${command[@]}" | xcbeautify --quiet --disable-logging
  fi
}

for target in "${targets[@]}"; do
  run_build "$target"
done

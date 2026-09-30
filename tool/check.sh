#!/usr/bin/env bash
# Runs every check CI runs, in the same order. Usage: ./tool/check.sh
set -euo pipefail
cd "$(dirname "$0")/.."

step() { printf '\n\033[1;34m▶ %s\033[0m\n' "$1"; }

step 'Resolve workspace dependencies'
flutter pub get

step 'Generate localizations'
flutter gen-l10n

step 'Check formatting'
dart format --output=none --set-exit-if-changed lib test packages

step 'Analyze (infos are fatal)'
flutter analyze --fatal-infos

step 'Test svg_core (pure Dart)'
(cd packages/svg_core && dart test)

for package in packages/design_system packages/svg_view; do
  step "Test $package"
  (cd "$package" && flutter test --coverage)
done

step 'Test app'
flutter test --coverage

printf '\n\033[1;32m✔ All checks passed\033[0m\n'

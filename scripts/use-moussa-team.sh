#!/usr/bin/env bash
# Restore DEVELOPMENT_TEAM and PRODUCT_BUNDLE_IDENTIFIER in project.pbxproj to
# Moussa's team and bundle IDs so pushes don't break his build. Run at session
# end, before pushing.

set -euo pipefail

MOUSSA_TEAM="6UWUMY6H27"
NICOLE_TEAM="NHQHUH57U7"

MOUSSA_APP_ID="com.polygoncyber.mise"
MOUSSA_WIDGET_ID="com.polygoncyber.mise.RecipesWidgets"
NICOLE_APP_ID="com.nicolebee.mise"
NICOLE_WIDGET_ID="com.nicolebee.mise.RecipesWidgets"

PROJ="$(cd "$(dirname "$0")/.." && pwd)/Recipes.xcodeproj/project.pbxproj"

if [[ ! -f "$PROJ" ]]; then
  echo "error: $PROJ not found" >&2
  exit 1
fi

sed -i '' \
  -e "s/DEVELOPMENT_TEAM = ${NICOLE_TEAM};/DEVELOPMENT_TEAM = ${MOUSSA_TEAM};/g" \
  -e "s/PRODUCT_BUNDLE_IDENTIFIER = ${NICOLE_WIDGET_ID};/PRODUCT_BUNDLE_IDENTIFIER = ${MOUSSA_WIDGET_ID};/g" \
  -e "s/PRODUCT_BUNDLE_IDENTIFIER = ${NICOLE_APP_ID};/PRODUCT_BUNDLE_IDENTIFIER = ${MOUSSA_APP_ID};/g" \
  "$PROJ"

team_count=$(grep -c "DEVELOPMENT_TEAM = ${MOUSSA_TEAM};" "$PROJ" || true)
app_count=$(grep -c "PRODUCT_BUNDLE_IDENTIFIER = ${MOUSSA_APP_ID};" "$PROJ" || true)
widget_count=$(grep -c "PRODUCT_BUNDLE_IDENTIFIER = ${MOUSSA_WIDGET_ID};" "$PROJ" || true)

echo "DEVELOPMENT_TEAM → ${MOUSSA_TEAM} (Moussa): ${team_count} location(s)"
echo "App bundle ID    → ${MOUSSA_APP_ID}: ${app_count} location(s)"
echo "Widget bundle ID → ${MOUSSA_WIDGET_ID}: ${widget_count} location(s)"

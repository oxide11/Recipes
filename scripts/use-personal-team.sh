#!/usr/bin/env bash
# Swap DEVELOPMENT_TEAM and PRODUCT_BUNDLE_IDENTIFIER in project.pbxproj to
# Nicole's personal team and bundle-ID prefix so Xcode can sign and provision
# locally. Run at session start. Do NOT commit the resulting pbxproj change —
# run scripts/use-moussa-team.sh before pushing.

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

# Widget first (longer string) so the app-id regex doesn't partially match it.
sed -i '' \
  -e "s/DEVELOPMENT_TEAM = ${MOUSSA_TEAM};/DEVELOPMENT_TEAM = ${NICOLE_TEAM};/g" \
  -e "s/PRODUCT_BUNDLE_IDENTIFIER = ${MOUSSA_WIDGET_ID};/PRODUCT_BUNDLE_IDENTIFIER = ${NICOLE_WIDGET_ID};/g" \
  -e "s/PRODUCT_BUNDLE_IDENTIFIER = ${MOUSSA_APP_ID};/PRODUCT_BUNDLE_IDENTIFIER = ${NICOLE_APP_ID};/g" \
  "$PROJ"

team_count=$(grep -c "DEVELOPMENT_TEAM = ${NICOLE_TEAM};" "$PROJ" || true)
app_count=$(grep -c "PRODUCT_BUNDLE_IDENTIFIER = ${NICOLE_APP_ID};" "$PROJ" || true)
widget_count=$(grep -c "PRODUCT_BUNDLE_IDENTIFIER = ${NICOLE_WIDGET_ID};" "$PROJ" || true)

echo "DEVELOPMENT_TEAM → ${NICOLE_TEAM} (Nicole): ${team_count} location(s)"
echo "App bundle ID    → ${NICOLE_APP_ID}: ${app_count} location(s)"
echo "Widget bundle ID → ${NICOLE_WIDGET_ID}: ${widget_count} location(s)"
echo ""
echo "Remember: run scripts/use-moussa-team.sh before pushing."

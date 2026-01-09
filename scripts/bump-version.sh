#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: ./scripts/bump-version.sh 0.1.1"
  exit 1
fi

NEW_VERSION="$1"

echo "📦 Bumping version to $NEW_VERSION..."

# Update version in Xcode project
sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $NEW_VERSION;/g" menubar-claude/menubar-claude.xcodeproj/project.pbxproj

# Update version in pyproject.toml
sed -i '' "s/^version = .*/version = \"$NEW_VERSION\"/" pyproject.toml

echo "✅ Version updated to $NEW_VERSION"
echo ""
echo "Next steps:"
echo "  git add -A"
echo "  git commit -m '🔖 Bump version to $NEW_VERSION'"
echo "  git push origin main"
echo "  git tag v$NEW_VERSION"
echo "  git push origin v$NEW_VERSION"
echo "  gh release create v$NEW_VERSION --generate-notes"

#!/usr/bin/env bash
# cspell:ignore npmjs
set -e

: "${BRANCH?Need to set BRANCH}"
: "${VERSION?Need to set VERSION}"
: "${NODE_AUTH_TOKEN?Need to set NODE_AUTH_TOKEN}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
TYPES_PACKAGE_DIR="$PROJECT_ROOT/types-package"

# Cleanup function to ensure .npmrc is always removed
cleanup() {
  rm -f "$TYPES_PACKAGE_DIR/.npmrc"
}

# Trap to ensure cleanup runs even if script fails or is interrupted
trap cleanup EXIT

cd "$PROJECT_ROOT"

echo "Ensuring dependencies installed..."
yarn install

echo "Generating TypeChain types..."
yarn generateTypes

echo "Building types package..."
yarn buildTypesPackage

cd "$TYPES_PACKAGE_DIR"

echo "Configuring npm authentication..."
cat > .npmrc << EOF
//registry.npmjs.org/:_authToken=${NODE_AUTH_TOKEN}
registry=https://registry.npmjs.org/
EOF

# Set restrictive permissions on .npmrc to protect the auth token
chmod 600 .npmrc

echo "Verifying authentication..."
if ! npm whoami; then
  echo "Error: npm authentication failed"
  rm -f .npmrc
  exit 1
fi

echo "Publishing types package..."
TAG=""
if [[ "$BRANCH" != "stable" ]]; then
  TAG="--tag $BRANCH"
fi

npm publish --access public $TAG



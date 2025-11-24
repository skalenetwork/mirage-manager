#!/usr/bin/env bash

set -e

: "${BRANCH?Need to set BRANCH}"
: "${VERSION?Need to set VERSION}"
: "${NODE_AUTH_TOKEN?Need to set NODE_AUTH_TOKEN}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
TYPES_PACKAGE_DIR="$PROJECT_ROOT/types-package"

cd "$PROJECT_ROOT"

echo "Ensuring dependencies installed..."
yarn install

echo "Generating TypeChain types..."
yarn generateTypes

echo "Building types package..."
yarn buildTypesPackage

cd "$TYPES_PACKAGE_DIR"

echo "Publishing types package..."
TAG=""
if [[ "$BRANCH" != "stable" ]]; then
  TAG="--tag $BRANCH"
fi

npm publish --access public $TAG

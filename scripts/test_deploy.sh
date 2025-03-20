#!/usr/bin/env bash

set -e

yarn hardhat run migrations/deploy.ts

# cspell:words .yarnrc.yml

FROM node:22-slim

RUN mkdir /usr/src/manager
WORKDIR /usr/src/manager

RUN corepack enable && corepack prepare yarn@4.7.0 --activate

COPY package.json ./
COPY hardhat.config.ts ./
COPY yarn.lock ./

RUN echo "nodeLinker: node-modules" > .yarnrc.yml
RUN yarn install

ENV NODE_OPTIONS="--max-old-space-size=2048"

COPY . .

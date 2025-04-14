FROM node:22

RUN mkdir /usr/src/manager
WORKDIR /usr/src/manager

RUN apt-get update && apt-get install build-essential
RUN corepack enable && corepack prepare yarn@4.7.0 --activate

COPY package.json ./
COPY hardhat.config.ts ./
COPY yarn.lock ./
RUN yarn install

ENV NODE_OPTIONS="--max-old-space-size=2048"

COPY . .

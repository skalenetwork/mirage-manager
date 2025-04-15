# cspell:words .yarnrc.yml

FROM node:22-slim

RUN mkdir /usr/src/manager
WORKDIR /usr/src/manager

# git is needed only if version is not set manually
RUN apt-get update && apt-get install -y git

COPY package.json ./
COPY hardhat.config.ts ./
COPY yarn.lock ./
COPY .yarn/ .yarn/
COPY .yarnrc.yml ./

RUN sed -i 's/nodeLinker: pnpm/nodeLinker: node-modules/' .yarnrc.yml
RUN yarn install

ENV NODE_OPTIONS="--max-old-space-size=2048"

COPY . .
# previous command has overwritten the .yarnrc.yml file
RUN sed -i 's/nodeLinker: pnpm/nodeLinker: node-modules/' .yarnrc.yml

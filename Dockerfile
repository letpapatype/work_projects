FROM alpine:latest
RUN apk add --update nodejs npm
WORKDIR /NexiaSTA

COPY package*.json ./
COPY ./src ./src
COPY ./Install/linux/run-nexia-sta ./

RUN npm install

# TODO: Should javascript-obfuscator be added to the package.json?
# Reason being, npm run build does not work without installing it by itself.
RUN npm -g install javascript-obfuscator

RUN npm run build

RUN rm -rf ./src

RUN mv ./build/src .
RUN mkdir ./src/configFiles

RUN rm -rf ./build

# # Are there any runtime env variables needed. I noticed was NODE_ENV
ENV NODE_ENV="production" 

# CMD ["node", "src/index.js"]
RUN chmod +x run-nexia-sta


FROM oven/bun AS builder

WORKDIR /app

# Build-time defaults. With VERT_RUNTIME_ENV=true (the default), any PUB_*
# variable can still be overridden when the container starts, e.g.
# `docker run -e PUB_VERTD_URL=https://vertd.example.com ...`
ARG VERT_RUNTIME_ENV=true
ARG PUB_ENV=production
ARG PUB_HOSTNAME=
ARG PUB_PLAUSIBLE_URL=
ARG PUB_VERTD_URL=https://vertd.vert.sh
ARG PUB_DISABLE_ALL_EXTERNAL_REQUESTS=false
ARG PUB_DONATION_URL=https://donations.vert.sh
ARG PUB_STRIPE_KEY=pk_live_51TlrPaFTPjkhEGBSu5Kwy5jJQYxcX5yUUHXiH5g7Xzvb0NKzDqbooc126HjlW35uUkfAgQN2ruEoCuyQynoxpKaA00ojFgQ116
ARG PUB_DISABLE_FAILURE_BLOCKS=false

ENV VERT_RUNTIME_ENV=${VERT_RUNTIME_ENV}
ENV PUB_ENV=${PUB_ENV}
ENV PUB_HOSTNAME=${PUB_HOSTNAME}
ENV PUB_PLAUSIBLE_URL=${PUB_PLAUSIBLE_URL}
ENV PUB_VERTD_URL=${PUB_VERTD_URL}
ENV PUB_DISABLE_ALL_EXTERNAL_REQUESTS=${PUB_DISABLE_ALL_EXTERNAL_REQUESTS}
ENV PUB_DONATION_URL=${PUB_DONATION_URL}
ENV PUB_STRIPE_KEY=${PUB_STRIPE_KEY}
ENV PUB_DISABLE_FAILURE_BLOCKS=${PUB_DISABLE_FAILURE_BLOCKS}

COPY package.json ./

RUN apt-get update && \
	apt-get install -y --no-install-recommends git && \
	rm -rf /var/lib/apt/lists/*

RUN bun install

COPY . ./

RUN bun run build

FROM nginx:stable-alpine

EXPOSE 80/tcp

COPY ./nginx/default.conf /etc/nginx/conf.d/default.conf

COPY --from=builder /app/build /usr/share/nginx/html

COPY --chmod=755 ./docker/*.sh /docker-entrypoint.d/

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
	CMD wget --quiet --spider http://localhost/ || exit 1

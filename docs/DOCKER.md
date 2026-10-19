## Using Docker

This file covers how to run VERT under a Docker container.

- [Quick start](#quick-start)
- [Configuration](#configuration)
- [Running your own vertd](#running-your-own-vertd)
- [Manually building the image](#manually-building-the-image)

### Quick start

```shell
docker run -d \
    --restart unless-stopped \
    -p 3000:80 \
    --name "vert" \
    ghcr.io/vert-sh/vert:latest
```

This will do the following:

- Use the prebuilt image as the container `vert`, in detached mode
- Continuously restart the container until manually stopped
- Map `3000/tcp` (host) to `80/tcp` (container)

VERT is now available on `http://localhost:3000`. Out of the box it uses the official vertd instance for video conversion, has analytics disabled and runs in production mode.

We also have a [`docker-compose.yml`](/docker-compose.yml) file available. Use `docker compose up -d` to start the stack, or `docker compose down` to bring it down. You can read more about Docker Compose in general [here](https://docs.docker.com/compose/intro/compose-application-model/).

### Configuration

All `PUB_*` variables are read when the container **starts**, so you can configure the prebuilt image without rebuilding it — change the variable and restart the container. Variables you don't set keep the defaults the image was built with.

| Variable                            | Default                 | Description                                                                                                                         |
| ----------------------------------- | ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `PUB_VERTD_URL`                     | `https://vertd.vert.sh` | URL of the [vertd](./VIDEO_CONVERSION.md) instance used for video conversion. Must be reachable from your users' browsers.          |
| `PUB_ENV`                           | `production`            | `production`, `nightly` or `development`.                                                                                           |
| `PUB_HOSTNAME`                      | _(empty)_               | Hostname reported to Plausible.                                                                                                     |
| `PUB_PLAUSIBLE_URL`                 | _(empty)_               | URL of your Plausible instance. Empty disables analytics.                                                                           |
| `PUB_DISABLE_ALL_EXTERNAL_REQUESTS` | `false`                 | Disable vertd, Stripe, Plausible, etc.                                                                                              |
| `PUB_DISABLE_FAILURE_BLOCKS`        | `false`                 | Set to `true` if you serve VERT over plain HTTP (e.g. on your LAN) — failure blocking needs a secure context (HTTPS) to hash files. |
| `PUB_DONATION_URL`/`PUB_STRIPE_KEY` | official VERT values    | Please keep these, they support VERT's development!                                                                                 |

With `docker run`, pass them with `-e`:

```shell
docker run -d -p 3000:80 --name vert \
    -e PUB_VERTD_URL=https://vertd.example.com \
    -e PUB_DISABLE_FAILURE_BLOCKS=true \
    ghcr.io/vert-sh/vert:latest
```

With Docker Compose, put them in a `.env` file next to `docker-compose.yml` (see [`.env.example`](/.env.example)) and run `docker compose up -d` again.

> [!NOTE]
> Values are injected into the served HTML as `window.__VERT_ENV__` by [`docker/40-vert-runtime-env.sh`](/docker/40-vert-runtime-env.sh). They are public by nature (like every `PUB_*` variable) — never put secrets in them.

### Running your own vertd

If you'd like to convert videos on your own hardware, run [vertd](https://github.com/VERT-sh/vertd) next to VERT and point `PUB_VERTD_URL` at it. Keep in mind the URL is used by the **browser**, not by the VERT container, so it has to be reachable from the machines opening VERT (e.g. `http://192.168.1.10:24153` or a reverse-proxied `https://vertd.example.com`), not a Docker-internal hostname like `http://vertd:24153`.

```yaml
services:
    vert:
        image: ghcr.io/vert-sh/vert:latest
        restart: unless-stopped
        ports:
            - 3000:80
        environment:
            PUB_VERTD_URL: http://localhost:24153
    vertd:
        image: ghcr.io/vert-sh/vertd:latest
        restart: unless-stopped
        ports:
            - 24153:24153
        # see the vertd docs for passing through your GPU
```

See [Video Conversion](./VIDEO_CONVERSION.md) for more details.

### Manually building the image

First, clone the repository:

```shell
git clone https://github.com/VERT-sh/VERT
cd VERT/
```

Then build a Docker image with:

```shell
docker build -t vert-sh/vert .
```

Any `PUB_*` variable can also be passed as a `--build-arg` to change the image's built-in defaults (they can still be overridden at runtime). Pass `--build-arg VERT_RUNTIME_ENV=false` if you want a fully static build that ignores runtime variables.

You can then run it by using:

```shell
docker run -d \
    --restart unless-stopped \
    -p 3000:80 \
    --name "vert" \
    vert-sh/vert
```

With Docker Compose, use `docker compose up -d --build`.

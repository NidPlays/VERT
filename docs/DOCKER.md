## Using Docker

This file covers how to run VERT under a Docker container.

- [Quick start](#quick-start)
- [Configuration](#configuration)
- [Docker Compose (with vertd)](#docker-compose-with-vertd)
- [Behind a reverse proxy](#behind-a-reverse-proxy)
- [Manually building the image](#manually-building-the-image)
- [Publishing images from a fork](#publishing-images-from-a-fork)

### Quick start

```shell
docker run -d \
    --restart unless-stopped \
    -p 3000:80 \
    --name "vert" \
    ghcr.io/nidplays/vert:latest
```

This will do the following:

- Use the prebuilt image as the container `vert`, in detached mode
- Continuously restart the container until manually stopped
- Map `3000/tcp` (host) to `80/tcp` (container)

VERT is now available on `http://localhost:3000`. Out of the box it uses the official vertd instance for video conversion, has analytics disabled and runs in production mode.

If you'd also like to run your own video conversion server, see [Docker Compose (with vertd)](#docker-compose-with-vertd).

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
    ghcr.io/nidplays/vert:latest
```

With Docker Compose, put them in a `.env` file next to `docker-compose.yml` (see [`.env.example`](/.env.example)) and run `docker compose up -d` again.

> [!NOTE]
> Values are injected into the served HTML as `window.__VERT_ENV__` by [`docker/40-vert-runtime-env.sh`](/docker/40-vert-runtime-env.sh). They are public by nature (like every `PUB_*` variable) — never put secrets in them.

### Docker Compose (with vertd)

The [`docker-compose.yml`](/docker-compose.yml) file runs VERT together with its own [vertd](https://github.com/VERT-sh/vertd) instance, so videos are converted on your hardware instead of the official servers. Use `docker compose up -d` to start the stack, or `docker compose down` to bring it down. You can read more about Docker Compose in general [here](https://docs.docker.com/compose/intro/compose-application-model/).

Settings go in a `.env` file next to `docker-compose.yml`. Besides the `PUB_*` variables above, it understands:

| Variable             | Default                        | Description                                                                          |
| -------------------- | ------------------------------ | ------------------------------------------------------------------------------------ |
| `VERT_IMAGE`         | `ghcr.io/nidplays/vert:latest` | VERT image to run, e.g. a specific version like `ghcr.io/nidplays/vert:sha-520427c`. |
| `VERTD_IMAGE`        | `ghcr.io/vert-sh/vertd:latest` | vertd image to run.                                                                  |
| `PORT`               | `3000`                         | Host port for VERT.                                                                  |
| `VERTD_PORT`         | `24153`                        | Host port for vertd.                                                                 |
| `ALLOW_CPU_FALLBACK` | `true`                         | Let vertd use (slower) CPU encoding when no supported GPU is found.                  |

> [!IMPORTANT]
> `PUB_VERTD_URL` (default `http://localhost:24153`) is used by your visitors' **browsers**, not by the VERT container. It works as-is when you open VERT on the machine running Docker; otherwise set it to something they can reach, like `http://192.168.1.10:24153` or a reverse-proxied `https://vertd.example.com` — not a Docker-internal hostname like `http://vertd:24153`. If you're serving VERT over HTTPS, vertd needs to be served over HTTPS as well.

If you'd rather use the official vertd instance, set `PUB_VERTD_URL=https://vertd.vert.sh` and remove the `vertd` service.

#### GPU acceleration

By default vertd encodes on the CPU. For hardware acceleration, uncomment **one** of the GPU blocks at the bottom of the `vertd` service in `docker-compose.yml`:

- **Intel/AMD:** the `devices` block, which passes through `/dev/dri`. Set `VERTD_VAAPI_DEVICE_PATH` if your GPU isn't at `/dev/dri/renderD128`.
- **NVIDIA:** the `runtime` and `deploy` blocks. These need the [NVIDIA Container Toolkit](https://github.com/VERT-sh/vertd/blob/main/docs/DOCKER_SETUP.md#for-nvidia-users).

Check `docker logs vertd` for a `detected a ... GPU` message. See the [vertd Docker docs](https://github.com/VERT-sh/vertd/blob/main/docs/DOCKER_SETUP.md) and [Video Conversion](./VIDEO_CONVERSION.md) for more details.

### Behind a reverse proxy

You can keep both containers off the public internet and serve vertd from the **same domain** as VERT under a path, e.g. `https://vert.example.com/vertd/`. Because everything is same-origin, no CORS setup is needed, and any authentication in front of VERT (like [oauth2-proxy](https://oauth2-proxy.github.io/oauth2-proxy/)) automatically covers vertd too: the session cookie is sent along with every upload, download and WebSocket.

1. Only listen on loopback with a `docker-compose.override.yml` next to `docker-compose.yml` (Compose picks it up automatically, so the main file stays untouched):

    ```yaml
    services:
        vert:
            ports: !override
                - 127.0.0.1:3000:80
        vertd:
            ports: !override
                - 127.0.0.1:24153:24153
    ```

2. Point VERT at the proxied path in your `.env`:

    ```shell
    PUB_VERTD_URL=https://vert.example.com/vertd
    ```

3. Proxy both, e.g. with nginx and oauth2-proxy in [`auth_request` mode](https://oauth2-proxy.github.io/oauth2-proxy/configuration/integration#configuring-for-use-with-the-nginx-auth_request-directive) (run oauth2-proxy with `--http-address=127.0.0.1:4180 --reverse-proxy=true --upstream=static://202`):

    ```nginx
    map $http_upgrade $connection_upgrade {
        default upgrade;
        ""      close;
    }

    server {
        listen 443 ssl;
        server_name vert.example.com;
        # ssl_certificate ...; ssl_certificate_key ...;

        # nginx defaults to 1 MB; videos sent to vertd can be much larger
        client_max_body_size 0;

        location /oauth2/ {
            proxy_pass http://127.0.0.1:4180;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Auth-Request-Redirect $request_uri;
        }

        location = /oauth2/auth {
            internal;
            proxy_pass http://127.0.0.1:4180;
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Content-Length "";
            proxy_pass_request_body off;
        }

        location / {
            auth_request /oauth2/auth;
            error_page 401 =403 /oauth2/sign_in;
            proxy_pass http://127.0.0.1:3000;
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /vertd/ {
            auth_request /oauth2/auth;
            # the trailing slash strips the /vertd prefix
            proxy_pass http://127.0.0.1:24153/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $connection_upgrade;
            proxy_set_header Host $host;
            # stream uploads/downloads and keep the WebSocket open during long conversions
            proxy_request_buffering off;
            proxy_buffering off;
            proxy_read_timeout 1h;
            proxy_send_timeout 1h;
        }
    }
    ```

Unauthenticated requests to `/vertd/` get a plain `401` rather than a login redirect, so vertd is never reachable without a session. If a session expires while VERT is open, video conversions will fail until the page is reloaded and the user logs in again.

### Manually building the image

First, clone the repository:

```shell
git clone https://github.com/NidPlays/VERT
cd VERT/
```

Then build a Docker image with:

```shell
docker build -t nidplays/vert .
```

Any `PUB_*` variable can also be passed as a `--build-arg` to change the image's built-in defaults (they can still be overridden at runtime). Pass `--build-arg VERT_RUNTIME_ENV=false` if you want a fully static build that ignores runtime variables.

You can then run it by using:

```shell
docker run -d \
    --restart unless-stopped \
    -p 3000:80 \
    --name "vert" \
    nidplays/vert
```

With Docker Compose, use `docker compose up -d --build`.

### Publishing images from a fork

The [Docker workflow](/.github/workflows/docker.yml) builds and pushes `ghcr.io/<owner>/<repo>` from whichever repository it runs in, so a fork can publish its own image:

1. Enable GitHub Actions on your fork.
2. Push to `main` (published as `latest`), push a `v*` tag (published as e.g. `1.2.3` and `1.2`), or run the workflow manually from the Actions tab.
3. New packages are private by default. Either make it public under your profile's **Packages** → package settings, or `docker login ghcr.io` on your server.
4. Set `VERT_IMAGE=ghcr.io/<your-user>/vert:latest` in your `.env` and run `docker compose pull && docker compose up -d`.

This fork publishes its image as `ghcr.io/nidplays/vert`, with tags `latest` (the `main` branch), `sha-<commit>` for every build, and `<version>` for `v*` tags.

Since configuration happens at runtime, you don't need to change any build arguments in the workflow.

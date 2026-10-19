import { browser } from "$app/environment";
import * as staticEnv from "$env/static/public";

// public env vars, baked in at build time via $env/static/public.
// when built with VERT_RUNTIME_ENV=true (the docker image does this), values can
// also be overridden at runtime through window.__VERT_ENV__, which the docker
// entrypoint injects into every prerendered page. for every other build
// __RUNTIME_ENV__ is false, so this folds down to the static values.

type PublicEnv = typeof staticEnv;

const runtimeEnv: Partial<Record<keyof PublicEnv, string>> =
	__RUNTIME_ENV__ && browser ? (window.__VERT_ENV__ ?? {}) : {};

const read = <K extends keyof PublicEnv>(key: K): string =>
	__RUNTIME_ENV__ && key in runtimeEnv
		? (runtimeEnv[key] as string)
		: staticEnv[key];

export const PUB_ENV = read("PUB_ENV");
export const PUB_HOSTNAME = read("PUB_HOSTNAME");
export const PUB_PLAUSIBLE_URL = read("PUB_PLAUSIBLE_URL");
export const PUB_VERTD_URL = read("PUB_VERTD_URL");
export const PUB_DISABLE_ALL_EXTERNAL_REQUESTS = read(
	"PUB_DISABLE_ALL_EXTERNAL_REQUESTS",
);
export const PUB_DONATION_URL = read("PUB_DONATION_URL");
export const PUB_STRIPE_KEY = read("PUB_STRIPE_KEY");
export const PUB_DISABLE_FAILURE_BLOCKS = read("PUB_DISABLE_FAILURE_BLOCKS");

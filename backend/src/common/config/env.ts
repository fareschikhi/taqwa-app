/**
 * Reads a required environment variable, failing loudly when it is absent.
 *
 * Secrets must never have an in-source fallback: a default that ships in the
 * repository is not a secret, and a server silently running on one is worse
 * than a server that refuses to start.
 */
export function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(
      `Missing required environment variable ${name}. ` +
        'Copy backend/.env.example to backend/.env and fill it in.',
    );
  }
  return value;
}

import { HttpException, HttpStatus, Injectable } from '@nestjs/common';

/** Wrong passwords allowed on one account before it is locked. */
export const MAX_FAILED_ATTEMPTS = 5;

/** How long a locked account refuses sign-ins, and how long failures count. */
export const LOCK_DURATION_MS = 15 * 60 * 1000;

/** Above this many tracked accounts, expired entries are swept out. */
const SWEEP_THRESHOLD = 10_000;

interface Attempts {
  failures: number;
  /** When the failure count resets, or when the lock lifts once locked. */
  expiresAt: number;
}

/**
 * Locks an account after repeated wrong passwords, whichever IP they come
 * from. The per-IP throttle on the login route cannot stop a guesser that
 * spreads its tries over many addresses; this can.
 *
 * Failures are counted per identifier typed, not per account found, so an
 * unknown email locks exactly like a real one and the lock reveals nothing
 * about which accounts exist.
 *
 * The state lives in memory: a restart clears it, and it is not shared
 * between instances. That fits the single API container this runs as.
 */
@Injectable()
export class LoginAttemptsService {
  private attempts = new Map<string, Attempts>();

  /** Throws 429 while any of the identifiers is locked. */
  assertNotLocked(keys: string[], now = Date.now()) {
    for (const key of keys) {
      const entry = this.current(key, now);
      if (entry && entry.failures >= MAX_FAILED_ATTEMPTS) {
        const minutes = Math.ceil((entry.expiresAt - now) / 60_000);
        throw new HttpException(
          `محاولات دخول خاطئة كثيرة. حاول مجددا بعد ${minutes} دقيقة`,
          HttpStatus.TOO_MANY_REQUESTS,
        );
      }
    }
  }

  recordFailure(keys: string[], now = Date.now()) {
    if (this.attempts.size > SWEEP_THRESHOLD) this.sweep(now);
    for (const key of keys) {
      const entry = this.current(key, now) ?? {
        failures: 0,
        expiresAt: now + LOCK_DURATION_MS,
      };
      entry.failures += 1;
      // The lock runs its full length from the failure that triggered it.
      if (entry.failures >= MAX_FAILED_ATTEMPTS) {
        entry.expiresAt = now + LOCK_DURATION_MS;
      }
      this.attempts.set(key, entry);
    }
  }

  recordSuccess(keys: string[]) {
    for (const key of keys) this.attempts.delete(key);
  }

  private current(key: string, now: number) {
    const entry = this.attempts.get(key);
    if (entry && entry.expiresAt <= now) {
      this.attempts.delete(key);
      return undefined;
    }
    return entry;
  }

  private sweep(now: number) {
    for (const [key, entry] of this.attempts) {
      if (entry.expiresAt <= now) this.attempts.delete(key);
    }
  }
}

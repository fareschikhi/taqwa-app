import { HttpStatus } from '@nestjs/common';
import {
  LOCK_DURATION_MS,
  LoginAttemptsService,
  MAX_FAILED_ATTEMPTS,
} from './login-attempts.service';

describe('LoginAttemptsService', () => {
  const KEY = ['phone:3001'];
  const fail = (service: LoginAttemptsService, times: number, now = 0) => {
    for (let i = 0; i < times; i++) service.recordFailure(KEY, now);
  };

  it('allows sign-ins below the failure limit', () => {
    const service = new LoginAttemptsService();
    fail(service, MAX_FAILED_ATTEMPTS - 1);

    expect(() => service.assertNotLocked(KEY, 0)).not.toThrow();
  });

  it('locks with a 429 at the failure limit', () => {
    const service = new LoginAttemptsService();
    fail(service, MAX_FAILED_ATTEMPTS);

    expect(() => service.assertNotLocked(KEY, 0)).toThrow(
      expect.objectContaining({ status: HttpStatus.TOO_MANY_REQUESTS }),
    );
  });

  it('lifts the lock once it runs out', () => {
    const service = new LoginAttemptsService();
    fail(service, MAX_FAILED_ATTEMPTS);

    expect(() => service.assertNotLocked(KEY, LOCK_DURATION_MS)).not.toThrow();
  });

  it('keeps other identifiers unaffected', () => {
    const service = new LoginAttemptsService();
    fail(service, MAX_FAILED_ATTEMPTS);

    expect(() => service.assertNotLocked(['phone:3002'], 0)).not.toThrow();
  });

  it('clears the count on success', () => {
    const service = new LoginAttemptsService();
    fail(service, MAX_FAILED_ATTEMPTS - 1);
    service.recordSuccess(KEY);
    fail(service, MAX_FAILED_ATTEMPTS - 1);

    expect(() => service.assertNotLocked(KEY, 0)).not.toThrow();
  });
});

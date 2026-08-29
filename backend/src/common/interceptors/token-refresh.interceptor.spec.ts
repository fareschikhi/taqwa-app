import { ExecutionContext, CallHandler } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { of, lastValueFrom } from 'rxjs';
import { TokenRefreshInterceptor } from './token-refresh.interceptor';

const SECONDS = 1000;
const DAY = 24 * 60 * 60;

function contextFor(user: unknown, response: { header: jest.Mock }) {
  return {
    switchToHttp: () => ({
      getRequest: () => ({ user }),
      getResponse: () => response,
    }),
  } as unknown as ExecutionContext;
}

const next: CallHandler = { handle: () => of('ok') };

function run(user: unknown) {
  const response = { header: jest.fn() };
  const jwt = { sign: jest.fn().mockReturnValue('fresh.jwt.token') };
  const interceptor = new TokenRefreshInterceptor(jwt as unknown as JwtService);
  const result = lastValueFrom(
    interceptor.intercept(contextFor(user, response), next),
  );
  return { response, jwt, result };
}

const nowSeconds = () => Math.floor(Date.now() / SECONDS);

describe('TokenRefreshInterceptor', () => {
  it('re-signs a token inside the last three days', async () => {
    const user = { id: 5, role: 'TEACHER', tokenExp: nowSeconds() + 2 * DAY };
    const { response, jwt, result } = run(user);

    await result;

    expect(jwt.sign).toHaveBeenCalledWith({ sub: 5, role: 'TEACHER' });
    expect(response.header).toHaveBeenCalledWith(
      'X-Refreshed-Token',
      'fresh.jwt.token',
    );
  });

  it('leaves a freshly issued token alone', async () => {
    const user = { id: 5, role: 'TEACHER', tokenExp: nowSeconds() + 6 * DAY };
    const { response, jwt, result } = run(user);

    await result;

    expect(jwt.sign).not.toHaveBeenCalled();
    expect(response.header).not.toHaveBeenCalled();
  });

  it('does nothing on an unauthenticated request', async () => {
    const { response, jwt, result } = run(undefined);

    await result;

    expect(jwt.sign).not.toHaveBeenCalled();
    expect(response.header).not.toHaveBeenCalled();
  });

  it('passes the handler response through untouched', async () => {
    const user = { id: 5, role: 'TEACHER', tokenExp: nowSeconds() + 2 * DAY };
    const { result } = run(user);

    await expect(result).resolves.toBe('ok');
  });
});

import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { TeacherNewsGuard } from './teacher-news.guard';

function contextFor(user: unknown): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => ({ user }) }),
  } as unknown as ExecutionContext;
}

describe('TeacherNewsGuard', () => {
  const guard = new TeacherNewsGuard();

  it.each(['ADMIN', 'MANAGER'])('passes %s, who @Roles already narrows', (role) => {
    expect(guard.canActivate(contextFor({ role }))).toBe(true);
  });

  it('allows a TEACHER the admin granted news to', () => {
    const user = { role: 'TEACHER', teacher: { id: 3, canPostNews: true } };
    expect(guard.canActivate(contextFor(user))).toBe(true);
  });

  it('rejects a TEACHER without the grant', () => {
    const user = { role: 'TEACHER', teacher: { id: 3, canPostNews: false } };
    expect(() => guard.canActivate(contextFor(user))).toThrow(ForbiddenException);
  });

  // Fails closed: no teacher row loaded is not a grant.
  it('rejects a TEACHER whose teacher relation was never loaded', () => {
    expect(() => guard.canActivate(contextFor({ role: 'TEACHER' }))).toThrow(
      ForbiddenException,
    );
  });
});

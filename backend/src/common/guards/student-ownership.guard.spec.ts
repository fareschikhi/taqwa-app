import { ExecutionContext } from '@nestjs/common';
import { StudentOwnershipGuard } from './student-ownership.guard';

function contextFor(user: unknown, studentId: number): ExecutionContext {
  return {
    switchToHttp: () => ({
      getRequest: () => ({ user, params: { id: String(studentId) } }),
    }),
    getHandler: () => undefined,
    getClass: () => undefined,
  } as unknown as ExecutionContext;
}

const guardFor = (row: { parentId?: number; userId?: number } | null) => {
  const prisma = {
    student: { findUnique: jest.fn().mockResolvedValue(row) },
  };
  return new StudentOwnershipGuard(prisma as any);
};

describe('StudentOwnershipGuard', () => {
  it('denies a STUDENT reading their own record', async () => {
    const guard = guardFor({ parentId: 4 });
    const user = { role: 'STUDENT', student: { id: 3 } };

    await expect(guard.canActivate(contextFor(user, 3))).resolves.toBe(false);
  });

  it('allows a PARENT reading their own child', async () => {
    const guard = guardFor({ parentId: 4 });
    const user = { role: 'PARENT', parent: { id: 4 } };

    await expect(guard.canActivate(contextFor(user, 3))).resolves.toBe(true);
  });

  it('denies a PARENT reading another parent\'s child', async () => {
    const guard = guardFor({ parentId: 9 });
    const user = { role: 'PARENT', parent: { id: 4 } };

    await expect(guard.canActivate(contextFor(user, 3))).resolves.toBe(false);
  });

  it.each(['ADMIN', 'TEACHER', 'MANAGER'])(
    'allows %s cross-student access',
    async (role) => {
      const guard = guardFor({ parentId: 4 });

      await expect(guard.canActivate(contextFor({ role }, 3))).resolves.toBe(
        true,
      );
    },
  );

  // `user.student.id` is a claim carried on the token, not the database row
  // the guard is supposed to trust — so it is set here to a third value that
  // matches neither the requested route id nor the actor's own id. A guard
  // that compared `studentId === user.student?.id` instead of the DB row's
  // `userId` would see 21 !== 999 and wrongly deny, so only the correct,
  // database-sourced comparison can pass this test.
  it('allows an ADULT_STUDENT reading his own record', async () => {
    const guard = guardFor({ userId: 11 });
    const user = { role: 'ADULT_STUDENT', id: 11, student: { id: 999 } };

    await expect(guard.canActivate(contextFor(user, 21))).resolves.toBe(true);
  });

  // Here the claimed `student.id` is deliberately set to match the route id
  // being requested — the exact shape of the attack this guard exists to
  // stop. A guard trusting that claim would wrongly allow; only comparing the
  // database row's `userId` against the actor's own id correctly denies.
  it('denies an ADULT_STUDENT reading another student\'s record', async () => {
    const guard = guardFor({ userId: 99 });
    const user = { role: 'ADULT_STUDENT', id: 11, student: { id: 22 } };

    await expect(guard.canActivate(contextFor(user, 22))).resolves.toBe(false);
  });

  it('denies an ADULT_STUDENT when the record does not exist', async () => {
    const guard = guardFor(null);
    const user = { role: 'ADULT_STUDENT', id: 11, student: { id: 21 } };

    await expect(guard.canActivate(contextFor(user, 404))).resolves.toBe(false);
  });
});

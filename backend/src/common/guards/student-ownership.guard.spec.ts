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

  it('allows an ADULT_STUDENT reading his own record', async () => {
    const guard = guardFor({ userId: 11 });
    const user = { role: 'ADULT_STUDENT', id: 11, student: { id: 21 } };

    await expect(guard.canActivate(contextFor(user, 21))).resolves.toBe(true);
  });

  it('denies an ADULT_STUDENT reading another student\'s record', async () => {
    const guard = guardFor({ userId: 99 });
    const user = { role: 'ADULT_STUDENT', id: 11, student: { id: 21 } };

    await expect(guard.canActivate(contextFor(user, 22))).resolves.toBe(false);
  });

  it('denies an ADULT_STUDENT when the record does not exist', async () => {
    const guard = guardFor(null);
    const user = { role: 'ADULT_STUDENT', id: 11, student: { id: 21 } };

    await expect(guard.canActivate(contextFor(user, 404))).resolves.toBe(false);
  });
});

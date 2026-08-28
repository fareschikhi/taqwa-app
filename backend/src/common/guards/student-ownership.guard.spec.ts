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

const guardFor = (parentId: number | null) => {
  const prisma = {
    student: {
      findUnique: jest
        .fn()
        .mockResolvedValue(parentId === null ? null : { parentId }),
    },
  };
  return new StudentOwnershipGuard(prisma as any);
};

describe('StudentOwnershipGuard', () => {
  it('denies a STUDENT reading their own record', async () => {
    const guard = guardFor(4);
    const user = { role: 'STUDENT', student: { id: 3 } };

    await expect(guard.canActivate(contextFor(user, 3))).resolves.toBe(false);
  });

  it('allows a PARENT reading their own child', async () => {
    const guard = guardFor(4);
    const user = { role: 'PARENT', parent: { id: 4 } };

    await expect(guard.canActivate(contextFor(user, 3))).resolves.toBe(true);
  });

  it('denies a PARENT reading another parent\'s child', async () => {
    const guard = guardFor(9);
    const user = { role: 'PARENT', parent: { id: 4 } };

    await expect(guard.canActivate(contextFor(user, 3))).resolves.toBe(false);
  });

  it.each(['ADMIN', 'TEACHER', 'MANAGER'])(
    'allows %s cross-student access',
    async (role) => {
      const guard = guardFor(4);

      await expect(guard.canActivate(contextFor({ role }, 3))).resolves.toBe(
        true,
      );
    },
  );
});

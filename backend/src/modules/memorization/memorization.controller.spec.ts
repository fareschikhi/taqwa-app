import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';
import { MemorizationController } from './memorization.controller';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';

/**
 * A manager opens a student's details page, which reads the memorization
 * history and progress next to the profile and attendance summary. Those two
 * routes left MANAGER out of @Roles, so the page came back 403 while the
 * attendance routes beside it answered fine.
 */
describe('MemorizationController role wiring', () => {
  const reflector = new Reflector();

  const rolesFor = (handler: unknown) =>
    reflector.get<Role[]>(ROLES_KEY, handler as never) ?? [];

  it("lets a manager read a student's memorization history", () => {
    expect(rolesFor(MemorizationController.prototype.findByStudent)).toContain(
      Role.MANAGER,
    );
  });

  it("lets a manager read a student's memorization progress", () => {
    expect(rolesFor(MemorizationController.prototype.getProgress)).toContain(
      Role.MANAGER,
    );
  });

  it('keeps recording memorization to admins and teachers', () => {
    expect(rolesFor(MemorizationController.prototype.create)).toEqual([
      Role.ADMIN,
      Role.TEACHER,
    ]);
  });
});

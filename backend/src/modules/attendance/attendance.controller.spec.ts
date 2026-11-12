import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';
import { AttendanceController } from './attendance.controller';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';

describe('AttendanceController role wiring', () => {
  const reflector = new Reflector();
  const rolesFor = (handler: unknown) =>
    reflector.get<Role[]>(ROLES_KEY, handler as never) ?? [];

  // Deleting a mistaken day corrects the register, so it stays with the two
  // roles that write it; a manager only reads.
  it('keeps deleting an attendance day to admins and teachers', () => {
    expect(rolesFor(AttendanceController.prototype.remove)).toEqual([
      Role.ADMIN,
      Role.TEACHER,
    ]);
  });
});

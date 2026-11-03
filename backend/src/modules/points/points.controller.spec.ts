import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { PointsController } from './points.controller';

const rolesOf = (handler: keyof PointsController) =>
  [...(new Reflector().get<string[]>(ROLES_KEY, PointsController.prototype[handler]) ?? [])].sort();

describe('PointsController roles', () => {
  it('lets staff and adult students read their own points', () => {
    expect(rolesOf('mine')).toEqual(['ADULT_STUDENT', 'MANAGER', 'TEACHER']);
  });

  it("lets a student's circle read the student's points", () => {
    expect(rolesOf('byStudent')).toEqual([
      'ADMIN',
      'ADULT_STUDENT',
      'MANAGER',
      'PARENT',
      'TEACHER',
    ]);
  });

  it("keeps any account's points to the admin", () => {
    expect(rolesOf('byUser')).toEqual(['ADMIN']);
  });

  it('keeps halaqa totals to staff', () => {
    expect(rolesOf('byHalaqa')).toEqual(['ADMIN', 'MANAGER', 'TEACHER']);
  });

  it('keeps adjusting and undoing to staff', () => {
    expect(rolesOf('create')).toEqual(['ADMIN', 'MANAGER', 'TEACHER']);
    expect(rolesOf('remove')).toEqual(['ADMIN', 'MANAGER', 'TEACHER']);
  });
});

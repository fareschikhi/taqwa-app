import { Reflector } from '@nestjs/core';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { Role } from '@prisma/client';
import { EvaluationsController } from './evaluations.controller';
import { StudentOwnershipGuard } from '../../common/guards/student-ownership.guard';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';

/**
 * Locks down the role wiring on the two read routes, which differ in a way
 * that is easy to undo by accident.
 *
 * `student/:id` takes a student id, so StudentOwnershipGuard can hold a parent
 * to their own child. `:id` takes an *evaluation* id, which that guard cannot
 * check — it reads `params.id` as a student id — so the only way to keep a
 * parent from reading any evaluation by guessing its id is to not offer them
 * the route at all. A future edit that adds PARENT back for symmetry would
 * reopen that, silently.
 */
describe('EvaluationsController role wiring', () => {
  const reflector = new Reflector();

  const rolesFor = (handler: unknown) =>
    reflector.get<Role[]>(ROLES_KEY, handler as never) ?? [];

  it('lets a parent read their own child\'s evaluations by student id', () => {
    expect(rolesFor(EvaluationsController.prototype.findByStudent)).toContain(
      Role.PARENT,
    );
  });

  it('guards that route so the parent only reaches their own child', () => {
    const guards = Reflect.getMetadata(
      GUARDS_METADATA,
      EvaluationsController.prototype.findByStudent,
    );
    expect(guards).toContain(StudentOwnershipGuard);
  });

  it('does not let a parent fetch an evaluation by evaluation id', () => {
    expect(rolesFor(EvaluationsController.prototype.findOne)).not.toContain(
      Role.PARENT,
    );
  });

  it('does not let an adult student fetch one by evaluation id either', () => {
    expect(rolesFor(EvaluationsController.prototype.findOne)).not.toContain(
      Role.ADULT_STUDENT,
    );
  });

  it('keeps that route available to staff', () => {
    const roles = rolesFor(EvaluationsController.prototype.findOne);
    expect(roles).toEqual(
      expect.arrayContaining([Role.ADMIN, Role.TEACHER]),
    );
  });
});

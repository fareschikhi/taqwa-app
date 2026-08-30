import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';
import { HalaqasController } from './halaqas.controller';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';

/**
 * Locks down who may reach each halaqa route.
 *
 * Two of these were wrong in a way that looked deliberate, so a test says out
 * loud what the roles are for. `findOne` returns the full roster including
 * every student's phone number, and `update` replaces the roster wholesale
 * while carrying the fine rates — neither is something to hand out for
 * symmetry with its neighbours.
 */
describe('HalaqasController role wiring', () => {
  const reflector = new Reflector();

  const rolesFor = (handler: unknown) =>
    reflector.get<Role[]>(ROLES_KEY, handler as never) ?? [];

  // findOne includes each student's fullName, avatar and phone. A parent
  // holding this route could walk the ids and harvest the contact details of
  // every child in the school.
  it('does not let a parent read a halaqa roster', () => {
    expect(rolesFor(HalaqasController.prototype.findOne)).not.toContain(
      Role.PARENT,
    );
  });

  it('does not let an adult student read a halaqa roster either', () => {
    expect(rolesFor(HalaqasController.prototype.findOne)).not.toContain(
      Role.ADULT_STUDENT,
    );
  });

  it('keeps the roster available to staff', () => {
    expect(rolesFor(HalaqasController.prototype.findOne)).toEqual(
      expect.arrayContaining([Role.ADMIN, Role.TEACHER]),
    );
  });

  // `studentIds` on update REPLACES the roster, and the body carries the fine
  // rates. A teacher holding this route could empty a colleague's halaqa or
  // reprice it, and nothing in the app ever asks her to.
  it('does not let a teacher rewrite a halaqa', () => {
    expect(rolesFor(HalaqasController.prototype.update)).not.toContain(
      Role.TEACHER,
    );
  });

  it('keeps halaqa writes with the admin', () => {
    for (const handler of [
      HalaqasController.prototype.create,
      HalaqasController.prototype.update,
      HalaqasController.prototype.remove,
    ]) {
      expect(rolesFor(handler)).toEqual([Role.ADMIN]);
    }
  });

  // Teachers legitimately need the list — two of their screens read it to find
  // a student's halaqa. The response is scoped in the service instead.
  it('keeps the list readable by a teacher', () => {
    expect(rolesFor(HalaqasController.prototype.findAll)).toEqual(
      expect.arrayContaining([Role.ADMIN, Role.TEACHER]),
    );
  });
});

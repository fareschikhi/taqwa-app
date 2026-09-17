import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';
import { HalaqaAnnouncementsController } from './halaqa-announcements.controller';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { HALAQA_SOURCE_KEY } from '../../common/decorators/halaqa-source.decorator';

/**
 * Says out loud who may reach each route, and what each route's `:id` means.
 *
 * Both matter: the reads are open to all six roles on purpose (the scope is
 * enforced below the roles, per-halaqa), and a write route that drifted open
 * would let a parent announce to a school.
 */
describe('HalaqaAnnouncementsController wiring', () => {
  const reflector = new Reflector();

  const rolesFor = (handler: unknown) =>
    reflector.get<Role[]>(ROLES_KEY, handler as never) ?? [];
  const sourceFor = (handler: unknown) =>
    reflector.get<string>(HALAQA_SOURCE_KEY, handler as never);

  const readers = [
    Role.ADMIN,
    Role.MANAGER,
    Role.TEACHER,
    Role.PARENT,
    Role.STUDENT,
    Role.ADULT_STUDENT,
  ];

  // Declared explicitly rather than by omitting @Roles: RolesGuard returns
  // true when no roles are set, so an omission would make a route that forgot
  // its roles indistinguishable from one that means "everyone".
  it('lets every role read their own feed', () => {
    expect(rolesFor(HalaqaAnnouncementsController.prototype.findMine)).toEqual(
      expect.arrayContaining(readers),
    );
  });

  it("lets every role read a halaqa's history", () => {
    expect(
      rolesFor(HalaqaAnnouncementsController.prototype.findByHalaqa),
    ).toEqual(expect.arrayContaining(readers));
  });

  it('keeps writes with the manager and the admin', () => {
    for (const handler of [
      HalaqaAnnouncementsController.prototype.create,
      HalaqaAnnouncementsController.prototype.update,
      HalaqaAnnouncementsController.prototype.remove,
    ]) {
      expect(rolesFor(handler).sort()).toEqual([Role.ADMIN, Role.MANAGER].sort());
    }
  });

  it.each([
    ['findByHalaqa', 'param'],
    ['create', 'body'],
    ['update', 'announcement'],
    ['remove', 'announcement'],
  ])('declares %s reads its halaqa from %s', (name, expected) => {
    const handler = (
      HalaqaAnnouncementsController.prototype as unknown as Record<string, unknown>
    )[name];

    expect(sourceFor(handler)).toBe(expected);
  });

  // findMine has no single halaqa to check and so carries no access guard —
  // its scoping happens in the service, over the same rule. The assertion
  // records that on purpose, so nobody later reads the bare route as an
  // oversight and bolts a guard onto it.
  it('declares no halaqa source on the feed route', () => {
    expect(sourceFor(HalaqaAnnouncementsController.prototype.findMine)).toBeUndefined();
  });
});

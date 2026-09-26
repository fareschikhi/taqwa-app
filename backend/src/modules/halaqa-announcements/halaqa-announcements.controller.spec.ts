import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';
import { HalaqaAnnouncementsController } from './halaqa-announcements.controller';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import { HALAQA_SOURCE_KEY } from '../../common/decorators/halaqa-source.decorator';
import { HalaqaAccessGuard } from '../../common/guards/halaqa-access.guard';

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
  const guardsFor = (handler: unknown) =>
    reflector.get<Function[]>('__guards__', handler as never) ?? [];

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
    expect(
      rolesFor(HalaqaAnnouncementsController.prototype.findMine).sort(),
    ).toEqual(readers.sort());
  });

  it("lets every role read a halaqa's history", () => {
    expect(
      rolesFor(HalaqaAnnouncementsController.prototype.findByHalaqa).sort(),
    ).toEqual(readers.sort());
  });

  it('keeps writes with the manager and the admin', () => {
    for (const handler of [
      HalaqaAnnouncementsController.prototype.create,
      HalaqaAnnouncementsController.prototype.createForAll,
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

  // The access guard is the feature's whole security boundary: a refactor
  // that dropped @UseGuards(HalaqaAccessGuard) while leaving @HalaqaFrom in
  // place would pass every other test here while halaqa scoping silently
  // stopped running. Assert the guard itself is wired, not just its metadata.
  it('attaches the access guard to every halaqa-scoped route', () => {
    for (const handler of [
      HalaqaAnnouncementsController.prototype.findByHalaqa,
      HalaqaAnnouncementsController.prototype.create,
      HalaqaAnnouncementsController.prototype.update,
      HalaqaAnnouncementsController.prototype.remove,
    ]) {
      expect(guardsFor(handler)).toContain(HalaqaAccessGuard);
    }
  });

  // findMine has no single halaqa to check (see above), so it must NOT carry
  // the access guard: bolting it on would deny the route outright, since it
  // declares no @HalaqaFrom for the guard to resolve an id from.
  it('does not attach the access guard to the feed route', () => {
    expect(guardsFor(HalaqaAnnouncementsController.prototype.findMine)).not.toContain(
      HalaqaAccessGuard,
    );
  });

  // Same reasoning as the feed: "all halaqas" names no halaqa for the guard
  // to resolve, and the service draws them from the caller's own scope.
  it('scopes the all-halaqas post in the service, not the guard', () => {
    const handler = HalaqaAnnouncementsController.prototype.createForAll;
    expect(sourceFor(handler)).toBeUndefined();
    expect(guardsFor(handler)).not.toContain(HalaqaAccessGuard);
  });
});

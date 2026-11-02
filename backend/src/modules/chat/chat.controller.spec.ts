import { Reflector } from '@nestjs/core';
import { Role } from '@prisma/client';
import { ChatController } from './chat.controller';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';
import {
  ManagerPermission,
  PERMISSION_KEY,
} from '../../common/decorators/permissions.decorator';
import { ManagerPermissionGuard } from '../../common/guards/manager-permission.guard';

/**
 * Who reaches each chat route. The service checks scope again on every call,
 * but a staff route that drifted open to parents, or lost the chat privilege,
 * should fail here first.
 */
describe('ChatController wiring', () => {
  const reflector = new Reflector();
  const proto = ChatController.prototype;
  const rolesFor = (handler: unknown) =>
    (reflector.get<Role[]>(ROLES_KEY, handler as never) ?? []).sort();
  const permissionFor = (handler: unknown) =>
    reflector.get<ManagerPermission>(PERMISSION_KEY, handler as never);
  const guardsFor = (handler: unknown) =>
    reflector.get<Function[]>('__guards__', handler as never) ?? [];

  const parentRoutes = [
    proto.parentMessages,
    proto.parentSend,
    proto.parentRead,
    proto.parentUnread,
  ];
  const staffRoutes = [
    proto.inbox,
    proto.staffUnread,
    proto.parents,
    proto.staffMessages,
    proto.staffSend,
    proto.staffRead,
  ];

  it('keeps the parent routes for parents', () => {
    for (const handler of parentRoutes) {
      expect(rolesFor(handler)).toEqual([Role.PARENT]);
    }
  });

  it('keeps the staff routes for admins and chat managers', () => {
    for (const handler of staffRoutes) {
      expect(rolesFor(handler)).toEqual([Role.ADMIN, Role.MANAGER].sort());
      expect(permissionFor(handler)).toBe(ManagerPermission.CHAT);
      expect(guardsFor(handler)).toContain(ManagerPermissionGuard);
    }
  });

  it('lets both sides edit, delete and see photos, scoped by the service', () => {
    for (const handler of [proto.edit, proto.remove, proto.photo]) {
      expect(rolesFor(handler)).toEqual(
        [Role.PARENT, Role.ADMIN, Role.MANAGER].sort(),
      );
    }
  });
});

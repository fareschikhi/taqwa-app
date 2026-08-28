import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import {
  ManagerPermission,
  PERMISSION_KEY,
} from '../decorators/permissions.decorator';

/**
 * Narrows MANAGER access on routes marked with `@RequirePermission(...)`.
 * ADMIN, TEACHER and PARENT pass through untouched — they are already
 * constrained by `@Roles`, and these privileges only ever describe managers.
 * Mirrors the pass-through shape of StudentOwnershipGuard.
 */
@Injectable()
export class ManagerPermissionGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const permission = this.reflector.getAllAndOverride<ManagerPermission>(
      PERMISSION_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!permission) return true;

    const { user } = context.switchToHttp().getRequest();
    if (user?.role !== 'MANAGER') return true;

    if (!user.manager?.[permission]) {
      throw new ForbiddenException('غير مصرح لك بهذا الإجراء');
    }
    return true;
  }
}

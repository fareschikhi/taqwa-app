import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ManagerPermissionGuard } from './manager-permission.guard';
import { ManagerPermission } from '../decorators/permissions.decorator';

function contextFor(user: unknown): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => ({ user }) }),
    getHandler: () => undefined,
    getClass: () => undefined,
  } as unknown as ExecutionContext;
}

function guardRequiring(
  permission: ManagerPermission | undefined,
): ManagerPermissionGuard {
  const reflector = {
    getAllAndOverride: () => permission,
  } as unknown as Reflector;
  return new ManagerPermissionGuard(reflector);
}

describe('ManagerPermissionGuard', () => {
  it('allows a route carrying no permission metadata', () => {
    const guard = guardRequiring(undefined);
    expect(guard.canActivate(contextFor({ role: 'MANAGER' }))).toBe(true);
  });

  it('allows ADMIN regardless of manager flags', () => {
    const guard = guardRequiring(ManagerPermission.MANAGE_ACCOUNTS);
    expect(guard.canActivate(contextFor({ role: 'ADMIN' }))).toBe(true);
  });

  it('allows TEACHER, who is constrained by @Roles instead', () => {
    const guard = guardRequiring(ManagerPermission.MANAGE_ACCOUNTS);
    expect(guard.canActivate(contextFor({ role: 'TEACHER' }))).toBe(true);
  });

  it('allows a MANAGER holding the required privilege', () => {
    const guard = guardRequiring(ManagerPermission.MANAGE_ACCOUNTS);
    const user = {
      role: 'MANAGER',
      manager: { id: 1, canManageAccounts: true, canDeleteAccounts: false },
    };
    expect(guard.canActivate(contextFor(user))).toBe(true);
  });

  it('rejects a MANAGER lacking the required privilege', () => {
    const guard = guardRequiring(ManagerPermission.DELETE_ACCOUNTS);
    const user = {
      role: 'MANAGER',
      manager: { id: 1, canManageAccounts: true, canDeleteAccounts: false },
    };
    expect(() => guard.canActivate(contextFor(user))).toThrow(
      ForbiddenException,
    );
  });

  it('rejects a MANAGER whose manager relation was never loaded', () => {
    const guard = guardRequiring(ManagerPermission.MANAGE_ACCOUNTS);
    expect(() => guard.canActivate(contextFor({ role: 'MANAGER' }))).toThrow(
      ForbiddenException,
    );
  });
});

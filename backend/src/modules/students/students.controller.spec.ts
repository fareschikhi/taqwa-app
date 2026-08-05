import { Reflector } from '@nestjs/core';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { StudentsController } from './students.controller';
import { ManagerPermissionGuard } from '../../common/guards/manager-permission.guard';
import {
  ManagerPermission,
  PERMISSION_KEY,
} from '../../common/decorators/permissions.decorator';

/**
 * Locks down the decorator wiring on StudentsController itself, so a future
 * edit that silently drops @RequirePermission from a route (or removes
 * ManagerPermissionGuard from the controller) fails a test instead of only
 * being caught by the isolated ManagerPermissionGuard unit tests.
 */
describe('StudentsController decorator wiring', () => {
  const reflector = new Reflector();

  it('requires MANAGE_ACCOUNTS on create', () => {
    expect(
      reflector.get(PERMISSION_KEY, StudentsController.prototype.create),
    ).toBe(ManagerPermission.MANAGE_ACCOUNTS);
  });

  it('requires MANAGE_ACCOUNTS on update', () => {
    expect(
      reflector.get(PERMISSION_KEY, StudentsController.prototype.update),
    ).toBe(ManagerPermission.MANAGE_ACCOUNTS);
  });

  it('requires DELETE_ACCOUNTS on remove', () => {
    expect(
      reflector.get(PERMISSION_KEY, StudentsController.prototype.remove),
    ).toBe(ManagerPermission.DELETE_ACCOUNTS);
  });

  it('applies ManagerPermissionGuard at the controller level', () => {
    const guards = Reflect.getMetadata(GUARDS_METADATA, StudentsController);
    expect(guards).toContain(ManagerPermissionGuard);
  });
});

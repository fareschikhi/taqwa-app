import { Reflector } from '@nestjs/core';
import { ForbiddenException } from '@nestjs/common';
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

/**
 * Hadith tracking is an admin decision: a manager can reach the same
 * POST/PATCH routes through MANAGE_ACCOUNTS, so the flag is gated here by
 * role rather than by hiding a switch in the app.
 */
describe('StudentsController tracksHadith gate', () => {
  const makeController = () => {
    const service = {
      create: jest.fn().mockResolvedValue({}),
      update: jest.fn().mockResolvedValue({}),
    };
    return {
      service,
      controller: new StudentsController(service as any),
    };
  };
  const payload = {
    fullName: 'Ali Ben',
    address: 'Algiers',
    birthDate: '2012-01-01',
  };

  it('lets an admin set tracksHadith on create', async () => {
    const { controller, service } = makeController();
    await controller.create({ ...payload, tracksHadith: true }, {
      role: 'ADMIN',
    });
    expect(service.create).toHaveBeenCalledWith({
      ...payload,
      tracksHadith: true,
    });
  });

  it('rejects a manager setting tracksHadith on create', async () => {
    const { controller, service } = makeController();
    expect(() =>
      controller.create({ ...payload, tracksHadith: false }, {
        role: 'MANAGER',
      }),
    ).toThrow(ForbiddenException);
    expect(service.create).not.toHaveBeenCalled();
  });

  it('lets a manager create a student without tracksHadith', async () => {
    const { controller, service } = makeController();
    await controller.create(payload, { role: 'MANAGER' });
    expect(service.create).toHaveBeenCalledWith(payload);
  });

  it('lets an admin set tracksHadith on update', async () => {
    const { controller, service } = makeController();
    await controller.update(7, { tracksHadith: true }, { role: 'ADMIN' });
    expect(service.update).toHaveBeenCalledWith(7, { tracksHadith: true });
  });

  it('rejects a manager or teacher setting tracksHadith on update', () => {
    const { controller, service } = makeController();
    for (const role of ['MANAGER', 'TEACHER']) {
      expect(() =>
        controller.update(7, { tracksHadith: true }, { role }),
      ).toThrow(ForbiddenException);
    }
    expect(service.update).not.toHaveBeenCalled();
  });

  it('lets a manager update other fields', async () => {
    const { controller, service } = makeController();
    await controller.update(7, { address: 'Oran' }, { role: 'MANAGER' });
    expect(service.update).toHaveBeenCalledWith(7, { address: 'Oran' });
  });
});

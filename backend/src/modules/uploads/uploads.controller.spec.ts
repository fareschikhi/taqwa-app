import { Reflector } from '@nestjs/core';
import { GUARDS_METADATA } from '@nestjs/common/constants';
import { Role } from '@prisma/client';
import { UploadsController } from './uploads.controller';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { ROLES_KEY } from '../../common/decorators/roles.decorator';

/**
 * The upload route writes to the server's own disk, so an edit that drops a
 * guard would hand anonymous callers free storage on our server. Lock the wiring down here rather than trusting review to catch it.
 */
describe('UploadsController decorator wiring', () => {
  const reflector = new Reflector();

  it('restricts uploading to ADMIN and MANAGER', () => {
    expect(
      reflector.get(ROLES_KEY, UploadsController.prototype.uploadImage),
    ).toEqual([Role.ADMIN, Role.MANAGER]);
  });

  it('applies JwtAuthGuard at the controller level', () => {
    const guards = Reflect.getMetadata(
      GUARDS_METADATA,
      UploadsController,
    ) as unknown[];
    expect(guards).toContain(JwtAuthGuard);
  });

  it('applies RolesGuard at the controller level', () => {
    const guards = Reflect.getMetadata(
      GUARDS_METADATA,
      UploadsController,
    ) as unknown[];
    expect(guards).toContain(RolesGuard);
  });
});

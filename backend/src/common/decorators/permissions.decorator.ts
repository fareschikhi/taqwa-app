import { SetMetadata } from '@nestjs/common';

/**
 * Account-management privileges an ADMIN can grant to an individual MANAGER.
 * Each value is the name of the matching boolean column on the Manager model,
 * so the guard can index `user.manager` with it directly.
 */
export enum ManagerPermission {
  MANAGE_ACCOUNTS = 'canManageAccounts',
  DELETE_ACCOUNTS = 'canDeleteAccounts',
}

export const PERMISSION_KEY = 'managerPermission';

export const RequirePermission = (permission: ManagerPermission) =>
  SetMetadata(PERMISSION_KEY, permission);

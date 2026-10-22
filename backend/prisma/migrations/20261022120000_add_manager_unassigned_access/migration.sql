-- AlterTable
-- Students with no halaqa have no manager_halaqas row to reach them through,
-- so the admin grants them to a manager with this flag instead.
ALTER TABLE `managers` ADD COLUMN `canAccessUnassigned` BOOLEAN NOT NULL DEFAULT false;

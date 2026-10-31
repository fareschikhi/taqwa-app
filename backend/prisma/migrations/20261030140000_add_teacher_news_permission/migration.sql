-- AlterTable
-- Granted by the admin: lets the teacher post news to their own halaqas.
ALTER TABLE `teachers` ADD COLUMN `canPostNews` BOOLEAN NOT NULL DEFAULT false;

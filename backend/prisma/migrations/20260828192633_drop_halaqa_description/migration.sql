-- AlterTable
-- The description was never editable: the admin form bound no input to it and
-- no screen ever rendered it, so the column only ever held seed text. Level
-- replaces it as the halaqa's secondary attribute.
ALTER TABLE `halaqas` DROP COLUMN `description`;

-- معلم مشرف becomes an on/off flag on the teacher. The level is no longer
-- stored: it is read from the halaqas the teacher runs.

-- AlterTable
ALTER TABLE `teachers` ADD COLUMN `isSupervisor` BOOLEAN NOT NULL DEFAULT false;

-- Keep everyone already named a supervisor of some level.
UPDATE `teachers` SET `isSupervisor` = true
WHERE `id` IN (SELECT `teacherId` FROM `level_supervisors`);

-- DropForeignKey
ALTER TABLE `level_supervisors` DROP FOREIGN KEY `level_supervisors_teacherId_fkey`;

-- DropTable
DROP TABLE `level_supervisors`;

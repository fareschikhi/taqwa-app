-- AlterTable
ALTER TABLE `students` ADD COLUMN `schoolLevel` VARCHAR(100) NULL,
    ADD COLUMN `healthStatus` VARCHAR(255) NULL,
    ADD COLUMN `familyStatus` VARCHAR(255) NULL,
    ADD COLUMN `fatherJob` VARCHAR(100) NULL,
    ADD COLUMN `motherJob` VARCHAR(100) NULL,
    ADD COLUMN `occupation` VARCHAR(100) NULL,
    ADD COLUMN `externalActivities` VARCHAR(255) NULL,
    ADD COLUMN `isMarried` BOOLEAN NULL;

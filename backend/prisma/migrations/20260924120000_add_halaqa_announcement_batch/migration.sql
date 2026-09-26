-- AlterTable
ALTER TABLE `halaqa_announcements` ADD COLUMN `batchId` VARCHAR(36) NULL;

-- CreateIndex
CREATE INDEX `halaqa_announcements_batchId_idx` ON `halaqa_announcements`(`batchId`);

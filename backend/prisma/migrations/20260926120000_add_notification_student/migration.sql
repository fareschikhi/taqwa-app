-- AlterTable
ALTER TABLE `notifications` ADD COLUMN `studentId` INTEGER NULL;

-- CreateIndex
CREATE INDEX `notifications_studentId_idx` ON `notifications`(`studentId`);

-- AddForeignKey
ALTER TABLE `notifications` ADD CONSTRAINT `notifications_studentId_fkey` FOREIGN KEY (`studentId`) REFERENCES `students`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

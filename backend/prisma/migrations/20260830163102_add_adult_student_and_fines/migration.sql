-- AlterEnum
ALTER TABLE `users` MODIFY `role` ENUM('ADMIN', 'TEACHER', 'PARENT', 'STUDENT', 'ADULT_STUDENT', 'MANAGER') NOT NULL;

-- AlterTable
ALTER TABLE `halaqas` ADD COLUMN `isAdult` BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN `absenceFee` INTEGER NOT NULL DEFAULT 0,
ADD COLUMN `lateFee` INTEGER NOT NULL DEFAULT 0,
ADD COLUMN `missedMemorizationFee` INTEGER NOT NULL DEFAULT 0;

-- AlterTable
ALTER TABLE `attendance` ADD COLUMN `missedMemorization` BOOLEAN NOT NULL DEFAULT false;

-- CreateTable
CREATE TABLE `fine_entries` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `studentId` INTEGER NOT NULL,
    `kind` ENUM('CHARGE', 'REDUCTION') NOT NULL,
    `amount` INTEGER NOT NULL,
    `reason` VARCHAR(300) NULL,
    `source` ENUM('ABSENCE', 'LATE', 'MISSED_MEMORIZATION', 'MANUAL') NOT NULL,
    `date` DATE NULL,
    `createdById` INTEGER NOT NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `fine_entries_studentId_idx`(`studentId`),
    INDEX `fine_entries_createdById_idx`(`createdById`),
    UNIQUE INDEX `fine_entries_studentId_date_source_key`(`studentId`, `date`, `source`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `fine_entries` ADD CONSTRAINT `fine_entries_studentId_fkey` FOREIGN KEY (`studentId`) REFERENCES `students`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `fine_entries` ADD CONSTRAINT `fine_entries_createdById_fkey` FOREIGN KEY (`createdById`) REFERENCES `users`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

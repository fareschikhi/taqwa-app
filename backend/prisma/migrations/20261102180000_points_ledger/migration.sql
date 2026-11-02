-- CreateTable
CREATE TABLE `point_entries` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `userId` INTEGER NOT NULL,
    `amount` DECIMAL(10, 3) NOT NULL,
    `source` ENUM('MEMORIZATION', 'PRESENT', 'ABSENCE', 'MISSED_MEMORIZATION', 'MANUAL') NOT NULL,
    `date` DATE NULL,
    `reason` VARCHAR(300) NULL,
    `createdById` INTEGER NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `point_entries_userId_idx`(`userId`),
    INDEX `point_entries_createdById_idx`(`createdById`),
    UNIQUE INDEX `point_entries_userId_date_source_key`(`userId`, `date`, `source`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `point_entries` ADD CONSTRAINT `point_entries_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `point_entries` ADD CONSTRAINT `point_entries_createdById_fkey` FOREIGN KEY (`createdById`) REFERENCES `users`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;


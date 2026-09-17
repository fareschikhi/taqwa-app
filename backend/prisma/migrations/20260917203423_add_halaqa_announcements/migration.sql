-- CreateTable
CREATE TABLE `halaqa_announcements` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `halaqaId` INTEGER NOT NULL,
    `authorId` INTEGER NOT NULL,
    `title` VARCHAR(200) NOT NULL,
    `body` TEXT NOT NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updatedAt` DATETIME(3) NOT NULL,

    INDEX `halaqa_announcements_halaqaId_createdAt_idx`(`halaqaId`, `createdAt`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `halaqa_announcements` ADD CONSTRAINT `halaqa_announcements_halaqaId_fkey` FOREIGN KEY (`halaqaId`) REFERENCES `halaqas`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `halaqa_announcements` ADD CONSTRAINT `halaqa_announcements_authorId_fkey` FOREIGN KEY (`authorId`) REFERENCES `users`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

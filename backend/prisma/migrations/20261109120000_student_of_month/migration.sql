-- طالب الشهر: one validated pick per halaqa per finished month.
-- CreateTable
CREATE TABLE `students_of_month` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `halaqaId` INTEGER NOT NULL,
    `month` VARCHAR(7) NOT NULL,
    `studentId` INTEGER NOT NULL,
    `score` DECIMAL(10, 3) NOT NULL,
    `wasTopScorer` BOOLEAN NOT NULL,
    `selectedById` INTEGER NOT NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `students_of_month_studentId_idx`(`studentId`),
    INDEX `students_of_month_selectedById_idx`(`selectedById`),
    UNIQUE INDEX `students_of_month_halaqaId_month_key`(`halaqaId`, `month`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `students_of_month` ADD CONSTRAINT `students_of_month_halaqaId_fkey` FOREIGN KEY (`halaqaId`) REFERENCES `halaqas`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `students_of_month` ADD CONSTRAINT `students_of_month_studentId_fkey` FOREIGN KEY (`studentId`) REFERENCES `students`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `students_of_month` ADD CONSTRAINT `students_of_month_selectedById_fkey` FOREIGN KEY (`selectedById`) REFERENCES `users`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;


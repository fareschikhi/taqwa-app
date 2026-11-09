-- معلم مشرف: teachers the admin names as supervisors of a halaqa level.
-- CreateTable
CREATE TABLE `level_supervisors` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `level` VARCHAR(100) NOT NULL,
    `teacherId` INTEGER NOT NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `level_supervisors_teacherId_idx`(`teacherId`),
    UNIQUE INDEX `level_supervisors_level_teacherId_key`(`level`, `teacherId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `level_supervisors` ADD CONSTRAINT `level_supervisors_teacherId_fkey` FOREIGN KEY (`teacherId`) REFERENCES `teachers`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

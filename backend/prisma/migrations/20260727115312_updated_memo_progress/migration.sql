/*
  Warnings:

  - You are about to drop the column `fromAyah` on the `memorization_progress` table. All the data in the column will be lost.
  - You are about to drop the column `memorizationScore` on the `memorization_progress` table. All the data in the column will be lost.
  - You are about to drop the column `notes` on the `memorization_progress` table. All the data in the column will be lost.
  - You are about to drop the column `revisionScore` on the `memorization_progress` table. All the data in the column will be lost.
  - You are about to drop the column `surahName` on the `memorization_progress` table. All the data in the column will be lost.
  - You are about to drop the column `toAyah` on the `memorization_progress` table. All the data in the column will be lost.
  - Added the required column `pagesDone` to the `memorization_progress` table without a default value. This is not possible if the table is not empty.

*/
-- DropIndex
DROP INDEX `memorization_progress_studentId_idx` ON `memorization_progress`;

-- DropIndex
DROP INDEX `memorization_progress_surahNumber_idx` ON `memorization_progress`;

-- DropIndex
DROP INDEX `students_halaqaId_fkey` ON `students`;

-- AlterTable
ALTER TABLE `memorization_progress` DROP COLUMN `fromAyah`,
    DROP COLUMN `memorizationScore`,
    DROP COLUMN `notes`,
    DROP COLUMN `revisionScore`,
    DROP COLUMN `surahName`,
    DROP COLUMN `toAyah`,
    ADD COLUMN `memorizationType` ENUM('MEMORIZING', 'SMALLREVISION', 'BIGREVISION') NOT NULL DEFAULT 'MEMORIZING',
    ADD COLUMN `pagesDone` INTEGER NOT NULL;

-- CreateIndex
CREATE INDEX `memorization_progress_studentId_recordedAt_idx` ON `memorization_progress`(`studentId`, `recordedAt`);

-- CreateIndex
CREATE INDEX `memorization_progress_studentId_surahNumber_idx` ON `memorization_progress`(`studentId`, `surahNumber`);

-- AddForeignKey
ALTER TABLE `teachers` ADD CONSTRAINT `teachers_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `parents` ADD CONSTRAINT `parents_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `students` ADD CONSTRAINT `students_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `students` ADD CONSTRAINT `students_parentId_fkey` FOREIGN KEY (`parentId`) REFERENCES `parents`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `students` ADD CONSTRAINT `students_halaqaId_fkey` FOREIGN KEY (`halaqaId`) REFERENCES `halaqas`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `halaqas` ADD CONSTRAINT `halaqas_teacherId_fkey` FOREIGN KEY (`teacherId`) REFERENCES `teachers`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `attendance` ADD CONSTRAINT `attendance_studentId_fkey` FOREIGN KEY (`studentId`) REFERENCES `students`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `memorization_progress` ADD CONSTRAINT `memorization_progress_studentId_fkey` FOREIGN KEY (`studentId`) REFERENCES `students`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `evaluations` ADD CONSTRAINT `evaluations_studentId_fkey` FOREIGN KEY (`studentId`) REFERENCES `students`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `evaluations` ADD CONSTRAINT `evaluations_teacherId_fkey` FOREIGN KEY (`teacherId`) REFERENCES `teachers`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `student_notes` ADD CONSTRAINT `student_notes_studentId_fkey` FOREIGN KEY (`studentId`) REFERENCES `students`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `student_notes` ADD CONSTRAINT `student_notes_teacherId_fkey` FOREIGN KEY (`teacherId`) REFERENCES `teachers`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `notifications` ADD CONSTRAINT `notifications_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `managers` ADD CONSTRAINT `managers_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `manager_halaqas` ADD CONSTRAINT `manager_halaqas_managerId_fkey` FOREIGN KEY (`managerId`) REFERENCES `managers`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `manager_halaqas` ADD CONSTRAINT `manager_halaqas_halaqaId_fkey` FOREIGN KEY (`halaqaId`) REFERENCES `halaqas`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `absence_justifications` ADD CONSTRAINT `absence_justifications_studentId_fkey` FOREIGN KEY (`studentId`) REFERENCES `students`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `absence_justifications` ADD CONSTRAINT `absence_justifications_attendanceId_fkey` FOREIGN KEY (`attendanceId`) REFERENCES `attendance`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `absence_justifications` ADD CONSTRAINT `absence_justifications_managerId_fkey` FOREIGN KEY (`managerId`) REFERENCES `managers`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

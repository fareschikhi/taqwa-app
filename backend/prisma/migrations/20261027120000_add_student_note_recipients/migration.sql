-- A note is now written once and addressed to its students through
-- student_note_recipients, instead of being copied into a row per student.
-- Existing rows keep their student as their one recipient, and the copies an
-- "all students" send left behind are folded back into a single note.

-- CreateTable
CREATE TABLE `student_note_recipients` (
    `noteId` INTEGER NOT NULL,
    `studentId` INTEGER NOT NULL,

    INDEX `student_note_recipients_studentId_idx`(`studentId`),
    PRIMARY KEY (`noteId`, `studentId`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- AddForeignKey
ALTER TABLE `student_note_recipients` ADD CONSTRAINT `student_note_recipients_noteId_fkey` FOREIGN KEY (`noteId`) REFERENCES `student_notes`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `student_note_recipients` ADD CONSTRAINT `student_note_recipients_studentId_fkey` FOREIGN KEY (`studentId`) REFERENCES `students`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- Every existing note keeps the student it was written for.
INSERT INTO `student_note_recipients` (`noteId`, `studentId`)
SELECT `id`, `studentId` FROM `student_notes`;

-- A bulk send wrote its copies in one transaction, milliseconds apart: same
-- teacher, same text. Each copy is mapped onto the oldest note of its send,
-- and five seconds is far short of a teacher retyping the same note by hand.
CREATE TABLE `_student_note_merge` (
    `noteId` INTEGER NOT NULL,
    `keepId` INTEGER NOT NULL,

    PRIMARY KEY (`noteId`)
);

INSERT INTO `_student_note_merge` (`noteId`, `keepId`)
SELECT n.`id`, MIN(k.`id`)
FROM `student_notes` n
JOIN `student_notes` k
  ON k.`teacherId` = n.`teacherId`
 AND k.`note` = n.`note`
 AND ABS(TIMESTAMPDIFF(MICROSECOND, k.`createdAt`, n.`createdAt`)) <= 5000000
GROUP BY n.`id`
HAVING MIN(k.`id`) < n.`id`;

-- IGNORE: a student already on the kept note stays put, and their duplicate
-- recipient row goes with its note below.
UPDATE IGNORE `student_note_recipients` r
JOIN `_student_note_merge` m ON m.`noteId` = r.`noteId`
SET r.`noteId` = m.`keepId`;

DELETE n FROM `student_notes` n
JOIN `_student_note_merge` m ON m.`noteId` = n.`id`;

DROP TABLE `_student_note_merge`;

-- DropForeignKey
ALTER TABLE `student_notes` DROP FOREIGN KEY `student_notes_studentId_fkey`;

-- DropIndex
DROP INDEX `student_notes_studentId_idx` ON `student_notes`;

-- AlterTable
ALTER TABLE `student_notes` DROP COLUMN `studentId`;

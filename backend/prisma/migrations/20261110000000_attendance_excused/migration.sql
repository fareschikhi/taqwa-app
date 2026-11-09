-- عذر: a day away with a reason, neither present nor absent.

-- AlterTable
ALTER TABLE `attendance` MODIFY `status` ENUM('PRESENT', 'ABSENT', 'LATE', 'EXCUSED') NOT NULL;

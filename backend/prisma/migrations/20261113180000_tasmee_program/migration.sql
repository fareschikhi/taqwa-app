-- برنامج التسميع: an admin opt-in per student, a TASMEE subject for its
-- recitations, and the free-text mistakes the teacher notes on them.
ALTER TABLE `students` ADD COLUMN `tracksTasmee` BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE `memorization_progress`
  MODIFY `subject` ENUM('QURAN', 'HADITH', 'TASMEE') NOT NULL DEFAULT 'QURAN',
  ADD COLUMN `mistakes` VARCHAR(1000) NULL;

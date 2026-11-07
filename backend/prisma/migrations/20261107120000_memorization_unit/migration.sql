-- A hadith entry can now be counted in pages as well as in single hadiths, so
-- each row says which unit its amountDone is in. Quran rows are pages. Every
-- hadith row written before this counted single hadiths, so they are marked
-- HADITH.
ALTER TABLE `memorization_progress`
  ADD COLUMN `unit` ENUM('PAGE', 'HADITH') NOT NULL DEFAULT 'PAGE';

UPDATE `memorization_progress`
SET `unit` = 'HADITH'
WHERE `subject` = 'HADITH';

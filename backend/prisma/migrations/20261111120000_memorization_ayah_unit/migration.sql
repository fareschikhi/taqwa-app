-- A Quran entry can be recorded as an ayah range inside its surah. AYAH rows
-- keep their own total; they never add to the page count.
ALTER TABLE `memorization_progress`
  MODIFY `unit` ENUM('PAGE', 'HADITH', 'AYAH') NOT NULL DEFAULT 'PAGE',
  ADD COLUMN `ayahFrom` INTEGER NULL,
  ADD COLUMN `ayahTo` INTEGER NULL;

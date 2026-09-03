-- AlterTable
ALTER TABLE `students` ADD COLUMN `tracksHadith` BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE `memorization_progress`
  ADD COLUMN `subject` ENUM('QURAN', 'HADITH') NOT NULL DEFAULT 'QURAN',
  ADD COLUMN `hadithReference` VARCHAR(500) NULL,
  MODIFY `surahNumber` INTEGER NULL;

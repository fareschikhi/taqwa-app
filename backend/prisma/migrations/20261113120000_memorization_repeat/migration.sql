-- A repeat (إعادة) recitation: half points, and a per-halaqa fee for adults.
ALTER TABLE `memorization_progress`
  ADD COLUMN `isRepeat` BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE `halaqas`
  ADD COLUMN `repeatFee` INTEGER NOT NULL DEFAULT 0;

ALTER TABLE `fine_entries`
  MODIFY `source` ENUM('ABSENCE', 'LATE', 'MISSED_MEMORIZATION', 'REPEAT', 'MANUAL') NOT NULL;

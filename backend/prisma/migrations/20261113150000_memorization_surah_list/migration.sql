-- One recitation may name several surahs (e.g. the last three of the mushaf).
-- The full list, in mushaf order, is kept only when there are two or more;
-- surahNumber still holds the first one.
ALTER TABLE `memorization_progress` ADD COLUMN `surahNumbers` JSON NULL;

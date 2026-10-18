-- AlterTable
ALTER TABLE `students` ADD COLUMN `hadithBooks` JSON NULL;

-- Hadith used to be a single on/off switch with no book attached, so every
-- student who already had it on keeps access to every book.
UPDATE `students`
SET `hadithBooks` = JSON_ARRAY(
  'الأربعون النووية',
  'المنهاج من ميراث النّبوّة',
  'عُمدة الأحكام',
  'بلوغ المرام من أدلّة الأحكام',
  'الجمع بين الصحيحين',
  'الزوائد على الجمع'
)
WHERE `tracksHadith` = true;

-- Quran revision used to be recorded in hizbs and is now recorded in pages,
-- like new memorization. The app enters a hizb as ten pages, so existing
-- revision amounts are converted at that same rate. Hadith rows count hadiths
-- and are left alone.
UPDATE `memorization_progress`
SET `amountDone` = `amountDone` * 10
WHERE `subject` = 'QURAN'
  AND `memorizationType` IN ('SMALLREVISION', 'BIGREVISION');

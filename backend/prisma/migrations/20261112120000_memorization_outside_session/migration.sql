-- A recitation recorded outside the halaqa session earns points but never
-- touches attendance or the day's missed-recitation fine.
ALTER TABLE `memorization_progress`
  ADD COLUMN `outsideSession` BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
-- Revision entries are counted in hizbs rather than pages, so the column is no
-- longer about pages at all. CHANGE renames in place and keeps existing rows;
-- a DROP + ADD pair would silently discard every recorded amount.
ALTER TABLE `memorization_progress` CHANGE `pagesDone` `amountDone` INTEGER NOT NULL;

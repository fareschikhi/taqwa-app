-- AlterTable
-- New memorization can be recorded in half pages (1.5, 3.5), so the amount is
-- no longer a whole number. Halves are exact in a DOUBLE, so sums stay exact.
ALTER TABLE `memorization_progress` MODIFY `amountDone` DOUBLE NOT NULL;

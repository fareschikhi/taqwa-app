-- AlterTable
-- Families sign in by phone, and many registration sheets leave the address
-- blank, so a student no longer needs one.
ALTER TABLE `students` MODIFY `address` VARCHAR(191) NULL;

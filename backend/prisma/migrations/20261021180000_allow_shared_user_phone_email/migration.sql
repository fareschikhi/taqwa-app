-- One person can hold two accounts (a teacher who is also an adult student),
-- so phone and email stop being unique. Plain indexes keep login lookups fast.

-- DropIndex
DROP INDEX `users_phone_key` ON `users`;

-- DropIndex
DROP INDEX `users_email_key` ON `users`;

-- CreateIndex
CREATE INDEX `users_phone_idx` ON `users`(`phone`);

-- CreateIndex
CREATE INDEX `users_email_idx` ON `users`(`email`);

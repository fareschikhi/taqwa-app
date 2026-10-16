-- AlterTable
ALTER TABLE `users` ADD COLUMN `mustChangePassword` BOOLEAN NOT NULL DEFAULT false;

-- Every existing password on an account that can log in, other than an
-- admin's, was handed out by an admin, so each holder replaces it on their
-- next login. A child STUDENT is refused at login whatever its hash says.
UPDATE `users`
SET `mustChangePassword` = true
WHERE `role` NOT IN ('ADMIN', 'STUDENT') AND `passwordHash` IS NOT NULL;

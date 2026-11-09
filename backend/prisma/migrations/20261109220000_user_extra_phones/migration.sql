-- Extra contact numbers beside the login phone (JSON string array).

-- AlterTable
ALTER TABLE `users` ADD COLUMN `extraPhones` JSON NULL;

-- Who actually uses the app: last password sign-in and last authenticated
-- request (throttled in AuthService). Null = never.

-- AlterTable
ALTER TABLE `users` ADD COLUMN `lastLoginAt` DATETIME(3) NULL,
    ADD COLUMN `lastSeenAt` DATETIME(3) NULL;

-- Backfill: the app re-registers its push token on every start, so the
-- newest device_tokens row is the best record of use before this column
-- existed. Users who never allowed notifications stay null until they next
-- open the app.
UPDATE `users` u
JOIN (
    SELECT `userId`, MAX(`updatedAt`) AS `lastUse`
    FROM `device_tokens`
    GROUP BY `userId`
) d ON d.`userId` = u.`id`
SET u.`lastSeenAt` = d.`lastUse`
WHERE u.`lastSeenAt` IS NULL;

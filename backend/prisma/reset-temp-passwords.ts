import { PrismaClient, Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';

// Sets one temporary password on every account that still holds an
// admin-issued password, i.e. whose holder has not changed it yet
// (mustChangePassword = true). Accounts that already chose their own
// password are never touched, and the flag stays set, so each holder is
// still forced to replace the new one on first login.
//
//   npx ts-node prisma/reset-temp-passwords.ts <password>            dry run: counts only
//   npx ts-node prisma/reset-temp-passwords.ts <password> --commit   apply
//
// The password comes from the command line so it never sits in the repo.

const prisma = new PrismaClient();

async function main() {
  const args = process.argv.slice(2);
  const commit = args.includes('--commit');
  const [password] = args.filter((a) => !a.startsWith('--'));
  if (!password) {
    throw new Error('usage: npx ts-node prisma/reset-temp-passwords.ts <password> [--commit]');
  }
  // Login rejects passwords shorter than this, so the accounts would be unusable.
  if (password.length < 6) throw new Error('password must be at least 6 characters');

  // ADMIN is excluded explicitly: admins are never flagged, but a stray flag
  // must not let this script reset an admin's password.
  const where = { mustChangePassword: true, isActive: true, role: { not: Role.ADMIN } };

  const byRole = await prisma.user.groupBy({ by: ['role'], where, _count: { _all: true } });
  const total = byRole.reduce((sum, r) => sum + r._count._all, 0);
  for (const r of byRole) console.log(`${r.role}: ${r._count._all}`);
  console.log(`total: ${total}`);

  if (!commit) {
    console.log('dry run, nothing changed. Re-run with --commit to apply.');
    return;
  }

  // One hash for all rows: bcrypt salts it once, which is fine for a
  // temporary password that every holder must replace anyway.
  const passwordHash = await bcrypt.hash(password, 10);
  const { count } = await prisma.user.updateMany({ where, data: { passwordHash } });
  console.log(`updated: ${count}`);
}

main()
  .catch((e) => {
    console.error(e instanceof Error ? e.message : e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());

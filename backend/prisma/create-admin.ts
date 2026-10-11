import { PrismaClient, Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';

// Creates the first admin on a fresh database, which has no account to sign
// in with and so no screen to create one from.
//
//   npm run create-admin -- <email> <password> [full name]
//
// The credentials come from the command line so they never sit in the repo.

const prisma = new PrismaClient();

async function main() {
  const [rawEmail, password, fullName = 'Admin'] = process.argv.slice(2);
  if (!rawEmail || !password) {
    throw new Error(
      'usage: npm run create-admin -- <email> <password> [full name]',
    );
  }

  const email = rawEmail.trim().toLowerCase();
  // Login rejects passwords shorter than this, so the account would be unusable.
  if (password.length < 6) {
    throw new Error('password must be at least 6 characters');
  }

  // Refuse rather than overwrite, so a rerun can't silently reset a password.
  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    throw new Error(`a user with email ${email} already exists`);
  }

  const admin = await prisma.user.create({
    data: {
      fullName,
      email,
      passwordHash: await bcrypt.hash(password, 10),
      role: Role.ADMIN,
    },
  });

  console.log(`Created admin #${admin.id} (${admin.email})`);
}

main()
  .catch((e: Error) => {
    console.error(e.message);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());

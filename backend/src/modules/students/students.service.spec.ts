import { NotFoundException, BadRequestException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { StudentsService } from './students.service';
import { HADITH_BOOKS } from './hadith-books';

describe('StudentsService.remove', () => {
  const makePrisma = (student: { id: number; userId: number } | null) => ({
    student: { findUnique: jest.fn().mockResolvedValue(student) },
    user: {
      delete: jest.fn().mockResolvedValue({ id: student?.userId }),
      update: jest.fn(),
    },
  });

  it('hard-deletes the linked user row', async () => {
    const prisma = makePrisma({ id: 7, userId: 42 });
    const service = new StudentsService(prisma as any);

    await service.remove(7);

    expect(prisma.user.delete).toHaveBeenCalledWith({ where: { id: 42 } });
  });

  it('does not soft-delete by flipping isActive', async () => {
    const prisma = makePrisma({ id: 7, userId: 42 });
    const service = new StudentsService(prisma as any);

    await service.remove(7);

    expect(prisma.user.update).not.toHaveBeenCalled();
  });

  it('throws NotFoundException when the student does not exist', async () => {
    const prisma = makePrisma(null);
    const service = new StudentsService(prisma as any);

    await expect(service.remove(7)).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.user.delete).not.toHaveBeenCalled();
  });
});

describe('StudentsService.create', () => {
  // A password alone means nothing: only isAdult turns a student into an
  // account, so a password arriving without it is ignored rather than
  // silently upgrading a child student into someone who can log in.
  const makePrisma = () => ({
    user: {
      create: jest.fn().mockResolvedValue({ id: 42, student: { id: 7 } }),
    },
    student: { findUnique: jest.fn().mockResolvedValue({ id: 7 }) },
  });

  const payload = {
    fullName: 'Bilal Cherguini',
    phone: '4008',
    address: 'الجزائر العاصمة',
    birthDate: '2012-05-01',
  };

  it('stores no password hash for a new student', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.create(payload as any);

    const data = prisma.user.create.mock.calls[0][0].data;
    expect(data.passwordHash).toBeNull();
  });

  it('ignores a password a stale client still sends', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.create({ ...payload, password: 'hunter2' } as any);

    const data = prisma.user.create.mock.calls[0][0].data;
    expect(data.passwordHash).toBeNull();
  });

  it('creates a normal student as an account that cannot log in', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.create(payload as any);

    const data = prisma.user.create.mock.calls[0][0].data;
    expect(data.role).toBe('STUDENT');
    expect(data.passwordHash).toBeNull();
  });

  it('creates an adult student with a usable password', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.create({
      ...payload,
      isAdult: true,
      password: 'secret123',
    } as any);

    const data = prisma.user.create.mock.calls[0][0].data;
    expect(data.role).toBe('ADULT_STUDENT');
    expect(await bcrypt.compare('secret123', data.passwordHash)).toBe(true);
  });

  // The admin typed that password, so it is a temporary one.
  it('makes an adult student change the password on first login', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.create({
      ...payload,
      isAdult: true,
      password: 'secret123',
    } as any);

    const data = prisma.user.create.mock.calls[0][0].data;
    expect(data.mustChangePassword).toBe(true);
  });

  // An adult student with no password is an account nobody can ever use, and
  // the form would have no way to tell the admin why he cannot sign in.
  it('refuses an adult student without a password', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await expect(
      service.create({ ...payload, isAdult: true } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('stores the books in list order and turns tracksHadith on', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.create({
      ...payload,
      hadithBooks: [HADITH_BOOKS[4], HADITH_BOOKS[1]],
    } as any);

    const data = prisma.user.create.mock.calls[0][0].data;
    expect(data.student.create.hadithBooks).toEqual([
      HADITH_BOOKS[1],
      HADITH_BOOKS[4],
    ]);
    expect(data.student.create.tracksHadith).toBe(true);
  });

  it('defaults to no books and tracksHadith false when omitted', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.create(payload as any);

    const data = prisma.user.create.mock.calls[0][0].data;
    expect(data.student.create.hadithBooks).toEqual([]);
    expect(data.student.create.tracksHadith).toBe(false);
  });
});

describe('StudentsService.update', () => {
  const makePrisma = (role: string = 'STUDENT') => ({
    student: {
      findUnique: jest
        .fn()
        .mockResolvedValue({ id: 7, userId: 42, user: { role } }),
      update: jest.fn().mockResolvedValue({ id: 7 }),
    },
    user: { update: jest.fn(), findFirst: jest.fn() },
    halaqa: { findUnique: jest.fn() },
  });

  it('ignores a password a stale client still sends', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.update(7, { password: 'hunter2' } as any);

    expect(prisma.user.update).not.toHaveBeenCalled();
  });

  // The overall rating is free text the teacher writes on the student profile,
  // so it belongs on the student row rather than the user account.
  it('persists a free-text currentRating on the student row', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.update(7, { currentRating: 'ممتاز' });

    expect(prisma.student.update.mock.calls[0][0].data).toEqual({
      currentRating: 'ممتاز',
    });
  });

  // Clearing the box is how a teacher retracts a rating, so an empty string has
  // to reach the database instead of being skipped as falsy.
  it('clears the rating when given an empty string', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.update(7, { currentRating: '' });

    expect(prisma.student.update.mock.calls[0][0].data).toEqual({
      currentRating: '',
    });
  });

  it('leaves the rating untouched when the field is absent', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.update(7, { address: 'Algiers' });

    expect(prisma.student.update.mock.calls[0][0].data).toEqual({
      address: 'Algiers',
    });
  });

  it('persists hadithBooks and the derived flag on update', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.update(7, { hadithBooks: [HADITH_BOOKS[2]] });

    expect(prisma.student.update.mock.calls[0][0].data).toEqual({
      hadithBooks: [HADITH_BOOKS[2]],
      tracksHadith: true,
    });
  });

  it('turns hadith off when the books are cleared', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.update(7, { hadithBooks: [] });

    expect(prisma.student.update.mock.calls[0][0].data).toEqual({
      hadithBooks: [],
      tracksHadith: false,
    });
  });

  it('leaves hadith untouched when absent from the update', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.update(7, { address: 'Algiers' });

    expect(prisma.student.update.mock.calls[0][0].data).toEqual({
      address: 'Algiers',
    });
  });
});

// The halaqa/students pairing can be broken from either side of the relation:
// HalaqasService checks it when a halaqa's roster is written, and these cover
// the same invariant reached instead through a student's own halaqaId.
describe('StudentsService halaqa pairing', () => {
  it('refuses moving a child student into an adults\' halaqa on update', async () => {
    const prisma = {
      student: {
        findUnique: jest
          .fn()
          .mockResolvedValue({ id: 7, userId: 42, user: { role: 'STUDENT' } }),
        update: jest.fn(),
      },
      user: { update: jest.fn(), findFirst: jest.fn() },
      halaqa: { findUnique: jest.fn().mockResolvedValue({ isAdult: true }) },
    };
    const service = new StudentsService(prisma as any);

    await expect(
      service.update(7, { halaqaId: 3 } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.student.update).not.toHaveBeenCalled();
  });

  it('refuses moving an adult student into a normal halaqa on update', async () => {
    const prisma = {
      student: {
        findUnique: jest.fn().mockResolvedValue({
          id: 7,
          userId: 42,
          user: { role: 'ADULT_STUDENT' },
        }),
        update: jest.fn(),
      },
      user: { update: jest.fn(), findFirst: jest.fn() },
      halaqa: { findUnique: jest.fn().mockResolvedValue({ isAdult: false }) },
    };
    const service = new StudentsService(prisma as any);

    await expect(
      service.update(7, { halaqaId: 3 } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.student.update).not.toHaveBeenCalled();
  });

  it('allows moving a normal student into a matching halaqa on update', async () => {
    const prisma = {
      student: {
        findUnique: jest
          .fn()
          .mockResolvedValue({ id: 7, userId: 42, user: { role: 'STUDENT' } }),
        update: jest.fn().mockResolvedValue({ id: 7 }),
      },
      user: { update: jest.fn(), findFirst: jest.fn() },
      halaqa: { findUnique: jest.fn().mockResolvedValue({ isAdult: false }) },
    };
    const service = new StudentsService(prisma as any);

    await service.update(7, { halaqaId: 3 } as any);

    expect(prisma.student.update.mock.calls[0][0].data).toEqual({
      halaqaId: 3,
    });
  });

  it('allows moving an adult student into a matching adults\' halaqa on update', async () => {
    const prisma = {
      student: {
        findUnique: jest.fn().mockResolvedValue({
          id: 7,
          userId: 42,
          user: { role: 'ADULT_STUDENT' },
        }),
        update: jest.fn().mockResolvedValue({ id: 7 }),
      },
      user: { update: jest.fn(), findFirst: jest.fn() },
      halaqa: { findUnique: jest.fn().mockResolvedValue({ isAdult: true }) },
    };
    const service = new StudentsService(prisma as any);

    await service.update(7, { halaqaId: 3 } as any);

    expect(prisma.student.update.mock.calls[0][0].data).toEqual({
      halaqaId: 3,
    });
  });

  // Clearing the halaqa has nothing to mismatch against, and omitting it
  // entirely means the student isn't moving at all — neither should touch
  // the halaqas table.
  it('clears halaqaId without checking the pairing', async () => {
    const prisma = {
      student: {
        findUnique: jest
          .fn()
          .mockResolvedValue({ id: 7, userId: 42, user: { role: 'STUDENT' } }),
        update: jest.fn().mockResolvedValue({ id: 7 }),
      },
      user: { update: jest.fn(), findFirst: jest.fn() },
      halaqa: { findUnique: jest.fn() },
    };
    const service = new StudentsService(prisma as any);

    await service.update(7, { halaqaId: null } as any);

    expect(prisma.halaqa.findUnique).not.toHaveBeenCalled();
    expect(prisma.student.update.mock.calls[0][0].data).toEqual({
      halaqaId: null,
    });
  });

  it('issues no halaqa query when halaqaId is omitted from the update', async () => {
    const prisma = {
      student: {
        findUnique: jest
          .fn()
          .mockResolvedValue({ id: 7, userId: 42, user: { role: 'STUDENT' } }),
        update: jest.fn().mockResolvedValue({ id: 7 }),
      },
      user: { update: jest.fn(), findFirst: jest.fn() },
      halaqa: { findUnique: jest.fn() },
    };
    const service = new StudentsService(prisma as any);

    await service.update(7, { address: 'Algiers' });

    expect(prisma.halaqa.findUnique).not.toHaveBeenCalled();
  });

  const createPayload = {
    fullName: 'Bilal Cherguini',
    phone: '4008',
    address: 'الجزائر العاصمة',
    birthDate: '2012-05-01',
  };

  it('refuses creating a child student directly into an adults\' halaqa', async () => {
    const prisma = {
      user: { create: jest.fn() },
      student: { findUnique: jest.fn() },
      halaqa: { findUnique: jest.fn().mockResolvedValue({ isAdult: true }) },
    };
    const service = new StudentsService(prisma as any);

    await expect(
      service.create({ ...createPayload, halaqaId: 3 } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.user.create).not.toHaveBeenCalled();
  });

  it('refuses creating an adult student directly into a normal halaqa', async () => {
    const prisma = {
      user: { create: jest.fn() },
      student: { findUnique: jest.fn() },
      halaqa: { findUnique: jest.fn().mockResolvedValue({ isAdult: false }) },
    };
    const service = new StudentsService(prisma as any);

    await expect(
      service.create({
        ...createPayload,
        halaqaId: 3,
        isAdult: true,
        password: 'secret123',
      } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.user.create).not.toHaveBeenCalled();
  });

  it('allows creating a student directly into a matching halaqa', async () => {
    const prisma = {
      user: {
        create: jest.fn().mockResolvedValue({ id: 42, student: { id: 7 } }),
      },
      student: { findUnique: jest.fn().mockResolvedValue({ id: 7 }) },
      halaqa: { findUnique: jest.fn().mockResolvedValue({ isAdult: false }) },
    };
    const service = new StudentsService(prisma as any);

    await service.create({ ...createPayload, halaqaId: 3 } as any);

    expect(prisma.user.create).toHaveBeenCalled();
  });
});

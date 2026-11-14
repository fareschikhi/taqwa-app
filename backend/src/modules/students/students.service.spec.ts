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

describe('StudentsService.findAll grouped by halaqa', () => {
  // The admin roster pages through students section by section, so a page
  // must continue where the last one stopped: every enrolled student (by
  // halaqa, then name) first, the unassigned bucket after them.
  const makePrisma = (assigned: number, unassigned: number) => {
    const rows = (prefix: string, n: number) =>
      Array.from({ length: n }, (_, i) => ({ id: `${prefix}${i}` }));
    const all = { assigned: rows('a', assigned), unassigned: rows('u', unassigned) };
    const bucket = (where: any) =>
      where.AND.some((c: any) => c.halaqaId === null) ? 'unassigned' : 'assigned';
    return {
      student: {
        count: jest.fn(({ where }) => Promise.resolve(all[bucket(where)].length)),
        findMany: jest.fn(({ where, skip, take }) =>
          Promise.resolve(all[bucket(where)].slice(skip, skip + take)),
        ),
        groupBy: jest.fn().mockResolvedValue([
          { halaqaId: 3, _count: { _all: assigned } },
          { halaqaId: null, _count: { _all: unassigned } },
        ]),
      },
      halaqa: { findMany: jest.fn().mockResolvedValue([{ id: 3 }]) },
    };
  };

  it('fills a page with enrolled students before unassigned ones', async () => {
    const service = new StudentsService(makePrisma(25, 100) as any);

    const res = await service.findAll({ groupByHalaqa: true, page: 1, limit: 30 });

    expect(res.data.map((s: any) => s.id)).toEqual([
      ...Array.from({ length: 25 }, (_, i) => `a${i}`),
      ...Array.from({ length: 5 }, (_, i) => `u${i}`),
    ]);
    expect(res.total).toBe(125);
  });

  it('continues the unassigned bucket where the previous page stopped', async () => {
    const service = new StudentsService(makePrisma(25, 100) as any);

    const res = await service.findAll({ groupByHalaqa: true, page: 2, limit: 30 });

    expect(res.data.map((s: any) => s.id)).toEqual(
      Array.from({ length: 30 }, (_, i) => `u${i + 5}`),
    );
  });

  it('reports each section total, not just the loaded rows', async () => {
    const service = new StudentsService(makePrisma(25, 100) as any);

    const res = await service.findAll({ groupByHalaqa: true, page: 1, limit: 30 });

    expect((res as any).halaqaCounts).toEqual([
      { halaqaId: 3, count: 25 },
      { halaqaId: null, count: 100 },
    ]);
  });
});

describe('StudentsService.findAll in the user\'s halaqa order', () => {
  // Three halaqas whose names sort 3 < 5 < 9, plus an unassigned bucket. A
  // student row is `<halaqa>-<index>`, `u-<index>` when unassigned.
  const sizes: Record<string, number> = { 3: 4, 5: 3, 9: 2, null: 2 };
  const makePrisma = () => {
    const rows = (key: string) =>
      Array.from({ length: sizes[key] }, (_, i) => ({
        id: `${key === 'null' ? 'u' : key}-${i}`,
      }));
    const sectionOf = (where: any) => {
      const c = where.AND.find((c: any) => 'halaqaId' in c);
      return String(c.halaqaId);
    };
    return {
      student: {
        findMany: jest.fn(({ where, skip, take }) =>
          Promise.resolve(rows(sectionOf(where)).slice(skip, skip + take)),
        ),
        groupBy: jest.fn().mockResolvedValue([
          { halaqaId: 9, _count: { _all: sizes[9] } },
          { halaqaId: null, _count: { _all: sizes.null } },
          { halaqaId: 3, _count: { _all: sizes[3] } },
          { halaqaId: 5, _count: { _all: sizes[5] } },
        ]),
      },
      halaqa: {
        // The database's own name order, which the app must not re-sort.
        findMany: jest.fn(({ where }) =>
          Promise.resolve(
            [3, 5, 9].filter((id) => where.id.in.includes(id)).map((id) => ({ id })),
          ),
        ),
      },
    };
  };
  const ids = (res: any) => res.data.map((s: any) => s.id);

  it('keeps halaqa name order when no order is given', async () => {
    const service = new StudentsService(makePrisma() as any);

    const res = await service.findAll({ groupByHalaqa: true, page: 1, limit: 20 });

    expect(ids(res)).toEqual([
      '3-0', '3-1', '3-2', '3-3', '5-0', '5-1', '5-2', '9-0', '9-1', 'u-0', 'u-1',
    ]);
    expect(res.total).toBe(11);
  });

  it('puts the chosen halaqas first, the rest by name, unassigned last', async () => {
    const service = new StudentsService(makePrisma() as any);

    const res = await service.findAll({
      groupByHalaqa: true,
      page: 1,
      limit: 20,
      halaqaOrder: [9, 5],
    });

    expect(ids(res)).toEqual([
      '9-0', '9-1', '5-0', '5-1', '5-2', '3-0', '3-1', '3-2', '3-3', 'u-0', 'u-1',
    ]);
  });

  it('continues across a section boundary without repeating anyone', async () => {
    const service = new StudentsService(makePrisma() as any);
    const order = [9, 5];

    const pages = await Promise.all(
      [1, 2, 3].map((page) =>
        service.findAll({ groupByHalaqa: true, page, limit: 4, halaqaOrder: order }),
      ),
    );

    expect(pages.map(ids)).toEqual([
      ['9-0', '9-1', '5-0', '5-1'],
      ['5-2', '3-0', '3-1', '3-2'],
      ['3-3', 'u-0', 'u-1'],
    ]);
  });

  it('ignores a saved halaqa that no longer has students', async () => {
    const service = new StudentsService(makePrisma() as any);

    const res = await service.findAll({
      groupByHalaqa: true,
      page: 1,
      limit: 3,
      halaqaOrder: [42, 5],
    });

    expect(ids(res)).toEqual(['5-0', '5-1', '5-2']);
  });

  it('reads only the sections the page overlaps', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.findAll({ groupByHalaqa: true, page: 2, limit: 3 });

    // Rows 3..5 are the last of halaqa 3 and the first two of halaqa 5.
    expect(prisma.student.findMany).toHaveBeenCalledTimes(2);
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

  it('stores tracksTasmee when the admin turns it on', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.create({ ...payload, tracksTasmee: true } as any);

    const data = prisma.user.create.mock.calls[0][0].data;
    expect(data.student.create.tracksTasmee).toBe(true);
  });

  it('leaves tracksTasmee to the column default when omitted', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.create(payload as any);

    const data = prisma.user.create.mock.calls[0][0].data;
    expect(data.student.create.tracksTasmee).toBeUndefined();
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

  it('turns tracksTasmee off when the admin sends false', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.update(7, { tracksTasmee: false } as any);

    const data = prisma.student.update.mock.calls[0][0].data;
    expect(data.tracksTasmee).toBe(false);
  });

  it('ignores a password sent for a child student', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.update(7, { password: 'hunter2' } as any);

    expect(prisma.user.update).not.toHaveBeenCalled();
  });

  it('resets an adult student\'s password as a temporary one', async () => {
    const prisma = makePrisma('ADULT_STUDENT');
    const service = new StudentsService(prisma as any);

    await service.update(7, { password: 'NewPass123' });

    const data = prisma.user.update.mock.calls[0][0].data;
    expect(await bcrypt.compare('NewPass123', data.passwordHash)).toBe(true);
    expect(data.mustChangePassword).toBe(true);
    expect(data.password).toBeUndefined();
  });

  it('leaves an adult student\'s password alone when none is sent', async () => {
    const prisma = makePrisma('ADULT_STUDENT');
    const service = new StudentsService(prisma as any);

    await service.update(7, { fullName: 'أحمد بن علي' });

    const data = prisma.user.update.mock.calls[0][0].data;
    expect(data.passwordHash).toBeUndefined();
    expect(data.mustChangePassword).toBeUndefined();
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

describe('StudentsService record resets', () => {
  const makePrisma = (student: { id: number; userId: number } | null) => ({
    student: { findUnique: jest.fn().mockResolvedValue(student) },
    attendance: {
      count: jest.fn().mockResolvedValue(12),
      deleteMany: jest.fn().mockResolvedValue({ count: 12 }),
    },
    memorizationProgress: {
      count: jest.fn().mockResolvedValue(5),
      deleteMany: jest.fn().mockResolvedValue({ count: 5 }),
    },
    pointEntry: {
      aggregate: jest.fn().mockResolvedValue({
        _count: { _all: 3 },
        _sum: { amount: '7.250' },
      }),
      deleteMany: jest.fn().mockResolvedValue({ count: 3 }),
    },
  });

  it('summarises counts and the points balance', async () => {
    const prisma = makePrisma({ id: 7, userId: 42 });
    const service = new StudentsService(prisma as any);

    await expect(service.getRecordsSummary(7)).resolves.toEqual({
      attendance: 12,
      memorization: 5,
      points: 3,
      pointsTotal: 7.25,
    });
    expect(prisma.pointEntry.aggregate).toHaveBeenCalledWith(
      expect.objectContaining({ where: { userId: 42 } }),
    );
  });

  it('clears only this student’s attendance', async () => {
    const prisma = makePrisma({ id: 7, userId: 42 });
    const service = new StudentsService(prisma as any);

    await expect(service.clearAttendance(7)).resolves.toEqual({ deleted: 12 });
    expect(prisma.attendance.deleteMany).toHaveBeenCalledWith({
      where: { studentId: 7 },
    });
    expect(prisma.pointEntry.deleteMany).not.toHaveBeenCalled();
  });

  it('clears only this student’s memorization', async () => {
    const prisma = makePrisma({ id: 7, userId: 42 });
    const service = new StudentsService(prisma as any);

    await expect(service.clearMemorization(7)).resolves.toEqual({ deleted: 5 });
    expect(prisma.memorizationProgress.deleteMany).toHaveBeenCalledWith({
      where: { studentId: 7 },
    });
    expect(prisma.pointEntry.deleteMany).not.toHaveBeenCalled();
  });

  it('clears points by the student’s user id, not the student id', async () => {
    const prisma = makePrisma({ id: 7, userId: 42 });
    const service = new StudentsService(prisma as any);

    await expect(service.clearPoints(7)).resolves.toEqual({ deleted: 3 });
    expect(prisma.pointEntry.deleteMany).toHaveBeenCalledWith({
      where: { userId: 42 },
    });
  });

  it('throws NotFoundException and deletes nothing for an unknown student', async () => {
    const prisma = makePrisma(null);
    const service = new StudentsService(prisma as any);

    await expect(service.clearAttendance(7)).rejects.toBeInstanceOf(NotFoundException);
    await expect(service.clearMemorization(7)).rejects.toBeInstanceOf(NotFoundException);
    await expect(service.clearPoints(7)).rejects.toBeInstanceOf(NotFoundException);
    await expect(service.getRecordsSummary(7)).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.attendance.deleteMany).not.toHaveBeenCalled();
    expect(prisma.memorizationProgress.deleteMany).not.toHaveBeenCalled();
    expect(prisma.pointEntry.deleteMany).not.toHaveBeenCalled();
  });
});

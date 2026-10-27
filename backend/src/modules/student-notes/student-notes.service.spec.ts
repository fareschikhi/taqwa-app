import { StudentNotesService } from './student-notes.service';

describe('StudentNotesService notifications', () => {
  const makePrisma = (opts: {
    parentUserId?: number | null;
    fullName?: string;
    role?: string;
  }) => ({
    studentNote: {
      create: jest
        .fn()
        .mockImplementation(({ data }: any) => Promise.resolve({ id: 1, ...data })),
      findUnique: jest.fn().mockResolvedValue({ id: 1, note: 'قديم' }),
      update: jest.fn().mockResolvedValue({ id: 1, note: 'جديد' }),
      delete: jest.fn().mockResolvedValue({ id: 1 }),
    },
    $transaction: jest.fn((ops: Promise<unknown>[]) => Promise.all(ops)),
    student: {
      findUnique: jest.fn().mockResolvedValue(
        opts.parentUserId == null
          ? {
              userId: 40,
              parentId: null,
              user: { fullName: opts.fullName ?? 'Bilal', role: opts.role ?? 'STUDENT' },
            }
          : {
              userId: 40,
              parentId: 1,
              user: { fullName: opts.fullName ?? 'Bilal', role: opts.role ?? 'STUDENT' },
              parent: { userId: opts.parentUserId },
            },
      ),
    },
  });

  const notificationsMock = () => ({ create: jest.fn().mockResolvedValue({}) });

  const dto = (note: string) => ({ studentId: 7, teacherId: 2, note });

  it("notifies the student's parent when a teacher writes a note", async () => {
    const prisma = makePrisma({ parentUserId: 9 });
    const notifications = notificationsMock();
    const service = new StudentNotesService(prisma as any, notifications as any);

    await service.create(dto('أحسن اليوم'));

    expect(notifications.create).toHaveBeenCalledWith({
      userId: 9,
      studentId: 7,
      title: 'ملاحظة من المعلم',
      body: 'Bilal: أحسن اليوم',
    });
  });

  it('names the child, so a parent of several knows which one', async () => {
    const prisma = makePrisma({ parentUserId: 9, fullName: 'Yusuf' });
    const notifications = notificationsMock();
    const service = new StudentNotesService(prisma as any, notifications as any);

    await service.create(dto('أحسن اليوم'));

    const { body } = notifications.create.mock.calls[0][0];
    expect(body.startsWith('Yusuf: ')).toBe(true);
  });

  it('sends a truncated preview of a long note, not the whole thing', async () => {
    const long =
      'أحسن الطالب اليوم في المراجعة وأتقن الحفظ الجديد وشارك في الحلقة بنشاط ملحوظ';
    const prisma = makePrisma({ parentUserId: 9 });
    const notifications = notificationsMock();
    const service = new StudentNotesService(prisma as any, notifications as any);

    await service.create(dto(long));

    const { body } = notifications.create.mock.calls[0][0];
    expect(body.endsWith('…')).toBe(true);
    expect(body).not.toContain('ملحوظ');
  });

  it('stores the note in full even though the preview is cut', async () => {
    const long =
      'أحسن الطالب اليوم في المراجعة وأتقن الحفظ الجديد وشارك في الحلقة بنشاط ملحوظ';
    const prisma = makePrisma({ parentUserId: 9 });
    const service = new StudentNotesService(
      prisma as any,
      notificationsMock() as any,
    );

    await service.create(dto(long));

    expect(prisma.studentNote.create).toHaveBeenCalledWith(
      expect.objectContaining({ data: expect.objectContaining({ note: long }) }),
    );
  });

  it('skips a student with no parent', async () => {
    const prisma = makePrisma({ parentUserId: null });
    const notifications = notificationsMock();
    const service = new StudentNotesService(prisma as any, notifications as any);

    await service.create(dto('أحسن اليوم'));

    expect(notifications.create).not.toHaveBeenCalled();
  });

  it('notifies an adult student himself, since he has no parent', async () => {
    const prisma = makePrisma({ parentUserId: null, role: 'ADULT_STUDENT' });
    const notifications = notificationsMock();
    const service = new StudentNotesService(prisma as any, notifications as any);

    await service.create(dto('أحسن اليوم'));

    // The note is about him, so his own name would only crowd the preview.
    expect(notifications.create).toHaveBeenCalledWith({
      userId: 40,
      studentId: 7,
      title: 'ملاحظة من المعلم',
      body: 'أحسن اليوم',
    });
  });

  it('keeps the note when notifying fails', async () => {
    const prisma = makePrisma({ parentUserId: 9 });
    const notifications = {
      create: jest.fn().mockRejectedValue(new Error('down')),
    };
    const service = new StudentNotesService(prisma as any, notifications as any);

    // The note is already written, so this must resolve rather than throw.
    await expect(service.create(dto('أحسن اليوم'))).resolves.toBeDefined();
    expect(prisma.studentNote.create).toHaveBeenCalled();
  });

  it('says nothing when a note is edited', async () => {
    // An edit is a correction. Re-announcing a fixed typo is noise.
    const prisma = makePrisma({ parentUserId: 9 });
    const notifications = notificationsMock();
    const service = new StudentNotesService(prisma as any, notifications as any);

    await service.update(1, { note: 'جديد' });

    expect(notifications.create).not.toHaveBeenCalled();
  });

  it('says nothing when a note is deleted', async () => {
    const prisma = makePrisma({ parentUserId: 9 });
    const notifications = notificationsMock();
    const service = new StudentNotesService(prisma as any, notifications as any);

    await service.remove(1);

    expect(notifications.create).not.toHaveBeenCalled();
  });

  describe('bulk notes', () => {
    const bulk = (studentIds: number[]) => ({ studentIds, teacherId: 2, note: 'غداً مراجعة' });

    it('writes one note per student, all in one transaction', async () => {
      const prisma = makePrisma({ parentUserId: 9 });
      const service = new StudentNotesService(prisma as any, notificationsMock() as any);

      const notes = await service.createBulk(bulk([7, 8, 9]));

      expect(notes.map((n: any) => n.studentId)).toEqual([7, 8, 9]);
      expect(prisma.studentNote.create).toHaveBeenCalledTimes(3);
      expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    });

    it('writes a repeated student only once', async () => {
      const prisma = makePrisma({ parentUserId: 9 });
      const service = new StudentNotesService(prisma as any, notificationsMock() as any);

      await service.createBulk(bulk([7, 7, 8]));

      expect(prisma.studentNote.create).toHaveBeenCalledTimes(2);
    });

    it("tells each student's parent", async () => {
      const prisma = makePrisma({ parentUserId: 9 });
      const notifications = notificationsMock();
      const service = new StudentNotesService(prisma as any, notifications as any);

      await service.createBulk(bulk([7, 8]));

      expect(notifications.create).toHaveBeenCalledTimes(2);
    });
  });
});

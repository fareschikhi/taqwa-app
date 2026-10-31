import { BadRequestException, NotFoundException } from '@nestjs/common';
import { ParentsService } from './parents.service';

describe('ParentsService.remove', () => {
  const makePrisma = (parent: { id: number; userId: number } | null) => ({
    parent: { findUnique: jest.fn().mockResolvedValue(parent) },
    user: {
      delete: jest.fn().mockResolvedValue({ id: parent?.userId }),
      update: jest.fn(),
    },
  });

  it('hard-deletes the linked user row', async () => {
    const prisma = makePrisma({ id: 3, userId: 88 });
    const service = new ParentsService(prisma as any);

    await service.remove(3);

    expect(prisma.user.delete).toHaveBeenCalledWith({ where: { id: 88 } });
  });

  it('does not soft-delete by flipping isActive', async () => {
    const prisma = makePrisma({ id: 3, userId: 88 });
    const service = new ParentsService(prisma as any);

    await service.remove(3);

    expect(prisma.user.update).not.toHaveBeenCalled();
  });

  it('throws NotFoundException when the parent does not exist', async () => {
    const prisma = makePrisma(null);
    const service = new ParentsService(prisma as any);

    await expect(service.remove(3)).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.user.delete).not.toHaveBeenCalled();
  });
});

// A password an admin sets is a temporary one: the parent replaces it on
// their next login.
describe('ParentsService passwords', () => {
  const makePrisma = () => ({
    user: {
      create: jest.fn().mockResolvedValue({ id: 42 }),
      update: jest.fn().mockResolvedValue({ id: 42 }),
    },
    parent: {
      findUnique: jest.fn().mockResolvedValue({ id: 4, userId: 42 }),
      update: jest.fn().mockResolvedValue({ id: 4 }),
    },
  });

  it('makes a new parent change the password on first login', async () => {
    const prisma = makePrisma();

    await new ParentsService(prisma as any).create({
      fullName: 'Karim Saidi',
      phone: '4200',
      password: 'secret123',
    } as any);

    expect(prisma.user.create.mock.calls[0][0].data.mustChangePassword).toBe(
      true,
    );
  });

  it('makes the parent change a password an admin reset', async () => {
    const prisma = makePrisma();

    await new ParentsService(prisma as any).update(4, {
      password: 'secret123',
    } as any);

    expect(prisma.user.update.mock.calls[0][0].data.mustChangePassword).toBe(
      true,
    );
  });

  it('leaves the flag alone when the password is not touched', async () => {
    const prisma = makePrisma();

    await new ParentsService(prisma as any).update(4, {
      fullName: 'Karim S.',
    } as any);

    expect(prisma.user.update.mock.calls[0][0].data).not.toHaveProperty(
      'mustChangePassword',
    );
  });
});

// The parent form picks the parent's children. A student carries one parent
// (Student.parentId), so linking is done from the parent row's side.
describe('ParentsService children', () => {
  const makePrisma = (roles: Record<number, string>) => ({
    user: { create: jest.fn().mockResolvedValue({ id: 42 }), update: jest.fn() },
    parent: {
      findUnique: jest.fn().mockResolvedValue({ id: 4, userId: 42 }),
      update: jest.fn().mockResolvedValue({ id: 4 }),
    },
    student: {
      findMany: jest.fn().mockImplementation(({ where }) =>
        Promise.resolve(
          (where.id.in as number[])
            .filter((id) => roles[id])
            .map((id) => ({ id, user: { role: roles[id] } })),
        ),
      ),
    },
  });

  it('links the picked students to a new parent', async () => {
    const prisma = makePrisma({ 7: 'STUDENT', 8: 'STUDENT' });

    await new ParentsService(prisma as any).create({
      fullName: 'Karim Saidi',
      password: 'secret123',
      studentIds: [7, 8],
    } as any);

    expect(
      prisma.user.create.mock.calls[0][0].data.parent.create.students,
    ).toEqual({ connect: [{ id: 7 }, { id: 8 }] });
  });

  it('replaces the children on update', async () => {
    const prisma = makePrisma({ 7: 'STUDENT' });

    await new ParentsService(prisma as any).update(4, {
      studentIds: [7],
    } as any);

    expect(prisma.parent.update.mock.calls[0][0].data.students).toEqual({
      set: [{ id: 7 }],
    });
  });

  it('unlinks every child when given an empty list', async () => {
    const prisma = makePrisma({});

    await new ParentsService(prisma as any).update(4, {
      studentIds: [],
    } as any);

    expect(prisma.parent.update.mock.calls[0][0].data.students).toEqual({
      set: [],
    });
  });

  it('leaves the children alone when studentIds is omitted', async () => {
    const prisma = makePrisma({});

    await new ParentsService(prisma as any).update(4, {
      fullName: 'Karim S.',
    } as any);

    expect(prisma.parent.update.mock.calls[0][0].data).not.toHaveProperty(
      'students',
    );
  });

  it('refuses an adult student', async () => {
    const prisma = makePrisma({ 7: 'STUDENT', 9: 'ADULT_STUDENT' });

    await expect(
      new ParentsService(prisma as any).update(4, {
        studentIds: [7, 9],
      } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.parent.update).not.toHaveBeenCalled();
  });

  it('refuses a student that does not exist', async () => {
    const prisma = makePrisma({ 7: 'STUDENT' });

    await expect(
      new ParentsService(prisma as any).create({
        fullName: 'Karim Saidi',
        password: 'secret123',
        studentIds: [7, 99],
      } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.user.create).not.toHaveBeenCalled();
  });
});

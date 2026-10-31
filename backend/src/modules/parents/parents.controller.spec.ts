import { ForbiddenException } from '@nestjs/common';
import { ParentsController } from './parents.controller';

describe('ParentsController.update', () => {
  const makeController = () => {
    const service = { update: jest.fn().mockResolvedValue({ id: 4 }) };
    return { service, controller: new ParentsController(service as any) };
  };

  it('lets a parent edit his own profile', async () => {
    const { service, controller } = makeController();

    await controller.update(4, { fullName: 'Karim S.' } as any, {
      role: 'PARENT',
      parent: { id: 4 },
    });

    expect(service.update).toHaveBeenCalledWith(4, { fullName: 'Karim S.' });
  });

  it('refuses a parent picking his own children', () => {
    const { service, controller } = makeController();

    expect(() =>
      controller.update(4, { studentIds: [7] } as any, {
        role: 'PARENT',
        parent: { id: 4 },
      }),
    ).toThrow(ForbiddenException);
    expect(service.update).not.toHaveBeenCalled();
  });

  it('lets an admin pick the children', async () => {
    const { service, controller } = makeController();

    await controller.update(4, { studentIds: [7] } as any, { role: 'ADMIN' });

    expect(service.update).toHaveBeenCalledWith(4, { studentIds: [7] });
  });
});

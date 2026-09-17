import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';
import {
  CreateHalaqaAnnouncementDto,
  UpdateHalaqaAnnouncementDto,
} from './halaqa-announcement.dto';

const errorsOn = (payload: Record<string, unknown>) =>
  validateSync(plainToInstance(CreateHalaqaAnnouncementDto, payload)).map(
    (e) => e.property,
  );

describe('CreateHalaqaAnnouncementDto', () => {
  it('accepts a title and a body on a halaqa', () => {
    expect(
      errorsOn({ halaqaId: 4, title: 'غياب المعلم', body: 'الحلقة معطلة غدا' }),
    ).toEqual([]);
  });

  it('rejects a missing halaqaId', () => {
    expect(errorsOn({ title: 'غياب المعلم', body: 'x' })).toContain('halaqaId');
  });

  it('rejects a halaqaId that is not an integer', () => {
    expect(errorsOn({ halaqaId: 'four', title: 'x', body: 'y' })).toContain(
      'halaqaId',
    );
  });

  // An announcement with no words is not an announcement. Whitespace-only
  // counts as empty: a manager who taps save on a blank form has not posted.
  it('rejects an empty title', () => {
    expect(errorsOn({ halaqaId: 4, title: '', body: 'y' })).toContain('title');
  });

  it('rejects a whitespace-only title', () => {
    expect(errorsOn({ halaqaId: 4, title: '   ', body: 'y' })).toContain('title');
  });

  it('rejects an empty body', () => {
    expect(errorsOn({ halaqaId: 4, title: 'x', body: '' })).toContain('body');
  });

  it('rejects a title longer than the column', () => {
    expect(
      errorsOn({ halaqaId: 4, title: 'ا'.repeat(201), body: 'y' }),
    ).toContain('title');
  });
});

describe('UpdateHalaqaAnnouncementDto', () => {
  it('accepts an empty patch', () => {
    expect(
      validateSync(plainToInstance(UpdateHalaqaAnnouncementDto, {})),
    ).toEqual([]);
  });

  it('still rejects a blank title when one is given', () => {
    const errors = validateSync(
      plainToInstance(UpdateHalaqaAnnouncementDto, { title: '  ' }),
    );

    expect(errors.map((e) => e.property)).toContain('title');
  });
});

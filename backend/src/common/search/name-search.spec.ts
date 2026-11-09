import { matchesSearch, userIdsMatching } from './name-search';

describe('matchesSearch', () => {
  it('finds a name written with a shadda and a space', () => {
    expect(matchesSearch('عبدالرحمان', 'عبد الرّحمان')).toBe(true);
  });

  it('ignores harakat and tatweel on either side', () => {
    expect(matchesSearch('محمّد', 'محمد')).toBe(true);
    expect(matchesSearch('محمد', 'مُحَمَّـــد')).toBe(true);
  });

  it('treats alef forms, ya/alef maqsura and ta marbuta as one', () => {
    expect(matchesSearch('احمد', 'أحمد')).toBe(true);
    expect(matchesSearch('مصطفي', 'مصطفى')).toBe(true);
    expect(matchesSearch('فاطمه', 'فاطمة')).toBe(true);
  });

  it('still rejects a different name', () => {
    expect(matchesSearch('عبدالله', 'عبد الرّحمان')).toBe(false);
  });
});

describe('userIdsMatching', () => {
  it('returns the ids whose normalized name contains the term', async () => {
    const prisma: any = {
      user: {
        findMany: jest.fn().mockResolvedValue([
          { id: 1, fullName: 'عبد الرّحمان بن علي' },
          { id: 2, fullName: 'عبد الله' },
        ]),
      },
    };

    await expect(userIdsMatching(prisma, 'عبدالرحمان')).resolves.toEqual([1]);
  });
});

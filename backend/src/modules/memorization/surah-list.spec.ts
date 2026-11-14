import { BadRequestException } from '@nestjs/common';
import { ProgressUnit } from '@prisma/client';
import { resolveSurahs } from './surah-list';

describe('resolveSurahs', () => {
  const page = ProgressUnit.PAGE;

  it('leaves a single-surah entry exactly as older clients send it', () => {
    expect(resolveSurahs({ unit: page, surahNumber: 2 })).toEqual({
      surahNumber: 2,
      surahNumbers: undefined,
    });
  });

  it('keeps the list in mushaf order, without repeats, led by its first surah', () => {
    expect(
      resolveSurahs({ unit: page, surahNumbers: [114, 112, 113, 112] }),
    ).toEqual({ surahNumber: 112, surahNumbers: [112, 113, 114] });
  });

  // One surah is the ordinary single-surah row, so the list is not stored.
  it('stores a one-surah list as a plain surahNumber', () => {
    expect(resolveSurahs({ unit: page, surahNumbers: [18] })).toEqual({
      surahNumber: 18,
      surahNumbers: null,
    });
  });

  it('reads an empty list as no surah at all', () => {
    expect(resolveSurahs({ unit: page, surahNumbers: [] })).toEqual({
      surahNumber: null,
      surahNumbers: null,
    });
  });

  it('accepts a surahNumber sent alongside the list when it is the first one', () => {
    expect(
      resolveSurahs({ unit: page, surahNumber: 113, surahNumbers: [114, 113] }),
    ).toEqual({ surahNumber: 113, surahNumbers: [113, 114] });
  });

  it('refuses a surahNumber the list does not lead with', () => {
    expect(() =>
      resolveSurahs({ unit: page, surahNumber: 2, surahNumbers: [113, 114] }),
    ).toThrow(BadRequestException);
  });

  // An ayah range is numbered inside a single surah.
  it('refuses several surahs on an entry counted in ayahs', () => {
    expect(() =>
      resolveSurahs({ unit: ProgressUnit.AYAH, surahNumbers: [113, 114] }),
    ).toThrow(BadRequestException);
  });

  it('allows one surah on an entry counted in ayahs', () => {
    expect(
      resolveSurahs({ unit: ProgressUnit.AYAH, surahNumbers: [114] }),
    ).toEqual({ surahNumber: 114, surahNumbers: null });
  });
});

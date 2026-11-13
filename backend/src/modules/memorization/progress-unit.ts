import { BadRequestException } from '@nestjs/common';
import { MemorizationSubject, ProgressUnit } from '@prisma/client';
import { ayahCountOf } from './surah-ayahs';

export { ProgressUnit };

/**
 * The unit a row's `amountDone` is in. A Quran entry is counted in mushaf
 * pages unless the teacher recorded an ayah range. A hadith entry is counted
 * in single hadiths unless the teacher chose pages; an omitted unit means
 * hadiths, which is what every hadith entry was before the choice existed
 * (and what older app versions still send).
 *
 * `requested` is only the client's wish: a unit that does not belong to the
 * subject is refused rather than silently corrected.
 */
export function unitFor(
  subject: MemorizationSubject,
  requested?: ProgressUnit | null,
): ProgressUnit {
  if (subject === MemorizationSubject.QURAN) {
    if (requested === ProgressUnit.HADITH) {
      throw new BadRequestException(
        'A Quran entry is counted in pages or ayahs, so unit must be PAGE or AYAH',
      );
    }
    return requested ?? ProgressUnit.PAGE;
  }
  if (requested === ProgressUnit.AYAH) {
    throw new BadRequestException(
      'A hadith entry is counted in hadiths or pages, so unit must be HADITH or PAGE',
    );
  }
  return requested ?? ProgressUnit.HADITH;
}

/**
 * Upper bound per entry: the mushaf has 604 pages, and the same cap serves a
 * hadith book's pages. Single hadiths have no physical ceiling — 50 is a
 * generous per-entry cap. An ayah entry stays inside one surah, and the
 * longest (البقرة) has 286.
 */
export const MAX_AMOUNT: Record<ProgressUnit, number> = {
  PAGE: 604,
  HADITH: 50,
  AYAH: 286,
};

/**
 * Checks the ayah fields against the unit and returns the amount the row must
 * store. An AYAH row that names a surah needs a range inside it, and its
 * amount is the number of ayahs in that range — the client's amount must
 * agree, so a mismatch is reported instead of one side silently winning. An
 * AYAH row with no surah is a bare count: a range has nothing to sit inside,
 * so it is refused. Any other unit must not carry a range at all.
 */
export function ayahRangeAmount(input: {
  unit: ProgressUnit;
  surahNumber?: number | null;
  ayahFrom?: number | null;
  ayahTo?: number | null;
  amountDone: number;
}): number {
  const { unit, surahNumber, ayahFrom, ayahTo, amountDone } = input;
  if (unit !== ProgressUnit.AYAH) {
    if (ayahFrom != null || ayahTo != null) {
      throw new BadRequestException(
        'ayahFrom and ayahTo are only valid on an entry counted in ayahs (unit AYAH)',
      );
    }
    return amountDone;
  }
  if (surahNumber == null) {
    if (ayahFrom != null || ayahTo != null) {
      throw new BadRequestException(
        'ayahFrom and ayahTo need a surahNumber; an ayah entry without a surah records only the count',
      );
    }
    return amountDone;
  }
  if (ayahFrom == null || ayahTo == null) {
    throw new BadRequestException(
      'An entry counted in ayahs with a surahNumber needs both ayahFrom and ayahTo',
    );
  }
  const ayahs = ayahCountOf(surahNumber);
  if (ayahs == null) {
    throw new BadRequestException(
      'An entry counted in ayahs needs a surahNumber between 1 and 114',
    );
  }
  if (ayahFrom < 1 || ayahTo > ayahs || ayahFrom > ayahTo) {
    throw new BadRequestException(
      `Surah ${surahNumber} has ${ayahs} ayahs, so the range must satisfy 1 ≤ ayahFrom ≤ ayahTo ≤ ${ayahs}`,
    );
  }
  const count = ayahTo - ayahFrom + 1;
  if (amountDone !== count) {
    throw new BadRequestException(
      `Ayahs ${ayahFrom}–${ayahTo} are ${count} ayahs, so amountDone must be ${count}`,
    );
  }
  return count;
}

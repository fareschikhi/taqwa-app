import { BadRequestException } from '@nestjs/common';
import { MemorizationSubject, ProgressUnit } from '@prisma/client';

export { ProgressUnit };

/**
 * The unit a row's `amountDone` is in. Quran is always counted in mushaf
 * pages. A hadith entry is counted in single hadiths unless the teacher chose
 * pages; an omitted unit means hadiths, which is what every hadith entry was
 * before the choice existed (and what older app versions still send).
 *
 * `requested` is only the client's wish: a Quran entry counted in hadiths is
 * refused rather than silently corrected.
 */
export function unitFor(
  subject: MemorizationSubject,
  requested?: ProgressUnit | null,
): ProgressUnit {
  if (subject === MemorizationSubject.QURAN) {
    if (requested === ProgressUnit.HADITH) {
      throw new BadRequestException(
        'A Quran entry is counted in pages, so unit must be PAGE',
      );
    }
    return ProgressUnit.PAGE;
  }
  return requested ?? ProgressUnit.HADITH;
}

/**
 * Upper bound per entry: the mushaf has 604 pages, and the same cap serves a
 * hadith book's pages. Single hadiths have no physical ceiling — 50 is a
 * generous per-entry cap.
 */
export const MAX_AMOUNT: Record<ProgressUnit, number> = {
  PAGE: 604,
  HADITH: 50,
};

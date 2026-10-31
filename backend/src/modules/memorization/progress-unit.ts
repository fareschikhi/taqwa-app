import { MemorizationSubject } from '@prisma/client';

export type ProgressUnit = 'PAGE' | 'HADITH';

/**
 * Every Quran entry, new memorization or revision, is measured in mushaf
 * pages. A hadith entry of any type is measured in hadiths — there is no
 * page concept for a free-text hadith reference. `amountDone` carries
 * whichever unit this returns, so this is the only place the mapping is
 * allowed to live.
 */
export function unitFor(subject: MemorizationSubject): ProgressUnit {
  return subject === MemorizationSubject.HADITH ? 'HADITH' : 'PAGE';
}

/**
 * Upper bound per unit: the mushaf has 604 pages. HADITH has no physical
 * ceiling behind it — 50 is a generous per-entry cap.
 */
export const MAX_AMOUNT: Record<ProgressUnit, number> = {
  PAGE: 604,
  HADITH: 50,
};

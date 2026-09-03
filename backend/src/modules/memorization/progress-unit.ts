import { Memorization, MemorizationSubject } from '@prisma/client';

export type ProgressUnit = 'PAGE' | 'HIZB' | 'HADITH';

/**
 * New Quran memorization is measured in pages, Quran revision in hizbs.
 * A hadith entry of any type is measured in hadiths — there is no
 * page/hizb concept for a free-text hadith reference. `amountDone` carries
 * whichever unit this returns, so this is the only place the mapping is
 * allowed to live.
 */
export function unitFor(
  subject: MemorizationSubject,
  type: Memorization,
): ProgressUnit {
  if (subject === MemorizationSubject.HADITH) return 'HADITH';
  return type === Memorization.MEMORIZING ? 'PAGE' : 'HIZB';
}

/**
 * Upper bound per unit: the mushaf has 604 pages and 60 hizbs. HADITH has no
 * physical ceiling behind it — 50 is a generous per-entry cap.
 */
export const MAX_AMOUNT: Record<ProgressUnit, number> = {
  PAGE: 604,
  HIZB: 60,
  HADITH: 50,
};

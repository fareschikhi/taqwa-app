import { Memorization } from '@prisma/client';

export type ProgressUnit = 'PAGE' | 'HIZB';

/**
 * New memorization is measured in pages; both kinds of revision are measured
 * in hizbs. `amountDone` carries whichever unit this returns, so this is the
 * only place the mapping is allowed to live.
 */
export function unitFor(type: Memorization): ProgressUnit {
  return type === Memorization.MEMORIZING ? 'PAGE' : 'HIZB';
}

/** Upper bound per unit: the mushaf has 604 pages and 60 hizbs. */
export const MAX_AMOUNT: Record<ProgressUnit, number> = {
  PAGE: 604,
  HIZB: 60,
};

import { PrismaService } from '../../prisma/prisma.service';

/**
 * Harakat (fatha … sukun, shadda, Quranic marks), superscript alef, tatweel
 * and spaces: they change how a name is written, not who it is.
 * Kept identical to the app's lib/core/utils/search_text.dart.
 */
const IGNORED = /[ً-ٰٟـ\s]/g;

const SAME_LETTER: Record<string, string> = {
  أ: 'ا',
  إ: 'ا',
  آ: 'ا',
  ٱ: 'ا',
  ى: 'ي',
  ة: 'ه',
};

/** 'عبد الرّحمان' and 'عبدالرحمان' both become 'عبدالرحمان'. */
export function normalizeForSearch(text: string): string {
  return Array.from(text.toLowerCase().replace(IGNORED, ''))
    .map((c) => SAME_LETTER[c] ?? c)
    .join('');
}

export function matchesSearch(term: string, text: string | null): boolean {
  const q = normalizeForSearch(term);
  return q === '' || (text !== null && normalizeForSearch(text).includes(q));
}

/*
 * MySQL's LIKE cannot drop diacritics or spaces, so names are matched here.
 * The school has hundreds of rows, not millions: reading id + name is cheap,
 * and the result goes back to Prisma as an `id IN (...)` filter.
 */

export async function userIdsMatching(
  prisma: PrismaService,
  term: string,
): Promise<number[]> {
  const users = await prisma.user.findMany({
    select: { id: true, fullName: true },
  });
  return users.filter((u) => matchesSearch(term, u.fullName)).map((u) => u.id);
}

export async function halaqaIdsMatching(
  prisma: PrismaService,
  term: string,
): Promise<number[]> {
  const halaqas = await prisma.halaqa.findMany({
    select: { id: true, name: true },
  });
  return halaqas.filter((h) => matchesSearch(term, h.name)).map((h) => h.id);
}

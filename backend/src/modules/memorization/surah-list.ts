import { BadRequestException } from '@nestjs/common';
import { Prisma, ProgressUnit } from '@prisma/client';

/// How a recitation names its surahs once checked.
///
/// `surahNumber` stays the one column every reader already uses (sorting, the
/// last-session prefill, duplicate checks), so it holds the first surah.
/// `surahNumbers` holds the full list only when there are two or more; a
/// single-surah row looks exactly as it did before the list existed.
/// `undefined` means "the request did not touch the list".
export type ResolvedSurahs = {
  surahNumber: number | null | undefined;
  surahNumbers: number[] | null | undefined;
};

/// Folds `surahNumbers` (several surahs recited in one go, e.g. the last
/// three of the mushaf) into the stored shape.
///
/// The list is kept in mushaf order without repeats, so the same recitation
/// always reads the same way whatever order the teacher tapped. An ayah range
/// is numbered inside one surah, so an AYAH entry may name only one.
export function resolveSurahs(input: {
  unit: ProgressUnit;
  surahNumber?: number | null;
  surahNumbers?: number[] | null;
}): ResolvedSurahs {
  const { unit, surahNumber, surahNumbers } = input;
  if (surahNumbers == null) {
    return { surahNumber, surahNumbers: undefined };
  }

  const list = [...new Set(surahNumbers)].sort((a, b) => a - b);
  const first = list[0] ?? null;
  if (surahNumber != null && surahNumber !== first) {
    throw new BadRequestException(
      'surahNumber must be the first surah of surahNumbers, so send one or the other',
    );
  }
  if (list.length > 1 && unit === ProgressUnit.AYAH) {
    throw new BadRequestException(
      'An ayah range lies inside one surah, so an entry counted in ayahs takes a single surah',
    );
  }
  return {
    surahNumber: first,
    surahNumbers: list.length > 1 ? list : null,
  };
}

/// The stored list, read off the untyped JSON column. Anything that is not a
/// list of whole numbers reads as no list, so a bad row falls back to its
/// surahNumber rather than throwing.
export function storedSurahList(raw: unknown): number[] | null {
  if (!Array.isArray(raw)) return null;
  const list = raw.filter((n): n is number => Number.isInteger(n));
  return list.length > 1 ? list : null;
}

/// Every surah a row names: its list when it has one, else its single
/// surahNumber, else none.
export function surahsOfRow(row: {
  surahNumber: number | null;
  surahNumbers?: unknown;
}): number[] {
  const list = storedSurahList(row.surahNumbers);
  if (list) return list;
  return row.surahNumber == null ? [] : [row.surahNumber];
}

/// The two columns as Prisma takes them. Prisma reads `undefined` as "leave
/// as is" and needs DbNull, not null, to clear a JSON column.
export function surahColumns(surahs: ResolvedSurahs): {
  surahNumber?: number | null;
  surahNumbers?: number[] | typeof Prisma.DbNull;
} {
  return {
    surahNumber: surahs.surahNumber,
    surahNumbers:
      surahs.surahNumbers === undefined
        ? undefined
        : (surahs.surahNumbers ?? Prisma.DbNull),
  };
}

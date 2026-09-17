import { SetMetadata } from '@nestjs/common';

export const HALAQA_SOURCE_KEY = 'halaqaSource';

/**
 * Where `HalaqaAccessGuard` finds the halaqa a request is reaching for.
 *
 *   'param'        — `params.id` IS the halaqa id
 *   'body'         — `body.halaqaId`, on create
 *   'announcement' — `params.id` is an announcement; load its halaqa
 */
export type HalaqaSource = 'param' | 'body' | 'announcement';

/**
 * Declared rather than sniffed from the request shape, so the route says out
 * loud what its `:id` means — the same way `@Roles` states intent instead of
 * leaving it inferred. A route with no `@HalaqaFrom` is denied.
 */
export const HalaqaFrom = (source: HalaqaSource) =>
  SetMetadata(HALAQA_SOURCE_KEY, source);

import { ConflictException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

/// Points, fines and announcements keep their author (`onDelete: Restrict`),
/// so deleting an account that made any of them fails with Prisma's P2003.
/// Turns that one failure into a sentence the admin can act on; anything else
/// is rethrown untouched.
///
/// Only for deletes: P2003 on a create means a bad reference, not this.
export function explainRestrictedDelete(error: unknown): never {
  if (
    error instanceof Prisma.PrismaClientKnownRequestError &&
    error.code === 'P2003'
  ) {
    throw new ConflictException(
      'لا يمكن حذف هذا الحساب لأن له سجلات مرتبطة (نقاط أو غرامات أو إعلانات). عطّل الحساب بدلاً من ذلك.',
    );
  }
  throw error;
}

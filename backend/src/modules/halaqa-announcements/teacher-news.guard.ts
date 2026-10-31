import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';

/**
 * Lets a TEACHER through a news write only when the admin has granted them
 * `canPostNews`. Every other role passes untouched: they are already narrowed
 * by `@Roles`, and which halaqas they reach is HalaqaAccessGuard's job.
 * Mirrors the pass-through shape of ManagerPermissionGuard.
 */
@Injectable()
export class TeacherNewsGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const { user } = context.switchToHttp().getRequest();
    if (user?.role !== 'TEACHER') return true;

    if (!user.teacher?.canPostNews) {
      throw new ForbiddenException('غير مصرح لك بنشر الأخبار');
    }
    return true;
  }
}

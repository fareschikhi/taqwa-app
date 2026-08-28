import {
  CanActivate,
  ExecutionContext,
  Injectable,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * Restricts a `:id` student-scoped route so a PARENT only reaches their own
 * child. ADMIN, TEACHER and MANAGER pass through unchanged since they
 * legitimately need cross-student access; every other role is denied.
 */
@Injectable()
export class StudentOwnershipGuard implements CanActivate {
  constructor(private prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const user = request.user;
    const studentId = Number(request.params.id);

    if (user.role === 'PARENT') {
      const student = await this.prisma.student.findUnique({
        where: { id: studentId },
        select: { parentId: true },
      });
      return !!student && student.parentId === user.parent?.id;
    }

    // Named rather than defaulted to true: @Roles already turns STUDENT away,
    // and a route that forgets to list its roles should fail closed here.
    return ['ADMIN', 'TEACHER', 'MANAGER'].includes(user.role);
  }
}

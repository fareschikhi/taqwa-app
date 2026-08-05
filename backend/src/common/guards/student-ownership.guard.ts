import {
  CanActivate,
  ExecutionContext,
  Injectable,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * Restricts a `:id` student-scoped route so PARENT/STUDENT users can only
 * reach their own child/own record. ADMIN, TEACHER and MANAGER pass through
 * unchanged since they legitimately need cross-student access.
 */
@Injectable()
export class StudentOwnershipGuard implements CanActivate {
  constructor(private prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const user = request.user;
    const studentId = Number(request.params.id);

    if (user.role === 'STUDENT') {
      return user.student?.id === studentId;
    }

    if (user.role === 'PARENT') {
      const student = await this.prisma.student.findUnique({
        where: { id: studentId },
        select: { parentId: true },
      });
      return !!student && student.parentId === user.parent?.id;
    }

    return true;
  }
}

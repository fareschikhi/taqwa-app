import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { TeachersModule } from './modules/teachers/teachers.module';
import { StudentsModule } from './modules/students/students.module';
import { ParentsModule } from './modules/parents/parents.module';
import { HalaqasModule } from './modules/halaqas/halaqas.module';
import { AttendanceModule } from './modules/attendance/attendance.module';
import { MemorizationModule } from './modules/memorization/memorization.module';
import { EvaluationsModule } from './modules/evaluations/evaluations.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { ManagersModule } from './modules/managers/managers.module';
import { AbsenceJustificationModule } from './modules/absence-justification/absence-justification.module';
import { StudentNotesModule } from './modules/student-notes/student-notes.module';

@Module({
  imports: [
    PrismaModule,
    AuthModule,
    UsersModule,
    TeachersModule,
    StudentsModule,
    ParentsModule,
    HalaqasModule,
    AttendanceModule,
    MemorizationModule,
    EvaluationsModule,
    NotificationsModule,
    ManagersModule,
    AbsenceJustificationModule,
    StudentNotesModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}


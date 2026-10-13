import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
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
import { HalaqaAnnouncementsModule } from './modules/halaqa-announcements/halaqa-announcements.module';
import { UploadsModule } from './modules/uploads/uploads.module';
import { DevicesModule } from './modules/devices/devices.module';
import { FinesModule } from './modules/fines/fines.module';

@Module({
  imports: [
    // Loads backend/.env into process.env. Prisma reads that file on its own,
    // but nothing else did, so every other process.env lookup was undefined.
    ConfigModule.forRoot({ isGlobal: true }),
    // Every route, per client IP. Generous for real use; the login route sets
    // its own much tighter limit. The message is what the app shows.
    ThrottlerModule.forRoot({
      throttlers: [{ name: 'default', ttl: 60_000, limit: 120 }],
      errorMessage: 'طلبات كثيرة جدا. انتظر قليلا ثم حاول مجددا',
    }),
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
    HalaqaAnnouncementsModule,
    UploadsModule,
    DevicesModule,
    FinesModule,
  ],
  controllers: [AppController],
  providers: [AppService, { provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}

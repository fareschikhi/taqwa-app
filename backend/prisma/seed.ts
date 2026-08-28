import {
  PrismaClient,
  Role,
  Memorization,
  AttendanceStatus,
  JustificationReasonType,
} from '@prisma/client';
import * as bcrypt from 'bcrypt'; // swap to bcryptjs if that's what you're using elsewhere

const prisma = new PrismaClient();

const PASSWORD_HASH = bcrypt.hashSync('123456', 10);

async function main() {
  //   console.log('Cleaning database...');
  //   await prisma.absenceJustification.deleteMany();
  //   await prisma.notification.deleteMany();
  //   await prisma.studentNote.deleteMany();
  //   await prisma.evaluation.deleteMany();
  //   await prisma.memorizationProgress.deleteMany();
  //   await prisma.attendance.deleteMany();
  //   await prisma.managerHalaqa.deleteMany();
  //   await prisma.student.deleteMany();
  //   await prisma.halaqa.deleteMany();
  //   await prisma.teacher.deleteMany();
  //   await prisma.parent.deleteMany();
  //   await prisma.manager.deleteMany();
  //   await prisma.user.deleteMany();

  // ── Admin ────────────────────────────────────────────────────────
  await prisma.user.create({
    data: {
      fullName: 'Mohamed Bensalah',
      phone: '0000',
      passwordHash: PASSWORD_HASH,
      role: Role.ADMIN,
    },
  });

  // ── Managers ─────────────────────────────────────────────────────
  const managerSeed = [
    { fullName: 'Abdelkader Meziane', phone: '1001' },
    { fullName: 'Khaled Rahmani', phone: '1002' },
  ];

  const managers = [];
  for (const data of managerSeed) {
    const user = await prisma.user.create({
      data: { ...data, passwordHash: PASSWORD_HASH, role: Role.MANAGER },
    });
    managers.push(await prisma.manager.create({ data: { userId: user.id } }));
  }

  // ── Teachers ─────────────────────────────────────────────────────
  const teacherSeed = [
    { fullName: 'Ahmed Boudiaf', phone: '2001' },
    { fullName: 'Yacine Cherif', phone: '2002' },
    { fullName: 'Islam Guerfi', phone: '2003' },
  ];

  const teachers = [];
  for (const data of teacherSeed) {
    const user = await prisma.user.create({
      data: { ...data, passwordHash: PASSWORD_HASH, role: Role.TEACHER },
    });
    teachers.push(await prisma.teacher.create({ data: { userId: user.id } }));
  }

  // ── Halaqas ──────────────────────────────────────────────────────
  const halaqaSeed = [
    { name: 'حلقة الفرقان', level: 'مبتدئ', teacherId: teachers[0].id },
    { name: 'حلقة النور', level: 'متوسط', teacherId: teachers[1].id },
    { name: 'حلقة الهدى', level: 'متقدم', teacherId: teachers[2].id },
  ];

  const halaqas = [];
  for (const data of halaqaSeed) {
    halaqas.push(await prisma.halaqa.create({ data }));
  }

  await prisma.managerHalaqa.createMany({
    data: [
      { managerId: managers[0].id, halaqaId: halaqas[0].id },
      { managerId: managers[0].id, halaqaId: halaqas[1].id },
      { managerId: managers[1].id, halaqaId: halaqas[2].id },
    ],
  });

  // ── Parents ──────────────────────────────────────────────────────
  const parentSeed = [
    { fullName: 'Nassim Belkacem', phone: '3001' },
    { fullName: 'Sofiane Zerrouki', phone: '3002' },
    { fullName: 'Ali Belaid', phone: '3003' },
    { fullName: 'Samir Amrani', phone: '3004' },
    { fullName: 'Walid Saidi', phone: '3005' },
  ];

  const parents = [];
  for (const data of parentSeed) {
    const user = await prisma.user.create({
      data: { ...data, passwordHash: PASSWORD_HASH, role: Role.PARENT },
    });
    parents.push(
      await prisma.parent.create({
        data: { userId: user.id, address: 'الجزائر العاصمة' },
      }),
    );
  }

  // ── Students ─────────────────────────────────────────────────────
  const studentSeed = [
    {
      fullName: 'Riad Haddad',
      phone: '4001',
      halaqaId: halaqas[0].id,
      parentId: parents[0].id,
    },
    {
      fullName: 'Djamel Kaddour',
      phone: '4002',
      halaqaId: halaqas[0].id,
      parentId: parents[0].id,
    },
    {
      fullName: 'Karim Boudaoud',
      phone: '4003',
      halaqaId: halaqas[0].id,
      parentId: parents[1].id,
    },
    {
      fullName: 'Adel Rezki',
      phone: '4004',
      halaqaId: halaqas[1].id,
      parentId: parents[1].id,
    },
    {
      fullName: 'Amine Bouzid',
      phone: '4005',
      halaqaId: halaqas[1].id,
      parentId: parents[2].id,
    },
    {
      fullName: 'Samir Bouazza',
      phone: '4006',
      halaqaId: halaqas[1].id,
      parentId: parents[2].id,
    },
    {
      fullName: 'Halim Ould Kablia',
      phone: '4007',
      halaqaId: halaqas[2].id,
      parentId: parents[3].id,
    },
    {
      fullName: 'Bilal Cherguini',
      phone: '4008',
      halaqaId: halaqas[2].id,
      parentId: parents[4].id,
    },
  ];

  const students = [];
  for (const { halaqaId, parentId, ...userData } of studentSeed) {
    const user = await prisma.user.create({
      // Students hold no password: they are records, not accounts.
      data: { ...userData, passwordHash: null, role: Role.STUDENT },
    });
    students.push(
      await prisma.student.create({
        data: {
          userId: user.id,
          address: 'الجزائر العاصمة',
          halaqaId,
          parentId,
          finishedMemo: false,
        },
      }),
    );
  }

  // ── Attendance (last 5 days per student) ────────────────────────
  const statusCycle = [
    AttendanceStatus.PRESENT,
    AttendanceStatus.PRESENT,
    AttendanceStatus.PRESENT,
    AttendanceStatus.LATE,
    AttendanceStatus.ABSENT,
  ];

  const attendanceRecords = [];
  for (const student of students) {
    for (let i = 0; i < 5; i++) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      attendanceRecords.push(
        await prisma.attendance.create({
          data: { studentId: student.id, date, status: statusCycle[i] },
        }),
      );
    }
  }

  // ── One absence justification, tied to an actual ABSENT record ───
  const absentRecord = attendanceRecords.find(
    (a) => a.status === AttendanceStatus.ABSENT,
  );
  if (absentRecord) {
    await prisma.absenceJustification.create({
      data: {
        studentId: absentRecord.studentId,
        attendanceId: absentRecord.id,
        managerId: managers[0].id,
        reasonType: JustificationReasonType.ILLNESS,
        notes: 'شهادة طبية مقدمة من ولي الأمر',
      },
    });
  }

  // ── Memorization progress ────────────────────────────────────────
  // amountDone carries pages for MEMORIZING and hizbs for either revision,
  // so each entry states its own amount rather than sharing one counter.
  const memorizationCycle = [
    { type: Memorization.MEMORIZING, amountDone: 2 }, // 2 pages
    { type: Memorization.SMALLREVISION, amountDone: 3 }, // 3 hizbs
    { type: Memorization.BIGREVISION, amountDone: 8 }, // 8 hizbs
  ];

  const date = new Date();

  for (const student of students) {
    for (const [i, entry] of memorizationCycle.entries()) {
      await prisma.memorizationProgress.create({
        data: {
          studentId: student.id,
          surahNumber: 78 + i,
          amountDone: entry.amountDone,
          date,
          memorizationType: entry.type,
        },
      });
    }
  }

  // ── Evaluations ───────────────────────────────────────────────────
  for (const [i, student] of students.entries()) {
    await prisma.evaluation.create({
      data: {
        studentId: student.id,
        teacherId: teachers[i % teachers.length].id,
        memorizationScore: 15 + (i % 5),
        tajweedScore: 14 + (i % 5),
        fluencyScore: 16 + (i % 4),
        disciplineScore: 18,
        overallScore: 15.5,
        notes: 'أداء جيد، يحتاج إلى مزيد من التركيز على التجويد',
      },
    });
  }

  // ── Student notes (a subset of students) ─────────────────────────
  for (const [i, student] of students.slice(0, 4).entries()) {
    await prisma.studentNote.create({
      data: {
        studentId: student.id,
        teacherId: teachers[i % teachers.length].id,
        note: 'الطالب ملتزم ومجتهد، يحتاج إلى تشجيع أكثر في المراجعة',
      },
    });
  }

  // ── Notifications (one welcome notif per user) ───────────────────
  const allUsers = await prisma.user.findMany();
  await prisma.notification.createMany({
    data: allUsers.map((user) => ({
      userId: user.id,
      title: 'مرحباً بك في تقوى',
      body: 'تم تفعيل حسابك بنجاح، يمكنك الآن متابعة التقدم.',
    })),
  });

  console.log(
    '✅ Seed completed. Login with any phone below + password 123456:',
  );
  console.log('  Admin:    0000');
  console.log('  Managers: 1001, 1002');
  console.log('  Teachers: 2001, 2002, 2003');
  console.log('  Parents:  3001–3005');
  console.log('  Students: 4001–4008');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

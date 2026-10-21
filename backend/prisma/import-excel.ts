import { PrismaClient, Prisma, Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { randomInt } from 'crypto';
import * as fs from 'fs';
import * as path from 'path';
import * as ExcelJS from 'exceljs';
import * as JSZip from 'jszip';

// Imports the parents and students sheets (filled from parents_template.xlsx
// and students_template.xlsx) into the database.
//
//   npx ts-node prisma/import-excel.ts <parents.xlsx> <students.xlsx> [--commit]
//
// Without --commit it is a dry run: every row is written inside a transaction
// that is then rolled back, so the report reflects the real constraints but
// nothing is kept. The report names sheet rows and reasons only — never a
// value from the sheets — so it is safe to paste or share.
//
// On --commit, parents and adult students get a random temporary password
// (they must change it on first login). Those are written to an
// import_passwords_<time>.xlsx next to the students file and nowhere else.

const prisma = new PrismaClient();

const TEMPLATE_DIR = path.resolve(__dirname, '..', '..');
const ROLLBACK = Symbol('dry-run rollback');

type Row = { n: number; get: (key: string) => string; date: (key: string) => Date | null | 'invalid' };

const PARENT_COLUMNS: Record<string, string> = {
  'اسم و لقب ولي الأمر': 'fullName',
  'رقم الهاتف': 'phone',
  'اسم ولقب الابن': 'childName',
  'البريد الإلكتروني': 'email',
  'العنوان': 'address',
};

const STUDENT_COLUMNS: Record<string, string> = {
  'اسم و لقب الطالب': 'fullName',
  'تاريخ الميلاد': 'birthDate',
  'العنوان': 'address',
  'رقم الهاتف': 'phone',
  'طالب بالغ؟': 'isAdult',
  'البريد الإلكتروني': 'email',
  'الحلقة القرآنية': 'halaqa',
  'اسم ولي الأمر': 'parentName',
  'هاتف ولي الأمر': 'parentPhone',
  // يتابع الحديث؟ is deliberately not imported: tracking needs hadith books,
  // which the sheet does not carry. Assign them from the app.
  'الصف / المستوى الدراسي': 'schoolLevel',
  'الحالة الصحية': 'healthStatus',
  'الحالة الاجتماعية للأسرة': 'familyStatus',
  'مهنة الأب': 'fatherJob',
  'مهنة الأم': 'motherJob',
  'المهنة': 'occupation',
  'الحالة الاجتماعية': 'isMarried',
  'توقيت النشاطات الخارجية': 'externalActivities',
};

// ── Reporting (row numbers and reasons only) ─────────────────────────────────

const issues: string[] = [];
const note = (sheet: string, n: number, reason: string) => issues.push(`${sheet} row ${n}: ${reason}`);

// ── Cell normalisation ───────────────────────────────────────────────────────

const clean = (s: string) => s.replace(/\s+/g, ' ').trim();

/// Algerian numbers as typed or as Excel stored them: a numeric cell drops the
/// leading 0, and some people type +213. Anything that still isn't 10 digits
/// is rejected rather than guessed at.
function normalizePhone(raw: string): string | null | 'invalid' {
  let d = raw.replace(/[^\d+]/g, '');
  if (!d) return null;
  if (d.startsWith('+213')) d = '0' + d.slice(4);
  else if (d.startsWith('00213')) d = '0' + d.slice(5);
  else if (d.startsWith('213') && d.length === 12) d = '0' + d.slice(3);
  if (/^[5-7]\d{8}$/.test(d)) d = '0' + d;
  return /^0\d{9}$/.test(d) ? d : 'invalid';
}

function normalizeEmail(raw: string): string | null | 'invalid' {
  const e = raw.trim().toLowerCase();
  if (!e) return null;
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e) ? e : 'invalid';
}

const yesNo = (raw: string): boolean | undefined =>
  raw === 'نعم' ? true : raw === 'لا' ? false : undefined;

const married = (raw: string): boolean | undefined =>
  raw === 'متزوج' ? true : raw === 'أعزب' ? false : undefined;

/// Compares names the way people mistype them: spacing, the حلقة prefix,
/// hamza/alef and taa-marbuta variants.
const nameKey = (s: string) =>
  clean(s)
    .replace(/^حلقة\s*/, '')
    .replace(/[أإآ]/g, 'ا')
    .replace(/ة/g, 'ه')
    .replace(/ى/g, 'ي')
    .replace(/ـ/g, '')
    .toLowerCase();

/// Plain text of any cell shape ExcelJS hands back: rich text, hyperlinks,
/// formulas (their cached result) and error cells, which `cell.text` does not
/// always survive.
function valueText(v: any): string {
  if (v === null || v === undefined) return '';
  if (typeof v === 'string') return v;
  if (typeof v === 'number' || typeof v === 'boolean') return String(v);
  if (v instanceof Date) return isNaN(v.getTime()) ? '' : v.toISOString();
  if (Array.isArray(v.richText)) return v.richText.map((t: any) => t?.text ?? '').join('');
  if ('text' in v) return valueText(v.text);
  if ('result' in v) return valueText(v.result);
  return '';
}

function cellText(cell: ExcelJS.Cell): string {
  return clean(valueText(cell.value));
}

/// A formula cell's cached result, or the cell's own value.
const cellValue = (cell: ExcelJS.Cell): any => {
  const v = cell.value as any;
  return v && typeof v === 'object' && !(v instanceof Date) && 'result' in v ? v.result : v;
};

/// Loads a workbook with its cell comments (notes) unlinked, in memory only.
/// ExcelJS resolves comment parts by one fixed path and crashes on files whose
/// comments live elsewhere (newer Excel, Google Sheets, WPS); the import never
/// needs them.
async function loadWorkbook(file: string) {
  const zip = await JSZip.loadAsync(fs.readFileSync(file));
  for (const name of Object.keys(zip.files)) {
    if (/^xl\/worksheets\/_rels\/[^/]+\.rels$/.test(name)) {
      const xml = await zip.file(name)!.async('string');
      zip.file(name, xml.replace(/<Relationship\b[^>]*Type="[^"]*\/(comments|vmlDrawing|threadedComment)"[^>]*\/>/g, ''));
    } else if (/^xl\/worksheets\/[^/]+\.xml$/.test(name)) {
      const xml = await zip.file(name)!.async('string');
      zip.file(name, xml.replace(/<legacyDrawing\b[^>]*\/>/g, ''));
    }
  }
  const wb = new ExcelJS.Workbook();
  await wb.xlsx.load((await zip.generateAsync({ type: 'nodebuffer' })) as any);
  return wb;
}

async function readSheet(file: string, sheetName: string, columns: Record<string, string>, sheet: string) {
  const wb = await loadWorkbook(file);
  const ws = wb.getWorksheet(sheetName) ?? wb.worksheets[0];

  const index: Record<string, number> = {};
  ws.getRow(1).eachCell((cell, col) => {
    const header = cellText(cell).replace(/\s*\*$/, '');
    if (columns[header]) index[columns[header]] = col;
  });
  const missing = Object.entries(columns).filter(([, key]) => !index[key]).map(([h]) => h);
  if (missing.length) throw new UsageError(`${sheet}: missing columns ${missing.join(', ')}`);

  const rows: Row[] = [];
  ws.eachRow((row, n) => {
    if (n === 1) return;
    const get = (key: string) => cellText(row.getCell(index[key]));
    const date = (key: string) => {
      const cell = row.getCell(index[key]);
      const v = cellValue(cell);
      if (v === null || v === undefined || v === '') return null;
      if (v instanceof Date) return isNaN(v.getTime()) ? 'invalid' : v;
      const m = cellText(cell).match(/^(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{4})$/);
      if (!m) return 'invalid';
      const d = new Date(Date.UTC(+m[3], +m[2] - 1, +m[1]));
      return d.getUTCDate() === +m[1] ? d : 'invalid';
    };
    const signature = Object.values(index).map((c) => cellText(row.getCell(c))).join('\u0001');
    if (signature.replace(/\u0001/g, '')) rows.push(Object.assign({ n, get, date }, { signature }));
  });
  return rows as (Row & { signature: string })[];
}

/// The templates ship one example row; a sheet filled from them may still
/// carry it, and it must not become a real account.
async function sampleSignature(template: string, sheetName: string, columns: Record<string, string>) {
  try {
    const rows = await readSheet(template, sheetName, columns, 'template');
    return rows[0]?.signature ?? null;
  } catch {
    return null;
  }
}

const ALPHABET = 'abcdefghjkmnpqrstuvwxyz23456789';
const tempPassword = () => Array.from({ length: 8 }, () => ALPHABET[randomInt(ALPHABET.length)]).join('');

class UsageError extends Error {}

// ── Import ───────────────────────────────────────────────────────────────────

async function main() {
  const args = process.argv.slice(2);
  const commit = args.includes('--commit');
  const [parentsFile, studentsFile] = args.filter((a) => !a.startsWith('--'));
  if (!parentsFile || !studentsFile) {
    throw new UsageError('usage: npx ts-node prisma/import-excel.ts <parents.xlsx> <students.xlsx> [--commit]');
  }
  for (const f of [parentsFile, studentsFile]) {
    if (!fs.existsSync(f)) throw new UsageError(`file not found: ${f}`);
  }

  const parentSample = await sampleSignature(path.join(TEMPLATE_DIR, 'parents_template.xlsx'), 'أولياء الأمور', PARENT_COLUMNS);
  const studentSample = await sampleSignature(path.join(TEMPLATE_DIR, 'students_template.xlsx'), 'الطلاب', STUDENT_COLUMNS);

  const parentRows = (await readSheet(parentsFile, 'أولياء الأمور', PARENT_COLUMNS, 'parents')).filter((r) => {
    if (r.signature !== parentSample) return true;
    note('parents', r.n, 'template example row, skipped');
    return false;
  });
  const studentRows = (await readSheet(studentsFile, 'الطلاب', STUDENT_COLUMNS, 'students')).filter((r) => {
    if (r.signature !== studentSample) return true;
    note('students', r.n, 'template example row, skipped');
    return false;
  });

  const halaqas = await prisma.halaqa.findMany({ select: { id: true, name: true, isAdult: true } });
  const halaqaByKey = new Map(halaqas.map((h) => [nameKey(h.name), h]));

  // Hashing is the slow part, so it happens before the transaction opens and
  // only for real runs; a dry run's rows are rolled back anyway.
  const placeholder = commit ? null : await bcrypt.hash('dry-run', 4);
  const credentials: { role: string; fullName: string; phone: string; email: string; password: string }[] = [];
  const issue = async (role: string, fullName: string, phone?: string, email?: string) => {
    if (!commit) return placeholder!;
    const password = tempPassword();
    credentials.push({ role, fullName, phone: phone ?? '', email: email ?? '', password });
    return bcrypt.hash(password, 10);
  };

  const counts = { parentsCreated: 0, parentsExisting: 0, parentsSkipped: 0, studentsCreated: 0, adultsCreated: 0, studentsSkipped: 0, linked: 0, unlinked: 0, inHalaqa: 0 };

  const run = async (tx: Prisma.TransactionClient) => {
    const takenPhone = async (phone: string) => tx.user.findUnique({ where: { phone }, select: { id: true, role: true, parent: { select: { id: true } } } });
    const takenEmail = async (email: string) => !!(await tx.user.findUnique({ where: { email }, select: { id: true } }));

    // parent id by phone and by name, for linking the students sheet
    const parentByPhone = new Map<string, number>();
    const parentsByName = new Map<string, Set<number>>();
    const parentsByChild = new Map<string, Set<number>>();
    const addTo = (m: Map<string, Set<number>>, k: string, id: number) => {
      if (!k) return;
      if (!m.has(k)) m.set(k, new Set());
      m.get(k)!.add(id);
    };

    for (const p of await tx.parent.findMany({ select: { id: true, user: { select: { fullName: true, phone: true } } } })) {
      if (p.user.phone) parentByPhone.set(p.user.phone, p.id);
      addTo(parentsByName, nameKey(p.user.fullName), p.id);
    }

    // ── Parents ──
    const seenPhones = new Set<string>();
    for (const r of parentRows) {
      const fullName = r.get('fullName');
      const phone = normalizePhone(r.get('phone'));
      if (!fullName) { note('parents', r.n, 'missing name, skipped'); counts.parentsSkipped++; continue; }
      if (!phone || phone === 'invalid') { note('parents', r.n, `${phone ? 'invalid' : 'missing'} phone, skipped`); counts.parentsSkipped++; continue; }
      if (seenPhones.has(phone)) { note('parents', r.n, 'same phone as an earlier row, skipped'); counts.parentsSkipped++; continue; }
      seenPhones.add(phone);

      const existing = await takenPhone(phone);
      if (existing) {
        if (existing.parent) {
          note('parents', r.n, 'parent with this phone already in the database, kept as is');
          counts.parentsExisting++;
          addTo(parentsByChild, nameKey(r.get('childName')), existing.parent.id);
        } else {
          note('parents', r.n, `phone belongs to an existing ${existing.role} account, skipped`);
          counts.parentsSkipped++;
        }
        continue;
      }

      let email = normalizeEmail(r.get('email'));
      if (email === 'invalid') { note('parents', r.n, 'invalid email, imported without it'); email = null; }
      if (email && (await takenEmail(email))) { note('parents', r.n, 'email already used, imported without it'); email = null; }

      const user = await tx.user.create({
        data: {
          fullName,
          phone,
          email: email ?? undefined,
          passwordHash: await issue('PARENT', fullName, phone, email ?? undefined),
          mustChangePassword: true,
          role: Role.PARENT,
          parent: { create: { address: r.get('address') || undefined } },
        },
        select: { parent: { select: { id: true } } },
      });
      const parentId = user.parent!.id;
      parentByPhone.set(phone, parentId);
      addTo(parentsByName, nameKey(fullName), parentId);
      addTo(parentsByChild, nameKey(r.get('childName')), parentId);
      counts.parentsCreated++;
    }

    // ── Students ──
    const unique = (s?: Set<number>) => (s && s.size === 1 ? [...s][0] : undefined);
    for (const r of studentRows) {
      const fullName = r.get('fullName');
      const address = r.get('address');
      if (!fullName) { note('students', r.n, 'missing name, skipped'); counts.studentsSkipped++; continue; }

      const isAdultRaw = r.get('isAdult');
      const isAdult = yesNo(isAdultRaw) ?? false;
      if (isAdultRaw && yesNo(isAdultRaw) === undefined) note('students', r.n, 'adult column is not نعم/لا, treated as child');

      let birthDate = r.date('birthDate');
      if (birthDate === 'invalid') { note('students', r.n, 'unreadable birth date, imported without it'); birthDate = null; }
      else if (!birthDate) note('students', r.n, 'missing birth date, imported without it');

      // Re-running the import must not duplicate students already in.
      const dup = await tx.student.findFirst({
        where: { user: { fullName }, ...(birthDate ? { birthDate } : {}) },
        select: { id: true },
      });
      if (dup) { note('students', r.n, 'same name and birth date already in the database, skipped'); counts.studentsSkipped++; continue; }

      let phone = normalizePhone(r.get('phone'));
      if (phone === 'invalid') { note('students', r.n, 'invalid phone, imported without it'); phone = null; }
      if (phone && (await takenPhone(phone))) {
        // Commonly the parent's number typed in the child's column.
        note('students', r.n, 'phone already used by another account, imported without it');
        phone = null;
      }
      let email = normalizeEmail(r.get('email'));
      if (email === 'invalid') { note('students', r.n, 'invalid email, imported without it'); email = null; }
      if (email && (await takenEmail(email))) { note('students', r.n, 'email already used, imported without it'); email = null; }
      if (isAdult && !phone && !email) note('students', r.n, 'adult with no phone or email: account created but cannot sign in yet');

      let halaqaId: number | undefined;
      const halaqaRaw = r.get('halaqa');
      if (halaqaRaw) {
        const h = halaqaByKey.get(nameKey(halaqaRaw));
        if (!h) note('students', r.n, 'halaqa name not found, imported without a halaqa');
        else if (h.isAdult !== isAdult) note('students', r.n, `halaqa is for ${h.isAdult ? 'adults' : 'children'}, imported without a halaqa`);
        else { halaqaId = h.id; counts.inHalaqa++; }
      }

      let parentId: number | undefined;
      if (!isAdult) {
        const pPhone = normalizePhone(r.get('parentPhone'));
        if (pPhone && pPhone !== 'invalid') parentId = parentByPhone.get(pPhone);
        parentId ??= unique(parentsByName.get(nameKey(r.get('parentName'))));
        parentId ??= unique(parentsByChild.get(nameKey(fullName)));
        if (parentId) counts.linked++;
        else { counts.unlinked++; note('students', r.n, 'no matching parent found, imported without one'); }
      }

      const text = (key: string, max: number) => {
        const v = r.get(key);
        if (v.length > max) note('students', r.n, `${key} longer than ${max} characters, cut`);
        return v ? v.slice(0, max) : undefined;
      };

      await tx.user.create({
        data: {
          fullName,
          phone: phone ?? undefined,
          email: email ?? undefined,
          // Same rule as StudentsService.create: a child is a record, not an
          // account; an adult is his own guardian and signs in.
          passwordHash: isAdult ? await issue('ADULT_STUDENT', fullName, phone ?? undefined, email ?? undefined) : null,
          mustChangePassword: isAdult,
          role: isAdult ? Role.ADULT_STUDENT : Role.STUDENT,
          student: {
            create: {
              birthDate: birthDate ?? undefined,
              address: address ? address.slice(0, 191) : undefined,
              parentId,
              halaqaId,
              schoolLevel: text('schoolLevel', 100),
              healthStatus: text('healthStatus', 255),
              familyStatus: text('familyStatus', 255),
              fatherJob: text('fatherJob', 100),
              motherJob: text('motherJob', 100),
              occupation: text('occupation', 100),
              externalActivities: text('externalActivities', 255),
              isMarried: married(r.get('isMarried')),
            },
          },
        },
      });
      if (isAdult) counts.adultsCreated++;
      else counts.studentsCreated++;
    }

    if (!commit) throw ROLLBACK;
  };

  try {
    await prisma.$transaction(run, { maxWait: 10_000, timeout: 600_000 });
  } catch (e) {
    if (e !== ROLLBACK) throw e;
  }

  console.log(commit ? '\nCOMMITTED — rows saved.' : '\nDRY RUN — everything rolled back, nothing saved.');
  console.log(`parents:  ${counts.parentsCreated} created, ${counts.parentsExisting} already existed, ${counts.parentsSkipped} skipped`);
  console.log(`students: ${counts.studentsCreated} children + ${counts.adultsCreated} adults created, ${counts.studentsSkipped} skipped`);
  console.log(`          ${counts.linked} linked to a parent, ${counts.unlinked} without a parent, ${counts.inHalaqa} placed in a halaqa`);
  console.log(`\n${issues.length} note(s):`);
  for (const i of issues) console.log('  ' + i);

  if (commit && credentials.length) {
    const out = path.join(path.dirname(path.resolve(studentsFile)), `import_passwords_${new Date().toISOString().replace(/[:.]/g, '-')}.xlsx`);
    const wb = new ExcelJS.Workbook();
    const ws = wb.addWorksheet('كلمات المرور');
    ws.views = [{ rightToLeft: true }];
    ws.columns = [
      { header: 'النوع', key: 'role', width: 16 },
      { header: 'الاسم', key: 'fullName', width: 30 },
      { header: 'الهاتف', key: 'phone', width: 16 },
      { header: 'البريد', key: 'email', width: 28 },
      { header: 'كلمة المرور المؤقتة', key: 'password', width: 20 },
    ];
    ws.addRows(credentials.map((c) => ({ ...c, role: c.role === 'PARENT' ? 'ولي أمر' : 'طالب بالغ' })));
    await wb.xlsx.writeFile(out);
    console.log(`\n${credentials.length} temporary password(s) written to:\n  ${out}\nHand them out, then delete the file.`);
  }
}

main()
  .catch((e) => {
    // Prisma and Excel errors can quote the offending value; print only what
    // identifies the failure so a crash cannot leak a row.
    if (e instanceof UsageError) console.error(e.message);
    else {
      console.error(`import failed (${e?.code ?? e?.name ?? 'error'}); nothing was saved.${e?.meta?.target ? ' field: ' + e.meta.target : ''}`);
      // Stack frames are code locations only — the message line is dropped.
      const frames = String(e?.stack ?? '').split('\n').filter((l) => /^\s+at /.test(l)).slice(0, 6);
      if (frames.length) console.error(frames.join('\n'));
    }
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());

# Stitch prompt pack: Parent pages (brand #009000)

How to use:

1. Open stitch.withgoogle.com, create a new project, choose **App** (mobile), and pick the strongest model offered.
2. If the Theme panel is available, set: custom color `#009000`, font Cairo, large corner radius, light mode.
3. Paste **Prompt 1** and get the Home screen right first: it sets the design system for every later screen.
4. Change one thing per follow-up edit, for example "make the hero card 20% shorter". Several changes in one edit tend to get some of them dropped.
5. Paste Prompts 2 to 7 **in the same project**, one at a time.
6. Export each screen's HTML plus the project's DESIGN.md into `design/parent/`.

Data in the prompts is fake sample data. The labels are the app's real Arabic strings, so the export maps 1:1 to the Flutter code.

---

## Prompt 1: Design system + Parent Home (الرئيسية)

```
Design a modern, calm mobile app screen for "التقوى" (Taqwa), a Quran school app. This screen is the PARENT HOME: a parent follows their child's Quran memorization, attendance and teacher notes.
Arabic only, fully RTL: text right-aligned, "start" = right edge, back arrows point right, the first bottom-nav tab is on the far right. Phone width 390px. Light theme only.

DESIGN SYSTEM (apply to every screen in this project)
Colors
- Primary (brand) #009000: hero card, active nav tab, filled buttons, progress, key icons, big numbers.
- Primary-dark #006B00: green text and links on white, pressed states, and ANY white text smaller than 18px that sits on green (white on #009000 is only 4.2:1).
- Primary-soft #E6F4E6 with text #005A00: selected chips, soft badges, unread items, active nav pill.
- Secondary #0E7C66 (teal-green) and tertiary #66751A (olive): ONLY to tell the three memorization types apart.
- Background #F5F8F5. Cards #FFFFFF, 1px border #E3EAE3, soft shadow 0 4px 16px rgba(0,40,0,0.06).
- Text #152015 (primary), #5A6A5A (secondary). No gray lighter than #5A6A5A for real data.
- Attendance status pills (12% tinted background + solid text + icon): present #009000 (check), late #B26A00 (schedule), excused #1F6FB2 (event_busy), absent #C62828 (close).
- One accent only: gold #C9A227, used just for the "student of the month" achievement.
Typography
- Cairo for headings and numbers, Tajawal for labels. Scale: 26 bold page title, 20 semibold section title, 16 body, 14 label, 12 minimum (never smaller). Generous Arabic line height.
Shape and spacing
- Cards 20px radius, buttons 14px, chips fully rounded. 16px screen padding, 8pt grid, 24px between sections. Touch targets at least 44px.
Icons
- Material Symbols Rounded, outlined; filled only on the active tab.
Style
- Clean, airy, premium, trustworthy. Flat surfaces with soft depth.
- NO glassmorphism, neon, rainbow gradients, mosque/lantern clip-art or emojis.
- One subtle gradient allowed, on hero cards only: #009000 to #006B00, optionally with a faint geometric 8-point-star pattern at 6% opacity.

SCREEN CONTENT (top to bottom; keep exactly these sections and Arabic labels)
1. Child switcher (only when the parent has several children): horizontal row of pill chips, each with a small round avatar + name ("يوسف", "مريم"). Selected chip: primary-soft fill + green border.
2. Header: greeting "أهلاً، أحمد" (26 bold) and subtitle "تابع تقدم أبنائك في حفظ القرآن الكريم.". On the left, a round icon button with a chat-bubble icon and a small red unread dot (accessible label "محادثة الإدارة").
3. Hero child card (green gradient): 56px avatar, child name "يوسف بن سالم", halaqa "حلقة الفرقان"; a "عرض التفاصيل" link with an arrow on the left. Below, three tappable stats in one row with thin dividers: "12" / "أيام الحضور هذا الشهر", "48 صفحة" / "حفظ", "ممتاز" / "التقييم العام" (the rating is free text and may be 2 words).
4. Student-of-the-month card (conditional): gold accent, trophy icon, title "طالب شهر نوفمبر", line "مبارك! اجتهاد ابنكم هذا الشهر جعله الأول في حلقته.".
5. Section "آخر حضور": one card with the date, a status pill "حاضر", and what was recited that day: "حفظ جديد · سورة الملك · 2 صفحة".
6. Section "أخبار الحلقة" with a "عرض الكل" link: card with 2 news items (date · title, one-line preview).
7. Section "ملاحظات المعلم" with "عرض الكل": vertical timeline of 3 notes (date + note text).
8. Card "وردك اليومي": icon, text "فعّله ليصلك إشعار يومي بوردك من القرآن", a switch, and "وقت التذكير 8:00 م" with a "تغيير" text button.
9. Bottom navigation, 5 tabs from right to left: "الرئيسية" (home, ACTIVE), "المقرأة" (menu_book), "الحضور" (emoji_events), "ملاحظات" (notifications, red badge "3"), "الحساب" (person). White bar, rounded top corners; active tab = primary-soft pill behind icon + bold label in #005A00.

Realistic Arabic sample data, Western digits (0-9). It should feel like a polished 2026 app a parent trusts at first glance.
```

---

## Prompt 2: المقرأة (Quran progress tab)

```
Same app, same design system as the Home screen. Create the "المقرأة" tab: the selected child's Quran memorization progress. Same bottom navigation with "المقرأة" active. RTL, Arabic only.

1. Header: title "تقدم المدرسة القرآنية", subtitle "تتبع رحلة يوسف في حفظ القرآن الكريم.", round chat icon button on the left (same as Home).
2. Summary hero card (green gradient): big number "48" + "صفحة منجزة", line "12 سورة تم تناولها", a large circular book icon on the left. Add a thin progress bar "48 / 604 صفحة" (604 = pages in the whole Quran).
3. Section "القرآن الكريم": three stat tiles in a row: "حفظ جديد" 18 (primary), "جمع" 9 (secondary teal), "مراجعة وضبط" 6 (tertiary olive). White tiles, colored number, small colored dot.
4. Section "الحديث الشريف": the same three tiles with smaller numbers (this section only appears when the halaqa tracks hadith).
5. Section "سجل الحفظ والمراجعة" with a small caption on the left "آخر 10 إدخالات". One card holding a list with dividers. Each row: surah name bold ("سورة الملك"), date "05/11", an amount pill "2 صفحة", and on the left a type pill colored by type ("حفظ جديد" / "جمع" / "مراجعة وضبط"). Include one hadith row ("الأربعون النووية · الحديث 12").
```

---

## Prompt 3: الحضور (attendance tab)

```
Same app, same design system. Create the "الحضور" tab: the selected child's attendance. Bottom navigation with "الحضور" active. RTL, Arabic only.

1. Header: title "سجل الحضور التفصيلي", subtitle "سجلات حضور يوسف وغيابه.", chat icon button on the left.
2. Section "إحصائيات هذا الشهر": two tiles side by side, "أيام الحضور" 12 (green) and "أيام الغياب" 2 (red); below them a full-width tile "أيام حضور متتالية" 5 with a streak/flame icon. Small caption: "أيام التأخر تُحتسب ضمن الحضور.".
3. A compact month calendar strip for the current month: each school day is a small dot colored by status (present/late/excused/absent), days with no session stay empty. Small legend under it.
4. Section "السجل الزمني": list of the last month. Each row is a white card: status icon in a tinted circle, colored status label ("حاضر" / "متأخر" / "عذر" / "غائب"), and the date "05/11/2026" with the weekday ("الأربعاء"). Show at least one of each status.
5. A text button with a history icon: "عرض السجل الأقدم (14)". When expanded it reads "إخفاء السجل الأقدم".
```

---

## Prompt 4: ملاحظات (notifications tab)

```
Same app, same design system. Create the "ملاحظات" tab: notifications about the selected child. Bottom navigation with "ملاحظات" active. RTL, Arabic only.

1. Header: title "ملاحظات" and the chat icon button on the left.
2. Two groups: "جديدة" (unread) and "سابقة" (read).
3. Notification card: icon in a tinted circle (attendance, memorization, news, or general), bold title, 2-line body, small relative time on the left ("منذ ساعتين", "أمس"). Unread cards: primary-soft background + small green dot. Read cards: white.
4. Also generate a second version of this screen in its EMPTY state: a simple outlined bell icon in a soft green circle, "لا توجد ملاحظات", and one line explaining new notes from the teacher will appear here. No cartoon illustration.
```

---

## Prompt 5: الحساب (account tab)

```
Same app, same design system. Create the "الحساب" tab (parent account). Bottom navigation with "الحساب" active. RTL, Arabic only.

1. Profile header card: 88px round avatar with a small camera edit button, name "أحمد بن علي", role badge "ولي أمر" (primary-soft).
2. Section "البيانات الشخصية": rows "الاسم الكامل" and "البريد الإلكتروني" with values; a "تعديل" text button on the section header. In edit mode the name becomes a labeled input (label "الاسم الكامل", hint "أدخل اسمك الكامل") with a full-width "حفظ التغييرات" button and a "إلغاء" text button.
3. Settings list card: "تغيير كلمة المرور" (lock icon, chevron pointing left).
4. "تسجيل الخروج" as a separate row in red (#C62828) with a logout icon, set apart from the other actions.
5. Also show the avatar bottom sheet: "التقاط صورة بالكاميرا", "اختيار من المعرض", "إلغاء".
```

---

## Prompt 6: ملف الطالب (child details, pushed page)

```
Same app, same design system. Create "ملف الطالب", a detail page opened from the Home hero card. No bottom navigation. RTL: back arrow on the RIGHT, pointing right.

1. Top bar: back arrow + title "ملف الطالب".
2. Header: 80px avatar, name "يوسف بن سالم", halaqa "حلقة الفرقان".
3. 2x2 info grid of small cards, each with an icon: "المعلم" "الأستاذ محمد" (person), "الحلقة" "حلقة الفرقان" (menu_book), "تاريخ الالتحاق" "15/09/2025" (calendar), "المستوى" "المستوى الثاني" (trending_up).
4. Card "تقدم الحفظ": subheading "القرآن الكريم" with three rows, each a label + count + horizontal bar in its type color: "حفظ" 18, "جمع" 9, "مراجعة وضبط" 6. Then subheading "الحديث الشريف" with the same three rows.
5. Card "النقاط": big number "320" with a star icon, tappable (chevron) to open the points history.
6. Card "برنامج الحديث": hadiths memorized "14 حديثاً" and pages "6 صفحات".
```

---

## Prompt 7: ملاحظات المعلم (full notes list) + loading state

```
Same app, same design system. Create two screens.

Screen A, "ملاحظات يوسف" (pushed page, no bottom nav, back arrow on the right): a vertical timeline of 8 teacher notes, newest first. Each note: date, note text (some long, 3-4 lines), timeline dot in primary. Pull-to-refresh feel. Also show its error state as a small variant: "تعذر تحميل الملاحظات، اسحب للأسفل لإعادة المحاولة".

Screen B: the Parent Home screen in its LOADING state: same layout, with soft skeleton blocks (#E9EFE9, rounded, gentle shimmer) where the stats, last attendance, news and notes go. The greeting and child name stay visible because they are already known.
```

---

## After Stitch

- Put the exports in `design/parent/` (one HTML per screen + DESIGN.md).
- The old teal `design/DESIGN.md` is the previous system. Keep it for reference or delete it once the green one is approved.
- Implementation order: theme tokens first (`taqwa/lib/core/theme/app_colors.dart`), then the shell and bottom nav, then one page at a time.

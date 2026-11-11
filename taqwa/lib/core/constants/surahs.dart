class Surah {
  final int number;
  final String name;

  /// First and last page in the 604-page Madinah mushaf. Short surahs share a
  /// page with their neighbours, so ranges overlap at the edges.
  final int startPage;
  final int endPage;

  /// Ayahs in the surah (Hafs count, 6,236 in the whole mushaf). Bounds the
  /// teacher's «من آية / إلى آية» picker; the server checks the same numbers.
  final int ayahCount;
  const Surah(
    this.number,
    this.name,
    this.startPage,
    this.endPage,
    this.ayahCount,
  );

  /// Every page the surah appears on, so a surah that shares one page with
  /// others still counts as one page rather than none.
  int get pageCount => endPage - startPage + 1;
}

const List<Surah> kSurahs = [
  Surah(1, 'الفاتحة', 1, 1, 7),
  Surah(2, 'البقرة', 2, 49, 286),
  Surah(3, 'آل عمران', 50, 76, 200),
  Surah(4, 'النساء', 77, 106, 176),
  Surah(5, 'المائدة', 106, 127, 120),
  Surah(6, 'الأنعام', 128, 150, 165),
  Surah(7, 'الأعراف', 151, 176, 206),
  Surah(8, 'الأنفال', 177, 186, 75),
  Surah(9, 'التوبة', 187, 207, 129),
  Surah(10, 'يونس', 208, 221, 109),
  Surah(11, 'هود', 221, 235, 123),
  Surah(12, 'يوسف', 235, 248, 111),
  Surah(13, 'الرعد', 249, 255, 43),
  Surah(14, 'إبراهيم', 255, 261, 52),
  Surah(15, 'الحجر', 262, 267, 99),
  Surah(16, 'النحل', 267, 281, 128),
  Surah(17, 'الإسراء', 282, 293, 111),
  Surah(18, 'الكهف', 293, 304, 110),
  Surah(19, 'مريم', 305, 312, 98),
  Surah(20, 'طه', 312, 321, 135),
  Surah(21, 'الأنبياء', 322, 331, 112),
  Surah(22, 'الحج', 332, 341, 78),
  Surah(23, 'المؤمنون', 342, 349, 118),
  Surah(24, 'النور', 350, 359, 64),
  Surah(25, 'الفرقان', 359, 366, 77),
  Surah(26, 'الشعراء', 367, 376, 227),
  Surah(27, 'النمل', 377, 385, 93),
  Surah(28, 'القصص', 385, 396, 88),
  Surah(29, 'العنكبوت', 396, 404, 69),
  Surah(30, 'الروم', 404, 410, 60),
  Surah(31, 'لقمان', 411, 414, 34),
  Surah(32, 'السجدة', 415, 417, 30),
  Surah(33, 'الأحزاب', 418, 427, 73),
  Surah(34, 'سبأ', 428, 434, 54),
  Surah(35, 'فاطر', 434, 440, 45),
  Surah(36, 'يس', 440, 445, 83),
  Surah(37, 'الصافات', 446, 452, 182),
  Surah(38, 'ص', 453, 458, 88),
  Surah(39, 'الزمر', 458, 467, 75),
  Surah(40, 'غافر', 467, 476, 85),
  Surah(41, 'فصلت', 477, 482, 54),
  Surah(42, 'الشورى', 483, 489, 53),
  Surah(43, 'الزخرف', 489, 495, 89),
  Surah(44, 'الدخان', 496, 498, 59),
  Surah(45, 'الجاثية', 499, 502, 37),
  Surah(46, 'الأحقاف', 502, 506, 35),
  Surah(47, 'محمد', 507, 510, 38),
  Surah(48, 'الفتح', 511, 515, 29),
  Surah(49, 'الحجرات', 515, 517, 18),
  Surah(50, 'ق', 518, 520, 45),
  Surah(51, 'الذاريات', 520, 523, 60),
  Surah(52, 'الطور', 523, 525, 49),
  Surah(53, 'النجم', 526, 528, 62),
  Surah(54, 'القمر', 528, 531, 55),
  Surah(55, 'الرحمن', 531, 534, 78),
  Surah(56, 'الواقعة', 534, 537, 96),
  Surah(57, 'الحديد', 537, 541, 29),
  Surah(58, 'المجادلة', 542, 545, 22),
  Surah(59, 'الحشر', 545, 548, 24),
  Surah(60, 'الممتحنة', 549, 551, 13),
  Surah(61, 'الصف', 551, 552, 14),
  Surah(62, 'الجمعة', 553, 554, 11),
  Surah(63, 'المنافقون', 554, 555, 11),
  Surah(64, 'التغابن', 556, 557, 18),
  Surah(65, 'الطلاق', 558, 559, 12),
  Surah(66, 'التحريم', 560, 561, 12),
  Surah(67, 'الملك', 562, 564, 30),
  Surah(68, 'القلم', 564, 566, 52),
  Surah(69, 'الحاقة', 566, 568, 52),
  Surah(70, 'المعارج', 568, 570, 44),
  Surah(71, 'نوح', 570, 571, 28),
  Surah(72, 'الجن', 572, 573, 28),
  Surah(73, 'المزمل', 574, 575, 20),
  Surah(74, 'المدثر', 575, 577, 56),
  Surah(75, 'القيامة', 577, 578, 40),
  Surah(76, 'الإنسان', 578, 580, 31),
  Surah(77, 'المرسلات', 580, 581, 50),
  Surah(78, 'النبأ', 582, 583, 40),
  Surah(79, 'النازعات', 583, 584, 46),
  Surah(80, 'عبس', 585, 585, 42),
  Surah(81, 'التكوير', 586, 586, 29),
  Surah(82, 'الإنفطار', 587, 587, 19),
  Surah(83, 'المطففين', 587, 589, 36),
  Surah(84, 'الإنشقاق', 589, 589, 25),
  Surah(85, 'البروج', 590, 590, 22),
  Surah(86, 'الطارق', 591, 591, 17),
  Surah(87, 'الأعلى', 591, 592, 19),
  Surah(88, 'الغاشية', 592, 592, 26),
  Surah(89, 'الفجر', 593, 594, 30),
  Surah(90, 'البلد', 594, 594, 20),
  Surah(91, 'الشمس', 595, 595, 15),
  Surah(92, 'الليل', 595, 596, 21),
  Surah(93, 'الضحى', 596, 596, 11),
  Surah(94, 'الشرح', 596, 596, 8),
  Surah(95, 'التين', 597, 597, 8),
  Surah(96, 'العلق', 597, 597, 19),
  Surah(97, 'القدر', 598, 598, 5),
  Surah(98, 'البينة', 598, 599, 8),
  Surah(99, 'الزلزلة', 599, 599, 8),
  Surah(100, 'العاديات', 599, 600, 11),
  Surah(101, 'القارعة', 600, 600, 11),
  Surah(102, 'التكاثر', 600, 600, 8),
  Surah(103, 'العصر', 601, 601, 3),
  Surah(104, 'الهمزة', 601, 601, 9),
  Surah(105, 'الفيل', 601, 601, 5),
  Surah(106, 'قريش', 602, 602, 4),
  Surah(107, 'الماعون', 602, 602, 7),
  Surah(108, 'الكوثر', 602, 602, 3),
  Surah(109, 'الكافرون', 603, 603, 6),
  Surah(110, 'النصر', 603, 603, 3),
  Surah(111, 'المسد', 603, 603, 5),
  Surah(112, 'الإخلاص', 604, 604, 4),
  Surah(113, 'الفلق', 604, 604, 5),
  Surah(114, 'الناس', 604, 604, 6),
];

/// The Arabic name of surah [number], or null when the number falls outside
/// the mushaf. Read screens pull the number off untyped JSON, so an unusable
/// value costs the name rather than throwing at them.
String? surahNameOf(int? number) {
  for (final surah in kSurahs) {
    if (surah.number == number) return surah.name;
  }
  return null;
}

/// The surah numbered [number], or null when it falls outside the mushaf.
Surah? surahOf(int? number) {
  for (final surah in kSurahs) {
    if (surah.number == number) return surah;
  }
  return null;
}

/// How a surah is named on screen: its name when known, its number when the
/// value falls outside the mushaf, so a bad row still reads as an entry.
String surahLabelOf(int? number) {
  final name = surahNameOf(number);
  return name != null ? 'سورة $name' : 'سورة رقم ${number ?? '-'}';
}

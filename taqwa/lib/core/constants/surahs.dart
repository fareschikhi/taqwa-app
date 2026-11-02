class Surah {
  final int number;
  final String name;

  /// First and last page in the 604-page Madinah mushaf. Short surahs share a
  /// page with their neighbours, so ranges overlap at the edges.
  final int startPage;
  final int endPage;
  const Surah(this.number, this.name, this.startPage, this.endPage);

  /// Every page the surah appears on, so a surah that shares one page with
  /// others still counts as one page rather than none.
  int get pageCount => endPage - startPage + 1;
}

const List<Surah> kSurahs = [
  Surah(1, 'الفاتحة', 1, 1),
  Surah(2, 'البقرة', 2, 49),
  Surah(3, 'آل عمران', 50, 76),
  Surah(4, 'النساء', 77, 106),
  Surah(5, 'المائدة', 106, 127),
  Surah(6, 'الأنعام', 128, 150),
  Surah(7, 'الأعراف', 151, 176),
  Surah(8, 'الأنفال', 177, 186),
  Surah(9, 'التوبة', 187, 207),
  Surah(10, 'يونس', 208, 221),
  Surah(11, 'هود', 221, 235),
  Surah(12, 'يوسف', 235, 248),
  Surah(13, 'الرعد', 249, 255),
  Surah(14, 'إبراهيم', 255, 261),
  Surah(15, 'الحجر', 262, 267),
  Surah(16, 'النحل', 267, 281),
  Surah(17, 'الإسراء', 282, 293),
  Surah(18, 'الكهف', 293, 304),
  Surah(19, 'مريم', 305, 312),
  Surah(20, 'طه', 312, 321),
  Surah(21, 'الأنبياء', 322, 331),
  Surah(22, 'الحج', 332, 341),
  Surah(23, 'المؤمنون', 342, 349),
  Surah(24, 'النور', 350, 359),
  Surah(25, 'الفرقان', 359, 366),
  Surah(26, 'الشعراء', 367, 376),
  Surah(27, 'النمل', 377, 385),
  Surah(28, 'القصص', 385, 396),
  Surah(29, 'العنكبوت', 396, 404),
  Surah(30, 'الروم', 404, 410),
  Surah(31, 'لقمان', 411, 414),
  Surah(32, 'السجدة', 415, 417),
  Surah(33, 'الأحزاب', 418, 427),
  Surah(34, 'سبأ', 428, 434),
  Surah(35, 'فاطر', 434, 440),
  Surah(36, 'يس', 440, 445),
  Surah(37, 'الصافات', 446, 452),
  Surah(38, 'ص', 453, 458),
  Surah(39, 'الزمر', 458, 467),
  Surah(40, 'غافر', 467, 476),
  Surah(41, 'فصلت', 477, 482),
  Surah(42, 'الشورى', 483, 489),
  Surah(43, 'الزخرف', 489, 495),
  Surah(44, 'الدخان', 496, 498),
  Surah(45, 'الجاثية', 499, 502),
  Surah(46, 'الأحقاف', 502, 506),
  Surah(47, 'محمد', 507, 510),
  Surah(48, 'الفتح', 511, 515),
  Surah(49, 'الحجرات', 515, 517),
  Surah(50, 'ق', 518, 520),
  Surah(51, 'الذاريات', 520, 523),
  Surah(52, 'الطور', 523, 525),
  Surah(53, 'النجم', 526, 528),
  Surah(54, 'القمر', 528, 531),
  Surah(55, 'الرحمن', 531, 534),
  Surah(56, 'الواقعة', 534, 537),
  Surah(57, 'الحديد', 537, 541),
  Surah(58, 'المجادلة', 542, 545),
  Surah(59, 'الحشر', 545, 548),
  Surah(60, 'الممتحنة', 549, 551),
  Surah(61, 'الصف', 551, 552),
  Surah(62, 'الجمعة', 553, 554),
  Surah(63, 'المنافقون', 554, 555),
  Surah(64, 'التغابن', 556, 557),
  Surah(65, 'الطلاق', 558, 559),
  Surah(66, 'التحريم', 560, 561),
  Surah(67, 'الملك', 562, 564),
  Surah(68, 'القلم', 564, 566),
  Surah(69, 'الحاقة', 566, 568),
  Surah(70, 'المعارج', 568, 570),
  Surah(71, 'نوح', 570, 571),
  Surah(72, 'الجن', 572, 573),
  Surah(73, 'المزمل', 574, 575),
  Surah(74, 'المدثر', 575, 577),
  Surah(75, 'القيامة', 577, 578),
  Surah(76, 'الإنسان', 578, 580),
  Surah(77, 'المرسلات', 580, 581),
  Surah(78, 'النبأ', 582, 583),
  Surah(79, 'النازعات', 583, 584),
  Surah(80, 'عبس', 585, 585),
  Surah(81, 'التكوير', 586, 586),
  Surah(82, 'الإنفطار', 587, 587),
  Surah(83, 'المطففين', 587, 589),
  Surah(84, 'الإنشقاق', 589, 589),
  Surah(85, 'البروج', 590, 590),
  Surah(86, 'الطارق', 591, 591),
  Surah(87, 'الأعلى', 591, 592),
  Surah(88, 'الغاشية', 592, 592),
  Surah(89, 'الفجر', 593, 594),
  Surah(90, 'البلد', 594, 594),
  Surah(91, 'الشمس', 595, 595),
  Surah(92, 'الليل', 595, 596),
  Surah(93, 'الضحى', 596, 596),
  Surah(94, 'الشرح', 596, 596),
  Surah(95, 'التين', 597, 597),
  Surah(96, 'العلق', 597, 597),
  Surah(97, 'القدر', 598, 598),
  Surah(98, 'البينة', 598, 599),
  Surah(99, 'الزلزلة', 599, 599),
  Surah(100, 'العاديات', 599, 600),
  Surah(101, 'القارعة', 600, 600),
  Surah(102, 'التكاثر', 600, 600),
  Surah(103, 'العصر', 601, 601),
  Surah(104, 'الهمزة', 601, 601),
  Surah(105, 'الفيل', 601, 601),
  Surah(106, 'قريش', 602, 602),
  Surah(107, 'الماعون', 602, 602),
  Surah(108, 'الكوثر', 602, 602),
  Surah(109, 'الكافرون', 603, 603),
  Surah(110, 'النصر', 603, 603),
  Surah(111, 'المسد', 603, 603),
  Surah(112, 'الإخلاص', 604, 604),
  Surah(113, 'الفلق', 604, 604),
  Surah(114, 'الناس', 604, 604),
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

/// How a surah is named on screen: its name when known, its number when the
/// value falls outside the mushaf, so a bad row still reads as an entry.
String surahLabelOf(int? number) {
  final name = surahNameOf(number);
  return name != null ? 'سورة $name' : 'سورة رقم ${number ?? '-'}';
}

/// Where each of the 60 ahzab begins: (surah number, ayah number in surah).
///
/// Every fourth rub' of qcf_quran's quarter table, copied here because the
/// package keeps that table under `src/`. Odd ahzab start the juz' in
/// `juzStarts`.
class HizbStart {
  const HizbStart(this.hizb, this.surah, this.ayah);

  final int hizb;
  final int surah;
  final int ayah;
}

const List<HizbStart> hizbStarts = [
  HizbStart(1, 1, 1),
  HizbStart(2, 2, 75),
  HizbStart(3, 2, 142),
  HizbStart(4, 2, 203),
  HizbStart(5, 2, 253),
  HizbStart(6, 3, 15),
  HizbStart(7, 3, 93),
  HizbStart(8, 3, 171),
  HizbStart(9, 4, 24),
  HizbStart(10, 4, 88),
  HizbStart(11, 4, 148),
  HizbStart(12, 5, 27),
  HizbStart(13, 5, 82),
  HizbStart(14, 6, 36),
  HizbStart(15, 6, 111),
  HizbStart(16, 7, 1),
  HizbStart(17, 7, 88),
  HizbStart(18, 7, 171),
  HizbStart(19, 8, 41),
  HizbStart(20, 9, 34),
  HizbStart(21, 9, 93),
  HizbStart(22, 10, 26),
  HizbStart(23, 11, 6),
  HizbStart(24, 11, 84),
  HizbStart(25, 12, 53),
  HizbStart(26, 13, 19),
  HizbStart(27, 15, 1),
  HizbStart(28, 16, 51),
  HizbStart(29, 17, 1),
  HizbStart(30, 17, 99),
  HizbStart(31, 18, 75),
  HizbStart(32, 20, 1),
  HizbStart(33, 21, 1),
  HizbStart(34, 22, 1),
  HizbStart(35, 23, 1),
  HizbStart(36, 24, 21),
  HizbStart(37, 25, 21),
  HizbStart(38, 26, 111),
  HizbStart(39, 27, 56),
  HizbStart(40, 28, 51),
  HizbStart(41, 29, 46),
  HizbStart(42, 31, 22),
  HizbStart(43, 33, 31),
  HizbStart(44, 34, 24),
  HizbStart(45, 36, 28),
  HizbStart(46, 37, 145),
  HizbStart(47, 39, 32),
  HizbStart(48, 40, 41),
  HizbStart(49, 41, 47),
  HizbStart(50, 43, 24),
  HizbStart(51, 46, 1),
  HizbStart(52, 48, 18),
  HizbStart(53, 51, 31),
  HizbStart(54, 55, 1),
  HizbStart(55, 58, 1),
  HizbStart(56, 62, 1),
  HizbStart(57, 67, 1),
  HizbStart(58, 72, 1),
  HizbStart(59, 78, 1),
  HizbStart(60, 87, 1),
];

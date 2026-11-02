/// A country the phone field offers beside the number box.
class CountryDialCode {
  const CountryDialCode(this.name, this.dialCode, this.flag);

  final String name;
  final String dialCode;
  final String flag;
}

/// Algeria first, since it is preselected and most accounts are there; then
/// the rest of the Arab world and the countries where families most often
/// live abroad. A number from anywhere else can still be typed in full with
/// its own +code.
const kAlgeria = CountryDialCode('الجزائر', '+213', '🇩🇿');

const kCountryDialCodes = <CountryDialCode>[
  kAlgeria,
  CountryDialCode('المغرب', '+212', '🇲🇦'),
  CountryDialCode('تونس', '+216', '🇹🇳'),
  CountryDialCode('ليبيا', '+218', '🇱🇾'),
  CountryDialCode('موريتانيا', '+222', '🇲🇷'),
  CountryDialCode('مصر', '+20', '🇪🇬'),
  CountryDialCode('السودان', '+249', '🇸🇩'),
  CountryDialCode('السعودية', '+966', '🇸🇦'),
  CountryDialCode('الإمارات', '+971', '🇦🇪'),
  CountryDialCode('قطر', '+974', '🇶🇦'),
  CountryDialCode('الكويت', '+965', '🇰🇼'),
  CountryDialCode('البحرين', '+973', '🇧🇭'),
  CountryDialCode('عُمان', '+968', '🇴🇲'),
  CountryDialCode('اليمن', '+967', '🇾🇪'),
  CountryDialCode('الأردن', '+962', '🇯🇴'),
  CountryDialCode('فلسطين', '+970', '🇵🇸'),
  CountryDialCode('لبنان', '+961', '🇱🇧'),
  CountryDialCode('سوريا', '+963', '🇸🇾'),
  CountryDialCode('العراق', '+964', '🇮🇶'),
  CountryDialCode('تركيا', '+90', '🇹🇷'),
  CountryDialCode('فرنسا', '+33', '🇫🇷'),
  CountryDialCode('بلجيكا', '+32', '🇧🇪'),
  CountryDialCode('سويسرا', '+41', '🇨🇭'),
  CountryDialCode('ألمانيا', '+49', '🇩🇪'),
  CountryDialCode('إسبانيا', '+34', '🇪🇸'),
  CountryDialCode('إيطاليا', '+39', '🇮🇹'),
  CountryDialCode('هولندا', '+31', '🇳🇱'),
  CountryDialCode('المملكة المتحدة', '+44', '🇬🇧'),
  CountryDialCode('كندا', '+1', '🇨🇦'),
  CountryDialCode('الولايات المتحدة', '+1', '🇺🇸'),
];

/// The listed country whose code [phone] (international form) starts with,
/// longest code first so "+213" is not taken for "+2…" elsewhere.
CountryDialCode? countryForPhone(String phone) {
  CountryDialCode? best;
  for (final c in kCountryDialCodes) {
    if (phone.startsWith(c.dialCode) &&
        (best == null || c.dialCode.length > best.dialCode.length)) {
      best = c;
    }
  }
  return best;
}

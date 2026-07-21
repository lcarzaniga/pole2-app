import 'package:intl/intl.dart';

/// Locale-aware date and number formatting via `intl`. Human phrasing that
/// needs translated words lives in `phrasing.dart` (it takes AppLocalizations).

/// Whole calendar days from today until [date] (negative if past).
int daysUntil(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(date.year, date.month, date.day);
  return that.difference(today).inDays;
}

/// A long, localized date, e.g. "3 marzo 2024" (it) / "3 March 2024" (en).
String formatDate(DateTime d, String locale) =>
    DateFormat('d MMMM y', locale).format(d.toLocal());

/// A calm, locale-aware human byte size, e.g. "1,2 MB" (it) / "1.2 MB" (en).
/// Uses decimal (SI) units and one decimal for KB and above; whole bytes below
/// 1 KB. Never negative. No new dependency — plain `intl` [NumberFormat].
String formatBytes(int bytes, String locale) {
  final b = bytes < 0 ? 0 : bytes;
  if (b < 1000) return '$b B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = b / 1000;
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  return '${NumberFormat('#,##0.0', locale).format(value)} ${units[unit]}';
}

const _symbols = {'EUR': '€', 'USD': r'$', 'GBP': '£'};

/// Localized money, e.g. "€ 18.499,00" (it). Amount is stored in minor units.
String formatMoney(int amountMinor, String? currency, String locale) {
  final number = NumberFormat('#,##0.00', locale).format(amountMinor / 100);
  final symbol = _symbols[currency] ?? (currency == null ? '' : '$currency ');
  return symbol.isEmpty ? number : '$symbol $number';
}

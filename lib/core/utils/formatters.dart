import 'package:intl/intl.dart';

final _currencyFormat = NumberFormat.currency(
  locale: 'tr_TR',
  symbol: '₺',
  decimalDigits: 2,
);

final _dateFormat = DateFormat('d MMM y', 'tr_TR');
final _dateTimeFormat = DateFormat('d MMM y HH:mm', 'tr_TR');
final _monthFormat = DateFormat('MMMM y', 'tr_TR');

String formatCurrency(num amount) => _currencyFormat.format(amount);

String formatDate(DateTime? date) =>
    date == null ? '-' : _dateFormat.format(date);

/// "Eylül 2026" — used by the month picker bar on the Giderler page.
String formatMonth(DateTime month) => _monthFormat.format(month);

String formatDateTime(DateTime? date) =>
    date == null ? '-' : _dateTimeFormat.format(date);

/// Relative "az önce / 5 dk önce / 3 sa önce / d MMM y" label for
/// notification and activity timestamps.
String formatRelative(DateTime? date) {
  if (date == null) return '-';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'az önce';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
  if (diff.inHours < 24) return '${diff.inHours} sa önce';
  if (diff.inDays < 7) return '${diff.inDays} gün önce';
  return formatDate(date);
}

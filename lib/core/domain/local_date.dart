// BEGINNER NOTE:
// [LocalDate] represents a pure calendar date (year, month, day) without hours, minutes,
// or timezone offsets.
// Standard Dart `DateTime` and Firestore `Timestamp` store instant-in-time epoch milliseconds.
// When converted across different time zones (e.g., UTC on a server vs. Indian Standard Time on
// a collector's phone), midnight UTC can shift to 05:30 AM local time, causing off-by-one errors.
// By strictly storing dates as formatted strings ("YYYY-MM-DD") via [LocalDate], delivery
// schedules and billing cycles remain completely deterministic regardless of device timezone.
/// Calendar-only date used by billing. It deliberately excludes time zones so
/// one delivery day cannot move to another day during serialization.
class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day)
    : assert(year >= 1 && year <= 9999),
      assert(month >= 1 && month <= 12),
      assert(day >= 1 && day <= 31);

  factory LocalDate.fromDateTime(DateTime value) =>
      LocalDate(value.year, value.month, value.day);

  factory LocalDate.parse(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw FormatException('Invalid date: $value');
    }
    final parts = value.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);
    if (!_isValidParts(year, month, day)) {
      throw FormatException('Invalid date: $value');
    }
    return LocalDate(year, month, day);
  }

  final int year;
  final int month;
  final int day;

  bool get isValid {
    return _isValidParts(year, month, day);
  }

  DateTime toDateTime() {
    if (!isValid) throw StateError('Invalid calendar date: $this');
    return DateTime.utc(year, month, day);
  }

  LocalDate addDays(int days) =>
      LocalDate.fromDateTime(toDateTime().add(Duration(days: days)));

  int get daysInMonth {
    if (year < 1 || year > 9999 || month < 1 || month > 12) {
      throw StateError('Invalid calendar month: $year-$month');
    }
    return _daysInMonth(year, month);
  }

  /// ISO-8601 weekday where Monday is 1 and Sunday is 7.
  int get isoWeekday => toDateTime().weekday;

  @override
  int compareTo(LocalDate other) => toDateTime().compareTo(other.toDateTime());

  bool isBefore(LocalDate other) => compareTo(other) < 0;

  bool isAfter(LocalDate other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  static int _daysInMonth(int year, int month) => switch (month) {
    2 => _isLeapYear(year) ? 29 : 28,
    4 || 6 || 9 || 11 => 30,
    _ => 31,
  };

  static bool _isLeapYear(int year) =>
      year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

  static bool _isValidParts(int year, int month, int day) =>
      year >= 1 &&
      year <= 9999 &&
      month >= 1 &&
      month <= 12 &&
      day >= 1 &&
      day <= _daysInMonth(year, month);
}

// BEGINNER NOTE:
// [LocalDateRange] models continuous calendar spans (inclusive of start and end dates).
// Used throughout subscription lifecycles to detect holiday pauses, active windows,
// and overlapping price rule periods.
class LocalDateRange {
  const LocalDateRange({required this.start, required this.end});

  final LocalDate start;
  final LocalDate end;

  bool contains(LocalDate date) => !date.isBefore(start) && !date.isAfter(end);

  bool overlaps(LocalDateRange other) =>
      !end.isBefore(other.start) && !other.end.isBefore(start);
}

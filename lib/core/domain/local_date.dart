/// Calendar-only date used by billing. It deliberately excludes time zones so
/// one delivery day cannot move to another day during serialization.
class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day)
    : assert(month >= 1 && month <= 12),
      assert(day >= 1 && day <= 31);

  factory LocalDate.fromDateTime(DateTime value) =>
      LocalDate(value.year, value.month, value.day);

  factory LocalDate.parse(String value) {
    final parts = value.split('-');
    if (parts.length != 3) throw FormatException('Invalid date: $value');
    return LocalDate(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  final int year;
  final int month;
  final int day;

  DateTime toDateTime() => DateTime.utc(year, month, day);

  LocalDate addDays(int days) =>
      LocalDate.fromDateTime(toDateTime().add(Duration(days: days)));

  int get daysInMonth => DateTime.utc(year, month + 1, 0).day;

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
}

class LocalDateRange {
  const LocalDateRange({required this.start, required this.end});

  final LocalDate start;
  final LocalDate end;

  bool contains(LocalDate date) => !date.isBefore(start) && !date.isAfter(end);
}

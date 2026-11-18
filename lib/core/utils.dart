/// Version helpers compatible with the Kotlin implementation.
library;

bool isVersionGreater(String v1, String v2) {
  final a = v1.split('.');
  final b = v2.split('.');
  final length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    final x = i < a.length ? int.tryParse(a[i]) ?? 0 : 0;
    final y = i < b.length ? int.tryParse(b[i]) ?? 0 : 0;
    if (x > y) return true;
    if (x < y) return false;
  }
  return false;
}

bool isVersionAtLeast(String current, String minimum) =>
    !isVersionGreater(minimum, current);

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = value >= 100 || unit == 0 ? 0 : (value >= 10 ? 1 : 2);
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

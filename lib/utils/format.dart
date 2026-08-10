String _twoDigits(int n) => n.toString().padLeft(2, '0');

String formatDateTime(DateTime d) =>
    '${_twoDigits(d.day)}.${_twoDigits(d.month)}.${d.year} в ${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';

String formatDate(DateTime d) =>
    '${_twoDigits(d.day)}.${_twoDigits(d.month)}.${d.year}';

String formatTime(DateTime d) =>
    '${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';

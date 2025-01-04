// ...lib/utils/digit_only_formatter.dart

import 'package:flutter/services.dart';

class DigitOnlyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    // Only allow digits
    final newString = RegExp(r'[0-9]').allMatches(newValue.text).map((m) => m.group(0)).join();

    return TextEditingValue(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }
}
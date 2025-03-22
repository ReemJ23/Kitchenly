import 'package:flutter/material.dart';

class FontHelper {
  static String getFontFamily(String text) {
    // Detect if the text contains Arabic characters
    bool isArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(text);

    return isArabic ? 'NotoSansArabic' : 'Mulish';
  }
  static String getDefaultFontFamily(Locale locale) {
    return locale.languageCode == 'ar' ? 'NotoSansArabic' : 'Mulish';
  }
}

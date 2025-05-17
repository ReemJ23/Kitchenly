import 'package:flutter/material.dart';

class AppColors {
  static final ValueNotifier<int> themeVersion = ValueNotifier(0);
  // Static colors that shouldn't change (unchanged)
  static const Color error = Colors.red;
  static const Color textFieldBorder = Colors.grey;
  static const Color textFieldBorderError = Colors.red;
  static const Color bgColor = Color(0xFFFFFFFF); //don't change
  static const Color heading1 = Color(0xFF000000); //don't change
  static const Color heading2 = Color(0xFF716F6F); //don't change
  static const Color toggleInactive = Color(0xFFFFFFFF); //don't change
  static const Color defaultLabel = Color(0xFF716F6F); //don't change
  static const Color bottomBorder = Color(0xFF716F6F); //don't change
  static const Color transparent = Colors.transparent; //don't change
  static const Color pastExpirationDate = Color(0xFFFF0000); //don't change
  static const Color declineFriend = Color(0xFFFF0000); //don't change
  static const Color dismissNotification = Color(0xFFFF0000); //don't change
  static const Color acceptFriend = Color(0xFF2DB30F); //don't change
  static const Color success = Color(0xFF2DB30F); //don't change
  static const Color hint = Color(0xFF716F6F); //don't change
  static const Color calendarText = Color(0xFF000000); //don't change
  static const Color focusedDayText = Color(0xFFFFFFFF); //don't change
  static const Color iconColor = Color(0xFF716F6F); //don't change
  //static const Color profileIconBg = _light;

  // Theme variables
  static Color _verylight = const Color(0xFFFFDAD2);
  static Color _light = const Color(0x99BF8E73);
  static Color _dark = const Color(0xFF51271D);
  // Theme-based colors
  static Color profileIconBg = _verylight;
  static Color toggleActive = _dark;
  static Color buttonBg = _light;
  static Color buttonBgOnPressed = _light;
  static Color buttonText = _dark;
  static Color focusedBorder = _dark;
  static Color futureExpirationDate = _dark;
  static Color categoryExpandedBg = _light;
  static Color deleteBg = _dark;
  static Color focusedDayBg = _dark;


  // Initialize with default red theme
  static void initialize() {
    setTheme('red');
  }

  // Method to change theme colors
  static void setTheme(String themeName) {
    // Define light and dark variants based on theme
    switch (themeName) {
      case 'green':
        _light = const Color(0xFFECF3E2);
        _verylight = const Color(0x99CED7C4);
        _dark = const Color(0xFF4A6B3D);
        break;
      case 'blue':
        _light = const Color(0xFFDEEAF7);
        _verylight = const Color(0x9998AAB4);
        _dark = const Color(0xFF3A536B);
        break;
      case 'orange':
        _light = const Color(0xFFFCE5CE);
        _verylight = const Color(0x99E3B38A);
        _dark = const Color(0xFFB3743C);
        break;
      case 'purple':
        _light = const Color(0xFFEBE5F7);
        _verylight = const Color(0x999A90B3);
        _dark = const Color(0xFF5A4A7A);
        break;
      case 'red':
      default:
        _verylight = const Color(0xFFFFDAD2);
        _light = const Color(0x99BF8E73);
        _dark = const Color(0xFF51271D);
        break;
    }

    // Set all theme-based colors using the light/dark variants
    toggleActive = _dark;
    buttonBg = _light;
    buttonBgOnPressed = _light;
    buttonText = _dark;
    focusedBorder = _dark;
    futureExpirationDate = _dark;
    categoryExpandedBg = _light;
    deleteBg = _dark;
    focusedDayBg = _dark;
    profileIconBg = _verylight;

    themeVersion.value++;
  }
}
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LocalizationHelper {
  static String getLocalizedString(AppLocalizations localizations, String key) {
    final Map<String, String> localizedStrings = {
      "Peanuts": localizations.peanuts,
      "Dairy": localizations.dairy,
      "Gluten": localizations.gluten,
      "Soy": localizations.soy,
      "Shellfish": localizations.shellfish,
      "Eggs": localizations.eggs,
      "Tree Nuts": localizations.treeNuts,
      "Sesame": localizations.sesame,
      "Tomato": localizations.tomato,
      "Carrot": localizations.carrot,
      "Potato": localizations.potato,
      "Milk": localizations.milk,
      "Cheese": localizations.cheese,
      "Yogurt": localizations.yogurt,
      "Rice": localizations.rice,
      "Pasta": localizations.pasta,
      "Bread": localizations.bread,
      "Vegetables": localizations.vegetables,
      "Dairy": localizations.dairy,
      "Grains": localizations.grains,
      "kg": localizations.kg,
      "g": localizations.g,
      "lb": localizations.lb,
      "oz": localizations.oz,
      "liter": localizations.liter,
      "pieces":localizations.pieces
    };

    return localizedStrings[key] ?? key; // If no translation is found, return the original key
  }
}

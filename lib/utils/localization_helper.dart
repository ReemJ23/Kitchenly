import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LocalizationHelper {
  static String getLocalizedString(AppLocalizations localizations, String key) {
    final Map<String, String> localizedStrings = {
      // Existing entries
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
      "Grains": localizations.grains,
      "kg": localizations.kg,
      "g": localizations.g,
      "lb": localizations.lb,
      "oz": localizations.oz,
      "liter": localizations.liter,
      "pieces": localizations.pieces,

      // New entries for recipes page
      "all": localizations.all,
      "italian": localizations.italian,
      "mexican": localizations.mexican,
      "indian": localizations.indian,
      "chinese": localizations.chinese,
      "mediterranean": localizations.mediterranean,
      "easy": localizations.difficulty_easy,
      "medium": localizations.difficulty_medium,
      "hard": localizations.difficulty_hard,
      "quick": localizations.time_quick,
      "tmedium": localizations.time_medium,
      "long": localizations.time_long,
      "full": localizations.availability_full,
      "partial": localizations.availability_partial,
      "low": localizations.availability_low,
      "minutes": localizations.minutes,
      "untitledRecipe": localizations.untitledRecipe,
      "ingredients": localizations.ingredients,
      "steps": localizations.steps,
      "servings": localizations.servings,
      "searchRecipes": localizations.searchRecipes,
      "noRecipesFound": localizations.noRecipesFound,
      "myRecipes": localizations.myRecipes,
      "cuisine": localizations.cuisine,
      "difficulty": localizations.difficulty,
      "time": localizations.time,
      "availability": localizations.availability,
    };

    return localizedStrings[key] ?? key; // If no translation is found, return the original key
  }
}
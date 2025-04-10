class RecipeStep {
  final int stepNumber;
  final String instructions;
  final List<Ingredient> ingredients;

  RecipeStep({
    required this.stepNumber,
    required this.instructions,
    required this.ingredients,
  });
}

class Ingredient {
  final String id;
  final String name;
  final dynamic quantity; // could be String or double
  final String unit;

  Ingredient({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
  });
}
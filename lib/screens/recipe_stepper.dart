import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/recipeStep.dart';

class RecipeStepper extends StatefulWidget {
  final List<RecipeStep> steps;
  final String recipeName;

  const RecipeStepper({
    Key? key,
    required this.steps,
    required this.recipeName,
  }) : super(key: key);

  @override
  _RecipeStepperState createState() => _RecipeStepperState();
}

class _RecipeStepperState extends State<RecipeStepper> {
  int _currentStep = 0;
  Map<String, double> inventoryDeductions = {};
  Map<String, bool> addToShoppingList = {};

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.recipeName} - ${loc.step} ${_currentStep + 1}/${widget.steps.length}'),
      ),
      body: _currentStep < widget.steps.length
          ? _buildStepContent(widget.steps[_currentStep], loc)
          : _buildInventoryAdjustment(loc),
      persistentFooterButtons: _buildNavigationButtons(loc),
    );
  }

  Widget _buildStepContent(RecipeStep step, AppLocalizations loc) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16),
          Text(
            '${loc.step} ${step.stepNumber}',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            step.instructions,
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 16),
          Text(
            loc.ingredientsForThisStep,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ...step.ingredients.map((ingredient) => ListTile(
            title: Text(ingredient.name),
            subtitle: Text('${ingredient.quantity} ${ingredient.unit}'),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildInventoryAdjustment(AppLocalizations loc) {
    Map<String, Ingredient> allIngredients = {};
    for (var step in widget.steps) {
      for (var ingredient in step.ingredients) {
        if (allIngredients.containsKey(ingredient.id)) {
          var existing = allIngredients[ingredient.id]!;
          allIngredients[ingredient.id] = Ingredient(
            id: ingredient.id,
            name: ingredient.name,
            quantity: existing.quantity + ingredient.quantity,
            unit: ingredient.unit,
          );
        } else {
          allIngredients[ingredient.id] = ingredient;
        }
      }
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.recipeComplete,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Text(
            loc.adjustYourInventory,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          ...allIngredients.values.map((ingredient) {
            inventoryDeductions.putIfAbsent(ingredient.id, () => ingredient.quantity);
            addToShoppingList.putIfAbsent(ingredient.id, () => false);

            return Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ingredient.name,
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: inventoryDeductions[ingredient.id]!.toStringAsFixed(2),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: loc.quantityToDeduct,
                              suffixText: ingredient.unit,
                            ),
                            onChanged: (value) {
                              double? newValue = double.tryParse(value);
                              if (newValue != null && newValue >= 0) {
                                setState(() {
                                  inventoryDeductions[ingredient.id] = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Checkbox(
                            value: addToShoppingList[ingredient.id],
                            onChanged: (value) {
                              setState(() {
                                addToShoppingList[ingredient.id] = value ?? false;
                              });
                            },
                          ),
                          Text(loc.addToShoppingListIfZero,softWrap: true,),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submitInventoryAdjustments,
            child: Text(loc.confirmAdjustments),
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNavigationButtons(AppLocalizations loc) {
    if (_currentStep < widget.steps.length) {
      return [
        if (_currentStep > 0)
          ElevatedButton(
            onPressed: () => setState(() => _currentStep--),
            child: Text(loc.previous),
          ),
        ElevatedButton(
          onPressed: () => setState(() => _currentStep++),
          child: Text(_currentStep == widget.steps.length - 1 ? loc.finish : loc.next),
        ),
      ];
    }
    return [];
  }

  Future<void> _submitInventoryAdjustments() async {
    final loc = AppLocalizations.of(context)!;

    for (var entry in inventoryDeductions.entries) {
      if (entry.value < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.quantitiesCannotBeNegative)),
        );
        return;
      }
    }

    bool success = await _updateInventoryInDatabase();

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.inventoryUpdatedSuccessfully)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.failedToUpdateInventory)),
      );
    }
  }

  Future<bool> _updateInventoryInDatabase() async {
    try {
      // Your database update logic
      return true;
    } catch (e) {
      print('Error updating inventory: $e');
      return false;
    }
  }
}
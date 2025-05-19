import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/recipeStep.dart';
import '../utils/category_helper.dart';
import '../utils/colors.dart';

class RecipeStepper extends StatefulWidget {
  final List<RecipeStep> steps;
  final String recipeName;
  final double multiplier;
  final String language;

  const RecipeStepper({
    Key? key,
    required this.steps,
    required this.recipeName,
    required this.language,
    this.multiplier = 1.0,
  }) : super(key: key);

  @override
  _RecipeStepperState createState() => _RecipeStepperState();
}

class _RecipeStepperState extends State<RecipeStepper> {
  int _currentStep = 0;
  final Map<String, double> _ingredientQuantities = {};
  final Map<String, bool> _selectedIngredients = {};
  final User? _user = FirebaseAuth.instance.currentUser;


  @override
  Widget build(BuildContext context) {
    final loc = widget.language != null
        ? lookupAppLocalizations(Locale(widget.language!))
        : AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.recipeName} - ${loc.step} ${_currentStep + 1}/${widget.steps.length}'),
      ),
      body: _currentStep < widget.steps.length
          ? _buildStepContent(widget.steps[_currentStep], loc)
          : _buildCompletionScreen(loc),
      persistentFooterButtons: _buildNavigationButtons(loc),
    );
  }

  Widget _buildStepContent(RecipeStep step, AppLocalizations loc) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            '${loc.step} ${step.stepNumber}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            step.instructions,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Text(
            loc.ingredientsForThisStep,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          ...step.ingredients.map((ingredient) => ListTile(
            title: Text(ingredient.name),
            subtitle: Text('${(ingredient.quantity * widget.multiplier).toStringAsFixed(2)} ${ingredient.unit}'),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildCompletionScreen(AppLocalizations loc) {
    final allIngredients = <String, Ingredient>{};
    for (final step in widget.steps) {
      for (final ingredient in step.ingredients) {
        if (allIngredients.containsKey(ingredient.id)) {
          final existing = allIngredients[ingredient.id]!;
          allIngredients[ingredient.id] = Ingredient(
            id: ingredient.id,
            name: ingredient.name,
            quantity: existing.quantity + (ingredient.quantity * widget.multiplier), // Apply multiplier
            unit: ingredient.unit,
          );
        } else {
          allIngredients[ingredient.id] = Ingredient(
            id: ingredient.id,
            name: ingredient.name,
            quantity: ingredient.quantity * widget.multiplier, // Apply multiplier
            unit: ingredient.unit,
          );
          _ingredientQuantities.putIfAbsent(ingredient.id, () => ingredient.quantity * widget.multiplier);
          _selectedIngredients.putIfAbsent(ingredient.id, () => false);
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.recipeComplete,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            loc.manageIngredients,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...allIngredients.values.map((ingredient) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _selectedIngredients[ingredient.id] ?? false,
                          onChanged: (value) {
                            setState(() {
                              _selectedIngredients[ingredient.id] = value ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: Text(
                            ingredient.name,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedIngredients[ingredient.id] ?? false) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: _ingredientQuantities[ingredient.id]?.toStringAsFixed(2),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: loc.quantity,
                          suffixText: ingredient.unit,
                        ),
                        onChanged: (value) {
                          final newValue = double.tryParse(value);
                          if (newValue != null && newValue >= 0) {
                            setState(() {
                              _ingredientQuantities[ingredient.id] = newValue;
                            });
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _addToShoppingList,
                  child: Text(loc.addToShoppingList),

                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _updateInventory,
                  child: Text(loc.updateInventory),

                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addToShoppingList() async {
    final loc = widget.language != null
        ? lookupAppLocalizations(Locale(widget.language!))
        : AppLocalizations.of(context)!;
    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.notSignedIn)),
      );
      return;
    }

    final shoppingListRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .collection('shoppingList');

    final existingItemsSnapshot = await shoppingListRef.get();
    final existingItems = {
      for (var doc in existingItemsSnapshot.docs)
        if (doc.data().containsKey('name') && doc.data().containsKey('unit'))
          '${doc['name']}_${doc['unit']}': doc
    };

    final batch = FirebaseFirestore.instance.batch();

    final itemsToAdd = _selectedIngredients.entries
        .where((e) => e.value)
        .map((e) {
      final ingredient = _findIngredientById(e.key);
      if (ingredient == null) return null;

      return {
        'name': ingredient.name,
        'quantity': _ingredientQuantities[e.key] ?? 0,
        'unit': ingredient.unit,
        'checked': false,
        'category': CategoryHelper.categorizeItem(ingredient.name),
      };
    })
        .where((item) => item != null)
        .toList();

    for (final item in itemsToAdd) {
      final key = '${item!['name']}_${item['unit']}';
      if (existingItems.containsKey(key)) {
        batch.update(
          existingItems[key]!.reference,
          {'quantity': FieldValue.increment(item['quantity'] as double)},
        );
      } else {
        batch.set(shoppingListRef.doc(), item);
      }
    }

    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.itemsAddedToShoppingList)),
    );
  }



  Future<void> _updateInventory() async {
    final loc = widget.language != null
        ? lookupAppLocalizations(Locale(widget.language!))
        : AppLocalizations.of(context)!;
    if (_user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.notSignedIn)),
      );
      return;
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      final inventoryRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .collection('inventory');

      for (final entry in _selectedIngredients.entries) {
        if (!entry.value) continue;

        final ingredient = _findIngredientById(entry.key);
        if (ingredient == null) continue;

        final quantity = _ingredientQuantities[entry.key] ?? 0;
        if (quantity <= 0) continue;

        // Find matching inventory item
        final inventoryItem = await inventoryRef
            .where('name', isEqualTo: ingredient.name)
            .where('unit', isEqualTo: ingredient.unit)
            .limit(1)
            .get();

        if (inventoryItem.docs.isNotEmpty) {
          final currentQuantity = inventoryItem.docs.first.data()['quantity'] ?? 0;
          final newQuantity = currentQuantity - quantity;

          batch.update(
            inventoryItem.docs.first.reference,
            {'quantity': newQuantity >= 0 ? newQuantity : 0},
          );
        }
      }

      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.inventoryUpdatedSuccessfully)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.failedToUpdateInventory}: $e')),
      );
    }
  }

  Ingredient? _findIngredientById(String id) {
    for (final step in widget.steps) {
      for (final ingredient in step.ingredients) {
        if (ingredient.id == id) {
          return ingredient;
        }
      }
    }
    return null;
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
}
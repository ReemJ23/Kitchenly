import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class EditRecipePage extends StatefulWidget {
  final DocumentSnapshot? recipe;

  const EditRecipePage({Key? key, this.recipe}) : super(key: key);

  @override
  _EditRecipePageState createState() => _EditRecipePageState();
}

class _EditRecipePageState extends State<EditRecipePage> {
  final User? user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _prepTimeController = TextEditingController();
  final TextEditingController _servingSizeController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _newLabelController = TextEditingController();
  final TextEditingController _newEquipmentController = TextEditingController();

  String? _difficulty;
  String? _cuisineType;
  List<String> _labels = [];
  List<String> _equipment = [];

  // Temporary lists for ingredients and steps (would be managed in state)
  List<Map<String, dynamic>> _ingredients = [];
  List<Map<String, dynamic>> _steps = [];
  String? _userLanguage;


  @override
  void initState() {
    super.initState();
    if (widget.recipe != null) {
      // Load existing recipe data
      final data = widget.recipe!.data() as Map<String, dynamic>;
      _nameController.text = data['name'] ?? '';
      _prepTimeController.text = data['preparationTime']?.toString() ?? '';
      _servingSizeController.text = data['servingSize']?.toString() ?? '';
      _categoryController.text = data['category'] ?? '';
      _notesController.text = data['notes'] ?? '';
      _difficulty = data['difficulty'];
      _cuisineType = data['cuisineType'];
      _labels = List<String>.from(data['labels'] ?? []);
      _equipment = List<String>.from(data['equipment'] ?? []);
    }
    _fetchUserLanguage().then((language) {
      setState(() {
        _userLanguage = language;
      });
    });
  }

  // Fetch the user's preferred language from Firestore
  Future<String> _fetchUserLanguage() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    if (userDoc.exists) {
      return userDoc['language'] ?? 'en'; // Default to 'en' if language is not set
    }
    return 'en'; // Default to 'en' if the user document doesn't exist
  }

  @override
  Widget build(BuildContext context) {
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;
    final isEditing = widget.recipe != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? localizations.editRecipe : localizations.addRecipe),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveRecipe,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recipe name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: localizations.recipeName,
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return localizations.recipeNameRequired;
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // Basic info section
              Text(localizations.basicInfo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _prepTimeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: localizations.preparationTime,
                        border: OutlineInputBorder(),
                        suffixText: localizations.minutes,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _difficulty,
                      decoration: InputDecoration(
                        labelText: localizations.difficulty,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(value: 'easy', child: Text(localizations.difficulty_easy)),
                        DropdownMenuItem(value: 'medium', child: Text(localizations.difficulty_medium)),
                        DropdownMenuItem(value: 'hard', child: Text(localizations.difficulty_hard)),
                      ],
                      onChanged: (value) => setState(() => _difficulty = value),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _servingSizeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: localizations.servingSize,
                        border: OutlineInputBorder(),
                        suffixText: localizations.servings,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _cuisineType,
                      decoration: InputDecoration(
                        labelText: localizations.cuisineType,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(value: 'italian', child: Text(localizations.cuisine_italian)),
                        DropdownMenuItem(value: 'mexican', child: Text(localizations.cuisine_mexican)),
                        DropdownMenuItem(value: 'indian', child: Text(localizations.cuisine_indian)),
                        DropdownMenuItem(value: 'chinese', child: Text(localizations.cuisine_chinese)),
                        DropdownMenuItem(value: 'mediterranean', child: Text(localizations.cuisine_mediterranean)),
                      ],
                      onChanged: (value) => setState(() => _cuisineType = value),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(
                  labelText: localizations.category,
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 24),

              // Labels section
              Text(localizations.labels, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _labels.map((label) => Chip(
                  label: Text(label),
                  onDeleted: () => setState(() => _labels.remove(label)),
                )).toList(),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _newLabelController,
                      decoration: InputDecoration(
                        labelText: localizations.addLabel,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () {
                      if (_newLabelController.text.isNotEmpty) {
                        setState(() {
                          _labels.add(_newLabelController.text);
                          _newLabelController.clear();
                        });
                      }
                    },
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Equipment section
              Text(localizations.equipment, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _equipment.map((item) => Chip(
                  label: Text(item),
                  onDeleted: () => setState(() => _equipment.remove(item)),
                )).toList(),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _newEquipmentController,
                      decoration: InputDecoration(
                        labelText: localizations.addEquipment,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () {
                      if (_newEquipmentController.text.isNotEmpty) {
                        setState(() {
                          _equipment.add(_newEquipmentController.text);
                          _newEquipmentController.clear();
                        });
                      }
                    },
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Ingredients section
              Text(localizations.ingredients, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              ..._ingredients.map((ingredient) => _buildIngredientItem(ingredient)).toList(),
              ElevatedButton(
                onPressed: _addIngredient,
                child: Text(localizations.addIngredient),
              ),
              SizedBox(height: 24),

              // Steps section
              Text(localizations.steps, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              ..._steps.map((step) => _buildStepItem(step)).toList(),
              ElevatedButton(
                onPressed: _addStep,
                child: Text(localizations.addStep),
              ),
              SizedBox(height: 24),

              // Notes section
              Text(localizations.notes, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: localizations.notesHint,
                ),
              ),
              SizedBox(height: 24),

              // Image section
              Text(localizations.image, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      // TODO: Implement image picker
                    },
                    child: Text(localizations.uploadImage),
                  ),

                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientItem(Map<String, dynamic> ingredient) {
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: ingredient['name'] ?? '');
    final quantityController = TextEditingController(text: ingredient['quantity']?.toString() ?? '');
    final unitController = TextEditingController(text: ingredient['unit'] ?? '');

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: localizations.ingredientName,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => ingredient['name'] = value,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: localizations.quantity,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => ingredient['quantity'] = double.tryParse(value),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: unitController,
                    decoration: InputDecoration(
                      labelText: localizations.unit,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => ingredient['unit'] = value,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => setState(() => _ingredients.remove(ingredient)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(Map<String, dynamic> step) {
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;
    final textController = TextEditingController(text: step['text'] ?? '');

    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          children: [
            TextFormField(
              controller: textController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: localizations.stepText,
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => step['text'] = value,
            ),
            SizedBox(height: 8),
            // TODO: Add ingredient selection for this step
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => setState(() => _steps.remove(step)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add({
        'name': '',
        'quantity': 0,
        'unit': '',
      });
    });
  }

  void _addStep() {
    setState(() {
      _steps.add({
        'text': '',
        'order': _steps.length + 1,
        'ingredients': [],
      });
    });
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    final recipeData = {
      'name': _nameController.text,
      'preparationTime': int.tryParse(_prepTimeController.text),
      'difficulty': _difficulty,
      'servingSize': int.tryParse(_servingSizeController.text),
      'cuisineType': _cuisineType,
      'category': _categoryController.text,
      'labels': _labels,
      'equipment': _equipment,
      'notes': _notesController.text,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.recipe == null) {
        // Add new recipe
        final docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('recipes')
            .add(recipeData);

        // Add ingredients
        for (var ingredient in _ingredients) {
          await docRef.collection('ingredients').add({
            'name': ingredient['name'],
            'quantity': ingredient['quantity'],
            'unit': ingredient['unit'],
          });
        }

        // Add steps
        for (var step in _steps) {
          await docRef.collection('steps').add({
            'text': step['text'],
            'order': step['order'],
            'ingredients': step['ingredients'],
          });
        }
      } else {
        // Update existing recipe
        await widget.recipe!.reference.update(recipeData);

        // TODO: Update ingredients and steps (more complex implementation needed)
      }

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving recipe: $e')),
      );
    }
  }
}
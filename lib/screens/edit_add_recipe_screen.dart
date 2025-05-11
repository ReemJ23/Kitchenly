import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../utils/localization_helper.dart';
import '../utils/colors.dart';

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
  List<DocumentSnapshot> _existingIngredients = [];
  List<DocumentSnapshot> _existingSteps = [];
  File? _recipeImage;
  String? _imageBase64;
  final ImagePicker _picker = ImagePicker();

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
      if (data['imageBase64'] != null) {
        _imageBase64 = data['imageBase64'];
      }
      // Load existing ingredients and steps
      _loadExistingIngredientsAndSteps();
    }
    _fetchUserLanguage().then((language) {
      setState(() {
        _userLanguage = language;
      });
    });
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800, // Limit image size
        maxHeight: 800,
        imageQuality: 85, // Reduce quality to save space
      );

      if (pickedFile == null) return;

      final imageFile = File(pickedFile.path);
      final imageBytes = await imageFile.readAsBytes();

      // Check image size (limit to 1MB)
      if (imageBytes.length > 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.imageTooLarge)),
        );
        return;
      }

      setState(() {
        _recipeImage = imageFile;
        _imageBase64 = base64Encode(imageBytes);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text
          (AppLocalizations.of(context)!.imagePickFailed(e.toString()),
        )
        ),
      );
    }
  }


  // Fetch the user's preferred language from Firestore
  Future<String> _fetchUserLanguage() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    if (userDoc.exists) {
      return userDoc['language'] ??
          'en'; // Default to 'en' if language is not set
    }
    return 'en'; // Default to 'en' if the user document doesn't exist
  }

  Future<void> _loadExistingIngredientsAndSteps() async {
    final ingredientsSnapshot = await widget.recipe!.reference.collection(
        'ingredients').get();
    final stepsSnapshot = await widget.recipe!.reference.collection('steps')
        .get();

    setState(() {
      _existingIngredients = ingredientsSnapshot.docs;
      _existingSteps = stepsSnapshot.docs;

      // Populate ingredients list
      _ingredients = _existingIngredients.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'quantity': data['quantity'] ?? 0,
          'unit': data['unit'] ?? '',
        };
      }).toList();

      // Populate steps list
      _steps = _existingSteps.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'text': data['text'] ?? '',
          'order': data['order'] ?? _steps.length + 1,
          'ingredients': (data['ingredients'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],

        };
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;
    final isEditing = widget.recipe != null;
    final recipeData = isEditing ? widget.recipe!.data() as Map<String, dynamic> : {};

    return Scaffold(
      appBar: AppBar(
        title: Text(
            isEditing ? localizations.editRecipe : localizations.addRecipe),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveRecipe,
          ),
        ],
        centerTitle: true,
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
              Text(localizations.basicInfo,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                        DropdownMenuItem(value: 'easy',
                            child: Text(localizations.difficulty_easy)),
                        DropdownMenuItem(value: 'medium',
                            child: Text(localizations.difficulty_medium)),
                        DropdownMenuItem(value: 'hard',
                            child: Text(localizations.difficulty_hard)),
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
                        DropdownMenuItem(value: 'italian',
                            child: Text(localizations.cuisine_italian)),
                        DropdownMenuItem(value: 'mexican',
                            child: Text(localizations.cuisine_mexican)),
                        DropdownMenuItem(value: 'indian',
                            child: Text(localizations.cuisine_indian)),
                        DropdownMenuItem(value: 'chinese',
                            child: Text(localizations.cuisine_chinese)),
                        DropdownMenuItem(value: 'mediterranean',
                            child: Text(localizations.cuisine_mediterranean)),
                      ],
                      onChanged: (value) =>
                          setState(() => _cuisineType = value),
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
              Text(localizations.labels,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _labels.map((label) =>
                    Chip(
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
              Text(localizations.equipment,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _equipment.map((item) =>
                    Chip(
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
              Text(localizations.ingredients,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              ..._ingredients.map((ingredient) =>
                  _buildIngredientItem(ingredient)).toList(),
              Center(
              child: TextButton.icon(
                onPressed: _addIngredient,
                icon: Icon(Icons.add),
                label: Text(localizations.addIngredient),
              ),
              ),
              SizedBox(height: 24),

              // Steps section
              Text(localizations.steps,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              ..._steps.map((step) => _buildStepItem(step)).toList(),
              Center(
              child: TextButton.icon(
                onPressed: _addStep,
                icon: Icon(Icons.add),
                label: Text(localizations.addStep),
              ),
              ),
              SizedBox(height: 24),

              // Notes section
              Text(localizations.notes,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              Text(localizations.image,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),

              if (_recipeImage != null)
                Image.file(_recipeImage!, height: 200, fit: BoxFit.cover)

              else if (_imageBase64 != null && _imageBase64!.isNotEmpty)
                Image.memory(
                  base64Decode(_imageBase64!),
                  height: 200,
                  fit: BoxFit.cover,
                )
              else if (widget.recipe != null&&recipeData['imageBase64'] != null)
                  Image.memory(
                    base64Decode(recipeData['imageBase64']),
                    height: 200,
                    fit: BoxFit.cover,
                  )
                else
                  Text(localizations.noImageSelected),
              Center(child: TextButton.icon(
                onPressed: _pickImage,
                icon: Icon(Icons.upload),
                label: Text(localizations.uploadImage),
              ),),



            ],
          ),
        ),
      ),
    );
  }

  final List<String> _availableUnits = [
    'g',
    'lb',
    'oz',
    'liter',
    'pieces',
    'packs',
    'cups'
  ];

  Widget _buildIngredientItem(Map<String, dynamic> ingredient) {
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;

    final nameController = TextEditingController(
        text: ingredient['name'] ?? '');
    final quantityController = TextEditingController(
        text: ingredient['quantity']?.toString() ?? '');
    final unit = ingredient['unit'] ?? '';

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
                    onChanged: (value) =>
                    ingredient['quantity'] = double.tryParse(value),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _availableUnits.contains(unit.toLowerCase()) ? unit
                        .toLowerCase() : null,
                    decoration: InputDecoration(
                      labelText: localizations.unit,
                      border: OutlineInputBorder(),
                    ),
                    items: _availableUnits.map((unit) {
                      return DropdownMenuItem<String>(
                        value: unit.toLowerCase(),
                        child: Text(LocalizationHelper.getLocalizedString(
                            localizations, unit)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      ingredient['unit'] = value?.toLowerCase();
                    },
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.delete, color: AppColors.deleteBg),
                onPressed: () =>
                    setState(() => _ingredients.remove(ingredient)),
              ),
            ),
          ],
        ),
      ),
    );
  }

// Show ingredient selection dialog
  Future<void> _showIngredientSelectionDialog(Map<String, dynamic> step) async {
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;

    // Get current selected ingredient IDs (if any)
    List<String> selectedIngredients = List<String>.from(
        step['ingredients'] ?? []);

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(localizations.selectIngredients),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _ingredients.length,
                  itemBuilder: (context, index) {
                    final ingredient = _ingredients[index];
                    final ingredientId = index
                        .toString(); // Using index as ID for simplicity
                    final isSelected = selectedIngredients.contains(
                        ingredientId);

                    return CheckboxListTile(
                      title: Text(
                          '${ingredient['name']} (${ingredient['quantity']} ${ingredient['unit']})'),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            selectedIngredients.add(ingredientId);
                          } else {
                            selectedIngredients.remove(ingredientId);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(localizations.cancel),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      step['ingredients'] = selectedIngredients;
                    });
                    Navigator.pop(context);
                  },
                  child: Text(localizations.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStepItem(Map<String, dynamic> step) {
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;
    final textController = TextEditingController(text: step['text'] ?? '');

    // Get names of selected ingredients for display
    final selectedIngredientNames = (step['ingredients'] as List<dynamic>? ??
        [])
        .map((id) => id.toString())
        .map((id) {
      final index = int.tryParse(id);
      if (index != null && index >= 0 && index < _ingredients.length) {
        return _ingredients[index]['name'];
      }
      return null;
    })
        .where((name) => name != null)
        .join(', ');


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
            SizedBox(height: 10),
            // Display selected ingredients
            if (selectedIngredientNames.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  '${localizations.ingredients}: $selectedIngredientNames',
                  style: TextStyle(fontSize: 14, color: AppColors.heading2),
                ),
              ),
            // Button to select ingredients
            ElevatedButton(
              onPressed: () => _showIngredientSelectionDialog(step),
              child: Text(localizations.selectIngredients),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.delete, color: AppColors.deleteBg),
                onPressed: () => setState(() => _steps.remove(step)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addIngredient() {
    if (_ingredients.isNotEmpty) {
      final last = _ingredients.last;
      if ((last['name'] as String).trim().isEmpty ||
          last['quantity'] == null ||
          last['quantity'].toString().isEmpty ||
          last['unit'] == null ||
          (last['unit'] as String).trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.fillPreviousIngredient)),
        );
        return;
      }
    }
    setState(() {
      _ingredients.add({
        'name': '',
        'quantity': 0,
        'unit': '',
      });
    });
  }

  void _addStep() {
    if (_steps.isNotEmpty) {
      final last = _steps.last;
      if ((last['text'] as String).trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.fillPreviousStep)),
        );
        return;
      }
    }

    setState(() {
      _steps.add({
        'text': '',
        'order': _steps.length + 1,
        'ingredients': [],
      });
    });
  }

  // Modified save method
  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
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
        'imageBase64': _imageBase64 ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      DocumentReference recipeRef;
      if (widget.recipe == null) {
        // Create new recipe
        recipeRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('recipes')
            .add(recipeData);
      } else {
        // Update existing recipe
        recipeRef = widget.recipe!.reference;
        await recipeRef.update(recipeData);
      }
      final ingredientIds = await _saveIngredients(recipeRef);
      await _saveSteps(recipeRef, ingredientIds);

      Navigator.pop(context); // Close loading
      Navigator.pop(context); // Return to previous screen
    } catch (e) {
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorSavingRecipe(e.toString())),)
      );
    }
  }
  Future<Map<int, String>> _saveIngredients(DocumentReference recipeRef) async {
    final ingredientsCollection = recipeRef.collection('ingredients');

    // Delete old ingredients if editing
    if (widget.recipe != null) {
      final existingIngredients = await ingredientsCollection.get();
      for (final doc in existingIngredients.docs) {
        await doc.reference.delete();
      }
    }

    // Save new ingredients and collect their new Firestore IDs
    Map<int, String> ingredientIds = {};

    for (int i = 0; i < _ingredients.length; i++) {
      final ingredient = _ingredients[i];
      final docRef = await ingredientsCollection.add({
        'name': ingredient['name'],
        'quantity': ingredient['quantity'],
        'unit': ingredient['unit'],
      });
      ingredientIds[i] = docRef.id; // Map local index to Firestore ID
    }

    return ingredientIds;
  }

  Future<void> _saveSteps(DocumentReference recipeRef, Map<int, String> ingredientIds) async {
    final stepsCollection = recipeRef.collection('steps');

    // Delete old steps if editing
    if (widget.recipe != null) {
      final existingSteps = await stepsCollection.get();
      for (final doc in existingSteps.docs) {
        await doc.reference.delete();
      }
    }

    // Save steps correctly
    for (final step in _steps) {
      List<String> ingredientFirestoreIds = [];

      if (step['ingredients'] != null) {
        for (var indexString in step['ingredients']) {
          if (indexString != null) {
            final index = int.tryParse(indexString.toString());
            if (index != null && ingredientIds.containsKey(index)) {
              final firestoreId = ingredientIds[index];
              if (firestoreId != null) {
                ingredientFirestoreIds.add(firestoreId);
              }
            }
          }
        }
      }

      await stepsCollection.add({
        'text': step['text'] ?? '',
        'order': step['order'] ?? 0,
        'ingredients': ingredientFirestoreIds,
      });
    }
  }


}
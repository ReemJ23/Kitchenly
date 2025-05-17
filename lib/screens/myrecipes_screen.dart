import 'dart:io';

import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kitchenly/screens/profile_screen.dart';
import 'package:kitchenly/screens/recipe_stepper.dart';
import '../models/dummy_document_snapshot.dart';
import '../models/recipeStep.dart';
import '../utils/localization_helper.dart';
import 'edit_add_recipe_screen.dart';
import 'dart:convert';
import '../utils/colors.dart';
const String SYSTEM_PROMPT = """
You are a helpful chef AI that extracts structured recipe information from messy or scanned text.

Return ONLY a JSON object in this format:
{
  "name": String,
  "servingSize": int,
  "preparationTime": int, // in minutes
  "ingredients": [{"quantity": Number, "unit": String, "name": String}],
  "steps": [{"order": Number, "text": String, "ingredientIds": [String]}]
}

- Try to infer reasonable defaults if any value is missing.
- Do not include any markdown, explanations, or code blocks — only return the JSON object.
""";





String? lang;
class _RecipeCardData {
  final int availableIngredients;
  final int totalIngredients;
  final Color availabilityColor;

  _RecipeCardData(this.availableIngredients, this.totalIngredients, this.availabilityColor);
}
class MyRecipesScreen extends StatefulWidget {
  const MyRecipesScreen({Key? key}) : super(key: key);

  @override
  _MyRecipesScreenState createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';
  String _selectedCuisine = 'all';
  String _selectedDifficulty = 'all';
  String _selectedTime = 'all';
  String _selectedAvailability = 'all';

  // Filter options (these should be populated from your recipes data)
  final List<String> _cuisineTypes = ['all', 'italian', 'mexican', 'indian', 'chinese', 'mediterranean'];
  final List<String> _difficultyLevels = ['all', 'easy', 'medium', 'hard'];
  final List<String> _timeCategories = ['all', 'quick', 'medium', 'long'];
  final List<String> _availabilityOptions = ['all', 'full', 'partial', 'low'];
  String? _userLanguage;


  @override
  void initState() {
    super.initState();
    _fetchUserLanguage().then((language) {
      setState(() {
        _userLanguage = language;
        lang=language;
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

  String cleanJson(String response) {
    final regex = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final match = regex.firstMatch(response);
    return match != null ? match.group(1)! : response;
  }
  Future<(Map<String, dynamic>, DocumentReference?)> processImageForRecipe(XFile imageFile) async {
    // 1. Initialize OpenAI
    OpenAI.apiKey = "sk-7d0d0c01152346a288aba518e6c2de58";
    OpenAI.baseUrl = "https://dashscope-intl.aliyuncs.com/compatible-mode";

    // 2. Perform OCR
    final inputImage = InputImage.fromFile(File(imageFile.path));
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    final String extractedText = recognizedText.text;
    textRecognizer.close();

    // 3. Process with OpenAI
    try {
      final chatCompletion = await OpenAI.instance.chat.create(
        model: "qwen2.5-72b-instruct",
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(SYSTEM_PROMPT),
            ],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(extractedText),
            ],
          ),
        ],
      );

      final responseContent = chatCompletion.choices.first.message.content;
      final textContent = responseContent?.first.text ?? '';
      print("AI Raw Response: $textContent");

      // ✅ Clean response by stripping triple backticks and 'json'
      final cleanedJson = _stripMarkdown(textContent);

      // ✅ Parse JSON
      final recipeData = jsonDecode(cleanedJson) as Map<String, dynamic>;
      return (recipeData, null);
    } catch (e) {
      print("AI Processing Error: $e");
      final fallback = await fallbackOcrParsing('');
      return fallback;
    }
  }

// ✅ Helper function to remove markdown formatting
  String _stripMarkdown(String input) {
    final regex = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final match = regex.firstMatch(input);
    return match != null ? match.group(1)! : input;
  }


  Future<(Map<String, dynamic>, DocumentReference?)> fallbackOcrParsing(String extractedText) async {
    List<String> lines = extractedText.split('\n');
    String name = '';
    int servings = 0;
    int prepTime = 0;
    List<String> ingredients = [];
    List<String> steps = [];
    bool inIngredients = false;
    bool inSteps = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase().trim();

      if (line.contains('name') || line == 'ame') {
        name = i + 1 < lines.length ? lines[i + 1].trim() : '';
      } else if (line.contains('serving')) {
        servings = int.tryParse(RegExp(r'\d+').firstMatch(lines[i])?.group(0) ?? '0') ?? 0;
      } else if (line.contains('prep')) {
        prepTime = int.tryParse(RegExp(r'\d+').firstMatch(lines[i])?.group(0) ?? '0') ?? 0;
      } else if (line.contains('ingredient')) {
        inIngredients = true;
        inSteps = false;
      } else if (line.contains('instruction') || line.contains('step') || line.contains('method')) {
        inIngredients = false;
        inSteps = true;
      } else if (inIngredients && line.isNotEmpty) {
        ingredients.add(lines[i].trim());
      } else if (inSteps && line.isNotEmpty) {
        steps.add(lines[i].trim());
      }
    }

    final fallbackData = {
      'name': name,
      'preparationTime': prepTime,
      'servingSize': servings,
      'category': '',
      'notes': '',
      'ingredients': ingredients,
      'steps': steps,
    };

    return (fallbackData, null); // ✅ Return plain data, no document reference
  }


  Stream<bool> hasUnreadNotifications(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }


  @override
  Widget build(BuildContext context) {
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.myRecipes),
        centerTitle: true,
        leading: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .collection('notifications')
              .where('read', isEqualTo: false)
              .snapshots(),
          builder: (context, snapshot) {
            final hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

            return Stack(
              children: [
                IconButton(
                    icon: CircleAvatar(
                      backgroundImage: AssetImage('assets/images/icons/profile_chef_icon.png'),
                      backgroundColor: AppColors.profileIconBg,
                      ),
                  tooltip: AppLocalizations.of(context)!.profile,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileScreen()),
                    );
                  },
                ),
                if (hasUnread)
                  const Positioned(
                    right: 8,
                    top: 8,
                    child: CircleAvatar(
                      radius: 5,
                      backgroundColor: Colors.red,
                    ),
                  ),
              ],
            );
          },
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'manual') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditRecipePage()),
                );
              } else {
                final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (image != null) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                      content: Row(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(width: 20),
                          Text(localizations.processingImage ?? 'Processing image...'),
                        ],
                      ),
                    ),
                  );

                  try {
                    final (recipeData, recipeRef) = await processImageForRecipe(image);

                    if (!mounted) return;
                    Navigator.pop(context); // Close the loading dialog

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditRecipePage(
                          recipeData: recipeData,
                          recipeRef: recipeRef,
                        ),
                      ),
                    );
                  } catch (e) {
                    if (mounted) Navigator.pop(context); // Close the dialog

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(localizations.errorProcessingImage ?? 'Failed to process image.'),
                      ),
                    );
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'manual', child: Text('Enter Manually')),
              const PopupMenuItem(value: 'gallery', child: Text('Upload from Gallery')),
              const PopupMenuItem(value: 'camera', child: Text('Take a Picture')),
            ],
            icon: const Icon(Icons.add),
          ),
        ],

      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: localizations.searchRecipes,
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          _buildFilterChips(localizations),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('recipes')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final recipes = snapshot.data!.docs;
                if (recipes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu_rounded,
                          size: 95,
                          color: AppColors.iconColor,
                        ),
                        SizedBox(height: 16),
                        Text(
                          localizations.noRecipesFound,
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.heading2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Apply filters
                var filteredRecipes = recipes.where((recipe) {
                  final data = recipe.data() as Map<String, dynamic>;
                  final name = data['name']?.toString().toLowerCase() ?? '';
                  final searchTerm = _searchController.text.toLowerCase();

                  // Search filter
                  if (searchTerm.isNotEmpty && !name.contains(searchTerm)) {
                    return false;
                  }

                  // Cuisine filter
                  if (_selectedCuisine != 'all' &&
                      (data['cuisineType']?.toString().toLowerCase() ?? '') != _selectedCuisine) {
                    return false;
                  }

                  // Difficulty filter
                  if (_selectedDifficulty != 'all' &&
                      (data['difficulty']?.toString().toLowerCase() ?? '') != _selectedDifficulty) {
                    return false;
                  }

                  // Time filter
                  if (_selectedTime != 'all') {
                    final prepTime = data['preparationTime'] as int? ?? 0;
                    if (_selectedTime == 'quick' && prepTime > 30) return false;
                    if (_selectedTime == 'tmedium' && (prepTime <= 30 || prepTime > 60)) return false;
                    if (_selectedTime == 'long' && prepTime <= 60) return false;
                  }

                  return true;
                }).toList();

                return ListView.builder(
                  itemCount: filteredRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = filteredRecipes[index];
                    final data = recipe.data() as Map<String, dynamic>;
                    return _buildRecipeCard(context, recipe, data, localizations);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(AppLocalizations localizations) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            FilterChip(
              label: Text(LocalizationHelper.getLocalizedString(localizations, 'all')),
              selected: _selectedFilter == 'all',
              onSelected: (selected) => setState(() => _selectedFilter = 'all'),
            ),
            SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.cuisine,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                DropdownButton<String>(
                  value: _selectedCuisine,
                  isDense: true,
                  items: _cuisineTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(LocalizationHelper.getLocalizedString(localizations, type)),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedCuisine = value!),
                ),
              ],
            ),
            SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.preparationTime,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                DropdownButton<String>(
                  value: _selectedTime,
                  isDense: true,
                  items: _timeCategories.map((time) {
                    return DropdownMenuItem(
                      value: time,
                      child: Text(LocalizationHelper.getLocalizedString(localizations, time)),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedTime = value!),
                ),
              ],
            ),
            SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.ingredientAvailability,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                DropdownButton<String>(
                  value: _selectedAvailability,
                  isDense: true,
                  items: _availabilityOptions.map((avail) {
                    return DropdownMenuItem(
                      value: avail,
                      child: Text(LocalizationHelper.getLocalizedString(localizations, avail)),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedAvailability = value!),
                ),
              ],
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildRecipeCard(BuildContext context, DocumentSnapshot recipe,
      Map<String, dynamic> data, AppLocalizations localizations) {
    return FutureBuilder(
      future: _getRecipeCardData(recipe),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ));
        }

        final cardData = snapshot.data!;

        return Card(
          margin: EdgeInsets.all(8),
          child: InkWell(
            onTap: () => _viewRecipeDetails(recipe),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // Recipe image or placeholder
                  if (data['imageBase64'] != null && data['imageBase64'].toString().isNotEmpty)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: data['imageBase64'].toString().startsWith('http')
                            ? CachedNetworkImage(
                          imageUrl: data['imageBase64'],
                          height: 60,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Icon(Icons.error),
                        )
                            : Image.memory(
                          base64Decode(data['imageBase64'].split(',').last),
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(Icons.error),
                        ),
                      ),
                    )
                    else Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.fastfood, size: 30, color: Colors.grey[600]),
                    ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['name'] ?? localizations.untitledRecipe,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.timer, size: 14, color: Colors.grey),
                            SizedBox(width: 4),
                            Text(
                              '${data['preparationTime'] ?? '?'} ${localizations.minutes}',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            SizedBox(width: 12),
                            Icon(Icons.star, size: 14, color: Colors.grey),
                            SizedBox(width: 4),
                            Text(
                              data['difficulty']?.toString().toUpperCase() ?? '?',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '${cardData.availableIngredients}/${cardData.totalIngredients}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: cardData.availabilityColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      if (data['labels'] != null && (data['labels'] as List).isNotEmpty)
                        Wrap(
                          spacing: 4,
                          children: (data['labels'] as List).take(2).map((label) {
                            return Chip(
                              label: Text(label.toString()),
                              backgroundColor: Colors.blue[50],
                              labelStyle: TextStyle(fontSize: 10),
                              visualDensity: VisualDensity.compact,
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<_RecipeCardData> _getRecipeCardData(DocumentSnapshot recipe) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _RecipeCardData(0, 0, Colors.grey);

    // 1. Get all ingredients from the recipe
    final ingredientsQuery = await recipe.reference.collection('ingredients').get();
    final totalIngredients = ingredientsQuery.docs.length;

    // 2. Check inventory for available ingredients
    int availableIngredients = 0;

    for (final ingredientDoc in ingredientsQuery.docs) {
      final ingredient = ingredientDoc.data() as Map<String, dynamic>;
      final inventoryItem = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('inventory')
          .where('name', isEqualTo: ingredient['name'])
          .where('unit', isEqualTo: ingredient['unit'])
          .get();

      if (inventoryItem.docs.isNotEmpty) {
        final inventoryData = inventoryItem.docs.first.data();
        final requiredQty = double.parse(ingredient['quantity'].toString());
        final availableQty = double.parse(inventoryData['quantity'].toString());

        if (availableQty >= requiredQty) {
          availableIngredients++;
        }
      }
    }

    // Calculate availability ratio
    final availabilityRatio = totalIngredients > 0
        ? availableIngredients / totalIngredients
        : 0;

    // Determine availability color
    Color availabilityColor;
    if (availabilityRatio == 1) {
      availabilityColor = Colors.green;
    } else if (availabilityRatio >= 0.5) {
      availabilityColor = Colors.orange;
    } else {
      availabilityColor = Colors.red;
    }

    return _RecipeCardData(availableIngredients, totalIngredients, availabilityColor);
  }


  void _viewRecipeDetails(DocumentSnapshot recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return RecipeDetailsSheet(recipe: recipe);
      },
    );
  }
}
void _confirmDeleteRecipe(BuildContext context, DocumentSnapshot recipe) {
  final localizations = AppLocalizations.of(context)!;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(localizations.confirmDelete),
        content: Text(localizations.areYouSureDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Cancel
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () async {
              try {
                Navigator.pop(context); // Close confirmation dialog
                Navigator.pop(context); // Close recipe details bottom sheet
                await recipe.reference.delete();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(localizations.recipeDeletedSuccessfully)),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${localizations.failedToDeleteRecipe}: $e')),
                );
              }
            },
            child: Text(localizations.delete, style: TextStyle(color: Colors.red)),
          ),
        ],
      );
    },
  );
}

class RecipeDetailsSheet extends StatefulWidget {
  final DocumentSnapshot recipe;

  RecipeDetailsSheet({Key? key, required this.recipe}) : super(key: key);

  @override
  State<RecipeDetailsSheet> createState() => _RecipeDetailsSheetState();
}

class _RecipeDetailsSheetState extends State<RecipeDetailsSheet> {
  double _multiplier = 1.0;
  final List<double> _multiplierOptions = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0];

  @override
  Widget build(BuildContext context) {
    final localizations = lang != null
        ? lookupAppLocalizations(Locale(lang!))
        : AppLocalizations.of(context)!;
    final data = widget.recipe.data() as Map<String, dynamic>;

    return Container(
      padding: EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: MediaQuery.of(context).size.width*0.67,
                child: Text(
                  data['name'] ?? localizations.untitledRecipe,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  softWrap: true,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => EditRecipePage(
                        recipeData: widget.recipe.data() as Map<String, dynamic>?,
                        recipeRef: widget.recipe.reference,
                      )
                      ));
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete),
                    color: Colors.red,
                    onPressed: () => _confirmDeleteRecipe(context, widget.recipe),
                  ),
                ],
              ),
            ],
          ),
          if (data['imageBase64'] != null && data['imageBase64'].toString().isNotEmpty)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: data['imageBase64'].toString().startsWith('http')
                    ? CachedNetworkImage(
                  imageUrl: data['imageBase64'],
                  height: 150,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Icon(Icons.error),
                )
                    : Image.memory(
                  base64Decode(data['imageBase64'].split(',').last),
                  height: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(Icons.error),
                ),
              ),
            ),
          SizedBox(height: 16),
          // Recipe metadata
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (data['preparationTime'] != null)
                _buildMetadataItem(Icons.timer, '${data['preparationTime']} ${localizations.minutes}'),
              if (data['difficulty'] != null)
                _buildMetadataItem(Icons.star, LocalizationHelper.getLocalizedString(localizations, 'difficulty')),
              if (data['servingSize'] != null)
                _buildMetadataItem(Icons.people, '${data['servingSize']} ${localizations.servings}'),
              if (data['category'] != null)
                _buildMetadataItem(Icons.category, data['category']),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Text('${localizations.scaleIngredients}: '),
              DropdownButton<double>(
                value: _multiplier,
                items: _multiplierOptions.map((value) {
                  return DropdownMenuItem<double>(
                    value: value,
                    child: Text('x$value'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _multiplier = value!;
                  });
                },
              ),
            ],
          ),
          SizedBox(height: 16),
          // Ingredients section
          Text(
            localizations.ingredients,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.recipe.reference.collection('ingredients').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final ingredientDoc = snapshot.data!.docs[index];
                    final ingredient = ingredientDoc.data() as Map<String, dynamic>;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.circle, size: 8),
                      title: Text(
                        '${(double.parse(ingredient['quantity'].toString()) * _multiplier).toStringAsFixed(2)} '
                            '${ingredient['unit']} ${ingredient['name']}',
                        softWrap: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(height: 16),
          // Steps section
          Text(
            localizations.steps,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.recipe.reference.collection('steps').orderBy('order').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final step = snapshot.data!.docs[index];
                    final stepData = step.data() as Map<String, dynamic>;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text('${index + 1}', style: TextStyle(color: Colors.white)),
                      ),
                      title: Text(
                          stepData['text'] ?? '',
                          softWrap: true, // Enable text wrapping
                      ),
                    );
                  },
                );
              },
            ),
          ),
          ElevatedButton(
            // In RecipeDetailsSheet's button onPressed:
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(child: CircularProgressIndicator()),
              );

              try {
                final recipeRef = FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('recipes')
                    .doc(widget.recipe.id);

                final ingredientsSnapshot = await recipeRef
                    .collection('ingredients')
                    .get();

                final ingredientsMap = {
                  for (var doc in ingredientsSnapshot.docs)
                    doc.id: doc.data()
                };

                final stepsSnapshot = await recipeRef
                    .collection('steps')
                    .orderBy('order')
                    .get();

                List<RecipeStep> steps = [];
                for (var stepDoc in stepsSnapshot.docs) {
                  final stepData = stepDoc.data();
                  List<Ingredient> stepIngredients = [];
                  if (stepData['ingredients'] != null) {
                    for (var id in List<String>.from(stepData['ingredients'])) {
                      if (ingredientsMap.containsKey(id)) {
                        final ing = ingredientsMap[id]!;
                        stepIngredients.add(Ingredient(
                          id: id,
                          name: ing['name'] ?? 'Unknown',
                          quantity: double.parse(ing['quantity'].toString()),
                          unit: ing['unit'] ?? '',
                        ));
                      }
                    }
                  }

                  steps.add(RecipeStep(
                    stepNumber: stepData['order'] ?? steps.length + 1,
                    instructions: stepData['text'] ?? '',
                    ingredients: stepIngredients,
                  ));
                }

                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecipeStepper(
                      steps: steps,
                      recipeName: data['name'] ?? localizations.untitledRecipe,
                      multiplier: _multiplier, // Pass the selected multiplier
                    ),
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            },
            child: Text(localizations.startcooking),
          ),
        ],
      ),
    );
  }

  List<RecipeStep> _parseSteps(Map<String, dynamic> recipeData) {
    // Implement parsing logic based on your database structure
    // Example:
    List<RecipeStep> steps = [];
    for (var step in recipeData['steps']) {
      steps.add(RecipeStep(
        stepNumber: step['stepNumber'],
        instructions: step['instructions'],
        ingredients: step['ingredients'].map<Ingredient>((ing) => Ingredient(
          id: ing['id'],
          name: ing['name'],
          quantity: ing['quantity'],
          unit: ing['unit'],
        )).toList(),
      ));
    }
    return steps;
  }
}

  Widget _buildMetadataItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        SizedBox(width: 4),
        Text(text, style: TextStyle(color: Colors.grey)),
      ],
    );
  }



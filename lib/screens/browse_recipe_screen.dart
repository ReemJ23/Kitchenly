import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../utils/localization_helper.dart';
import 'package:kitchenly/utils/colors.dart';

class RecipeBrowserPage extends StatefulWidget {
  const RecipeBrowserPage({Key? key}) : super(key: key);

  @override
  _RecipeBrowserPageState createState() => _RecipeBrowserPageState();
}

class _RecipeBrowserPageState extends State<RecipeBrowserPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> _recipes = [];
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _userLanguage;

  @override
  void initState() {
    super.initState();
    _fetchRandomRecipes();
    _fetchUserLanguage().then((language) {
      setState(() {
        _userLanguage = language;
      });
    });
  }

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

  Future<void> _fetchRandomRecipes() async {
    setState(() => _isLoading = true);
    try {
      final futures = List.generate(5, (_) => http.get(
        Uri.parse('https://www.themealdb.com/api/json/v1/1/random.php'),
      ));

      final responses = await Future.wait(futures);
      final recipes = responses.map((res) {
        final data = json.decode(res.body);
        if (data['meals'] != null && data['meals'].isNotEmpty) {
          return _convertApiRecipeToAppFormat(data['meals'][0]);
        }
        return null;
      }).whereType<Map<String, dynamic>>().toList();

      setState(() => _recipes = recipes);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.fetchRecipesFailed(e.toString()))),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _searchRecipes() async {
    if (_searchQuery.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://www.themealdb.com/api/json/v1/1/search.php?s=$_searchQuery'),
      );
      final data = json.decode(response.body);
      if (data['meals'] != null) {
        setState(() {
          _recipes = data['meals'].map<Map<String, dynamic>>((apiRecipe) {
            return _convertApiRecipeToAppFormat(apiRecipe);
          }).toList();
        });
      } else {
        setState(() => _recipes = []);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.noRecipesFoundFor(_searchQuery))),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.searchFailed(e.toString()))),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _convertApiRecipeToAppFormat(Map<String, dynamic> apiRecipe) {
    // Extract ingredients and measures
    List<Map<String, dynamic>> ingredients = [];
    for (int i = 1; i <= 20; i++) {
      final ingredient = apiRecipe['strIngredient$i'];
      final measure = apiRecipe['strMeasure$i'];
      if (ingredient != null && ingredient.isNotEmpty) {
        ingredients.add({
          'name': ingredient,
          'quantity': _parseQuantity(measure),
          'unit': _parseUnit(measure),
        });
      }
    }

    // Convert instructions to steps
    List<Map<String, dynamic>> steps = [];
    final instructions = (apiRecipe['strInstructions'] ?? '').split('\r\n');
    int stepNumber = 1;
    for (final instruction in instructions) {
      if (instruction.trim().isNotEmpty) {
        steps.add({
          'text': instruction,
          'order': stepNumber++,
          'ingredients': [], // Can be populated later if needed
        });
      }
    }

    return {
      'idFromApi': apiRecipe['idMeal'],
      'name': apiRecipe['strMeal'],
      'preparationTime': _estimatePrepTime(ingredients, steps),
      'difficulty': _determineDifficulty(apiRecipe),
      'cuisineType': apiRecipe['strArea']?.toLowerCase(),
      'imageBase64': apiRecipe['strMealThumb'],
      'category': apiRecipe['strCategory'],
      'ingredients': ingredients,
      'steps': steps,
      'source': 'TheMealDB',
    };
  }

  double _parseQuantity(String measure) {
    // Simple parsing - could be enhanced
    try {
      final numericPart = measure.split(' ').first;
      if (numericPart.contains('/')) {
        final parts = numericPart.split('/');
        return double.parse(parts[0]) / double.parse(parts[1]);
      }
      return double.tryParse(numericPart) ?? 1.0;
    } catch (e) {
      return 1.0;
    }
  }

  String _parseUnit(String measure) {
    // Simple parsing - could be enhanced
    final parts = measure.split(' ');
    if (parts.length > 1) {
      return parts.sublist(1).join(' ').trim();
    }
    return 'unit';
  }

  String _determineDifficulty(Map<String, dynamic> recipe) {
    // Simple determination - could be enhanced
    final ingredientsCount = List.generate(20, (i) => i + 1)
        .where((i) => recipe['strIngredient$i']?.isNotEmpty ?? false)
        .length;

    return ingredientsCount > 10 ? 'hard' : ingredientsCount > 5 ? 'medium' : 'easy';
  }

  int _estimatePrepTime(List ingredients, List steps) {
    return (ingredients.length * 2 + steps.length * 3).clamp(5, 90);
  }

  Future<void> _saveRecipeToMyRecipes(Map<String, dynamic> recipe) async {
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      // Check if recipe already exists
      final existingRecipe = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('recipes')
          .where('idFromApi', isEqualTo: recipe['idFromApi'])
          .limit(1)
          .get();

      if (existingRecipe.docs.isNotEmpty) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.recipeAlreadySaved)),
        );
        return;
      }

      // Add to Firestore
      final recipeRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('recipes')
          .add({
        ...recipe,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Save ingredients subcollection
      final ingredients = recipe['ingredients'] as List<Map<String, dynamic>>;
      for (final ingredient in ingredients) {
        await recipeRef.collection('ingredients').add(ingredient);
      }

      // Save steps subcollection
      final steps = recipe['steps'] as List<Map<String, dynamic>>;
      for (final step in steps) {
        await recipeRef.collection('steps').add(step);
      }

      Navigator.pop(context);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 48), // larger icon
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)!.recipeSaved,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );


      Future.delayed(const Duration(seconds: 2), () {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.saveRecipeFailed(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.browseRecipes),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchRandomRecipes,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: localizations.searchRecipes,
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                    onSubmitted: (_) => _searchRecipes(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.search),
                  onPressed: _searchRecipes,
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _recipes.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: 85,
                    color: AppColors.iconColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    localizations.noRecipesFound,
                    style: const TextStyle(fontSize: 16, color: AppColors.heading2),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _recipes.length,
              itemBuilder: (context, index) {
                final recipe = _recipes[index];
                return _buildRecipeCard(recipe, localizations);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe, AppLocalizations loc) {
    return Card(
      margin: EdgeInsets.all(8),
      child: InkWell(
        onTap: () => _showRecipeDetails(recipe),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recipe['imageBase64'] != null)
              Image.network(
                recipe['imageBase64'],
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe['name'] ?? loc.untitledRecipe,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.timer, size: 16),
                      SizedBox(width: 4),
                      Text('${recipe['preparationTime']} ${loc.minutes}'),
                      SizedBox(width: 16),
                      Icon(Icons.star, size: 16),
                      SizedBox(width: 4),
                      Text(LocalizationHelper.getLocalizedString(loc, recipe['difficulty'])),
                      SizedBox(width: 20),
                      Text(
                        '${recipe['ingredients'].length} ${loc.ingredients}',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        onPressed: () => _saveRecipeToMyRecipes(recipe),
                        child: Text(loc.saveRecipe),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecipeDetails(Map<String, dynamic> recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.8,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width*0.75,
                      child: Text(
                        recipe['name'],
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        softWrap: true,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                if (recipe['imageBase64'] != null)
                  Center(
                    child: Image.network(
                      recipe['imageBase64'],
                      height: 150,
                      fit: BoxFit.cover,
                    ),
                  ),
                SizedBox(height: 16),
                Text(
                  'Ingredients',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                ...recipe['ingredients'].map<Widget>((ingredient) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.circle, size: 8),
                    title: Text(
                      '${ingredient['quantity']} ${ingredient['unit']} ${ingredient['name']}',
                    ),
                  );
                }).toList(),
                SizedBox(height: 16),
                Text(
                  'Instructions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                // ...recipe['steps'].map<Widget>((step) {
                //   return ListTile(
                //     contentPadding: EdgeInsets.zero,
                //     leading: CircleAvatar(
                //       radius: 12,
                //       child: Text('${step['order']}'),
                //     ),
                //     title: Text(step['text']),
                //   );
                // }).toList(),
                ...List.generate(recipe['steps'].length * 2 - 1, (index) {
                  if (index.isEven) {
                    final step = recipe['steps'][index ~/ 2];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 12,
                        child: Text('${step['order']}'),
                      ),
                      title: Text(step['text']),
                    );
                  } else {
                    return const Divider(thickness: 1.0, height: 24);
                  }
                }),
                SizedBox(height: 16),
                Center(
                  child: ElevatedButton(
                    onPressed: () => _saveRecipeToMyRecipes(recipe),
                    child: Text(AppLocalizations.of(context)!.saveToMyRecipes),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
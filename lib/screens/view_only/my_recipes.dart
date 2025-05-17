import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import '../../utils/colors.dart';
import '../../utils/localization_helper.dart';

class ViewOnlyRecipeScreen extends StatefulWidget {
  final String familyOwnerId;
  final String language;

  const ViewOnlyRecipeScreen({
    required this.familyOwnerId,
    required this.language,
    Key? key,
  }) : super(key: key);

  @override
  _ViewOnlyRecipeScreenState createState() => _ViewOnlyRecipeScreenState();
}

class _ViewOnlyRecipeScreenState extends State<ViewOnlyRecipeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';
  String _selectedCuisine = 'all';
  String _selectedDifficulty = 'all';
  String _selectedTime = 'all';
  String _selectedAvailability = 'all';
  late AppLocalizations localizations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    localizations = AppLocalizations.of(context)!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.recipes+" - "+localizations.readOnlyMode),
        centerTitle: true,
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
          _buildFilterChips(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.familyOwnerId)
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
                    if (_selectedTime == 'medium' && (prepTime <= 30 || prepTime > 60)) return false;
                    if (_selectedTime == 'long' && prepTime <= 60) return false;
                  }

                  return true;
                }).toList();
                if (filteredRecipes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu_rounded,
                          size: 85,
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
                return ListView.builder(
                  itemCount: filteredRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = filteredRecipes[index];
                    final data = recipe.data() as Map<String, dynamic>;
                    return _buildRecipeCard(context, recipe, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final List<String> _cuisineTypes = ['all', 'italian', 'mexican', 'indian', 'chinese', 'mediterranean'];
    final List<String> _difficultyLevels = ['all', 'easy', 'medium', 'hard'];
    final List<String> _timeCategories = ['all', 'quick', 'medium', 'long'];
    final List<String> _availabilityOptions = ['all', 'full', 'partial', 'low'];
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
                Text(localizations.cuisine, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
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
                Text(localizations.difficulty, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                DropdownButton<String>(
                  value: _selectedDifficulty,
                  isDense: true,
                  items: _difficultyLevels.map((level) {
                    return DropdownMenuItem(
                      value: level,
                      child: Text(LocalizationHelper.getLocalizedString(localizations, level)),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedDifficulty = value!),
                ),
              ],
            ),
            SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(localizations.preparationTime, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
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
                Text(localizations.ingredientAvailability, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
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

  Widget _buildRecipeCard(BuildContext context, DocumentSnapshot recipe, Map<String, dynamic> data) {
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
        ),
      ),
    );
  }

  void _viewRecipeDetails(DocumentSnapshot recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return ViewOnlyRecipeDetailsSheet(recipe: recipe, language: widget.language);
      },
    );
  }
}

class ViewOnlyRecipeDetailsSheet extends StatelessWidget {
  final DocumentSnapshot recipe;
  final String language;

  const ViewOnlyRecipeDetailsSheet({
    required this.recipe,
    required this.language,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = lookupAppLocalizations(Locale(language));
    final data = recipe.data() as Map<String, dynamic>;

    return Container(
      padding: EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data['name'] ?? localizations.untitledRecipe,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
          // Ingredients section
          Text(
            localizations.ingredients,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: recipe.reference.collection('ingredients').snapshots(),
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
                        '${ingredient['quantity']} ${ingredient['unit']} ${ingredient['name']}',
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
              stream: recipe.reference.collection('steps').orderBy('order').snapshots(),
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
                        softWrap: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
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
}
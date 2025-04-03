import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../utils/colors.dart';


import '../utils/localization_helper.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _newCategoryController = TextEditingController();
  final TextEditingController _editItemNameController = TextEditingController();
  final TextEditingController _editQuantityController = TextEditingController();
  final TextEditingController _editCategoryController = TextEditingController();
  String? _selectedUnit = "kg";
  String? _selectedCategory;
  DateTime? _expirationDate;
  User? user = FirebaseAuth.instance.currentUser;
  String? _userLanguage;

  @override
  void initState() {
    super.initState();
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

  // Fetch existing categories dynamically
  Future<List<String>> _fetchCategories() async {
    var snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('inventory')
        .get();

    Set<String> categories = {};

    for (var doc in snapshot.docs) {
      categories.add(doc['category']);
    }

    return categories.toList();
  }

  // Add an item to a selected or new category
  void _addItem() async {
    String quantityText = _quantityController.text.trim();
    int quantity = int.tryParse(quantityText) ?? 0;

    // Validation checks
    if (_itemNameController.text.trim().isEmpty ||
        quantity <= 0 ||
        quantity > 999) {
      // Show error if quantity is invalid
      _showErrorDialog(AppLocalizations.of(context)!.invalidQuantity);
      return;
    }

    if (_selectedCategory != null && _newCategoryController.text.trim().isNotEmpty) {
      // Show error if both category and new category name are filled
      _showErrorDialog(AppLocalizations.of(context)!.categoryConflict);
      return;
    }

    String finalCategory = _selectedCategory ?? _newCategoryController.text.trim();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('inventory')
        .add({
      'name': _itemNameController.text.trim(),
      'quantity': quantity,
      'unit': _selectedUnit,
      'category': finalCategory,
      'expirationDate': _expirationDate != null ? Timestamp.fromDate(_expirationDate!) : null,
    });

    _itemNameController.clear();
    _quantityController.clear();
    _newCategoryController.clear();
    setState(() {
      _expirationDate = null;
      _selectedCategory = null;
    });
  }

  // Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.error),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.ok),
          ),
        ],
      ),
    );
  }

  void _pickExpirationDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _expirationDate = picked;
      });
    }
  }

  // Show edit dialog for an item
  void _showEditItemDialog(DocumentSnapshot itemDoc) async {
    final itemData = itemDoc.data() as Map<String, dynamic>;
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;

    // Set initial values for the edit dialog
    _editItemNameController.text = itemData['name'];
    _editQuantityController.text = itemData['quantity'].toString();
    _editCategoryController.text = itemData['category'] ?? '';
    _selectedUnit = itemData['unit'];
    _expirationDate = itemData['expirationDate']?.toDate();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.editItem),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _editItemNameController,
                decoration: InputDecoration(labelText: localizations.itemName),
              ),
              TextField(
                controller: _editQuantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: localizations.quantity),
              ),
              DropdownButtonFormField<String>(
                value: _selectedUnit,
                decoration: InputDecoration(labelText: localizations.unit),
                items: [
                  'kg', 'g', 'lb', 'oz', 'liter','pieces'
                ].map((unit) {
                  return DropdownMenuItem(
                    value: unit,
                    child: Text(LocalizationHelper.getLocalizedString(localizations, unit)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedUnit = value;
                  });
                },
              ),
              TextField(
                controller: _editCategoryController,
                decoration: InputDecoration(labelText: localizations.category),
              ),
              ElevatedButton(
                onPressed: _pickExpirationDate,
                child: Text(_expirationDate != null
                    ? "${localizations.expirationDate}: ${DateFormat.yMd().format(_expirationDate!)}"
                    : localizations.pickExpirationDate),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              // Update the item in Firestore
              itemDoc.reference.update({
                'name': _editItemNameController.text.trim(),
                'quantity': int.tryParse(_editQuantityController.text.trim()) ?? 0,
                'unit': _selectedUnit,
                'category': _editCategoryController.text.trim(),
                'expirationDate': _expirationDate != null ? Timestamp.fromDate(_expirationDate!) : null,
              });
              Navigator.pop(context);
            },
            child: Text(localizations.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.inventory)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemDialog(),
        child: Icon(Icons.add),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('inventory')
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return CircularProgressIndicator();

          // Group items by category
          Map<String, List<QueryDocumentSnapshot>> categorizedItems = {};
          List<QueryDocumentSnapshot> uncategorizedItems = [];

          for (var doc in snapshot.data!.docs) {
            Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
            if (data == null || !data.containsKey('name')) {
              continue;
            }

            String category = data['category'] ?? '';

            if (category.isEmpty) {
              uncategorizedItems.add(doc);
            } else {
              if (!categorizedItems.containsKey(category)) {
                categorizedItems[category] = [];
              }
              categorizedItems[category]!.add(doc);
            }
          }

          return ListView(
            children: [
              // Uncategorized items
              if (uncategorizedItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    localizations.uncategorized,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ...uncategorizedItems.map((itemDoc) {
                Map<String, dynamic> itemData = itemDoc.data() as Map<String, dynamic>;
                return Dismissible(
                  key: Key(itemDoc.id), // Unique key for each item
                  direction: DismissDirection.endToStart, // Swipe from right to left
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    // Delete the item from Firestore
                    itemDoc.reference.delete();
                  },
                  child: ListTile(
                    title: Text(itemData['name'] ?? "Unnamed Item"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${itemData['quantity']} ${itemData['unit']}"),
                        if (itemData.containsKey('expirationDate') && itemData['expirationDate'] != null)
                          Text(
                            "${localizations.expirationDate}: ${DateFormat.yMd().format((itemData['expirationDate'] as Timestamp).toDate())}",
                            style: TextStyle(color: Colors.red),
                          ),
                      ],
                    ),
                    onTap: () => _showEditItemDialog(itemDoc), // Open edit dialog on tap
                  ),
                );
              }).toList(),

              // Categorized items
              ...categorizedItems.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        entry.key, // Category name
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...entry.value.map((itemDoc) {
                      Map<String, dynamic> itemData = itemDoc.data() as Map<String, dynamic>;
                      return Dismissible(
                        key: Key(itemDoc.id), // Unique key for each item
                        direction: DismissDirection.endToStart, // Swipe from right to left
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) {
                          // Delete the item from Firestore
                          itemDoc.reference.delete();
                        },
                        child: ListTile(
                          title: Text(itemData['name'] ?? "Unnamed Item"),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("${itemData['quantity']} ${itemData['unit']}"),
                              if (itemData.containsKey('expirationDate') && itemData['expirationDate'] != null)
                                Text(
                                  "${localizations.expirationDate}: ${DateFormat.yMd().format((itemData['expirationDate'] as Timestamp).toDate())}",
                                  style: TextStyle(color: Colors.red),
                                ),
                            ],
                          ),
                          onTap: () => _showEditItemDialog(itemDoc), // Open edit dialog on tap
                        ),
                      );
                    }).toList(),
                  ],
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }

  void _showAddItemDialog() async {
    List<String> existingCategories = await _fetchCategories();
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.addItem),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _itemNameController,
                decoration: InputDecoration(labelText: localizations.itemName),
              ),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: localizations.quantity),
              ),
              DropdownButtonFormField<String>(
                value: _selectedUnit,
                decoration: InputDecoration(labelText: localizations.unit),
                items: [
                  'kg', 'g', 'lb', 'oz', 'liter','pieces'
                ].map((unit) {
                  return DropdownMenuItem(
                    value: unit,
                    child: Text(LocalizationHelper.getLocalizedString(localizations, unit)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedUnit = value;
                  });
                },
              ),
              TextField(
                controller: _newCategoryController,
                decoration: InputDecoration(labelText: localizations.newCategory),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = null;
                  });
                },
              ),
              ElevatedButton(
                onPressed: _pickExpirationDate,
                child: Text(_expirationDate != null
                    ? "${localizations.expirationDate}: ${DateFormat.yMd().format(_expirationDate!)}"
                    : localizations.pickExpirationDate),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              _addItem();
              Navigator.pop(context);
            },
            child: Text(localizations.add),
          ),
        ],
      ),
    );
  }
}
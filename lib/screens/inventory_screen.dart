import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:kitchenly/screens/profile_screen.dart';
import '../utils/category_helper.dart';
import '../utils/colors.dart';
import 'package:openfoodfacts/openfoodfacts.dart' as OFF;
import '../utils/localization_helper.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

// enum SortOption { expirationDate, dateAdded, alphabetically }

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _newCategoryController = TextEditingController();
  final TextEditingController _editItemNameController = TextEditingController();
  final TextEditingController _editQuantityController = TextEditingController();
  final TextEditingController _editCategoryController = TextEditingController();
  String? _selectedUnit = "g";
  String? _selectedCategory;
  DateTime? _expirationDate;
  User? user = FirebaseAuth.instance.currentUser;
  String? _userLanguage;
  Set<String> expandedCategories = {};
  bool _isAddingItem =false;
  @override
  void initState() {
    super.initState();
    _fetchUserLanguage().then((language) {
      setState(() {
        _userLanguage = language;
      });
    });
  }

  // void _applySorting(List<QueryDocumentSnapshot> items) {
  //   if (_currentSort == 'alphabetical') {
  //     items.sort((a, b) =>
  //         (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));
  //   } else if (_currentSort == 'expiration') {
  //     items.sort((a, b) {
  //       Timestamp? aExp = a['expirationDate'];
  //       Timestamp? bExp = b['expirationDate'];
  //
  //       if (aExp == null && bExp == null) return 0;
  //       if (aExp == null) return 1;
  //       if (bExp == null) return -1;
  //
  //       return aExp.toDate().compareTo(bExp.toDate());
  //     });
  //   }
  // }

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
  Future<String> fetchProductCategory(String productName) async {
    return CategoryHelper.categorizeItem(productName);
  }

  // Add an item to a selected or new category
  void _addItem() async {
    setState(() {
      _isAddingItem = true;
    });

    String itemName = _itemNameController.text.trim().toLowerCase(); // 🔥 normalize lowercase
    String quantityText = _quantityController.text.trim();
    int quantity = int.tryParse(quantityText) ?? 0;

    if (itemName.isEmpty || quantity <= 0 || quantity > 999) {
      _showErrorDialog(AppLocalizations.of(context)!.invalidQuantity);
      setState(() {
        _isAddingItem = false;
      });
      return;
    }

    String finalCategory = _selectedCategory ?? _newCategoryController.text.trim();

    if (finalCategory.isEmpty) {
      finalCategory = await fetchProductCategory(itemName) ?? 'Uncategorized';
    }

    final inventoryRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('inventory');

    // 🔥 Check if item already exists with same name and unit
    final existingQuery = await inventoryRef
        .where('name', isEqualTo: itemName)
        .where('unit', isEqualTo: _selectedUnit)
        .limit(1)
        .get();

    if (existingQuery.docs.isNotEmpty) {
      // 🔥 Item exists → update quantity
      final existingDoc = existingQuery.docs.first;
      int existingQuantity = existingDoc['quantity'] ?? 0;

      await existingDoc.reference.update({
        'quantity': existingQuantity + quantity,
      });
    } else {
      // 🔥 No existing item → add new
      await inventoryRef.add({
        'name': itemName,
        'quantity': quantity,
        'unit': _selectedUnit,
        'category': finalCategory,
        'expirationDate': _expirationDate != null ? Timestamp.fromDate(_expirationDate!) : null,
      });
    }

    _itemNameController.clear();
    _quantityController.clear();
    _newCategoryController.clear();
    setState(() {
      _expirationDate = null;
      _selectedCategory = null;
      _isAddingItem = false;
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

    _editItemNameController.text = itemData['name'];
    _editQuantityController.text = itemData['quantity'].toString();
    _editCategoryController.text = itemData['category'] ?? '';
    _selectedUnit = itemData['unit'];
    _expirationDate = itemData['expirationDate']?.toDate();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(localizations.editItem),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              tooltip: localizations.delete,
              onPressed: () async {
                // Show confirmation first
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(localizations.delete),
                    content: Text(localizations.confirmDeleteItem),
                    actions: [
                      TextButton(
                        child: Text(localizations.cancel),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                      TextButton(
                        child: Text(localizations.delete),
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await itemDoc.reference.delete();
                  Navigator.pop(context); // Close the edit dialog too
                }
              },
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _editItemNameController,
                decoration: InputDecoration(labelText: localizations.itemName),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _editQuantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: localizations.quantity),
              ),
              SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedUnit,
                decoration: InputDecoration(labelText: localizations.unit),
                items: [
                  'g', 'lb', 'oz', 'liter', 'pieces', 'packs', 'cups'
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
              SizedBox(height: 10),
              TextField(
                controller: _editCategoryController,
                decoration: InputDecoration(labelText: localizations.category),
              ),
              SizedBox(height: 20),
              TextButton(
                onPressed: _pickExpirationDate,
                child: Text(_expirationDate != null
                    ? localizations.editExpirationDate
                    : localizations.pickExpirationDate),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
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
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.inventory), centerTitle: true, leading: IconButton(
        icon: const Icon(Icons.person),
        tooltip: AppLocalizations.of(context)!.profile,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) =>  ProfileScreen(),),
          );
        },
      ),),

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

          if (snapshot.data!.docs.isEmpty) {
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
                    localizations.inventoryIsEmpty,
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
          // Group items by category
          Map<String, List<QueryDocumentSnapshot>> categorizedItems = {};
          List<QueryDocumentSnapshot> uncategorizedItems = [];

          for (var doc in snapshot.data!.docs) {
            Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
            if (data == null || !data.containsKey('name')) {
              continue;
            }
            // _applySorting(uncategorizedItems);
            // for (var list in categorizedItems.values) {
            //   _applySorting(list);
            // }
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
          for (var entry in categorizedItems.entries) {
            entry.value.sort((a, b) {
              DateTime? aDate = (a['expirationDate'] as Timestamp?)?.toDate();
              DateTime? bDate = (b['expirationDate'] as Timestamp?)?.toDate();
              if (aDate == null && bDate == null) return 0;
              if (aDate == null) return 1;
              if (bDate == null) return -1;
              return aDate.compareTo(bDate);
            });
          }

          uncategorizedItems.sort((a, b) {
            DateTime? aDate = (a['expirationDate'] as Timestamp?)?.toDate();
            DateTime? bDate = (b['expirationDate'] as Timestamp?)?.toDate();
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return aDate.compareTo(bDate);
          });
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
                return ListTile(
                    title: Text(itemData['name'] ?? "Unnamed Item"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${itemData['quantity']} ${itemData['unit']}"),
                        if (itemData.containsKey('expirationDate') && itemData['expirationDate'] != null)
                          Text(
                            "${localizations.expirationDate}: ${DateFormat.yMd().format((itemData['expirationDate'] as Timestamp).toDate())}",
                            style: TextStyle(
                              color: (itemData['expirationDate'] as Timestamp).toDate().isBefore(DateTime.now())
                                  ? AppColors.pastExpirationDate
                                  : AppColors.futureExpirationDate,
                            ),
                          ),
                      ],
                    ),
                    onTap: () => _showEditItemDialog(itemDoc), // Open edit dialog on tap
                  );
              }).toList(),

              // Categorized items
              ...categorizedItems.entries.map((entry) {return DragTarget<DocumentSnapshot>(
                onAccept: (draggedItemDoc) async {
                  await draggedItemDoc.reference.update({'category': entry.key});
                },
                builder: (context, candidateData, rejectedData) {
                  final isExpanded = expandedCategories.contains(entry.key);

                  return ExpansionTile(
                    key: PageStorageKey(entry.key),
                    title: Row(
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (candidateData.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Icon(Icons.folder_open, color: Theme.of(context).colorScheme.primary),
                          ),
                      ],
                    ),
                    initiallyExpanded: isExpanded,
                    onExpansionChanged: (expanded) {
                      setState(() {
                        if (expanded) {
                          expandedCategories.add(entry.key);
                        } else {
                          expandedCategories.remove(entry.key);
                        }
                      });
                    },
                    children: entry.value.map((itemDoc) {
                      Map<String, dynamic> itemData = itemDoc.data() as Map<String, dynamic>;
                      return Dismissible(
                        key: Key(itemDoc.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: AppColors.deleteBg,
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => itemDoc.reference.delete(),
                        child: Draggable<DocumentSnapshot>(
                          data: itemDoc,
                          feedback: Material(
                            color: Colors.transparent,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: 250),
                              child: ListTile(
                                  title: Text(itemData['name']),
                                  subtitle: Text("${itemData['quantity']} ${itemData['unit']}")
                              ),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.5,
                            child: ListTile(
                                title: Text(itemData['name']),
                                subtitle: Text("${itemData['quantity']} ${itemData['unit']}")
                            ),
                          ),
                          child: ListTile(
                            title: Text(itemData['name']),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("${itemData['quantity']} ${itemData['unit']}"),
                                if (itemData['expirationDate'] != null)
                                  Text(
                                    "${localizations.expirationDate}: ${DateFormat.yMd().format((itemData['expirationDate'] as Timestamp).toDate())}",
                                    style: TextStyle(
                                      color: (itemData['expirationDate'] as Timestamp).toDate().isBefore(DateTime.now())
                                          ? AppColors.pastExpirationDate
                                          : AppColors.futureExpirationDate,
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () => _showEditItemDialog(itemDoc),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              );}).toList(),

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
              SizedBox(height: 10),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: localizations.quantity),
              ),
              SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedUnit,
                decoration: InputDecoration(labelText: localizations.unit),
                items: [
                  'g', 'lb', 'oz', 'liter', 'pieces','packs','cups'
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
              SizedBox(height: 20),
              TextButton(
                onPressed: _pickExpirationDate,
                child: Text(_expirationDate != null
                    ? "${localizations.expirationDate}: ${DateFormat.yMd().format(_expirationDate!)}"
                    : localizations.pickExpirationDate),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  _addItem();
                  Navigator.pop(context);
                },
                child: Text(localizations.add),
              ),
            ],
          ),
        ),

      ),
    );
  }
}
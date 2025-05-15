import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:kitchenly/utils/category_helper.dart';
import 'package:kitchenly/utils/colors.dart';
import 'package:kitchenly/utils/localization_helper.dart';

class EditableInventoryScreen extends StatefulWidget {
  final String familyOwnerId;
  final String language;

  const EditableInventoryScreen({
    required this.familyOwnerId,
    required this.language,
    Key? key,
  }) : super(key: key);

  @override
  _EditableInventoryScreenState createState() => _EditableInventoryScreenState();
}

class _EditableInventoryScreenState extends State<EditableInventoryScreen> {
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _newCategoryController = TextEditingController();
  final TextEditingController _editItemNameController = TextEditingController();
  final TextEditingController _editQuantityController = TextEditingController();
  final TextEditingController _editCategoryController = TextEditingController();
  String? _selectedUnit = "g";
  String? _selectedCategory;
  DateTime? _expirationDate;
  Set<String> expandedCategories = {};
  bool _isAddingItem = false;
  AppLocalizations? _localizations;

  @override
  void initState() {
    super.initState();
    _localizations = lookupAppLocalizations(Locale(widget.language));
  }

  Future<String> fetchProductCategory(String productName) async {
    return CategoryHelper.categorizeItem(productName);
  }

  void _addItem() async {
    setState(() {
      _isAddingItem = true;
    });

    String itemName = _itemNameController.text.trim().toLowerCase();
    String quantityText = _quantityController.text.trim();
    int quantity = int.tryParse(quantityText) ?? 0;

    if (itemName.isEmpty || quantity <= 0 || quantity > 999) {
      _showErrorDialog(_localizations!.invalidQuantity);
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
        .doc(widget.familyOwnerId)
        .collection('inventory');

    // Check if item already exists with same name and unit
    final existingQuery = await inventoryRef
        .where('name', isEqualTo: itemName)
        .where('unit', isEqualTo: _selectedUnit)
        .limit(1)
        .get();

    if (existingQuery.docs.isNotEmpty) {
      // Item exists → update quantity
      final existingDoc = existingQuery.docs.first;
      int existingQuantity = existingDoc['quantity'] ?? 0;

      await existingDoc.reference.update({
        'quantity': existingQuantity + quantity,
      });
    } else {
      // No existing item → add new
      await inventoryRef.add({
        'name': itemName,
        'quantity': quantity,
        'unit': _selectedUnit,
        'category': finalCategory,
        'expirationDate': _expirationDate != null ? Timestamp.fromDate(_expirationDate!) : null,
        'lastEditedBy': FirebaseAuth.instance.currentUser?.uid,
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_localizations!.error),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_localizations!.ok),
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

  void _showEditItemDialog(DocumentSnapshot itemDoc) async {
    final itemData = itemDoc.data() as Map<String, dynamic>;

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
            Text(_localizations!.editItem),
            IconButton(
              icon: Icon(Icons.delete, color: AppColors.deleteBg),
              tooltip: _localizations!.delete,
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(_localizations!.delete),
                    content: Text(_localizations!.confirmDeleteItem),
                    actions: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(_localizations!.delete),
                              ),
                              SizedBox(height: 10),
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(_localizations!.cancel),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await itemDoc.reference.delete();
                  Navigator.pop(context);
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
                decoration: InputDecoration(labelText: _localizations!.itemName),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _editQuantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: _localizations!.quantity),
              ),
              SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedUnit,
                decoration: InputDecoration(labelText: _localizations!.unit),
                items: [
                  'g', 'lb', 'oz', 'liter', 'pieces', 'packs', 'cups'
                ].map((unit) {
                  return DropdownMenuItem(
                    value: unit,
                    child: Text(LocalizationHelper.getLocalizedString(_localizations!, unit)),
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
                decoration: InputDecoration(labelText: _localizations!.category),
              ),
              SizedBox(height: 20),
              TextButton(
                onPressed: _pickExpirationDate,
                child: Text(_expirationDate != null
                    ? _localizations!.editExpirationDate
                    : _localizations!.pickExpirationDate),
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
                    'lastEditedBy': FirebaseAuth.instance.currentUser?.uid,
                  });
                  Navigator.pop(context);
                },
                child: Text(_localizations!.save),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<String>> _fetchCategories() async {
    var snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.familyOwnerId)
        .collection('inventory')
        .get();

    Set<String> categories = {};
    for (var doc in snapshot.docs) {
      categories.add(doc['category']);
    }
    return categories.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_localizations!.inventory),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemDialog(),
        child: Icon(Icons.add),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.familyOwnerId)
            .collection('inventory')
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

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
                    _localizations!.inventoryIsEmpty,
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
            if (data == null || !data.containsKey('name')) continue;

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

          // Sort items by expiration date
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
              if (uncategorizedItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _localizations!.uncategorized,
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
                          "${_localizations!.expirationDate}: ${DateFormat.yMd().format((itemData['expirationDate'] as Timestamp).toDate())}",
                          style: TextStyle(
                            color: (itemData['expirationDate'] as Timestamp).toDate().isBefore(DateTime.now())
                                ? AppColors.pastExpirationDate
                                : AppColors.futureExpirationDate,
                          ),
                        ),
                    ],
                  ),
                  onTap: () => _showEditItemDialog(itemDoc),
                );
              }).toList(),

              ...categorizedItems.entries.map((entry) {
                return DragTarget<DocumentSnapshot>(
                  onAccept: (draggedItemDoc) async {
                    await draggedItemDoc.reference.update({
                      'category': entry.key,
                      'lastEditedBy': FirebaseAuth.instance.currentUser?.uid,
                    });
                  },
                  builder: (context, candidateData, rejectedData) {
                    final isExpanded = expandedCategories.contains(entry.key);
                    return ExpansionTile(
                      key: PageStorageKey(entry.key),
                      title: Row(
                        children: [
                          Text(
                            entry.key,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (candidateData.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
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
                            child: Icon(Icons.delete, color: AppColors.iconColor),
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
                                      "${_localizations!.expirationDate}: ${DateFormat.yMd().format((itemData['expirationDate'] as Timestamp).toDate())}",
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_localizations!.addItem),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _itemNameController,
                decoration: InputDecoration(labelText: _localizations!.itemName),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: _localizations!.quantity),
              ),
              SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedUnit,
                decoration: InputDecoration(labelText: _localizations!.unit),
                items: [
                  'g', 'lb', 'oz', 'liter', 'pieces','packs','cups'
                ].map((unit) {
                  return DropdownMenuItem(
                    value: unit,
                    child: Text(LocalizationHelper.getLocalizedString(_localizations!, unit)),
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
                    ? "${_localizations!.expirationDate}: ${DateFormat.yMd().format(_expirationDate!)}"
                    : _localizations!.pickExpirationDate),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  _addItem();
                  Navigator.pop(context);
                },
                child: Text(_localizations!.add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kitchenly/utils/category_helper.dart';
import 'package:kitchenly/utils/localization_helper.dart';
import 'package:kitchenly/utils/colors.dart';

class EditableShoppingListScreen extends StatefulWidget {
  final String familyOwnerId;
  final String language;

  const EditableShoppingListScreen({
    required this.familyOwnerId,
    required this.language,
    Key? key,
  }) : super(key: key);

  @override
  State<EditableShoppingListScreen> createState() => _EditableShoppingListScreenState();
}

class _EditableShoppingListScreenState extends State<EditableShoppingListScreen>
    with TickerProviderStateMixin {
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _editNameController = TextEditingController();
  final TextEditingController _editQtyController = TextEditingController();
  final TextEditingController _renameTabController = TextEditingController();
  String? _selectedUnit = "g";
  List<String> _tabs = [];
  TabController? _tabController;
  bool _checkedItemsExpanded = false;
  late AnimationController _fabAnimationController;
  Set<String> expandedCategories = {};
  AppLocalizations? _localizations;

  @override
  void initState() {
    super.initState();
    _localizations = lookupAppLocalizations(Locale(widget.language));
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadSublistNames();
    _ensureShoppingListExists();
  }

  Future<void> _ensureShoppingListExists() async {
    final collectionRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.familyOwnerId)
        .collection('shoppingList');

    final snapshot = await collectionRef.limit(1).get();
    if (snapshot.docs.isEmpty) {
      await collectionRef.add({ 'init': true });
    }
  }

  Future<void> _loadSublistNames() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.familyOwnerId)
        .collection('sublists')
        .get();

    setState(() {
      _tabs = [_localizations!.main];
      _tabs.addAll(snapshot.docs.map((doc) => doc.id));
      _tabController = TabController(length: _tabs.length, vsync: this);
    });
  }

  Future<void> _addTab() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_localizations!.addListName ?? 'Add List Name'),
        content: TextField(
          controller: _renameTabController,
          decoration: InputDecoration(labelText: _localizations!.listName ?? 'List Name'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final name = _renameTabController.text.trim();
              if (name.isNotEmpty && !_tabs.contains(name)) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.familyOwnerId)
                    .collection('sublists')
                    .doc(name)
                    .set({'createdAt': DateTime.now()});
                setState(() {
                  _tabs.add(name);
                  _tabController = TabController(length: _tabs.length, vsync: this);
                });
              }
              _renameTabController.clear();
              Navigator.pop(context);
            },
            child: Text(_localizations!.add ?? 'Add'),
          )
        ],
      ),
    );
  }

  Future<void> _renameTab(int index) async {
    final oldName = _tabs[index];
    _renameTabController.text = oldName;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_localizations!.renameList ?? 'Rename List'),
        content: TextField(
          controller: _renameTabController,
          decoration: InputDecoration(labelText: _localizations!.listName ?? 'List Name'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final newName = _renameTabController.text.trim();
              if (newName.isNotEmpty && !_tabs.contains(newName)) {
                // Copy documents to new collection
                final oldCollection = FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.familyOwnerId)
                    .collection('sublists')
                    .doc(oldName)
                    .collection('items');
                final newCollection = FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.familyOwnerId)
                    .collection('sublists')
                    .doc(newName)
                    .collection('items');
                final docs = await oldCollection.get();
                for (final doc in docs.docs) {
                  await newCollection.add(doc.data());
                  await doc.reference.delete();
                }

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.familyOwnerId)
                    .collection('sublists')
                    .doc(oldName)
                    .delete();

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.familyOwnerId)
                    .collection('sublists')
                    .doc(newName)
                    .set({'createdAt': DateTime.now()});

                setState(() {
                  _tabs[index] = newName;
                  _tabController = TabController(length: _tabs.length, vsync: this);
                });
              }
              _renameTabController.clear();
              Navigator.pop(context);
            },
            child: Text(_localizations!.save ?? 'Save'),
          )
        ],
      ),
    );
  }

  void _removeTab(int index) async {
    String listKey = _tabs[index];
    if (listKey != _localizations!.main) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.familyOwnerId)
          .collection('sublists')
          .doc(listKey)
          .delete();
    }
    setState(() {
      _tabs.removeAt(index);
      _tabController = TabController(length: _tabs.length, vsync: this);
    });
  }

  Future<void> _addItem(String listKey) async {
    String itemName = _itemNameController.text.trim();
    String quantityText = _quantityController.text.trim();
    int quantity = int.tryParse(quantityText) ?? 0;
    if (itemName.isEmpty || quantity <= 0 || quantity > 999) {
      _showErrorDialog(_localizations!.invalidQuantity);
      return;
    }
    String category = CategoryHelper.categorizeItem(itemName);
    final shoppingListRef = (listKey == _tabs[0])
        ? FirebaseFirestore.instance
        .collection('users')
        .doc(widget.familyOwnerId)
        .collection('shoppingList')
        : FirebaseFirestore.instance
        .collection('users')
        .doc(widget.familyOwnerId)
        .collection('sublists')
        .doc(listKey)
        .collection('items');

    await shoppingListRef.add({
      'name': itemName,
      'quantity': quantity,
      'unit': _selectedUnit,
      'checked': false,
      'category': category,
      'lastEditedBy': FirebaseAuth.instance.currentUser?.uid,
    });

    _itemNameController.clear();
    _quantityController.clear();
    setState(() => _selectedUnit = "g");
  }

  void _editItem(DocumentSnapshot itemDoc, String currentListKey) {
    var itemData = itemDoc.data() as Map<String, dynamic>;
    _editNameController.text = itemData['name'];
    _editQtyController.text = itemData['quantity'].toString();

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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _editNameController,
              decoration: InputDecoration(labelText: _localizations!.itemName),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _editQtyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: _localizations!.quantity),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              await itemDoc.reference.update({
                'name': _editNameController.text.trim(),
                'quantity': int.tryParse(_editQtyController.text.trim()) ?? 1,
                'lastEditedBy': FirebaseAuth.instance.currentUser?.uid,
              });
              Navigator.pop(context);
            },
            child: Text(_localizations!.save),
          ),
        ],
      ),
    );
  }

  void _addSublistToMain(String listKey) async {
    final sublistDocs = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.familyOwnerId)
        .collection('sublists')
        .doc(listKey)
        .collection('items')
        .get();

    for (var doc in sublistDocs.docs) {
      var data = doc.data();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.familyOwnerId)
          .collection('shoppingList')
          .add({
        ...data,
        'lastEditedBy': FirebaseAuth.instance.currentUser?.uid,
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Items from "$listKey" have been added to the main list.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _updateInventory(DocumentSnapshot itemDoc) async {
    final data = itemDoc.data() as Map<String, dynamic>;
    final inventoryRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.familyOwnerId)
        .collection('inventory');

    final inventoryQuery = await inventoryRef
        .where('name', isEqualTo: data['name'])
        .where('unit', isEqualTo: data['unit'])
        .get();

    if (inventoryQuery.docs.isNotEmpty) {
      final existing = inventoryQuery.docs.first;
      await existing.reference.update({
        'quantity': (existing['quantity'] ?? 0) + (data['quantity'] ?? 0),
        'lastEditedBy': FirebaseAuth.instance.currentUser?.uid,
      });
    } else {
      await inventoryRef.add({
        'name': data['name'],
        'quantity': data['quantity'],
        'unit': data['unit'],
        'category': data['category'] ?? 'Uncategorized',
        'expirationDate': null,
        'lastEditedBy': FirebaseAuth.instance.currentUser?.uid,
      });
    }
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

  Widget _buildListView(String listKey) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.familyOwnerId)
          .collection('sublists')
          .doc(listKey)
          .collection('items')
          .where('checked', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        final Map<String, List<DocumentSnapshot>> categorizedItems = {};

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final category = data['category'] ?? 'Uncategorized';
          if (!categorizedItems.containsKey(category)) {
            categorizedItems[category] = [];
          }
          categorizedItems[category]!.add(doc);
        }

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_rounded,
                  size: 95,
                  color: AppColors.iconColor,
                ),
                SizedBox(height: 16),
                Text(
                  _localizations!.shoppingSublistIsEmpty,
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

        return ListView(
          children: categorizedItems.entries.map((entry) {
            final isExpanded = expandedCategories.contains(entry.key);
            return DragTarget<DocumentSnapshot>(
              onAccept: (draggedItemDoc) async {
                await draggedItemDoc.reference.update({
                  'category': entry.key,
                  'lastEditedBy': FirebaseAuth.instance.currentUser?.uid,
                });
              },
              builder: (context, candidateData, rejectedData) {
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
                    final itemData = itemDoc.data() as Map<String, dynamic>;
                    return Draggable<DocumentSnapshot>(
                      data: itemDoc,
                      feedback: Material(
                        color: Colors.transparent,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 250),
                          child: ListTile(
                            title: Text(itemData['name']),
                            subtitle: Text("${itemData['quantity']} ${itemData['unit']}"),
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.5,
                        child: ListTile(
                          title: Text(itemData['name']),
                          subtitle: Text("${itemData['quantity']} ${itemData['unit']}"),
                        ),
                      ),
                      child: ListTile(
                        title: Text(itemData['name']),
                        subtitle: Text("${itemData['quantity']} ${itemData['unit']}"),
                        onTap: () => _editItem(itemDoc, listKey),
                      ),
                    );
                  }).toList(),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCheckedItemsDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.familyOwnerId)
          .collection('shoppingList')
          .where('checked', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return SizedBox.shrink();

        return ExpansionTile(
          title: Text(_localizations!.checkedItems),
          onExpansionChanged: (expanded) {
            setState(() {
              _checkedItemsExpanded = expanded;
              expanded
                  ? _fabAnimationController.forward()
                  : _fabAnimationController.reverse();
            });
          },
          children: [
            ...docs.map((itemDoc) {
              Map<String, dynamic> itemData = itemDoc.data() as Map<String, dynamic>;
              return ListTile(
                title: Text(itemData['name']),
                subtitle: Text("${itemData['quantity']} ${itemData['unit']}"),
                leading: Checkbox(
                  value: true,
                  onChanged: (_) async {
                    await itemDoc.reference.update({
                      'checked': false,
                      'lastEditedBy': FirebaseAuth.instance.currentUser?.uid,
                    });
                  },
                ),
              );
            }).toList(),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                for (var doc in docs) {
                  await doc.reference.delete();
                }
              },
              child: Text(_localizations!.deleteCheckedItems),
            ),
            SizedBox(height: 10)
          ],
        );
      },
    );
  }

  Widget _buildCategorizedMainList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.familyOwnerId)
          .collection('shoppingList')
          .where('checked', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_rounded,
                  size: 95,
                  color: AppColors.iconColor,
                ),
                SizedBox(height: 16),
                Text(
                  _localizations!.shoppingListIsEmpty,
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
        final Map<String, List<DocumentSnapshot>> categorizedItems = {};

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final category = data['category'] ?? 'Uncategorized';
          if (!categorizedItems.containsKey(category)) {
            categorizedItems[category] = [];
          }
          categorizedItems[category]!.add(doc);
        }
        return ListView(
          children: categorizedItems.entries.map((entry) {
            final isExpanded = expandedCategories.contains(entry.key);
            return DragTarget<DocumentSnapshot>(
              onAccept: (draggedItemDoc) async {
                await draggedItemDoc.reference.update({
                  'category': entry.key,
                  'lastEditedBy': FirebaseAuth.instance.currentUser?.uid,
                });
              },
              builder: (context, candidateData, rejectedData) {
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
                    return Draggable<DocumentSnapshot>(
                      data: itemDoc,
                      feedback: Material(
                        color: Colors.transparent,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 250),
                          child: ListTile(
                            title: Text(itemData['name']),
                            subtitle: Text("${itemData['quantity']} ${itemData['unit']}"),
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.5,
                        child: ListTile(
                          leading: Checkbox(
                            value: itemData['checked'] ?? false,
                            onChanged: (value) async {
                              if (value == true) {
                                await itemDoc.reference.update({
                                  'checked': true,
                                  'lastEditedBy': FirebaseAuth.instance.currentUser?.uid,
                                });
                                await _updateInventory(itemDoc);
                              }
                            },
                          ),
                          title: Text(itemData['name']),
                          subtitle: Text("${itemData['quantity']} ${itemData['unit']}"),
                          onTap: () => _editItem(itemDoc, 'Main'),
                        ),
                      ),
                      child: ListTile(
                        leading: Checkbox(
                          value: itemData['checked'] ?? false,
                          onChanged: (value) async {
                            if (value == true) {
                              await itemDoc.reference.update({
                                'checked': true,
                                'lastEditedBy': FirebaseAuth.instance.currentUser?.uid,
                              });
                              await _updateInventory(itemDoc);
                            }
                          },
                        ),
                        title: Text(itemData['name']),
                        subtitle: Text("${itemData['quantity']} ${itemData['unit']}"),
                        onTap: () => _editItem(itemDoc, 'Main'),
                      ),
                    );
                  }).toList(),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_tabController == null) {
      return Center(child: CircularProgressIndicator());
    }

    bool isMainTab = _tabs[_tabController!.index] == _localizations!.main;

    return Scaffold(
      appBar: AppBar(
        title: Text(_localizations!.shoppingList),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: List.generate(_tabs.length, (i) {
                    return GestureDetector(
                      onLongPress: _tabs[i] != _localizations!.main ? () => _renameTab(i) : null,
                      child: Tab(
                        child: Row(
                          children: [
                            Text(_tabs[i]),
                            if (_tabs[i] != _localizations!.main)
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => _removeTab(i),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton.icon(
                  onPressed: _addTab,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    _localizations!.addSublist,
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _fabAnimationController,
        builder: (context, child) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: 40 + (_fabAnimationController.value * 200),
              right: 2,
            ),
            child: FloatingActionButton(
              onPressed: () => _showAddItemDialog(_tabs[_tabController!.index]),
              child: Icon(Icons.add),
            ),
          );
        },
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((key) {
          if (key == _localizations!.main) {
            return Column(
              children: [
                Expanded(child: _buildCategorizedMainList()),
                _buildCheckedItemsDropdown(),
              ],
            );
          } else {
            return Column(
              children: [
                Expanded(child: _buildListView(key)),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.familyOwnerId)
                      .collection('sublists')
                      .doc(key)
                      .collection('items')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final hasItems = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Tooltip(
                        message: hasItems
                            ? _localizations!.addItemsTooltip
                            : _localizations!.emptySublistTooltip,
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.upload),
                          label: Text(_localizations!.addToMainList),
                          onPressed: hasItems
                              ? () => _addSublistToMain(key)
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          }
        }).toList(),
      ),
    );
  }

  void _showAddItemDialog(String listKey) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_localizations!.addItem),
        content: Column(
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
              items: ['g', 'lb', 'oz', 'liter', 'pieces','packs','cups'].map((unit) {
                return DropdownMenuItem(
                  value: unit,
                  child: Text(LocalizationHelper.getLocalizedString(
                      _localizations!, unit)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedUnit = value;
                });
              },
            ),
            SizedBox(height: 20),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              _addItem(listKey);
              Navigator.pop(context);
            },
            child: Text(_localizations!.add),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _tabController?.dispose();
    _itemNameController.dispose();
    _quantityController.dispose();
    _editNameController.dispose();
    _editQtyController.dispose();
    _renameTabController.dispose();
    super.dispose();
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../utils/localization_helper.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({Key? key}) : super(key: key);

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen>
    with TickerProviderStateMixin {
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _editNameController = TextEditingController();
  final TextEditingController _editQtyController = TextEditingController();
  final TextEditingController _renameTabController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  String? _selectedUnit = "kg";
  User? user = FirebaseAuth.instance.currentUser;
  List<String> _tabs = ['Main'];
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _loadSublistNames();
    _ensureShoppingListExists();
  }

  Future<void> _ensureShoppingListExists() async {
    final collectionRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('shoppingList');

    final snapshot = await collectionRef.limit(1).get();
    if (snapshot.docs.isEmpty) {
      await collectionRef.add({ 'init': true });
    }
  }

  Future<void> _loadSublistNames() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('sublists')
        .get();

    setState(() {
      _tabs = ['Main'];
      _tabs.addAll(snapshot.docs.map((doc) => doc.id));
      _tabController = TabController(length: _tabs.length, vsync: this);
    });
  }

  Future<void> _addTab() async {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(localizations.addListName ?? 'Add List Name'),
        content: TextField(
          controller: _renameTabController,
          decoration: InputDecoration(labelText: localizations.listName ?? 'List Name'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final name = _renameTabController.text.trim();
              if (name.isNotEmpty && !_tabs.contains(name)) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
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
            child: Text(localizations.add ?? 'Add'),
          )
        ],
      ),
    );
  }

  Future<void> _renameTab(int index) async {
    final oldName = _tabs[index];
    final localizations = AppLocalizations.of(context)!;
    _renameTabController.text = oldName;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(localizations.renameList ?? 'Rename List'),
        content: TextField(
          controller: _renameTabController,
          decoration: InputDecoration(labelText: localizations.listName ?? 'List Name'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final newName = _renameTabController.text.trim();
              if (newName.isNotEmpty && !_tabs.contains(newName)) {
                // Copy documents to new collection
                final oldCollection = FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .collection('sublists')
                    .doc(oldName)
                    .collection('items');
                final newCollection = FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
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
                    .doc(user!.uid)
                    .collection('sublists')
                    .doc(oldName)
                    .delete();

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
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
            child: Text(localizations.save ?? 'Save'),
          )
        ],
      ),
    );
  }

  void _removeTab(int index) async {
    String listKey = _tabs[index];
    if (listKey != 'Main') {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
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
      _showErrorDialog(AppLocalizations.of(context)!.invalidQuantity);
      return;
    }

    String category = (listKey == 'Main') ? _categoryController.text.trim() : '';

    String collectionPath =
    listKey == 'Main' ? 'shoppingList' : 'sublists/$listKey/items';

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection(collectionPath)
        .add({
      'name': itemName,
      'quantity': quantity,
      'unit': _selectedUnit,
      'checked': false,
      if (listKey == 'Main' && category.isNotEmpty) 'category': category
    });
    _itemNameController.clear();
    _quantityController.clear();
    _categoryController.clear();
    setState(() => _selectedUnit = "kg");
  }

  void _editItem(DocumentSnapshot itemDoc, String currentListKey) {
    var itemData = itemDoc.data() as Map<String, dynamic>;
    _editNameController.text = itemData['name'];
    _editQtyController.text = itemData['quantity'].toString();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.editItem),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _editNameController,
              decoration:
              InputDecoration(labelText: AppLocalizations.of(context)!.itemName),
            ),
            TextField(
              controller: _editQtyController,
              keyboardType: TextInputType.number,
              decoration:
              InputDecoration(labelText: AppLocalizations.of(context)!.quantity),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text(AppLocalizations.of(context)!.save),
            onPressed: () async {
              await itemDoc.reference.update({
                'name': _editNameController.text.trim(),
                'quantity': int.tryParse(_editQtyController.text.trim()) ?? 1
              });
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _addSublistToMain(String listKey) async {
    final sublistDocs = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('sublists')
        .doc(listKey)
        .collection('items')
        .get();

    for (var doc in sublistDocs.docs) {
      var data = doc.data();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('shoppingList')
          .add({
        ...data,
        'category': listKey,
      });
    }

    // Show confirmation message
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
        .doc(user!.uid)
        .collection('inventory');

    final inventoryQuery = await inventoryRef
        .where('name', isEqualTo: data['name'])
        .where('unit', isEqualTo: data['unit'])
        .get();

    if (inventoryQuery.docs.isNotEmpty) {
      final existing = inventoryQuery.docs.first;
      await existing.reference.update({
        'quantity': (existing['quantity'] ?? 0) + (data['quantity'] ?? 0),
      });
    } else {
      await inventoryRef.add({
        'name': data['name'],
        'quantity': data['quantity'],
        'unit': data['unit'],
        'category': data['category'] ?? 'Uncategorized',
        'expirationDate': null,
      });
    }
  }

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
  Widget _buildListView(String listKey) {
    final path = 'sublists/$listKey/items';
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection(path)
          .where('checked', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        final docs = snapshot.data!.docs;
        return ListView(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return ListTile(
              title: Text(data['name']),
              subtitle: Text("${data['quantity']} ${data['unit']}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () => _editItem(doc, listKey),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () async => await doc.reference.delete(),
                  )
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
  Widget _buildCheckedItemsDropdown() {
    final localizations = AppLocalizations.of(context)!;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('shoppingList')
          .where('checked', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return SizedBox.shrink();

        return ExpansionTile(
          title: Text(localizations.checkedItems),
          children: [
            ...docs.map((itemDoc) {
              Map<String, dynamic> itemData = itemDoc.data() as Map<String, dynamic>;
              return ListTile(
                title: Text(itemData['name']),
                subtitle: Text("${itemData['quantity']} ${itemData['unit']}"),
                leading: Checkbox(
                  value: true,
                  onChanged: (_) async {
                    await itemDoc.reference.update({'checked': false});
                  },
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildCategorizedMainList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('shoppingList')
          .where('checked', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();

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

        return ListView(
          children: categorizedItems.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    entry.key,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ...entry.value.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(data['name']),
                    subtitle: Text("${data['quantity']} ${data['unit']}"),
                    leading: Checkbox(
                      value: data['checked'],
                      onChanged: (_) async {
                        await doc.reference.update({'checked': true});
                        await _updateInventory(doc);
                      },
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () => _editItem(doc, 'Main'),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () async => await doc.reference.delete(),
                        )
                      ],
                    ),
                  );
                }).toList(),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    if (_tabController == null) {
      return Center(child: CircularProgressIndicator());
    }

    final isMainTab = _tabs[_tabController!.index] == 'Main';

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.shoppingList),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, // Make the TabBar scrollable
          tabs: List.generate(_tabs.length, (i) {
            return GestureDetector(
              onLongPress: _tabs[i] != 'Main' ? () => _renameTab(i) : null,
              child: Tab(
                child: Row(
                  children: [
                    Text(_tabs[i]),
                    if (_tabs[i] != 'Main')
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => _removeTab(i),
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _addTab,
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemDialog(_tabs[_tabController!.index]),
        child: Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((key) {
          if (key == 'Main') {
            return Column(
              children: [
                Expanded(child: _buildCategorizedMainList()),
                _buildCheckedItemsDropdown(),
              ],
            );
          } else {
            return _buildListView(key); // Use _buildListView for sublists
          }
        }).toList(),
      ),
      bottomNavigationBar: !isMainTab
          ? StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('sublists')
            .doc(_tabs[_tabController!.index])
            .collection('items')
            .snapshots(),
        builder: (context, snapshot) {
          final hasItems = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Tooltip(
              message: hasItems
                  ? localizations.addItemsTooltip
                  : localizations.emptySublistTooltip,
              child: ElevatedButton.icon(
                icon: Icon(Icons.upload),
                label: Text(localizations.addToMainList),
                onPressed: hasItems
                    ? () => _addSublistToMain(_tabs[_tabController!.index])
                    : null, // Disable the button if the sublist is empty
              ),
            ),
          );
        },
      )
          : null,
    );
  }

  void _showAddItemDialog(String listKey) {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(localizations.addItem),
        content: Column(
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
              items: ['kg', 'g', 'lb', 'oz', 'liter', 'pieces'].map((unit) {
                return DropdownMenuItem(
                  value: unit,
                  child: Text(LocalizationHelper.getLocalizedString(
                      localizations, unit)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedUnit = value;
                });
              },
            ),
            if (listKey == 'Main')
              TextField(
                controller: _categoryController,
                decoration: InputDecoration(
                    labelText: localizations.category ?? 'Category'),
              ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              _addItem(listKey);
              Navigator.pop(context);
            },
            child: Text(localizations.add),
          )
        ],
      ),
    );
  }
}
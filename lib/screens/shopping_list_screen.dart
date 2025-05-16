import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kitchenly/screens/profile_screen.dart';
import '../utils/category_helper.dart';
import '../utils/localization_helper.dart';
import '../utils/colors.dart';


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
  String? _selectedUnit = "g";
  User? user = FirebaseAuth.instance.currentUser;
  List<String> _tabs = [];
  TabController? _tabController;
  bool _checkedItemsExpanded = false;
  late AnimationController _fabAnimationController;
  Set<String> expandedCategories = {};
  String? _userLanguage;

  static const String _mainTabKey = '__main__';



  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadSublistNames();
    _ensureShoppingListExists();
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
      _tabs = [_mainTabKey];
      _tabs.addAll(snapshot.docs.map((doc) => doc.id));
      _tabController = TabController(length: _tabs.length, vsync: this);
    });

  }

  Future<void> _addTab() async {
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;
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
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;
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
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;
    String listKey = _tabs[index];

    // Prevent deletion of the main tab
    if (listKey == _mainTabKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.cannotDeleteMainList),
        ),
      );
      return;
    }

    // Delete the sublist document from Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('sublists')
        .doc(listKey)
        .delete();

    setState(() {
      _tabs.removeAt(index);
      _tabController = TabController(length: _tabs.length, vsync: this);
    });
  }

  Future<void> _addItem(String listKey) async {
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;
    String itemName = _itemNameController.text.trim();
    String quantityText = _quantityController.text.trim();
    int quantity = int.tryParse(quantityText) ?? 0;
    if (itemName.isEmpty || quantity <= 0 || quantity > 999) {
      _showErrorDialog(localizations.invalidQuantity);
      return;
    }
    String category =  CategoryHelper.categorizeItem(itemName);
    final shoppingListRef = (listKey == _tabs[0])
        ? FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('shoppingList')
        : FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('sublists')
        .doc(listKey)
        .collection('items');

    await shoppingListRef.add({
      'name': itemName,
      'quantity': quantity,
      'unit': _selectedUnit,
      'checked': false,
      'category': category,
    });

    _itemNameController.clear();
    _quantityController.clear();
    setState(() => _selectedUnit = "g");
  }

  // void _editItem(DocumentSnapshot itemDoc, String currentListKey) {
  //   var itemData = itemDoc.data() as Map<String, dynamic>;
  //   _editNameController.text = itemData['name'];
  //   _editQtyController.text = itemData['quantity'].toString();
  //   showDialog(
  //     context: context,
  //     builder: (_) => AlertDialog(
  //       title: Text(AppLocalizations.of(context)!.editItem),
  //     IconButton(
  //       icon: Icon(Icons.delete, color: AppColors.deleteBg),
  //       tooltip: localizations.delete,),
  //       content: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           TextField(
  //             controller: _editNameController,
  //             decoration:
  //             InputDecoration(labelText: AppLocalizations.of(context)!.itemName),
  //           ),
  //           TextField(
  //             controller: _editQtyController,
  //             keyboardType: TextInputType.number,
  //             decoration:
  //             InputDecoration(labelText: AppLocalizations.of(context)!.quantity),
  //           ),
  //         ],
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () async {
  //             await itemDoc.reference.delete();
  //             Navigator.pop(context);
  //           },
  //           child: Icon(Icons.delete, color: AppColors.deleteBg),
  //         ),
  //         TextButton(
  //           child: Text(AppLocalizations.of(context)!.save),
  //           onPressed: () async {
  //             await itemDoc.reference.update({
  //               'name': _editNameController.text.trim(),
  //               'quantity': int.tryParse(_editQtyController.text.trim()) ?? 1
  //             });
  //             Navigator.pop(context);
  //           },
  //         ),
  //       ],
  //     ),
  //   );
  // }


  void _editItem(DocumentSnapshot itemDoc, String currentListKey) {
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;
    var itemData = itemDoc.data() as Map<String, dynamic>;
    _editNameController.text = itemData['name'];
    _editQtyController.text = itemData['quantity'].toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(localizations.editItem),
            IconButton(
              icon: Icon(Icons.delete, color: AppColors.deleteBg),
              tooltip: localizations.delete,
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(localizations.delete),
                    content: Text(localizations.confirmDeleteItem),
                    actions: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(localizations.delete),
                              ),
                              SizedBox(height: 10),
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(localizations.cancel),
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
                  Navigator.pop(context); // Close the edit dialog
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
              decoration: InputDecoration(labelText: localizations.itemName),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _editQtyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: localizations.quantity),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              await itemDoc.reference.update({
                'name': _editNameController.text.trim(),
                'quantity': int.tryParse(_editQtyController.text.trim()) ?? 1,
              });
              Navigator.pop(context);
            },
            child: Text(localizations.save),
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
          .add(data);
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
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.error),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.ok),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(String listKey) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('sublists')
          .doc(listKey)
          .collection('items')
          .where('checked', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        final Map<String, List<DocumentSnapshot>> categorizedItems = {};
        final localizations = _userLanguage != null
            ? lookupAppLocalizations(Locale(_userLanguage!))
            : AppLocalizations.of(context)!;
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final category = data['category'] ?? 'Uncategorized';
          if (!categorizedItems.containsKey(category)) {
            categorizedItems[category] = [];
          }
          categorizedItems[category]!.add(doc);
        }

        if (!snapshot.hasData) return CircularProgressIndicator();

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
                  localizations.shoppingSublistIsEmpty,
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
        //final docs = snapshot.data!.docs;
        return ListView(
          children: categorizedItems.entries.map((entry) {
            final isExpanded = expandedCategories.contains(entry.key);
            return DragTarget<DocumentSnapshot>(
              onAccept: (draggedItemDoc) async {
                await draggedItemDoc.reference.update({'category': entry.key});
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
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;
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
                    await itemDoc.reference.update({'checked': false});
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
              child: Text(localizations.deleteCheckedItems),
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
          .doc(user!.uid)
          .collection('shoppingList')
          .where('checked', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        final docs = snapshot.data!.docs;
        final localizations = _userLanguage != null
            ? lookupAppLocalizations(Locale(_userLanguage!))
            : AppLocalizations.of(context)!;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_rounded, // Same cart icon
                  size: 95,
                  color: AppColors.iconColor,
                ),
                SizedBox(height: 16),
                Text(
                  localizations.shoppingListIsEmpty, // Add this to your l10n
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
                            value: itemData['checked'] ?? false, // ✅ dynamic from Firestore
                            onChanged: (value) async {
                              if (value == true) {
                                await itemDoc.reference.update({'checked': true});
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
                          value: itemData['checked'] ?? false, // ✅ dynamic from Firestore
                          onChanged: (value) async {
                            if (value == true) {
                              await itemDoc.reference.update({'checked': true});
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
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;
    if (_tabController == null) {
      return Center(child: CircularProgressIndicator());
    }

    bool isMainTab = _tabs[_tabController!.index] == _mainTabKey;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.shoppingList),
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
                    icon: const CircleAvatar(
                      backgroundImage: AssetImage('assets/images/icons/profile_chef_icon.png'),
                      backgroundColor: AppColors.profileIconBg,
                      ),
                  tooltip: localizations.profile,
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
                      onLongPress: _tabs[i] != _mainTabKey ? () => _renameTab(i) : null,
                      child: Tab(
                        child: Row(
                          children: [
                            Text(_tabs[i] == _mainTabKey
                                ? localizations.main
                                : _tabs[i]),

                            if (_tabs[i] != _mainTabKey)
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
                    localizations.addSublist,
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
          if (key == _mainTabKey) {
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
                      .doc(user!.uid)
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
                            ? localizations.addItemsTooltip
                            : localizations.emptySublistTooltip,
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.upload),
                          label: Text(localizations.addToMainList),
                          onPressed: hasItems
                              ? () => _addSublistToMain(key)
                              : null, // Disable the button if the sublist is empty
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
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;
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
              items: ['g', 'lb', 'oz', 'liter', 'pieces','packs','cups'].map((unit) {
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
            SizedBox(height: 20),
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
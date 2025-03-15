import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ShoppingListScreen extends StatefulWidget {
  final String language;

  const ShoppingListScreen({Key? key, required this.language}) : super(key: key);

  @override
  _ShoppingListScreenState createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  String? _selectedUnit = "kg";
  User? user = FirebaseAuth.instance.currentUser;

  void _addItem() async {
    if (_itemNameController.text.trim().isNotEmpty &&
        _quantityController.text.trim().isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('shopping_list')
          .add({
        'name': _itemNameController.text.trim(),
        'quantity': int.parse(_quantityController.text.trim()),
        'unit': _selectedUnit,
        'checked': false,
      });

      _itemNameController.clear();
      _quantityController.clear();
      setState(() {
        _selectedUnit = "kg"; // Reset unit selection
      });
    }
  }

  void _toggleItemChecked(String itemId, bool isChecked) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('shopping_list')
        .doc(itemId)
        .update({'checked': isChecked});
  }

  void _deleteItem(String itemId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('shopping_list')
        .doc(itemId)
        .delete();
  }

  void _deleteCheckedItems() async {
    var checkedItems = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('shopping_list')
        .where('checked', isEqualTo: true)
        .get();

    for (var doc in checkedItems.docs) {
      await doc.reference.delete();
    }
  }

  void _moveCheckedItemsToInventory() async {
    var checkedItems = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('shopping_list')
        .where('checked', isEqualTo: true)
        .get();

    for (var item in checkedItems.docs) {
      var itemData = item.data();
      var existingItemQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('inventory')
          .where('name', isEqualTo: itemData['name'])
          .get();

      if (existingItemQuery.docs.isNotEmpty) {
        var existingItem = existingItemQuery.docs.first;
        int newQuantity =
            existingItem['quantity'] + itemData['quantity'];

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('inventory')
            .doc(existingItem.id)
            .update({'quantity': newQuantity});
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('inventory')
            .add({
          'name': itemData['name'],
          'quantity': itemData['quantity'],
          'unit': itemData['unit'],
          'category': "Uncategorized",
        });
      }
      await item.reference.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.shoppingList)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemDialog(),
        child: Icon(Icons.add),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: _deleteCheckedItems,
              tooltip: localizations.deleteCheckedItems,
            ),
            IconButton(
              icon: Icon(Icons.check_circle),
              onPressed: _moveCheckedItemsToInventory,
              tooltip: localizations.addToInventory,
            ),
          ],
        ),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('shopping_list')
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return CircularProgressIndicator();

          return ListView(
            children: snapshot.data!.docs.map((itemDoc) {
              var itemData = itemDoc.data() as Map<String, dynamic>;

              return Dismissible(
                key: Key(itemDoc.id),
                direction: DismissDirection.startToEnd,
                onDismissed: (direction) => _deleteItem(itemDoc.id),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.only(left: 20),
                  child: Icon(Icons.delete, color: Colors.white),
                ),
                child: CheckboxListTile(
                  title: Text(
                    itemData['name'],
                    style: TextStyle(
                        decoration: itemData['checked']
                            ? TextDecoration.lineThrough
                            : TextDecoration.none),
                  ),
                  subtitle: Text("${itemData['quantity']} ${itemData['unit']}"),
                  value: itemData['checked'],
                  onChanged: (value) =>
                      _toggleItemChecked(itemDoc.id, value ?? false),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.addItem),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _itemNameController,
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.itemName),
              ),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.quantity),
              ),
              DropdownButtonFormField<String>(
                value: _selectedUnit,
                items: ["kg", "grams", "liters", "pieces"]
                    .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedUnit = value;
                  });
                },
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
            child: Text(AppLocalizations.of(context)!.add),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../utils/localization_helper.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({Key? key}) : super(key: key);

  @override
  _ShoppingListScreenState createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  String? _selectedUnit = "kg";
  User? user = FirebaseAuth.instance.currentUser;

  // ✅ Add item to Shopping List
  void _addItem() async {
    String itemName = _itemNameController.text.trim();
    String quantityText = _quantityController.text.trim();
    int quantity = int.tryParse(quantityText) ?? 0;

    if (itemName.isEmpty || quantity <= 0 || quantity > 999) {
      _showErrorDialog(AppLocalizations.of(context)!.invalidQuantity);
      return;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('shoppingList')
        .add({
      'name': itemName,
      'quantity': quantity,
      'unit': _selectedUnit,
      'checked': false
    });

    _itemNameController.clear();
    _quantityController.clear();
    setState(() {
      _selectedUnit = "kg";
    });
  }

  // ✅ Check or uncheck item
  void _toggleCheckItem(DocumentSnapshot itemDoc) async {
    Map<String, dynamic> itemData = itemDoc.data() as Map<String, dynamic>;
    bool isChecked = itemData['checked'];

    await itemDoc.reference.update({'checked': !isChecked});

    if (!isChecked) {
      // ✅ If item is checked, add it to inventory
      QuerySnapshot existingItems = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('inventory')
          .where('name', isEqualTo: itemData['name'])
          .get();

      if (existingItems.docs.isNotEmpty) {
        var existingItem = existingItems.docs.first;
        int newQuantity = existingItem['quantity'] + itemData['quantity'];
        await existingItem.reference.update({'quantity': newQuantity});
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('inventory')
            .add({
          'name': itemData['name'],
          'quantity': itemData['quantity'],
          'unit': itemData['unit'],
          'category': '',
        });
      }
    }
  }

  // ✅ Delete all checked-off items
  void _deleteCheckedItems() async {
    QuerySnapshot checkedItems = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('shoppingList')
        .where('checked', isEqualTo: true)
        .get();

    for (var doc in checkedItems.docs) {
      await doc.reference.delete();
    }
  }

  // ✅ Show error dialog
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

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.shoppingList)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemDialog(),
        child: Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ✅ Checked-off items dropdown
          StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user!.uid)
                .collection('shoppingList')
                .where('checked', isEqualTo: true)
                .snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> checkedSnapshot) {
              if (!checkedSnapshot.hasData) return CircularProgressIndicator();

              var checkedItems = checkedSnapshot.data!.docs;

              return ExpansionTile(
                title: Text(localizations.checkedItems),
                children: [
                  ...checkedItems.map((itemDoc) {
                    Map<String, dynamic> itemData =
                    itemDoc.data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(itemData['name']),
                      subtitle:
                      Text("${itemData['quantity']} ${itemData['unit']}"),
                      leading: Checkbox(
                        value: true,
                        onChanged: (_) => _toggleCheckItem(itemDoc),
                      ),
                    );
                  }).toList(),
                  TextButton(
                    onPressed: _deleteCheckedItems,
                    child: Text(localizations.deleteAll),
                  )
                ],
              );
            },
          ),

          // ✅ Shopping List
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('shoppingList')
                  .where('checked', isEqualTo: false)
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();

                return ListView(
                  children: snapshot.data!.docs.map((itemDoc) {
                    Map<String, dynamic> itemData =
                    itemDoc.data() as Map<String, dynamic>;

                    return ListTile(
                      title: Text(itemData['name']),
                      subtitle:
                      Text("${itemData['quantity']} ${itemData['unit']}"),
                      leading: Checkbox(
                        value: false,
                        onChanged: (_) => _toggleCheckItem(itemDoc),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => itemDoc.reference.delete(),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Add item dialog
  void _showAddItemDialog() {
    final localizations = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
          ],
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

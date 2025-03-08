import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class OnboardingInventoryScreen extends StatefulWidget {
  final String language;

  const OnboardingInventoryScreen({Key? key, required this.language}) : super(key: key);

  @override
  _OnboardingInventoryScreenState createState() => _OnboardingInventoryScreenState();
}

class _OnboardingInventoryScreenState extends State<OnboardingInventoryScreen> {
  final Map<String, Map<String, dynamic>> selectedItems = {};
  final Map<String, List<String>> categorizedItems = {
    "Vegetables": ["Tomato", "Carrot", "Potato"],
    "Dairy": ["Milk", "Cheese", "Yogurt"],
    "Grains": ["Rice", "Pasta", "Bread"]
  };

  void _submitInventory() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      for (var item in selectedItems.entries) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('inventory')
            .doc(item.key)
            .set(item.value);
      }
      Navigator.pushNamedAndRemoveUntil(context, '/inventory', (route) => false, arguments: widget.language);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.selectKitchenItems)),
      body: ListView(
        children: categorizedItems.entries.map((category) {
          return ExpansionTile(
            title: Text(localizations.getString(category.key)),
            children: category.value.map((item) {
              return ListTile(
                title: Text(localizations.getString(item)),
                trailing: SizedBox(
                  width: 100,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: localizations.quantity),
                    onChanged: (value) {
                      setState(() {
                        if (value.isNotEmpty) {
                          selectedItems[item] = {"category": category.key, "quantity": int.parse(value)};
                        } else {
                          selectedItems.remove(item);
                        }
                      });
                    },
                  ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _submitInventory,
        child: Icon(Icons.check),
      ),
    );
  }
}

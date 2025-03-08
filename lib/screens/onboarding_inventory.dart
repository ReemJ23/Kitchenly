import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../utils/localization_helper.dart'; // ✅ Import the helper

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

  final Map<String, String> units = {
    "Tomato": "kg",
    "Carrot": "kg",
    "Potato": "kg",
    "Milk": "liters",
    "Cheese": "grams",
    "Yogurt": "grams",
    "Rice": "kg",
    "Pasta": "grams",
    "Bread": "pieces"
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
      Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false, arguments: widget.language);
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
            title: Text(LocalizationHelper.getLocalizedString(localizations, category.key)), // ✅ Fixed
            children: category.value.map((item) {
              return ListTile(
                title: Text(LocalizationHelper.getLocalizedString(localizations, item)), // ✅ Fixed
                subtitle: DropdownButtonFormField<String>(
                  value: selectedItems[item]?['unit'] ?? units[item],
                  onChanged: (value) {
                    setState(() {
                      if (selectedItems.containsKey(item)) {
                        selectedItems[item]!['unit'] = value!;
                      }
                    });
                  },
                  items: ["kg", "grams", "liters", "pieces"]
                      .map((unit) => DropdownMenuItem(
                    value: unit,
                    child: Text(unit),
                  ))
                      .toList(),
                ),
                trailing: SizedBox(
                  width: 100,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: localizations.quantity),
                    onChanged: (value) {
                      setState(() {
                        if (value.isNotEmpty) {
                          selectedItems[item] = {
                            "category": category.key,
                            "quantity": int.parse(value),
                            "unit": units[item] ?? "pieces"
                          };
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

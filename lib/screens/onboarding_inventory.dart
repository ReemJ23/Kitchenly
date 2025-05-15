import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../utils/category_helper.dart';
import '../utils/colors.dart';
import '../utils/localization_helper.dart';




bool _isLoading = false;
class OnboardingInventoryScreen extends StatefulWidget {
  final String language;

  const OnboardingInventoryScreen({Key? key, required this.language}) : super(key: key);

  @override
  _OnboardingInventoryScreenState createState() => _OnboardingInventoryScreenState();
}

class _OnboardingInventoryScreenState extends State<OnboardingInventoryScreen> {
  final Map<String, Map<String, dynamic>> selectedItems = {
  };
  final Map<String, List<String>> categorizedItems = {
    "Vegetables": ["Tomato", "Carrot", "Potato"],
    "Dairy": ["Milk", "Cheese", "Yogurt"],
    "Grains": ["Rice", "Pasta", "Bread"]
  };

  final Map<String, String> units = {
    "Tomato": "g",
    "Carrot": "g",
    "Potato": "g",
    "Milk": "liter",
    "Cheese": "g",
    "Yogurt": "g",
    "Rice": "g",
    "Pasta": "g",
    "Bread": "pieces"
  };


  void _submitInventory() async {
    setState(() {
      _isLoading = true;
    });

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      for (var item in selectedItems.entries) {
        String itemName = item.key;
        var itemData = item.value;

        if (itemData['quantity'].toString().isEmpty) continue;

        final category = CategoryHelper.categorizeItem(itemName);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('inventory.dart')
            .add({
          'name': itemName,
          'quantity': itemData['quantity'],
          'unit': itemData['unit'],
          'category': category,
          'expirationDate': null,
        });
      }
    }

    setState(() {
      _isLoading = false;
    });

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/main',
          (route) => false,
      arguments: widget.language,
    );
  }


  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Setting up your kitchen...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.heading1, // You can customize the color
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(" "),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                localizations.onboardingInventoryMessage,
                style: Theme
                    .of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(
                  color: AppColors.heading1,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 5),
              Text(
                localizations.onboardingInventorySubMessage,
                style: Theme
                    .of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  color: AppColors.heading2,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
          ...categorizedItems.entries.map((category) {
            return ExpansionTile(
              title: Text(LocalizationHelper.getLocalizedString(
                  localizations, category.key)),
              children: category.value.map((item) {
                if (!selectedItems.containsKey(item)) {
                  selectedItems[item] = {
                    "quantity": "",
                    "unit": units[item] ?? "pieces"
                  };
                }

                return ListTile(
                  title: Text(LocalizationHelper.getLocalizedString(
                      localizations, item)),
                  subtitle: DropdownButtonFormField<String>(
                    value: selectedItems[item]!['unit'],
                    onChanged: (value) {
                      setState(() {
                        selectedItems[item]!['unit'] = value!;
                      });
                    },
                    items: ['g', 'lb', 'oz', 'liter', 'pieces','packs','cups']
                        .map((unit) =>
                        DropdownMenuItem(
                          value: unit,
                          child: Text(unit),
                        ))
                        .toList(),
                  ),
                  trailing: SizedBox(
                    width: 100,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: localizations.quantity),
                      controller: TextEditingController(
                        text: selectedItems[item]!['quantity'].toString(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          if (value.isNotEmpty) {
                            selectedItems[item]!['quantity'] =
                                int.tryParse(value) ?? "";
                          } else {
                            selectedItems[item]!['quantity'] = "";
                          }
                        });
                      },
                    ),
                  ),
                );
              }).toList(),
            );
          }).toList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _submitInventory,
        child: Icon(Icons.check),
      ),
    );
  }
}

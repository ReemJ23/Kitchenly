import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../utils/localization_helper.dart'; // Import localization helper

class InventoryScreen extends StatelessWidget {
  final String language;

  const InventoryScreen({Key? key, required this.language}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.inventory)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('inventory')
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          Map<String, List<Map<String, dynamic>>> categorizedItems = {};

          for (var doc in snapshot.data!.docs) {
            Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?; // ✅ Ensure correct type
            if (data == null) continue; // ✅ Skip if null

            String category = data['category'] ?? 'Unknown'; // ✅ Handle null category
            String itemName = data['name'] ?? 'Unnamed Item'; // ✅ Handle null item name
            int quantity = (data['quantity'] as int?) ?? 0; // ✅ Handle null quantity

            if (!categorizedItems.containsKey(category)) {
              categorizedItems[category] = [];
            }
            categorizedItems[category]!.add({
              'name': itemName,
              'quantity': quantity,
            });
          }

          return ListView(
            children: categorizedItems.entries.map((entry) {
              return ExpansionTile(
                title: Text(LocalizationHelper.getLocalizedString(localizations, entry.key)), // ✅ Fix null category
                children: entry.value.map((item) {
                  return ListTile(
                    title: Text(LocalizationHelper.getLocalizedString(localizations, item['name'])), // ✅ Fix null name
                    subtitle: Text("${localizations.quantity}: ${item['quantity']}"),
                  );
                }).toList(),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

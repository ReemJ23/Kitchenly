import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../utils/localization_helper.dart'; // ✅ Import the helper

class InventoryScreen extends StatelessWidget {
  final String language;

  const InventoryScreen({Key? key, required this.language}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.inventory)),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('inventory')
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          Map<String, List<Map<String, dynamic>>> categorizedItems = {};

          for (var doc in snapshot.data!.docs) {
            Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;

            String category = data['category'] ?? 'Unknown';
            String itemName = data['name'] ?? 'Unnamed Item';
            int quantity = (data['quantity'] as int?) ?? 0;
            String unit = data['unit'] ?? 'pieces';

            if (!categorizedItems.containsKey(category)) {
              categorizedItems[category] = [];
            }
            categorizedItems[category]!.add({
              'name': itemName,
              'quantity': quantity,
              'unit': unit
            });
          }

          return ListView(
            children: categorizedItems.entries.map((entry) {
              return ExpansionTile(
                title: Text(LocalizationHelper.getLocalizedString(localizations, entry.key)), // ✅ Fixed
                children: entry.value.map((item) {
                  return ListTile(
                    title: Text(LocalizationHelper.getLocalizedString(localizations, item['name'])), // ✅ Fixed
                    subtitle: Text("${localizations.quantity}: ${item['quantity']} ${item['unit']}"),
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

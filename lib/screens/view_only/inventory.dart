import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../utils/colors.dart';

class ViewOnlyInventoryScreen extends StatefulWidget {
  final String familyOwnerId;
  final String language;

  const ViewOnlyInventoryScreen({
    required this.familyOwnerId,
    required this.language,
    Key? key,
  }) : super(key: key);

  @override
  _ViewOnlyInventoryScreenState createState() => _ViewOnlyInventoryScreenState();
}

class _ViewOnlyInventoryScreenState extends State<ViewOnlyInventoryScreen> {
  Set<String> expandedCategories = {};
  String? _userLanguage;

  @override
  void initState() {
    super.initState();
    _userLanguage = widget.language;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.inventory+" - "+localizations.readOnlyMode),
        centerTitle: true,
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.familyOwnerId)
            .collection('inventory')
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.restaurant_menu_rounded,
                    size: 95,
                    color: AppColors.iconColor,
                  ),
                  SizedBox(height: 16),
                  Text(
                    localizations.inventoryIsEmpty,
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

          // Group items by category
          Map<String, List<QueryDocumentSnapshot>> categorizedItems = {};
          List<QueryDocumentSnapshot> uncategorizedItems = [];

          for (var doc in snapshot.data!.docs) {
            Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
            if (data == null || !data.containsKey('name')) continue;

            String category = data['category'] ?? '';

            if (category.isEmpty) {
              uncategorizedItems.add(doc);
            } else {
              if (!categorizedItems.containsKey(category)) {
                categorizedItems[category] = [];
              }
              categorizedItems[category]!.add(doc);
            }
          }

          // Sort items by expiration date (soonest first)
          for (var entry in categorizedItems.entries) {
            entry.value.sort((a, b) {
              DateTime? aDate = (a['expirationDate'] as Timestamp?)?.toDate();
              DateTime? bDate = (b['expirationDate'] as Timestamp?)?.toDate();
              if (aDate == null && bDate == null) return 0;
              if (aDate == null) return 1;
              if (bDate == null) return -1;
              return aDate.compareTo(bDate);
            });
          }

          uncategorizedItems.sort((a, b) {
            DateTime? aDate = (a['expirationDate'] as Timestamp?)?.toDate();
            DateTime? bDate = (b['expirationDate'] as Timestamp?)?.toDate();
            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;
            return aDate.compareTo(bDate);
          });

          return ListView(
            children: [
              // Uncategorized items
              if (uncategorizedItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    localizations.uncategorized,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ...uncategorizedItems.map((itemDoc) {
                Map<String, dynamic> itemData = itemDoc.data() as Map<String, dynamic>;
                return ListTile(
                  title: Text(itemData['name'] ?? "Unnamed Item"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${itemData['quantity']} ${itemData['unit']}"),
                      if (itemData.containsKey('expirationDate') && itemData['expirationDate'] != null)
                        Text(
                          "${localizations.expirationDate}: ${DateFormat.yMd().format((itemData['expirationDate'] as Timestamp).toDate())}",
                          style: TextStyle(
                            color: (itemData['expirationDate'] as Timestamp).toDate().isBefore(DateTime.now())
                                ? AppColors.pastExpirationDate
                                : AppColors.futureExpirationDate,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),

              // Categorized items
              ...categorizedItems.entries.map((entry) {
                final isExpanded = expandedCategories.contains(entry.key);

                return ExpansionTile(
                  key: PageStorageKey(entry.key),
                  title: Text(
                    entry.key,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                    return ListTile(
                      title: Text(itemData['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${itemData['quantity']} ${itemData['unit']}"),
                          if (itemData['expirationDate'] != null)
                            Text(
                              "${localizations.expirationDate}: ${DateFormat.yMd().format((itemData['expirationDate'] as Timestamp).toDate())}",
                              style: TextStyle(
                                color: (itemData['expirationDate'] as Timestamp).toDate().isBefore(DateTime.now())
                                    ? AppColors.pastExpirationDate
                                    : AppColors.futureExpirationDate,
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }
}
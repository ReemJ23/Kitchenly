import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../utils/colors.dart';

class ViewOnlyShoppingListScreen extends StatefulWidget {
  final String familyOwnerId;
  final String language;

  const ViewOnlyShoppingListScreen({
    required this.familyOwnerId,
    required this.language,
    Key? key,
  }) : super(key: key);

  @override
  State<ViewOnlyShoppingListScreen> createState() => _ViewOnlyShoppingListScreenState();
}

class _ViewOnlyShoppingListScreenState extends State<ViewOnlyShoppingListScreen>
    with TickerProviderStateMixin {
  List<String> _tabs = [];
  TabController? _tabController;
  Set<String> expandedCategories = {};
  late AppLocalizations localizations;
  String? _userLanguage;
  @override
  void initState() {
    super.initState();
    _userLanguage = widget.language;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;
    _loadSublistNames();
  }

  Future<void> _loadSublistNames() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.familyOwnerId)
        .collection('sublists')
        .get();

    setState(() {
      _tabs = [localizations.main];
      _tabs.addAll(snapshot.docs.map((doc) => doc.id));
      _tabController = TabController(length: _tabs.length, vsync: this);
    });
  }

  Widget _buildListView(String listKey) {
    final collectionRef = listKey == localizations.main
        ? FirebaseFirestore.instance
        .collection('users')
        .doc(widget.familyOwnerId)
        .collection('shoppingList')
        : FirebaseFirestore.instance
        .collection('users')
        .doc(widget.familyOwnerId)
        .collection('sublists')
        .doc(listKey)
        .collection('items');

    return StreamBuilder<QuerySnapshot>(
      stream: collectionRef.where('checked', isEqualTo: false).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

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
                  listKey == localizations.main
                      ? localizations.shoppingListIsEmpty
                      : localizations.shoppingSublistIsEmpty,
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

        return ListView(
          children: categorizedItems.entries.map((entry) {
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
                final itemData = itemDoc.data() as Map<String, dynamic>;
                return ListTile(
                  title: Text(itemData['name']),
                  subtitle: Text("${itemData['quantity']} ${itemData['unit']}"),
                );
              }).toList(),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCheckedItemsDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.familyOwnerId)
          .collection('shoppingList')
          .where('checked', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox.shrink();
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
                  onChanged: null, // Disabled for view-only
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_tabController == null) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.shoppingList+"-"+localizations.readOnlyMode),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((key) {
          if (key == localizations.main) {
            return Column(
              children: [
                Expanded(child: _buildListView(key)),
                _buildCheckedItemsDropdown(),
              ],
            );
          } else {
            return _buildListView(key);
          }
        }).toList(),
      ),
    );
  }
}
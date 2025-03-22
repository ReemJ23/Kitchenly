import 'package:flutter/material.dart';
import 'package:kitchenly/screens/profile_screen.dart';
import 'package:kitchenly/screens/inventory_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kitchenly/screens/shopping_list_screen.dart';

import 'inventory_screen.dart';

class MainScreen extends StatefulWidget {
  final String language;

  const MainScreen({Key? key, required this.language}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 1; // Default to Inventory screen

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _pages.add(ProfileScreen(language: widget.language));
    _pages.add(InventoryScreen());
    _pages.add(ShoppingListScreen()); // Placeholder for Shopping List
    _pages.add(Container()); // Placeholder for Recipes
    _pages.add(Container()); // Placeholder for Browsing
    _pages.add(Container()); // Placeholder for Meal Plan
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      body: _pages[_selectedIndex], // Display selected page
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Allows more than 3 items
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.person), label: localizations.profile),
          BottomNavigationBarItem(icon: Icon(Icons.kitchen), label: localizations.inventory),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: localizations.shoppingList),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: localizations.recipes),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: localizations.browsing),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: localizations.mealPlan),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitchenly/screens/view_only/my_recipes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kitchenly/screens/editable/inventory.dart';
import 'package:kitchenly/screens/editable/shopping_list.dart';
import 'package:kitchenly/screens/editable/meal_plan.dart';
import 'package:kitchenly/screens/view_only/inventory.dart';
import 'package:kitchenly/screens/view_only/shopping_list.dart';
import 'package:kitchenly/screens/view_only/meal_plan.dart';

import 'editable/my_recipes.dart';

class FamilyLoginScreen extends StatefulWidget {
  final String language;
  const FamilyLoginScreen({Key? key, required this.language}) : super(key: key);
  @override
  _FamilyLoginScreenState createState() => _FamilyLoginScreenState();
}

class _FamilyLoginScreenState extends State<FamilyLoginScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  String? errorText;
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loginAsFamily() async {
    if (_isLoading) return;

    setState(() {
      errorText = null;
      _isLoading = true;
    });

    try {
      final code = _codeController.text.trim();
      final name = _nameController.text.trim();

      if (code.isEmpty || name.isEmpty) {
        throw AppLocalizations.of(context)!.fillAllFields;
      }

      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('syncCode', isEqualTo: code)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        throw AppLocalizations.of(context)!.invalidCode;
      }

      final userDoc = userQuery.docs.first;
      final familyOwnerId = userDoc.id;

      // Get the family owner's language preference
      final ownerLanguage = userDoc['language'] ?? 'en';

      final familyMemberQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(familyOwnerId)
          .collection('familyMembers')
          .where('name', isEqualTo: name.toLowerCase())
          .limit(1)
          .get();

      if (familyMemberQuery.docs.isEmpty) {
        throw AppLocalizations.of(context)!.nameNotFound;
      }

      final memberDoc = familyMemberQuery.docs.first;
      final permission = memberDoc['permission'] as String;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('family_owner_uid', familyOwnerId);
      await prefs.setString('family_member_name', name);
      await prefs.setString('family_member_permission', permission);
      await prefs.setBool('is_family_member', true);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => FamilyDashboard(
              familyOwnerId: familyOwnerId,
              permission: permission,
              language: ownerLanguage, // Pass the owner's language
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorText = e is String ? e : AppLocalizations.of(context)!.loginError;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.loginAsFamily),
      centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              SizedBox(height: 20),
              TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: loc.enterSyncCode,
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: loc.enterName,
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 24),
              if (errorText != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    errorText!,
                    style: TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _loginAsFamily,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Text(
                    loc.login,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FamilyDashboard extends StatefulWidget {
  final String familyOwnerId;
  final String permission;
  final String language;

  const FamilyDashboard({
    required this.familyOwnerId,
    required this.permission,
    required this.language,
    Key? key,
  }) : super(key: key);

  @override
  _FamilyDashboardState createState() => _FamilyDashboardState();
}

class _FamilyDashboardState extends State<FamilyDashboard> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _buildScreen(
        viewScreen: ViewOnlyInventoryScreen(
          familyOwnerId: widget.familyOwnerId,
          language: widget.language,
        ),
        editScreen: EditableInventoryScreen(
          familyOwnerId: widget.familyOwnerId,
          language: widget.language,
        ),
      ),
      _buildScreen(
        viewScreen: ViewOnlyShoppingListScreen(
          familyOwnerId: widget.familyOwnerId,
          language: widget.language,
        ),
        editScreen: EditableShoppingListScreen(
          familyOwnerId: widget.familyOwnerId,
          language: widget.language,
        ),
      ),
      _buildScreen(
        viewScreen: ViewOnlyRecipeScreen(
          familyOwnerId: widget.familyOwnerId,
          language: widget.language,
        ),
        editScreen: EditableRecipesScreen(
          familyOwnerId: widget.familyOwnerId,
          language: widget.language,
        ),
      ),
      _buildScreen(
        viewScreen: ViewOnlyMealPlanScreen(
          familyOwnerId: widget.familyOwnerId,
          language: widget.language,
        ),
        editScreen: EditableMealPlanScreen(
          familyOwnerId: widget.familyOwnerId,
          language: widget.language,
        ),
      ),
    ];
  }

  Widget _buildScreen({
    required Widget viewScreen,
    required Widget editScreen,
  }) {
    return widget.permission == 'edit' ? editScreen : viewScreen;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.kitchen),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Shopping List',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu),
            label: 'Recipes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Meal Plan',
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Inventory';
      case 1:
        return 'Shopping List';
      case 2:
        return 'Recipes';
      case 3:
        return 'Meal Plan';
      default:
        return 'Kitchenly';
    }
  }
}
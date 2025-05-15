import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:kitchenly/screens/profile_screen.dart';
import 'package:table_calendar/table_calendar.dart';
import '../utils/category_helper.dart';
import '../utils/colors.dart';
import '../utils/localization_helper.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({Key? key}) : super(key: key);

  @override
  _MealPlanScreenState createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  String? _userLanguage;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<String>> _mealsByDay = {};
  List<DateTime> _mealPlanRanges = [];
  String? _selectedMealPlanId;


  @override
  void initState() {
    super.initState();
    _fetchUserLanguage();
    _selectedDay = _focusedDay;
    _loadMealPlans();
  }

  Future<void> _loadMealPlans({String? selectedPlanId}) async {
    if (selectedPlanId == null && _selectedMealPlanId == null) return;

    final planIdToLoad = selectedPlanId ?? _selectedMealPlanId;

    final mealPlanDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('mealPlans')
        .doc(planIdToLoad)
        .get();

    if (!mealPlanDoc.exists) return;

    final data = mealPlanDoc.data()!;
    _selectedMealPlanId = mealPlanDoc.id;

    final recipeDates = data['recipeDates'] as Map<String, dynamic>;
    final startDate = (data['startDate'] as Timestamp).toDate();
    final endDate = (data['endDate'] as Timestamp).toDate();

    Map<DateTime, List<String>> meals = {};
    Set<DateTime> ranges = {};

    for (var d = startDate; d.isBefore(endDate.add(Duration(days: 1)));
    d = d.add(Duration(days: 1))) {
      ranges.add(DateTime(d.year, d.month, d.day));
    }

    recipeDates.forEach((id, ts) {
      final date = (ts as Timestamp).toDate();
      final key = DateTime(date.year, date.month, date.day);
      meals[key] = (meals[key] ?? [])
        ..add(id);
    });

    setState(() {
      _mealPlanRanges = ranges.toList();
      _mealsByDay = meals;
    });
  }

  void _selectMealPlan() async {
    final localizations = AppLocalizations.of(context)!;

    final plans = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('mealPlans')
        .get();

    if (plans.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.noMealPlans)));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(localizations.selectMealPlan),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: plans.docs.map((doc) {
              final data = doc.data();
              final start = (data['startDate'] as Timestamp).toDate();
              final end = (data['endDate'] as Timestamp).toDate();

              return ListTile(
                title: Text(
                    '${DateFormat.yMMMd().format(start)} - ${DateFormat.yMMMd()
                        .format(end)}'),
                trailing: _selectedMealPlanId == doc.id ? Icon(
                    Icons.check, color: Colors.green) : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _loadMealPlans(selectedPlanId: doc.id);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }


  List<dynamic> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _mealsByDay[key] ?? [];
  }


  Future<void> _fetchUserLanguage() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    if (userDoc.exists) {
      setState(() {
        _userLanguage = userDoc['language'] ?? 'en';
      });
    }
  }

  void _confirmDeleteMealPlan() async {
    final localizations = AppLocalizations.of(context)!;
    final plans = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('mealPlans')
        .get();

    if (plans.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.noMealPlans)));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(localizations.deleteMealPlan),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: plans.docs.map((doc) {
              final start = (doc['startDate'] as Timestamp).toDate();
              final end = (doc['endDate'] as Timestamp).toDate();
              return ListTile(
                title: Text(
                    '${DateFormat.yMMMd().format(start)} - ${DateFormat.yMMMd()
                        .format(end)}'),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: AppColors.deleteBg),
                  onPressed: () async {
                    final deletedPlanId = doc.id;

                    await doc.reference.delete();
                    Navigator.of(context).pop();

                    if (_selectedMealPlanId == deletedPlanId) {
                      setState(() {
                        _selectedMealPlanId = null;
                        _mealPlanRanges.clear();
                        _mealsByDay.clear();
                      });
                    } else {
                      _loadMealPlans(
                          selectedPlanId: _selectedMealPlanId); // refresh if another plan was selected
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(
                          AppLocalizations.of(context)!.mealPlanDeleted)),
                    );
                  },
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _navigateToEditMealPlan() async {
    final localizations = AppLocalizations.of(context)!;

    final plans = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('mealPlans')
        .get();

    if (plans.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.noMealPlans)));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(localizations.editMealPlan),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: plans.docs.map((doc) {
              final data = doc.data();
              final start = (data['startDate'] as Timestamp).toDate();
              final end = (data['endDate'] as Timestamp).toDate();

              return ListTile(
                title: Text(
                    '${DateFormat.yMMMd().format(start)} - ${DateFormat.yMMMd()
                        .format(end)}'),
                onTap: () {
                  Navigator.of(ctx).pop(); // Close dialog
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CreateMealPlanPage(
                            existingMealPlanDoc: doc,
                          ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.mealPlan),
        centerTitle: true,
        leading: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .collection('notifications')
              .where('read', isEqualTo: false)
              .snapshots(),
          builder: (context, snapshot) {
            final hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

            return Stack(
              children: [
                IconButton(
                  icon: const CircleAvatar(
                      backgroundImage: AssetImage('assets/images/icons/profile_chef_icon.png'),
                      backgroundColor: AppColors.profileIconBg,),
                  tooltip: AppLocalizations.of(context)!.profile,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileScreen()),
                    );
                  },
                ),
                if (hasUnread)
                  const Positioned(
                    right: 8,
                    top: 8,
                    child: CircleAvatar(
                      radius: 5,
                      backgroundColor: Colors.red,
                    ),
                  ),
              ],
            );
          },
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'select') {
                _selectMealPlan();
              } else if (value == 'edit') {
                _navigateToEditMealPlan();
              } else if (value == 'delete') {
                _confirmDeleteMealPlan();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'select',
                child: Text(localizations.selectMealPlan),
              ),
              PopupMenuItem(
                value: 'edit',
                child: Text(localizations.editMealPlan),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(localizations.deleteMealPlan),
              ),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 17),
                  child: TextButton.icon(
                    onPressed: () => _showCreateMealPlanDialog(context),
                    icon: Icon(
                      Icons.add,
                      size: 16,
                    ),
                    label: Text(
                      localizations.createMealPlan,
                      style: TextStyle(fontSize: 14),
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.only(top: 17),
                child: Align(
                  alignment: Alignment.centerRight,
                  child:ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        if (_calendarFormat == CalendarFormat.week) {
                          _calendarFormat = CalendarFormat.twoWeeks;
                        } else if (_calendarFormat == CalendarFormat.twoWeeks) {
                          _calendarFormat = CalendarFormat.month;
                        } else {
                          _calendarFormat = CalendarFormat.week;
                        }
                      });
                    },
                    label: Text(
                      _calendarFormat == CalendarFormat.week
                          ? localizations.oneWeek
                          : _calendarFormat == CalendarFormat.twoWeeks
                          ? localizations.twoWeeks
                          : localizations.month,
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  // ToggleButtons(
                  //   isSelected: [
                  //     _calendarFormat == CalendarFormat.week,
                  //     _calendarFormat == CalendarFormat.twoWeeks,
                  //     _calendarFormat == CalendarFormat.month,
                  //   ],
                  //   onPressed: (index) {
                  //     setState(() {
                  //       _calendarFormat = [
                  //         CalendarFormat.week,
                  //         CalendarFormat.twoWeeks,
                  //         CalendarFormat.month,
                  //       ][index];
                  //     });
                  //   },
                  //   constraints: BoxConstraints(minWidth: 36),
                  //   borderRadius: BorderRadius.circular(6),
                  //   children: [
                  //     Padding(
                  //       padding: EdgeInsets.symmetric(horizontal: 12),
                  //       child: Text(localizations.oneWeek),
                  //     ),
                  //     Padding(
                  //       padding: EdgeInsets.symmetric(horizontal: 12),
                  //       child: Text(localizations.twoWeeks),
                  //     ),
                  //     Padding(
                  //       padding: EdgeInsets.symmetric(horizontal: 12),
                  //       child: Text(localizations.month),
                  //     ),
                  //   ],
                  // ),
                ),
              ),
              ],
            ),
          ),



          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            rangeStartDay: _mealPlanRanges.isNotEmpty
                ? _mealPlanRanges.reduce((a, b) => a.isBefore(b) ? a : b)
                : null,
            rangeEndDay: _mealPlanRanges.isNotEmpty
                ? _mealPlanRanges.reduce((a, b) => a.isAfter(b) ? a : b)
                : null,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            onPageChanged: (focusedDay) => _focusedDay = focusedDay,
            eventLoader: (day) => _getEventsForDay(day),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(fontSize: 15),
              weekendStyle: TextStyle(fontSize: 15),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
            ),
            calendarBuilders: CalendarBuilders(
              rangeStartBuilder: (context, day, isSelected) {
                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.01),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(color: AppColors.calendarText),
                  ),
                );
              },
              rangeEndBuilder: (context, day, isSelected) {
                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.01),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(color: AppColors.calendarText),
                  ),
                );
              },
              rangeHighlightBuilder: (context, day, isWithinRange) {
                final date = DateTime(day.year, day.month, day.day);
                if (_mealPlanRanges.contains(date)) {
                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.03),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${day.day}',
                      style: TextStyle(color: AppColors.calendarText),
                    ),
                  );
                }
                return null;
              },
            ),
            calendarStyle: CalendarStyle(
              rangeHighlightColor: AppColors.transparent,
              rangeStartDecoration: BoxDecoration(
                color:  AppColors.transparent,
                shape: BoxShape.circle,
              ),
              rangeEndDecoration: BoxDecoration(
                color:  AppColors.transparent,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: AppColors.focusedDayBg,
                shape: BoxShape.circle,
              ),

              withinRangeTextStyle: TextStyle(),
              selectedDecoration: BoxDecoration(
                color: AppColors.focusedDayBg,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: TextStyle(
                color: AppColors.focusedDayText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Expanded(
            child: _buildMealsForSelectedDay(),
          ),
        ],
      ),
    );

  }


  Widget _buildMealsForSelectedDay() {
    if (_selectedMealPlanId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_restaurant_rounded,
              size: 80,
              color: AppColors.iconColor,
            ),
            SizedBox(height: 16), // Space between icon and text
            Text(
              AppLocalizations.of(context)!.noRecipesSelected,
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

    final selectedKey = DateTime(
        _selectedDay!.year, _selectedDay!.month, _selectedDay!.day);

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('mealPlans')
          .doc(_selectedMealPlanId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return Center(child: CircularProgressIndicator());
        if (!snapshot.data!.exists)
          return Center(child: Text(AppLocalizations.of(context)!.noMealPlans));

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final recipeDates = data['recipeDates'] as Map<String, dynamic>;

        // Filter recipe IDs scheduled for this selected day
        List<String> recipeIdsForDay = [];

        recipeDates.forEach((recipeId, ts) {
          final date = (ts as Timestamp).toDate();
          final key = DateTime(date.year, date.month, date.day);
          if (key == selectedKey) {
            recipeIdsForDay.add(recipeId);
          }
        });

        if (recipeIdsForDay.isEmpty) {
          return Center(
              child: Text(AppLocalizations.of(context)!.noRecipesSelected));
        }

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user!.uid)
              .collection('recipes')
              .where(FieldPath.documentId, whereIn: recipeIdsForDay)
              .get(),
          builder: (context, recipeSnapshot) {
            if (!recipeSnapshot.hasData)
              return Center(child: CircularProgressIndicator());

            final recipes = recipeSnapshot.data!.docs;

            return ListView.builder(
              itemCount: recipes.length,
              itemBuilder: (context, index) {
                final recipe = recipes[index].data() as Map<String, dynamic>;

                return Card(
                  margin: EdgeInsets.all(8),
                  child: ListTile(
                    leading: recipe['imageBase64'] != null &&
                        recipe['imageBase64']
                            .toString()
                            .isNotEmpty
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(recipe['imageBase64']
                            .toString()
                            .split(',')
                            .last),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    )
                        : Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.fastfood, color: Colors.grey[600]),
                    ),
                    title: Text(recipe['name'] ?? 'Unknown Recipe'),
                    subtitle: Text(recipe['category'] ?? ''),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }


  void _deleteMealPlanItem(String mealId) async {
    final localizations = AppLocalizations.of(context)!;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('mealPlans')
        .doc(mealId)
        .delete();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.mealPlanCreated)),
    );
  }

  void _showCreateMealPlanDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateMealPlanPage(),
        fullscreenDialog: true,
      ),
    );
  }
}

class CreateMealPlanPage extends StatefulWidget {
  final DocumentSnapshot? existingMealPlanDoc;

  const CreateMealPlanPage({Key? key, this.existingMealPlanDoc})
      : super(key: key);

  @override
  _CreateMealPlanPageState createState() => _CreateMealPlanPageState();
}

class _CreateMealPlanPageState extends State<CreateMealPlanPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  DateTime? _startDate;
  DateTime? _endDate;
  int _numberOfRecipes = 1;
  final List<String> _selectedRecipeIds = [];
  final Map<String, DocumentSnapshot> _selectedRecipes = {};
  final Map<String, DateTime> _recipeDates = {};
  final List<Map<String, dynamic>> _shoppingListItems = [];
  String? _userLanguage;
  int _currentStep = 0;
  bool _isGeneratingShoppingList = false;

  @override
  void initState() {
    super.initState();
    _fetchUserLanguage();

    if (widget.existingMealPlanDoc != null) {
      final data = widget.existingMealPlanDoc!.data() as Map<String, dynamic>;
      _startDate = (data['startDate'] as Timestamp).toDate();
      _endDate = (data['endDate'] as Timestamp).toDate();
      _numberOfRecipes = data['numberOfRecipes'];
      _selectedRecipeIds.addAll(List<String>.from(data['recipeIds']));
      _recipeDates.addAll(
        (data['recipeDates'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(key, (value as Timestamp).toDate()),
        ),
      );
    }
  }


  Future<_RecipeCardData> _getRecipeCardData(DocumentSnapshot recipe) async {
    final ingredientsSnapshot = await recipe.reference.collection('ingredients')
        .get();
    final total = ingredientsSnapshot.docs.length;

    final inventorySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('inventory.dart')
        .get();

    final inventory = inventorySnapshot.docs.map((e) => e.data()).toList();

    int available = 0;
    for (final doc in ingredientsSnapshot.docs) {
      final data = doc.data();
      final match = inventory.firstWhere(
            (item) =>
        item['name'] == data['name'] && item['unit'] == data['unit'],
        orElse: () => {},
      );
      if (match.isNotEmpty &&
          (match['quantity'] ?? 0) >= (data['quantity'] ?? 0)) {
        available++;
      }
    }

    final ratio = total > 0 ? available / total : 0;
    final color = ratio == 1 ? Colors.green : ratio >= 0.5
        ? Colors.orange
        : Colors.red;

    return _RecipeCardData(available, total, color);
  }

  Future<void> _fetchUserLanguage() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    if (userDoc.exists) {
      setState(() {
        _userLanguage = userDoc['language'] ?? 'en';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = _userLanguage != null
        ? lookupAppLocalizations(Locale(_userLanguage!))
        : AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.createMealPlan),
      ),
      body: Stepper(
        controlsBuilder: (context, details) {
          return Column(
            // children: [
            //   if (details.currentStep > 0)
            //     // ElevatedButton(
            //     //   onPressed: details.onStepCancel,
            //     //   child: Text(AppLocalizations.of(context)!.back),
            //     // ),
            //   // ElevatedButton(
            //   //   onPressed: details.onStepContinue,
            //   //   child: Text(AppLocalizations.of(context)!.continueText),
            //   // ),
            // ],
          );
        },
        currentStep: _currentStep,
        onStepContinue: _continue,
        onStepCancel: _cancel,
        onStepTapped: (step) => setState(() => _currentStep = step),
        steps: [
          Step(
            title: Text(localizations.selectPeriod),
            content: _buildDateSelectionStep(localizations),
            isActive: _currentStep >= 0,
          ),
          Step(
            title: Text(localizations.selectRecipes),
            content: _buildRecipeSelectionStep(),
            isActive: _currentStep >= 1,
          ),
          Step(
            title: Text(localizations.assignDates),
            content: _buildDateAssignmentStep(localizations),
            isActive: _currentStep >= 2,
          ),
          Step(
            title: Text(localizations.generateShoppingList),
            content: _buildShoppingListStep(localizations),
            isActive: _currentStep >= 3,
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelectionStep(AppLocalizations localizations) {
    return Column(
      children: [
        ListTile(
          title: Text(localizations.startDate),
          subtitle: Text(_startDate != null
              ? DateFormat.yMd().format(_startDate!)
              : localizations.selectDate),
          trailing: Icon(Icons.calendar_today),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(Duration(days: 365)),
            );
            if (date != null) {
              setState(() => _startDate = date);
            }
          },
        ),
        ListTile(
          title: Text(localizations.endDate),
          subtitle: Text(_endDate != null
              ? DateFormat.yMd().format(_endDate!)
              : localizations.selectDate),
          trailing: Icon(Icons.calendar_today),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _startDate ?? DateTime.now(),
              firstDate: _startDate ?? DateTime.now(),
              lastDate: DateTime.now().add(Duration(days: 365)),
            );
            if (date != null) {
              setState(() => _endDate = date);
            }
          },
        ),
        SizedBox(height: 16),
        Text(localizations.numberOfRecipes),
        Slider(
          value: _numberOfRecipes.toDouble(),
          min: 1,
          max: 20,
          divisions: 19,
          label: _numberOfRecipes.toString(),
          onChanged: (value) =>
              setState(() => _numberOfRecipes = value.toInt()),
        ),
      ],
    );
  }

  Widget _buildRecipeSelectionStep() {
    if (_startDate == null || _endDate == null) {
      return Center(
          child: Text(AppLocalizations.of(context)!.selectPeriodFirst));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('recipes')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return Center(child: CircularProgressIndicator());

        final recipes = snapshot.data!.docs;
        if (recipes.isEmpty) {
          return Center(
              child: Text(AppLocalizations.of(context)!.noRecipesFound));
        }

        return ListView.builder(
          shrinkWrap: true,
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            final recipe = recipes[index];
            final data = recipe.data() as Map<String, dynamic>;
            final isSelected = _selectedRecipeIds.contains(recipe.id);

            return FutureBuilder<_RecipeCardData>(
              future: _getRecipeCardData(recipe),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return SizedBox.shrink();

                final cardData = snapshot.data!;
                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true &&
                          !_selectedRecipeIds.contains(recipe.id)) {
                        if (_selectedRecipeIds.length < _numberOfRecipes) {
                          _selectedRecipeIds.add(recipe.id);
                          _selectedRecipes[recipe.id] = recipe;
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppLocalizations.of(context)!
                                .maxRecipesSelected)),
                          );
                        }
                      } else {
                        _selectedRecipeIds.remove(recipe.id);
                        _selectedRecipes.remove(recipe.id);
                        _recipeDates.remove(recipe.id);
                      }
                    });
                  },
                  title: Text(data['name'] ?? 'Unknown Recipe'),
                  subtitle: Text(
                    '${cardData.availableIngredients}/${cardData
                        .totalIngredients} ${AppLocalizations.of(context)!
                        .ingredients}',
                    style: TextStyle(color: cardData.availabilityColor),
                  ),
                  secondary: data['imageBase64'] != null && data['imageBase64']
                      .toString()
                      .isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8), // Rounded corners
                    child: Image.memory(
                      base64Decode(data['imageBase64']
                          .toString()
                          .split(',')
                          .last),
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  )
                      : Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.fastfood, color: Colors.grey[600]),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }


  Widget _buildDateAssignmentStep(AppLocalizations localizations) {
    if (_selectedRecipes.isEmpty) {
      return Center(child: Text(localizations.selectAtLeastOneRecipe));
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _selectedRecipes.length,
      itemBuilder: (context, index) {
        final recipe = _selectedRecipes.values.elementAt(index);
        final data = recipe.data() as Map<String, dynamic>;
        final assignedDate = _recipeDates[recipe.id];


        return ListTile(
          leading: data['imageBase64'] != null && data['imageBase64']
              .toString()
              .isNotEmpty
              ? ClipRRect(
            borderRadius: BorderRadius.circular(8), // Rounded corners
            child: Image.memory(
              base64Decode(data['imageBase64']
                  .toString()
                  .split(',')
                  .last),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          )
              : Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.fastfood, color: AppColors.iconColor),
          ),

          title: Text(data['name'] ?? 'Unknown Recipe'),
          subtitle: Text(assignedDate != null
              ? DateFormat.yMd().format(assignedDate)
              : localizations.notAssigned),
          trailing: IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: assignedDate ?? _startDate!,
                firstDate: _startDate!,
                lastDate: _endDate!,
              );
              if (date != null) {
                setState(() => _recipeDates[recipe.id] = date);
              }
            },
          ),
        );
      },
    );
  }

  void _continue() {
    final localizations = AppLocalizations.of(context)!;

    switch (_currentStep) {
      case 0:
        if (_startDate == null || _endDate == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.selectPeriod)),
          );
          return;
        }
        if (_endDate!.isBefore(_startDate!)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.invalidDateRange)),
          );
          return;
        }
        break;
      case 1:
        if (_selectedRecipes.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.selectAtLeastOneRecipe)),
          );
          return;
        }
        break;
      case 2:
        if (_recipeDates.length != _selectedRecipes.length) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.datesAssigned)),
          );
          return;
        }
        break;
      case 3:
        _saveMealPlan();
        return;
    }

    setState(() => _currentStep += 1);
  }

  void _cancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
    } else {
      Navigator.pop(context);
    }
  }

  Widget _buildShoppingListStep(AppLocalizations localizations) {
    if (_shoppingListItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Text(localizations.generateShoppingList),
            // const SizedBox(height: 20),
            // ElevatedButton(
            //   onPressed: _isGeneratingShoppingList ? null : _generateShoppingList,
            //   child: _isGeneratingShoppingList
            //       ? const CircularProgressIndicator()
            //       : Text(localizations.generateShoppingList),
            // ),
            ElevatedButton(
              onPressed: _isGeneratingShoppingList ? null : _generateShoppingList,
              child: _isGeneratingShoppingList
                  ? const CircularProgressIndicator()
                  : Text(localizations.generateShoppingList),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localizations.ingredientsToBuy),
        const SizedBox(height: 16),
        SizedBox(
          height: 300, // ✅ Fix here: add a bounded height
          child: ListView.builder(
            itemCount: _shoppingListItems.length,
            itemBuilder: (context, index) {
              final item = _shoppingListItems[index];
              return CheckboxListTile(
                value: item['selected'] ?? false,
                onChanged: (value) {
                  setState(() {
                    _shoppingListItems[index]['selected'] = value;
                  });
                },
                title: Text('${item['quantity']} ${item['unit']} ${item['name']}'),
                subtitle: Text('Needed for: ${item['recipes'].join(', ')}'),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _generateShoppingList() async {
    final localizations = AppLocalizations.of(context)!;
    setState(() {
      _isGeneratingShoppingList = true;
      _shoppingListItems.clear();
    });

    // 1. Get all ingredients from all selected recipes
    Map<String, Map<String, dynamic>> mergedIngredients = {};
    Map<String, List<String>> ingredientRecipes = {};

    for (final recipeDoc in _selectedRecipes.values) {
      final recipe = recipeDoc.data() as Map<String, dynamic>;
      final ingredientsSnapshot = await recipeDoc.reference.collection(
          'ingredients').get();

      for (final ingredientDoc in ingredientsSnapshot.docs) {
        final ingredient = ingredientDoc.data();
        final key = '${ingredient['name']}_${ingredient['unit']}';

        if (mergedIngredients.containsKey(key)) {
          mergedIngredients[key]!['quantity'] += ingredient['quantity'];
          ingredientRecipes[key]!.add(recipe['name'] ?? 'Unknown Recipe');
        } else {
          mergedIngredients[key] = {
            'name': ingredient['name'],
            'quantity': ingredient['quantity'],
            'unit': ingredient['unit'],
          };
          ingredientRecipes[key] = [recipe['name'] ?? 'Unknown Recipe'];
        }
      }
    }

    // 2. Check inventory.dart for available quantities
    final inventorySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('inventory.dart')
        .get();

    for (final inventoryItem in inventorySnapshot.docs) {
      final inventoryData = inventoryItem.data();
      final key = '${inventoryData['name']}_${inventoryData['unit']}';

      if (mergedIngredients.containsKey(key)) {
        final needed = mergedIngredients[key]!['quantity'];
        final available = inventoryData['quantity'];

        if (available >= needed) {
          mergedIngredients.remove(key);
        } else {
          mergedIngredients[key]!['quantity'] = needed - available;
        }
      }
    }

    // 3. Prepare shopping list items
    setState(() {
      _isGeneratingShoppingList = false;
      if (mergedIngredients.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.allIngredientsAvailable)),
        );
      } else {
        mergedIngredients.forEach((key, ingredient) {
          final name = ingredient['name'] ?? '';
          final category = CategoryHelper.categorizeItem(name);
          _shoppingListItems.add({
            ...ingredient,
            'selected': true,
            'category': category,
            'recipes': ingredientRecipes[key] ?? [],
          });
        });
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 8),
            Text(localizations.shoppingListGenerated),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMealPlan() async {
    final localizations = AppLocalizations.of(context)!;

    try {
      final mealPlansRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('mealPlans');

      final newMealPlanDoc = await mealPlansRef.add({
        'startDate': _startDate,
        'endDate': _endDate,
        'numberOfRecipes': _numberOfRecipes,
        'createdAt': FieldValue.serverTimestamp(),
        'recipeIds': _selectedRecipeIds,
        'recipeDates': _recipeDates.map((key, value) => MapEntry(key, Timestamp.fromDate(value))),
      });

      // 🔥 ADD SHOPPING LIST ITEMS TO MAIN SHOPPING LIST
      final shoppingListRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('shoppingList');

      final batch = FirebaseFirestore.instance.batch();

      for (final item in _shoppingListItems) {
        if (item['selected'] == true) {
          final docRef = shoppingListRef.doc();
          batch.set(docRef, {
            'name': item['name'],
            'quantity': item['quantity'],
            'unit': item['unit'],
            'category': item['category'],
            'checked': false,
            'addedFromMealPlanId': newMealPlanDoc.id, // optional: to track where it came from
          });
        }
      }

      await batch.commit(); // ✅ Upload all at once

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.shoppingListGenerated)),
      );

      Navigator.of(context).popUntil((route) => route.isFirst);

    } catch (e) {
      setState(() => _isGeneratingShoppingList = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.errorSavingMealPlan(e.toString()))),
      );
    }
  }


}

class _RecipeCardData {
  final int availableIngredients;
  final int totalIngredients;
  final Color availabilityColor;

  _RecipeCardData(this.availableIngredients, this.totalIngredients,
      this.availabilityColor);
}
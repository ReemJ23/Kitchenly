import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../utils/colors.dart';

class ViewOnlyMealPlanScreen extends StatefulWidget {
  final String familyOwnerId;
  final String language;

  const ViewOnlyMealPlanScreen({
    required this.familyOwnerId,
    required this.language,
    Key? key,
  }) : super(key: key);

  @override
  _ViewOnlyMealPlanScreenState createState() => _ViewOnlyMealPlanScreenState();
}

class _ViewOnlyMealPlanScreenState extends State<ViewOnlyMealPlanScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<String>> _mealsByDay = {};
  List<DateTime> _mealPlanRanges = [];
  String? _selectedMealPlanId;
  late AppLocalizations localizations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    localizations = AppLocalizations.of(context)!;
    _selectedDay = _focusedDay;
    _loadMealPlans();
  }

  Future<void> _loadMealPlans() async {
    final mealPlans = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.familyOwnerId)
        .collection('mealPlans')
        .orderBy('startDate', descending: true)
        .limit(1)
        .get();

    if (mealPlans.docs.isEmpty) return;

    final mealPlanDoc = mealPlans.docs.first;
    final data = mealPlanDoc.data();
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
      meals[key] = (meals[key] ?? [])..add(id);
    });

    setState(() {
      _mealPlanRanges = ranges.toList();
      _mealsByDay = meals;
    });
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _mealsByDay[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.mealPlan+" - "+localizations.readOnlyMode),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
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
                color: AppColors.transparent,
                shape: BoxShape.circle,
              ),
              rangeEndDecoration: BoxDecoration(
                color: AppColors.transparent,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: AppColors.focusedDayBg,
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: AppColors.focusedDayText,
                fontWeight: FontWeight.bold,
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
            SizedBox(height: 16),
            Text(
              localizations.noMealPlans,
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
          .doc(widget.familyOwnerId)
          .collection('mealPlans')
          .doc(_selectedMealPlanId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.data!.exists) {
          return Center(child: Text(localizations.noMealPlans));
        }

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
          return Center(child: Text(localizations.noRecipesSelected));
        }

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.familyOwnerId)
              .collection('recipes')
              .where(FieldPath.documentId, whereIn: recipeIdsForDay)
              .get(),
          builder: (context, recipeSnapshot) {
            if (!recipeSnapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            final recipes = recipeSnapshot.data!.docs;

            return ListView.builder(
              itemCount: recipes.length,
              itemBuilder: (context, index) {
                final recipe = recipes[index].data() as Map<String, dynamic>;

                return Card(
                  margin: EdgeInsets.all(8),
                  child: ListTile(
                    leading: recipe['imageBase64'] != null &&
                        recipe['imageBase64'].toString().isNotEmpty
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
}
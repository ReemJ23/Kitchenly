import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../utils/colors.dart';
import '../utils/localization_helper.dart';

class OnboardingAllergiesScreen extends StatefulWidget {
  final String language;

  const OnboardingAllergiesScreen({Key? key, required this.language}) : super(key: key);

  @override
  _OnboardingAllergiesScreenState createState() => _OnboardingAllergiesScreenState();
}

class _OnboardingAllergiesScreenState extends State<OnboardingAllergiesScreen> {
  List<String> selectedAllergies = [];
  final List<String> allAllergies = ["Peanuts", "Dairy", "Gluten", "Soy", "Shellfish", "Eggs", "Tree Nuts", "Sesame"];

  final Map<String, String> allergyImages = {
    "Peanuts": "assets/images/peanuts.png",
    "Dairy": "assets/images/dairy.png",
    "Gluten": "assets/images/gluten.png",
    "Soy": "assets/images/soy.png",
    "Shellfish": "assets/images/shellfish.png",
    "Eggs": "assets/images/eggs.png",
    "Tree Nuts": "assets/images/treenuts.png",
    "Sesame": "assets/images/sesame.png",
  };

  void _submitAllergies() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'allergies': selectedAllergies,
      });


      Navigator.pushNamed(context, '/onboarding_inventory', arguments: widget.language);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
        appBar: AppBar(title: Text(" ")
        ),
      body: Padding(
        padding: EdgeInsets.all(16),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
    children: [
    Text(
    localizations.onboardingAllergiesMessage,

    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
    color: AppColors.heading1,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    ),
    ),
    const SizedBox(height: 5),
    Text(
    localizations.onboardingAllergiesSubMessage,

    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
    color: AppColors.heading2,
    fontSize: 16,
    ),
    ),
    const SizedBox(height: 10),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: EdgeInsets.all(16),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: allAllergies.map((allergy) {
                final isSelected = selectedAllergies.contains(allergy);
                final imagePath = allergyImages[allergy];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      isSelected
                          ? selectedAllergies.remove(allergy)
                          : selectedAllergies.add(allergy);
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                       color: isSelected ? AppColors.toggleActive : AppColors.toggleInactive,
                        width: 2,
                      ),
                      color: isSelected ? AppColors.toggleActive.withOpacity(0.1) : AppColors.toggleInactive,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (imagePath != null)
                          Image.asset(imagePath, width: 90, height: 90),
                        SizedBox(height: 24),
                        Text(
                          LocalizationHelper.getLocalizedString(localizations, allergy),
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _submitAllergies,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 55),
              ),
              child: Text(localizations.next),
            ),
          ),
        ],
      ),

          ),
    );
  }
}
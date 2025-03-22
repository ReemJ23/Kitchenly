import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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

  void _submitAllergies() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'allergies': selectedAllergies,
      });


      Navigator.pushReplacementNamed(context, '/onboarding_inventory', arguments: widget.language);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.selectAllergies)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: allAllergies.length,
              itemBuilder: (context, index) {
                return CheckboxListTile(
                  title: Text(LocalizationHelper.getLocalizedString(localizations, allAllergies[index])),
                  value: selectedAllergies.contains(allAllergies[index]),
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        selectedAllergies.add(allAllergies[index]);
                      } else {
                        selectedAllergies.remove(allAllergies[index]);
                      }
                    });
                  },
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: _submitAllergies,
            child: Text(localizations.next),
          ),
        ],
      ),
    );
  }
}

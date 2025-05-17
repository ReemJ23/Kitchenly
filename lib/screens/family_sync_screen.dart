import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import '../utils/colors.dart';

class SyncCodePage extends StatefulWidget {
  @override
  _SyncCodePageState createState() => _SyncCodePageState();
}

class _SyncCodePageState extends State<SyncCodePage> {
  String syncCode = '';
  final _nameController = TextEditingController();
  String selectedPermission = 'view';
  final currentUser = FirebaseAuth.instance.currentUser;
  final Map<String, TextEditingController> _editNameControllers = {};
  final Map<String, String> _editPermissions = {};

  @override
  void dispose() {
    _nameController.dispose();
    _editNameControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSyncCode();
  }

  String capitalizeFirst(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }

  Future<void> _loadSyncCode() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();
    setState(() {
      syncCode = userDoc.data()?['syncCode'] ?? '';
    });
  }

  String _generateSyncCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890';
    final rnd = Random();
    return String.fromCharCodes(
        Iterable.generate(8, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
    }

  Future<void> _regenerateCode() async {
    final newCode = _generateSyncCode();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .update({
      'syncCode': newCode,
    });
    setState(() {
      syncCode = newCode;
    });
  }

  Future<void> _addFamilyMember() async {
    final name = _nameController.text.trim().toLowerCase();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.enterFamilyMemberName),
        ),
      );
      return;
    }


    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('familyMembers')
        .doc(name.toLowerCase())
        .set({
      'name': name,
      'permission': selectedPermission,
    });

    _nameController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.memberAdded)),
    );
  }

  Future<void> _updateFamilyMember(String docId, String currentName) async {
    final newName = _editNameControllers[docId]!.text.trim().toLowerCase();
    final newPermission = _editPermissions[docId]!;

    if (newName.isEmpty) return;

    // If name changed, we need to delete old doc and create new one
    if (newName != currentName.toLowerCase()) {
      final batch = FirebaseFirestore.instance.batch();

      // Delete old document
      batch.delete(FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('familyMembers')
          .doc(currentName.toLowerCase()));

      // Create new document
      batch.set(
          FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser!.uid)
              .collection('familyMembers')
              .doc(newName.toLowerCase()),
          {
            'name': newName,
            'permission': newPermission,
          });

      await batch.commit();
    } else {
      // Just update permission if name didn't change
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('familyMembers')
          .doc(currentName.toLowerCase())
          .update({
        'permission': newPermission,
      });
    }

    // Clear edit state
    setState(() {
      _editNameControllers.remove(docId);
      _editPermissions.remove(docId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.memberUpdated)),
    );
  }

  Future<void> _deleteFamilyMember(String name) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('familyMembers')
        .doc(name.toLowerCase())
        .delete();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.memberDeleted)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(localization.syncSettings),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
           /* Text('${localization.currentSyncCode}: $syncCode'),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _regenerateCode,
              child: Text(localization.regenerateCode),
            ),*/
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localization.codeGeneration,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          syncCode,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: syncCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(localization.copiedToClipboard)),
                            );
                          },
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: _regenerateCode,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        minimumSize: const Size(0, 40),
                      ),
                      child: Text(localization.regenerateCode),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(thickness: 1.2),

            const SizedBox(height: 20),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(
                  localization.addFamilyMembers,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: localization.familyMemberName,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: selectedPermission,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(value: 'view', child: Text(localization.viewPermission)),
                          DropdownMenuItem(value: 'edit', child: Text(localization.editPermission)),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedPermission = value;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _addFamilyMember,
                      child: Text(localization.addMember),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(thickness: 1.2),

            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: Directionality.of(context) == TextDirection.ltr
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                Text(
                  localization.addedFamilyMembers,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser!.uid)
                    .collection('familyMembers')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final members = snapshot.data!.docs;
                  if (members.isEmpty) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_outlined, size: 95, color: AppColors.iconColor),
                        const SizedBox(height: 12),
                        Text(
                          localization.noFamilyMembers,
                          style: const TextStyle(color: AppColors.heading2, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final doc = members[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final docId = doc.id;
                      final name = data['name'];
                      final permission = data['permission'];

                      final isEditing = _editNameControllers.containsKey(docId);

                      if (isEditing && !_editPermissions.containsKey(docId)) {
                        _editPermissions[docId] = permission;
                      }

                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: isEditing
                              ? TextField(
                            controller: _editNameControllers[docId]!,
                            decoration: InputDecoration(
                              hintText: localization.familyMemberName,
                            ),
                          )
                              : Text(capitalizeFirst(name)),
                          subtitle: isEditing
                              ? DropdownButton<String>(
                            value: _editPermissions[docId],
                            items: [
                              DropdownMenuItem(
                                value: 'view',
                                child: Text(localization.viewPermission),
                              ),
                              DropdownMenuItem(
                                value: 'edit',
                                child: Text(localization.editPermission),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _editPermissions[docId] = value;
                                });
                              }
                            },
                          )
                              : Text(permission == 'edit'
                              ? localization.editPermission
                              : localization.viewPermission),
                          trailing: isEditing
                              ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.check),
                                onPressed: () =>
                                    _updateFamilyMember(docId, name),
                              ),
                              IconButton(
                                icon: Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _editNameControllers.remove(docId);
                                    _editPermissions.remove(docId);
                                  });
                                },
                              ),
                            ],
                          )
                              : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit),
                                onPressed: () {
                                  setState(() {
                                    _editNameControllers[docId] =
                                        TextEditingController(text: name);
                                    _editPermissions[docId] = permission;
                                  });
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete),
                                onPressed: () => _deleteFamilyMember(name),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
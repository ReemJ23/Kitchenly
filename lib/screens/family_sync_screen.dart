import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
    if (name.isEmpty) return;

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
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.syncSettings)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('${loc.currentSyncCode}: $syncCode'),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _regenerateCode,
              child: Text(loc.regenerateCode),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: loc.familyMemberName,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButton<String>(
              value: selectedPermission,
              items: [
                DropdownMenuItem(value: 'view', child: Text(loc.viewPermission)),
                DropdownMenuItem(value: 'edit', child: Text(loc.editPermission)),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedPermission = value;
                  });
                }
              },
            ),
            ElevatedButton(
              onPressed: _addFamilyMember,
              child: Text(loc.addMember),
            ),
            const SizedBox(height: 20),
            Text(loc.addedFamilyMembers,
                style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    return Text(loc.noFamilyMembers);
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
                              hintText: loc.familyMemberName,
                            ),
                          )
                              : Text(capitalizeFirst(name)),
                          subtitle: isEditing
                              ? DropdownButton<String>(
                            value: _editPermissions[docId],
                            items: [
                              DropdownMenuItem(
                                value: 'view',
                                child: Text(loc.viewPermission),
                              ),
                              DropdownMenuItem(
                                value: 'edit',
                                child: Text(loc.editPermission),
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
                              ? loc.editPermission
                              : loc.viewPermission),
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
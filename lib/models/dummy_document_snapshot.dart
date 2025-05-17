import 'package:cloud_firestore/cloud_firestore.dart';

class DummyDocumentSnapshot extends DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic> _data;

  DummyDocumentSnapshot(this._data);

  @override
  Map<String, dynamic>? data([GetOptions? options]) => _data;

  @override
  dynamic operator [](Object field) => _data[field.toString()];

  @override
  dynamic get(Object field) => _data[field.toString()];

  @override
  String get id => 'dummy_id';

  @override
  DocumentReference<Map<String, dynamic>> get reference => _dummyReference;

  static final _dummyReference = FirebaseFirestore.instance
      .collection('recipes')
      .doc('dummy_doc_id');

  @override
  SnapshotMetadata get metadata =>
      throw UnimplementedError('Dummy snapshot has no metadata.');

  @override
  bool get exists => true;
}

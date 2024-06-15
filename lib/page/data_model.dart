import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DataModel with ChangeNotifier {
  List<CODataPoint> _dataPoints = [];

  List<CODataPoint> get dataPoints => _dataPoints;

  void fetchData() async {
    // Fetch data from Firestore
    final snapshot = await FirebaseFirestore.instance.collection('data').get();
    _dataPoints = snapshot.docs.map((doc) => CODataPoint.fromFirestore(doc)).toList();
    notifyListeners();
  }

  void addDataPoint(CODataPoint dataPoint) {
    _dataPoints.add(dataPoint);
    // Save to Firestore
    FirebaseFirestore.instance.collection('data').add(dataPoint.toFirestore());
    notifyListeners();
  }
}

class CODataPoint {
  final DateTime timestamp;
  final double value;

  CODataPoint({required this.timestamp, required this.value});

  factory CODataPoint.fromFirestore(DocumentSnapshot doc) {
    return CODataPoint(
      timestamp: (doc['timestamp'] as Timestamp).toDate(),
      value: doc['value'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'timestamp': timestamp,
      'value': value,
    };
  }
}

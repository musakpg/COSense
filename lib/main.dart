import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fypcosense/page/welcome_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure that Flutter bindings are initialized
  await Firebase.initializeApp(); // Initialize Firebase
  Workmanager().initialize(callbackDispatcher, isInDebugMode: true); // Initialize WorkManager
  runApp(const MyApp());
}

// This is the function that WorkManager will call periodically to fetch CO data
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await Firebase.initializeApp();
    final database = FirebaseDatabase.instance.reference().child('rate/coRate');
    database.once().then((DatabaseEvent event) async {
      if (event.snapshot.exists) {
        final newCoRate = double.tryParse(event.snapshot.value.toString()) ?? 0;
        final prefs = await SharedPreferences.getInstance();
        List<String>? dataPoints = prefs.getStringList('coDataPoints');
        if (dataPoints == null) {
          dataPoints = [];
        }
        dataPoints.add('${DateTime.now().toIso8601String()}:$newCoRate');
        prefs.setStringList('coDataPoints', dataPoints);
      }
    });
    return Future.value(true);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fypcosense/page/signInPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fypcosense/page/homePage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  Workmanager().registerPeriodicTask(
    "1",
    "fetchData",
    frequency: const Duration(minutes: 15),
  );
  runApp(const MyApp());
}

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
        await prefs.setStringList('coDataPoints', dataPoints);

        print("Fetched new CO data point: $newCoRate");
        print("Current saved data points: $dataPoints");
      }
    });
    return Future.value(true);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  Future<bool> isUserLoggedIn() async {
    final FirebaseAuth auth = FirebaseAuth.instance;
    User? user = auth.currentUser;
    return user != null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      home: FutureBuilder(
        future: isUserLoggedIn(),
        builder: (context, AsyncSnapshot<bool> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else {
            if (snapshot.data == true) {
              return const HomePage(); // Navigate to HomePage if the user is logged in
            } else {
              return const SignInScreen(); // Navigate to SignInScreen if the user is not logged in
            }
          }
        },
      ),
    );
  }
}

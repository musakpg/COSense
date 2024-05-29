import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sendgrid_mailer/sendgrid_mailer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fypcosense/page/signInPage.dart';
import 'package:fypcosense/page/settingProfile.dart';
import 'package:fypcosense/page/settingEmergency.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:io' show Platform;
import 'dart:math';

const initializationSettingsAndroid = AndroidInitializationSettings('icon');

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double coRate = 0; // Initial value
  double previousCoRate = 0; // Previous CO rate to calculate the change percentage
  String carState = ''; // Variable to hold car state
  List<CODataPoint> coDataPoints = []; // List to hold CO data points
  double latitude = 0; // Initial value for latitude
  double longitude = 0; // Initial value for longitude

  late FirebaseDatabase database;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    initFirebase();
    _loadDataPoints();
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true,
    );
    Workmanager().registerPeriodicTask(
      "1",
      "fetchCOData",
      frequency: Duration(minutes: 15),
    );
  }

  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      // Task code here
      return Future.value(true);
    });
  }

  Future<void> _loadDataPoints() async {
    final prefs = await SharedPreferences.getInstance();
    final dataPoints = prefs.getStringList('coDataPoints') ?? [];
    setState(() {
      coDataPoints = dataPoints.map((e) {
        final parts = e.split(':');
        return CODataPoint(DateTime.parse(parts[0]), double.parse(parts[1]));
      }).toList();
      if (coDataPoints.isNotEmpty) {
        coRate = coDataPoints.last.coRate;
        previousCoRate = coDataPoints.length > 1 ? coDataPoints[coDataPoints.length - 2].coRate : 0;
      }
    });
  }

  double _calculateChangePercentage(double newRate, double oldRate) {
    if (oldRate == 0) return 0;
    return ((newRate - oldRate) / oldRate) * 100;
  }

  List<charts.Series<CODataPoint, DateTime>> _createLineData(List<CODataPoint> dataPoints) {
    return [
      charts.Series<CODataPoint, DateTime>(
        id: 'CO Data',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (CODataPoint point, _) => point.time,
        measureFn: (CODataPoint point, _) => point.coRate,
        data: dataPoints,
      )
    ];
  }

  double _calculateMaxY(double maxRate) {
    return (maxRate ~/ 10 + 1) * 10.0;
  }

  @override
  Widget build(BuildContext context) {
    double maxRate = coDataPoints.isNotEmpty
        ? coDataPoints.map((point) => point.coRate).reduce(max)
        : 10;
    double maxY = _calculateMaxY(maxRate);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Text(
                'Carbon Monoxide',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.settings),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (BuildContext context) {
                      return Container(
                        height: MediaQuery.of(context).size.height * 0.3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              leading: Icon(Icons.person),
                              title: Text('Profile Settings'),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => SettingProfile()),
                                );
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.contact_phone),
                              title: Text('Emergency Contact Settings'),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => EmergencySetupScreen()),
                                );
                              },
                            ),
                            ListTile(
                              leading: Icon(Icons.logout),
                              title: Text('Logout'),
                              onTap: () {
                                _signOut();
                                Navigator.pop(context);
                              },
                            ),
                          ],
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current level',
              style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CO',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 5),
                Text(
                  '${coRate.toStringAsFixed(2)} PPM',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      'Now',
                      style: TextStyle(fontSize: 18, color: Colors.black),
                    ),
                    SizedBox(width: 5), // Adjust the spacing between the text widgets
                    Text(
                      '${_calculateChangePercentage(coRate, previousCoRate).toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 18,
                        color: _calculateChangePercentage(coRate, previousCoRate) < 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 10),
            Container(
              height: 200,
              child: coDataPoints.isNotEmpty
                  ? charts.TimeSeriesChart(
                _createLineData(coDataPoints),
                animate: true,
                dateTimeFactory: const charts.LocalDateTimeFactory(),
                behaviors: [
                  charts.PanAndZoomBehavior(),
                  charts.SeriesLegend(),
                ],
                primaryMeasureAxis: charts.NumericAxisSpec(
                  tickProviderSpec: charts.BasicNumericTickProviderSpec(desiredTickCount: 5),
                  viewport: charts.NumericExtents(0, maxY),
                ),
                domainAxis: charts.DateTimeAxisSpec(
                  tickFormatterSpec: charts.AutoDateTimeTickFormatterSpec(
                    hour: charts.TimeFormatterSpec(
                      format: 'HH:mm',
                      transitionFormat: 'HH:mm',
                    ),
                  ),
                ),
              )
                  : Center(child: Text('Loading CO Data...')),
            ),
            SizedBox(height: 10),
            Center(
              child: Text(
                carState == 'danger' ? 'Danger' : 'Safe',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: carState == 'danger' ? Colors.red : Colors.green),
              ),
            ),
            if (carState == 'danger') ...[
              SizedBox(height: 20),
              Text(
                'Actions',
                style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                '   Reduce your exposure to CO',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 10),
              Text(
                '   Turn off the car and get out',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 10),
              Text(
                '   Call emergency services immediately',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 10),
              Text(
                '   If feeling unwell, seek medical attention',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> sendEmail(
      _HomePageState state, String userEmail, String emergencyEmail, String userName) async {
    final mailer = Mailer('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');
    final toAddress = Address(emergencyEmail); // Use emergency email fetched from Firestore
    final fromAddress = Address(userEmail); // Use user email fetched from FirebaseAuth
    final latitude = state.latitude; // Access latitude from state parameter
    final longitude = state.longitude; // Access longitude from state parameter

    final subject = 'COSense Alert';
    final userNameFormatted = Uri.encodeComponent(userName); // Encode user name for URL
    final locationLink = Platform.isAndroid
        ? 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'
        : 'https://maps.apple.com/?q=$latitude,$longitude'; // URL to open in Google Maps or Apple Maps

    final content = Content('text/html',
        'Alert!!! $userName\'s vehicle is in danger. Location: <a href="$locationLink">Open in Maps</a>'); // Include a link to open in Maps

    final personalization = Personalization([toAddress]);
    final email = Email([personalization], fromAddress, subject, content: [content]);

    mailer.send(email).then((result) {
      print('Email sent successfully!');
    }).catchError((error) {
      print('Error sending email: $error');
    });

    print('Emergency contact is: $emergencyEmail');
    print('User contact is: $userEmail');
    print('User name is: $userName');
    print('Latitude: $latitude, Longitude: $longitude');
  }

  Future<void> initFirebase() async {
    await Firebase.initializeApp();
    database = FirebaseDatabase.instance;
    // Listen to changes in Firebase database
    database.reference().child('rate/coRate').onValue.listen((event) {
      final newCoRate = double.tryParse(event.snapshot.value.toString()) ?? 0;
      setState(() {
        previousCoRate = coRate;
        coRate = newCoRate;
        // Update CO data points
        coDataPoints.add(CODataPoint(DateTime.now(), coRate));
        // Keep only the last 100 data points for display
        if (coDataPoints.length > 100) {
          coDataPoints.removeAt(0);
        }
        // Set car state based on coRate
        if (coRate >= 0.05) { // Change to 0.05 ppm
          carState = 'danger';
          _notifyEmergencyContact(); // Notify if in danger state
        } else {
          carState = 'normal';
        }
      });
    });

    // Listen to changes in GPS location
    database.reference().child('gps/latitude').onValue.listen((event) {
      final newLatitude = double.tryParse(event.snapshot.value.toString()) ?? 0;
      setState(() {
        latitude = newLatitude;
      });
    });

    database.reference().child('gps/longitude').onValue.listen((event) {
      final newLongitude = double.tryParse(event.snapshot.value.toString()) ?? 0;
      setState(() {
        longitude = newLongitude;
      });
    });

    _saveDataPoints();
  }

  Future<void> _saveDataPoints() async {
    final prefs = await SharedPreferences.getInstance();
    final dataPoints = coDataPoints.map((e) => '${e.time.toIso8601String()}:${e.coRate}').toList();
    prefs.setStringList('coDataPoints', dataPoints);
  }

  void _showInAppNotification() async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'high_co_channel',
        'CO Level Alert',
        channelDescription: 'High CO level detected in your car.',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'CO Alert',
      ),
    );

    await flutterLocalNotificationsPlugin.show(
        0, 'High CO Level Detected', 'Please take necessary action.', notificationDetails);
  }

  void _showLocalAlert() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Emergency Alert'),
          content: Text('High CO levels detected. Please take necessary action.'),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _notifyEmergencyContact() {
    print('CO rate exceeded 0.20 ppm. Notifying emergency contact...'); // Change to 0.05 ppm
    _showInAppNotification(); // Alternative 6: Display in-app notification
    _showLocalAlert(); // Alternative 7: Display local alert

    // Fetch user's data from FirebaseAuth
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final userId = user.uid; // Get the user ID
      final userDocRef = _firestore.collection('users').doc(userId);

      userDocRef.get().then((userSnapshot) {
        if (userSnapshot.exists) {
          final userName = userSnapshot.data()?['profile']['name'] ?? ''; // User's name (ensure existence)
          final userEmail = user.email ?? ''; // Null-safe assignment
          final emergencyContacts = userSnapshot.data()?['emergencyContacts'] ?? []; // User's emergency contacts (ensure existence)

          // Loop through all emergency contacts
          for (var contact in emergencyContacts) {
            final contactEmail = contact['email'] ?? '';
            sendEmail(this, userEmail, contactEmail, userName); // Pass this as the first argument
          }

          if (emergencyContacts.isEmpty) {
            print('No emergency contacts found for user.');
          }
        } else {
          print('Error: User document not found.');
        }
      }).catchError((error) {
        print('Error fetching user data: $error');
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SignInScreen()),
      );
    } catch (e) {
      print('Error signing out: $e');
    }
  }
}

class CODataPoint {
  final DateTime time;
  final double coRate;

  CODataPoint(this.time, this.coRate);
}

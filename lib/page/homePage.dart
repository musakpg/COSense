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

const initializationSettingsAndroid = AndroidInitializationSettings('icon');

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double coRate = 0;
  double previousCoRate = 0;
  String carState = '';
  List<CODataPoint> coDataPoints = [];

  late FirebaseDatabase database;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    initFirebase();
    _loadDataPoints();
    Workmanager().registerPeriodicTask(
      "1",
      "fetchCOData",
      frequency: Duration(minutes: 15),
    );
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

  @override
  Widget build(BuildContext context) {
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
                  tickProviderSpec:
                  charts.BasicNumericTickProviderSpec(desiredTickCount: 5),
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

  Future<void> sendEmail(String userEmail, String emergencyEmail, String userName) async {
    final mailer =
    Mailer('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');
    final toAddress = Address(emergencyEmail);
    final fromAddress = Address(userEmail);
    final content = Content('text/plain', 'Alert!!! $userName\'s vehicle is in danger');
    final subject = 'COSense Alert';
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
  }

  Future<void> initFirebase() async {
    await Firebase.initializeApp();
    database = FirebaseDatabase.instance;
    database.reference().child('rate/coRate').onValue.listen((event) {
      final newCoRate = double.tryParse(event.snapshot.value.toString()) ?? 0;
      setState(() {
        previousCoRate = coRate;
        coRate = newCoRate;
        coDataPoints.add(CODataPoint(DateTime.now(), coRate));
        if (coDataPoints.length > 100) {
          coDataPoints.removeAt(0);
        }
        if (coRate >= 0.20) {
          carState = 'danger';
          _notifyEmergencyContact();
        } else {
          carState = 'normal';
        }
      });
      _saveDataPoints();
    });
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
    print('CO rate exceeded 0.20 ppm. Notifying emergency contact...');
    _showInAppNotification();
    _showLocalAlert();

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final userId = user.uid;
      final userDocRef = _firestore.collection('users').doc(userId);

      userDocRef.get().then((userSnapshot) {
        if (userSnapshot.exists) {
          final userName = userSnapshot.data()?['profile']['name'] ?? '';
          final userEmail = user.email ?? '';
          final emergencyContacts = userSnapshot.data()?['emergencyContacts'] ?? [];

          for (var contact in emergencyContacts) {
            final contactEmail = contact['email'] ?? '';
            sendEmail(userEmail, contactEmail, userName);
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
}

class CODataPoint {
  final DateTime time;
  final double coRate;

  CODataPoint(this.time, this.coRate);
}
import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sendgrid_mailer/sendgrid_mailer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' show Platform;
import 'signInPage.dart';
import 'settingProfile.dart';
import 'settingEmergency.dart';
import 'adminPage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final appDocumentDir = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDir.path);
  Hive.registerAdapter(CODataPointAdapter());
  await Hive.openBox<CODataPoint>('coDataPoints');

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carbon Monoxide Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SignInScreen(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double coRate = 0;
  double previousCoRate = 0;
  String carState = '';
  List<CODataPoint> coDataPoints = [];
  double latitude = 0;
  double longitude = 0;

  late FirebaseDatabase database;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Box<CODataPoint> coDataBox;

  @override
  void initState() {
    super.initState();
    initFirebase();
    loadLocalData();
  }

  Future<void> loadLocalData() async {
    coDataBox = Hive.box<CODataPoint>('coDataPoints');
    setState(() {
      coDataPoints = coDataBox.values.toList();
      if (coDataPoints.isNotEmpty) {
        coRate = coDataPoints.last.coRate;
        carState = coRate > 9 ? 'danger' : 'safe';
      }
    });
  }

  void updateDataPoints(List<CODataPoint> newPoints) {
    setState(() {
      coDataPoints = newPoints;
      if (newPoints.isNotEmpty) {
        coRate = newPoints.last.coRate;
        carState = coRate > 9 ? 'danger' : 'safe';
      }
      for (var point in newPoints) {
        coDataBox.add(point);
      }
    });
    if (carState == 'danger') {
      _notifyEmergencyContact();
    }
  }

  double _calculateChangePercentage(double newRate, double oldRate) {
    if (oldRate == 0) return 0;
    return ((newRate - oldRate) / oldRate) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Carbon Monoxide'),
        actions: [
          IconButton(
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
                          leading: Icon(Icons.admin_panel_settings),
                          title: Text('Admin Page'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => AdminPage(onUpdateData: updateDataPoints, initialDataPoints: coDataPoints)),
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
        ],
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
                Text(
                  'Now ${_calculateChangePercentage(coRate, previousCoRate).toStringAsFixed(2)}%',
                  style: TextStyle(fontSize: 18, color: Colors.green),
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
                primaryMeasureAxis: charts.NumericAxisSpec(
                  renderSpec: charts.GridlineRendererSpec(
                    labelStyle: charts.TextStyleSpec(
                      fontSize: 10,
                      color: charts.MaterialPalette.black,
                    ),
                    lineStyle: charts.LineStyleSpec(
                      thickness: 0,
                      color: charts.MaterialPalette.transparent,
                    ),
                  ),
                ),
                domainAxis: charts.DateTimeAxisSpec(
                  renderSpec: charts.SmallTickRendererSpec(
                    labelStyle: charts.TextStyleSpec(
                      fontSize: 10,
                      color: charts.MaterialPalette.black,
                    ),
                    lineStyle: charts.LineStyleSpec(
                      thickness: 0,
                      color: charts.MaterialPalette.transparent,
                    ),
                  ),
                ),
                defaultRenderer: charts.LineRendererConfig(
                  includeArea: true,
                  stacked: false,
                  areaOpacity: 0.2,
                  strokeWidthPx: 2.0,
                ),
              )
                  : Center(child: Text('Loading CO Data...')),
            ),
            SizedBox(height: 10),
            Center(
              child: Text(
                carState == 'danger' ? 'Danger' : 'Safe',
                style: TextStyle(
                  fontSize: 18,
                  color: carState == 'danger' ? Colors.red : Colors.green,
                ),
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
                '• Reduce your exposure to CO',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 5),
              Text(
                '• Turn off the car and get out',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> sendEmail(_HomePageState state, String userEmail, String emergencyEmail, String emergencyName, String userName) async {
    final mailer = Mailer('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');
    final toAddress = Address(emergencyEmail);
    final fromAddress = Address(userEmail);
    final latitude = state.latitude;
    final longitude = state.longitude;
    final coRateValue = state.coRate.toStringAsFixed(2);

    final subject = 'URGENT: COSense Alert';
    final locationLink = Platform.isAndroid
        ? 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'
        : 'https://maps.apple.com/?q=$latitude,$longitude';

    final content = Content('text/html',
        '''
        <html>
        <body>
            <h2 style="color: red;">URGENT: COSense Alert</h2>
            <p>Attention to <b>$emergencyName</b>,</p>
            <p><b style="color: red;">$userName's vehicle is in danger.</b></p>
            <p><b>Vehicle CO Rate:</b> <span style="color: red;">$coRateValue PPM (danger level)</span></p>
            <p><b>Current Location of the Car:</b> <a href="$locationLink">Open in Maps</a></p>
            <p>Latitude: $latitude</p>
            <p>Longitude: $longitude</p>
            <br>
            <p style="color: red;"><b>Please take necessary action immediately to ensure the safety of the vehicle's occupants.</b></p>
            <br>
            <p>Thank you,</p>
            <p><b>COSense Team</b></p>
        </body>
        </html>
        ''');

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
    print('CO Rate: $coRateValue PPM');
    print('Latitude: $latitude, Longitude: $longitude');
  }

  Future<void> initFirebase() async {
    await Firebase.initializeApp();
    database = FirebaseDatabase.instance;
    database.reference().child('rate/coRate').onValue.listen((event) {
      final newCoRate = double.tryParse(event.snapshot.value.toString()) ?? 0;
      setState(() {
        previousCoRate = coRate;
        coRate = newCoRate;
        final newPoint = CODataPoint(DateTime.now(), coRate);
        coDataPoints.add(newPoint);
        coDataBox.add(newPoint);
        if (coDataPoints.length > 100) {
          coDataPoints.removeAt(0);
        }
        carState = coRate > 9 ? 'danger' : 'safe';
      });
      if (carState == 'danger') {
        _notifyEmergencyContact();
      }
    });

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
  }

  void _showInAppNotification() async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const initializationSettingsAndroid = AndroidInitializationSettings('icon');
    final initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
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

    await flutterLocalNotificationsPlugin.show(0, 'High CO Level Detected', 'Please take necessary action.', notificationDetails);
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

  Future<void> _notifyEmergencyContact() async {
    print('CO rate exceeded 9 ppm. Notifying emergency contact...');
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
            final contactName = contact['name'] ?? ''; // Extract the emergency contact's name
            sendEmail(this, userEmail, contactEmail, contactName, userName); // Pass the emergency contact's name
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
        domainFn: (CODataPoint point, _) => point.time,
        measureFn: (CODataPoint point, _) => point.coRate,
        data: dataPoints,
        colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
      )
    ];
  }
}

class CODataPoint {
  final DateTime time;
  final double coRate;

  CODataPoint(this.time, this.coRate);
}

class CODataPointAdapter extends TypeAdapter<CODataPoint> {
  @override
  final int typeId = 0;

  @override
  CODataPoint read(BinaryReader reader) {
    final time = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final coRate = reader.readDouble();
    return CODataPoint(time, coRate);
  }

  @override
  void write(BinaryWriter writer, CODataPoint obj) {
    writer.writeInt(obj.time.millisecondsSinceEpoch);
    writer.writeDouble(obj.coRate);
  }
}

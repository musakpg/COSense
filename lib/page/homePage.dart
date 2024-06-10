import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sendgrid_mailer/sendgrid_mailer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signInPage.dart';
import 'settingProfile.dart';
import 'settingEmergency.dart';
import 'adminPage.dart';
import 'dart:io' show Platform;

const initializationSettingsAndroid = AndroidInitializationSettings('icon');

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double coRate = 0;
  double previousCoRate = 0;
  String carState = 'safe';
  List<CODataPoint> coDataPoints = [];
  double latitude = 0;
  double longitude = 0;

  late FirebaseDatabase database;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    coRate = 0; // Initialize CO rate to 0 PPM
    initFirebase();
    _initializeNotifications();
  }

  void updateDataPoints(List<CODataPoint> newPoints) {
    setState(() {
      if (newPoints.isNotEmpty) {
        previousCoRate = coRate;
        coRate = newPoints.last.coRate;
        carState = _determineCarState(coRate);
        coDataPoints = newPoints;
      }
    });
    if (carState == 'danger') {
      _notifyEmergencyContact();
    } else if (carState == 'warning') {
      _showWarningAlert();
    } else if (carState == 'caution') {
      _showCautionNotification();
    }
  }

  String _determineCarState(double coRate) {
    if (coRate < 0.3) {
      return 'safe';
    } else if (coRate < 1.2) {
      return 'caution';
    } else if (coRate < 1.7) {
      return 'warning';
    } else {
      return 'danger';
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
        automaticallyImplyLeading: false,
        title: Align(
          alignment: Alignment.center,
          child: Text(
            'Carbon Monoxide',
            textAlign: TextAlign.center,
          ),
        ),
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
            GestureDetector(
              onLongPressStart: (_) => _showThresholdsDialog(context),
              onLongPressEnd: (_) => _hideThresholdsDialog(),
              child: Center(
                child: Text(
                  carState == 'danger' ? 'Danger' : carState == 'warning' ? 'Warning' : carState == 'caution' ? 'Caution' : 'Safe',
                  style: TextStyle(
                    fontSize: 18,
                    color: carState == 'danger' ? Colors.red : carState == 'warning' ? Colors.orange : carState == 'caution' ? Colors.yellow : Colors.green,
                  ),
                ),
              ),
            ),
            if (carState == 'danger' || carState == 'warning') ...[
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
    final String apiKey = dotenv.env['SENDGRID_API_KEY']!;
    final mailer = Mailer(apiKey);
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
            <p><b>Latitude:</b> $latitude</p>
            <p><b>Longitude:</b> $longitude</p>
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

  List<charts.Series<CODataPoint, DateTime>> _createLineData(List<CODataPoint> dataPoints) {
    return [
      charts.Series<CODataPoint, DateTime>(
        id: 'COData',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (CODataPoint point, _) => point.time,
        measureFn: (CODataPoint point, _) => point.coRate,
        data: dataPoints,
      ),
    ];
  }

  Future<void> initFirebase() async {
    await Firebase.initializeApp();
    final database = FirebaseDatabase.instance;
    final coDataRef = database.reference().child('coData');
    coDataRef.onValue.listen((event) {
      final dataSnapshot = event.snapshot.value as Map<dynamic, dynamic>;
      final newPoints = <CODataPoint>[];
      dataSnapshot.forEach((key, value) {
        final time = DateTime.parse(key);
        final coRate = double.parse(value['coRate'].toString());
        newPoints.add(CODataPoint(time: time, coRate: coRate));
      });
      updateDataPoints(newPoints);
    });
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('icon');
    final initSettings = InitializationSettings(android: androidSettings);

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tapped logic here
      },
    );
  }


  Future<void> _showWarningAlert() async {
    const androidDetails = AndroidNotificationDetails(
      'channel_id',
      'CO Warning',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'icon',
      styleInformation: BigTextStyleInformation('Dangerous level of CO detected. Please ventilate your car immediately!'),
    );
    const platformDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Warning',
      'CO levels are at a warning threshold!',
      platformDetails,
      payload: 'CO warning notification',
    );
  }

  Future<void> _showCautionNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'channel_id',
      'CO Caution',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: 'icon',
      styleInformation: BigTextStyleInformation('CO levels are rising. Monitor your environment closely.'),
    );
    const platformDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Caution',
      'CO levels are rising, please take note.',
      platformDetails,
      payload: 'CO caution notification',
    );
  }

  void _showThresholdsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Thresholds'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Safe'),
                trailing: Text('0 - 0.29 PPM'),
              ),
              ListTile(
                title: Text('Caution'),
                trailing: Text('0.30 - 1.19 PPM'),
              ),
              ListTile(
                title: Text('Warning'),
                trailing: Text('1.20 - 1.69 PPM'),
              ),
              ListTile(
                title: Text('Danger'),
                trailing: Text('1.70+ PPM'),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _hideThresholdsDialog() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _notifyEmergencyContact() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userData = await _firestore.collection('users').doc(user.uid).get();
      final emergencyEmail = userData.get('emergencyEmail') as String;
      final emergencyName = userData.get('emergencyName') as String;
      final userName = userData.get('name') as String;
      await sendEmail(this, user.email!, emergencyEmail, emergencyName, userName);
    }
  }

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => SignInScreen()),
          (Route<dynamic> route) => false,
    );
  }
}

class CODataPoint {
  final DateTime time;
  final double coRate;

  CODataPoint({required this.time, required this.coRate});
}

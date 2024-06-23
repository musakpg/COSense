import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sendgrid_mailer/sendgrid_mailer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'signInPage.dart';
import 'settingProfile.dart';
import 'settingEmergency.dart';
import 'adminPage.dart';
import 'dart:io' show Platform;
import 'Noti.dart';

const initializationSettingsAndroid = AndroidInitializationSettings('icon');
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// Define custom colors for car states
const Color safeColor = Color(0xFF4CAF50); // Green
const Color warningColor = Color(0xFFFFC107); // Amber
const Color dangerColor = Color(0xFFF44336); // Red

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

  CODataPoint? selectedDataPoint;
  DateTime? selectedDate;
  bool showAllData = false;

  late FirebaseDatabase database;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  late List<CODataPoint> _chartData;
  late TooltipBehavior _tooltipBehavior;
  late ZoomPanBehavior _zoomPanBehavior;
  final GlobalKey<SfCartesianChartState> _chartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    Noti.initialize(flutterLocalNotificationsPlugin);
    coRate = 0; // Initialize CO rate to 0 PPM
    initFirebase();
    _setupFirebaseMessaging();
    _loadDataFromFirestore(); // Load data from Firestore when the app starts
    Workmanager().registerPeriodicTask(
      'fetchCoData',
      'fetchCoDataTask',
      frequency: Duration(minutes: 15),
    );

    _chartData = getChartData();
    _tooltipBehavior = TooltipBehavior(enable: true);
    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enableDoubleTapZooming: true,
      enableSelectionZooming: true,
      selectionRectBorderColor: Colors.red,
      selectionRectBorderWidth: 2,
      selectionRectColor: Colors.grey,
      enablePanning: true,
      zoomMode: ZoomMode.x,
      enableMouseWheelZooming: true,
    );
  }

  void _setupFirebaseMessaging() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        _showNotification(message.notification!);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message clicked!');
    });

    String? token = await _firebaseMessaging.getToken();
    print("FirebaseMessaging token: $token");
    // Save the token to your backend or Firestore if needed
  }

  void _showNotification(RemoteNotification notification) async {
    const androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'high_importance_channel', // id
      'COSense Alert!', // title
      importance: Importance.max,
      priority: Priority.high,
    );
    const platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      platformChannelSpecifics,
    );
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
    _saveDataToFirestore();
    if (carState == 'danger') {
      _notifyEmergencyContact();
    } else if (carState == 'warning') {
      _showWarningAlert();
    }
  }

  String _determineCarState(double coRate) {
    if (coRate < 0.3) {
      return 'safe';
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

  double _getPeakLevel() {
    if (coDataPoints.isEmpty) return 0;
    return coDataPoints.map((point) => point.coRate).reduce((a, b) => a > b ? a : b);
  }

  void _loadDataFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userId = user.uid;
        final coDataPointsRef = _firestore.collection('users').doc(userId).collection('coDataPoints');
        final snapshot = await coDataPointsRef.orderBy('time', descending: false).get();

        final newPoints = snapshot.docs.map((doc) {
          final data = doc.data();
          final timestamp = (data['time'] as Timestamp).toDate(); // Convert Firestore Timestamp to DateTime
          final coRate = (data['coRate'] as num).toDouble(); // Retrieve the value and cast to double
          return CODataPoint(timestamp, coRate);
        }).toList();

        print("Fetched data points: $newPoints");

        setState(() {
          coDataPoints = newPoints;
          if (newPoints.isNotEmpty) {
            previousCoRate = coRate;
            coRate = newPoints.last.coRate;
            carState = _determineCarState(coRate);
          }
        });

        print("Updated state with data points: $coDataPoints");
      }
    } catch (e) {
      print('Error loading data from Firestore: $e');
    }
  }

  void _saveDataToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userId = user.uid;
        final batch = _firestore.batch();
        final collectionRef = _firestore.collection('users').doc(userId).collection('coDataPoints');

        for (var point in coDataPoints) {
          final docRef = collectionRef.doc(point.time.toIso8601String());
          batch.set(docRef, {
            'time': Timestamp.fromDate(point.time), // Convert DateTime to Firestore Timestamp
            'coRate': point.coRate, // Store as double
          });
        }

        await batch.commit();
        print("Saved data points to Firestore: $coDataPoints");
      }
    } catch (e) {
      print('Error saving data to Firestore: $e');
    }
  }

  DateTime _getVisibleMinimum() {
    if (showAllData || selectedDate == null || coDataPoints.isEmpty) {
      return coDataPoints.isNotEmpty ? coDataPoints.first.time : DateTime.now();
    }
    final startOfDay = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day);
    return startOfDay;
  }

  DateTime _getVisibleMaximum() {
    if (showAllData || selectedDate == null || coDataPoints.isEmpty) {
      return coDataPoints.isNotEmpty ? coDataPoints.last.time : DateTime.now();
    }
    final startOfNextDay = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day + 1);
    return startOfNextDay;
  }

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2021),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        showAllData = false;
        _zoomPanBehavior.reset(); // Reset zoom and pan state before setting new visible range
      });
    }
  }

  void _showAllData() {
    setState(() {
      showAllData = true;
      selectedDate = null;
      _zoomPanBehavior.reset(); // Reset zoom and pan state to show all data
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdminPage(
                  onUpdateData: updateDataPoints,
                  initialDataPoints: coDataPoints,
                ),
              ),
            );
          },
          child: Text(
            'COSense',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white),
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
                          leading: Icon(Icons.person, color: Colors.blue),
                          title: Text('Profile Settings', style: TextStyle(color: Colors.blue)),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => SettingProfile()),
                            );
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.contact_phone, color: Colors.blue),
                          title: Text('Emergency Contact Settings', style: TextStyle(color: Colors.blue)),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => EmergencySetupScreen()),
                            );
                          },
                        ),
                        ListTile(
                          leading: Icon(Icons.logout, color: Colors.blue),
                          title: Text('Logout', style: TextStyle(color: Colors.blue)),
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Material(
                        elevation: 5.0,  // Adjust the elevation value as needed
                        shadowColor: Colors.black,  // Black shadow color
                        borderRadius: BorderRadius.circular(15.0),
                        child: Container(
                          height: 100,
                          child: ListTile(
                            tileColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(15.0), bottom: Radius.circular(15.0)),
                            ),
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Level',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                                SizedBox(height: 5),
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${coRate.toStringAsFixed(2)}',
                                        style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.blue),
                                      ),
                                      TextSpan(
                                        text: ' ppm',
                                        style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Material(
                        elevation: 5.0,  // Adjust the elevation value as needed
                        shadowColor: Colors.black,  // Black shadow color
                        borderRadius: BorderRadius.circular(15.0),
                        child: Container(
                          height: 100,
                          child: ListTile(
                            tileColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(15.0), bottom: Radius.circular(15.0)),
                            ),
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Peak Level',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                                SizedBox(height: 5),
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${_getPeakLevel().toStringAsFixed(2)}',
                                        style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.blue),
                                      ),
                                      TextSpan(
                                        text: ' ppm',
                                        style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Material(
                      elevation: 5.0,  // Adjust the elevation value as needed
                      shadowColor: Colors.black,  // Black shadow color
                      borderRadius: BorderRadius.circular(15.0),
                      child: Container(
                        height: 100, // Set the height to be the same for both containers
                        child: ListTile(
                          tileColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(15.0), bottom: Radius.circular(15.0)),
                          ),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Percentage Change',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                              SizedBox(height: 5),
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${_calculateChangePercentage(coRate, previousCoRate).toStringAsFixed(2)}',
                                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.blue),
                                    ),
                                    TextSpan(
                                      text: ' %',
                                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Material(
                      elevation: 5.0,  // Adjust the elevation value as needed
                      shadowColor: Colors.black,  // Black shadow color
                      borderRadius: BorderRadius.circular(15.0),
                      child: Container(
                        height: 100, // Set the height to be the same for both containers
                        child: ListTile(
                          tileColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(15.0), bottom: Radius.circular(15.0)),
                          ),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Status',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                              SizedBox(height: 5),
                              Text(
                                carState == 'danger'
                                    ? 'Danger'
                                    : carState == 'warning'
                                    ? 'Warning'
                                    : 'Safe',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: carState == 'danger'
                                      ? dangerColor
                                      : carState == 'warning'
                                      ? warningColor
                                      : safeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Material(
                elevation: 5.0,
                shadowColor: Colors.black,
                borderRadius: BorderRadius.circular(15.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () => _selectDate(context),
                            icon: Icon(Icons.calendar_today, color: Colors.blue),
                          ),
                          TextButton(
                            onPressed: _showAllData,
                            child: Text(
                              'Overview',
                              style: TextStyle(color: Colors.blue, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 450,
                        child: coDataPoints.isNotEmpty
                            ? SfCartesianChart(
                          key: _chartKey,
                          title: ChartTitle(
                            text: 'CO Data Analysis',
                            textStyle: TextStyle(
                              fontSize: 18, // Adjust the font size as needed
                              fontWeight: FontWeight.bold, // Make the text bold
                              color: Colors.black, // Set the color to black or any other color you prefer
                            ),
                          ),
                          legend: Legend(isVisible: true),
                          tooltipBehavior: _tooltipBehavior,
                          zoomPanBehavior: _zoomPanBehavior,
                          primaryXAxis: DateTimeAxis(
                            edgeLabelPlacement: EdgeLabelPlacement.shift,
                            dateFormat: DateFormat('MMM d, H:mm'), // Date and hour to hour format
                            intervalType: DateTimeIntervalType.hours, // Set the interval type to hours
                            visibleMinimum: _getVisibleMinimum(),
                            visibleMaximum: _getVisibleMaximum(),
                            interactiveTooltip: InteractiveTooltip(enable: false),
                            majorGridLines: MajorGridLines(width: 0), // Remove X-axis grid lines
                          ),
                          primaryYAxis: NumericAxis(
                            labelFormat: '{value} PPM',
                            numberFormat: NumberFormat.compact(),
                            interactiveTooltip: InteractiveTooltip(enable: false),
                            majorGridLines: MajorGridLines(width: 0), // Remove Y-axis grid lines
                          ),
                          plotAreaBorderWidth: 0, // Remove the border around the chart
                          series: <ChartSeries>[
                            LineSeries<CODataPoint, DateTime>(
                              name: 'CO Data',
                              dataSource: coDataPoints,
                              xValueMapper: (CODataPoint point, _) => point.time,
                              yValueMapper: (CODataPoint point, _) => point.coRate,
                              dataLabelSettings: DataLabelSettings(isVisible: true),
                              enableTooltip: true,
                              onPointTap: (ChartPointDetails details) {
                                setState(() {
                                  selectedDataPoint = coDataPoints[details.pointIndex!];
                                });
                              },
                            ),
                          ],
                        )
                            : Center(child: Text('Loading CO Data...')),
                      ),
                      SizedBox(height: 10),
                      GestureDetector(
                        onLongPressStart: (_) => _showThresholdsDialog(context),
                        onLongPressEnd: (_) => _hideThresholdsDialog(),
                        child: Center(
                          child: Text(
                            carState == 'danger'
                                ? 'Danger'
                                : carState == 'warning'
                                ? 'Warning'
                                : 'Safe',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: carState == 'danger'
                                  ? dangerColor
                                  : carState == 'warning'
                                  ? warningColor
                                  : safeColor,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              if (selectedDataPoint != null)
                Material(
                  elevation: 5.0, // Adjust the elevation as needed
                  shadowColor: Colors.black,
                  borderRadius: BorderRadius.circular(15.0),
                  child: ListTile(
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    title: Text(
                      'Selected Data Point',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: TextStyle(color: Colors.black),
                            children: [
                              TextSpan(
                                text: 'Rate: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: '${selectedDataPoint!.coRate.toStringAsFixed(2)} PPM\n',
                              ),
                              TextSpan(
                                text: 'Time: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: '${DateFormat.yMMMd().add_Hms().format(selectedDataPoint!.time)}',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.clear, color: Colors.blue),
                      onPressed: () {
                        setState(() {
                          selectedDataPoint = null;
                        });
                      },
                    ),
                  ),
                ),
              SizedBox(height: 20.0),
              if (carState == 'danger' || carState == 'warning')
                Material(
                  elevation: 5.0, // Adjust the elevation value as needed
                  shadowColor: Colors.black, // Black shadow color
                  borderRadius: BorderRadius.circular(15.0),
                  child: Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: 20),
                        Text(
                          'Actions',
                          style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        SizedBox(height: 10),
                        ListTile(
                          tileColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(15.0), bottom: Radius.circular(15.0)),
                          ),
                          leading: Icon(Icons.medical_services, color: Colors.white),
                          title: Text(
                            'Reduce your exposure to CO',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                        Divider(height: 10, thickness: 1, color: Colors.white), // Add divider for separation
                        ListTile(
                          tileColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(15.0), bottom: Radius.circular(15.0)),
                          ),
                          leading: Icon(Icons.power_off, color: Colors.white),
                          title: Text(
                            'Turn off the car and get out',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                        Divider(height: 10, thickness: 1, color: Colors.white), // Add divider for separation
                        ListTile(
                          tileColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(15.0), bottom: Radius.circular(15.0)),
                          ),
                          leading: Icon(Icons.phone, color: Colors.white),
                          title: Text(
                            'Call 999',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                        Divider(height: 10, thickness: 1, color: Colors.white), // Add divider for separation
                        ListTile(
                          tileColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(15.0), bottom: Radius.circular(15.0)),
                          ),
                          leading: Icon(Icons.sentiment_satisfied_alt, color: Colors.white),
                          title: Text(
                            'Stay calm and don\'t panic',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> sendEmail(_HomePageState state, String userEmail, String emergencyEmail, String emergencyName, String userName, String userPhoneNumber) async {
    final mailer = Mailer('');
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
            <p><b>$userName Phone Number:</b> $userPhoneNumber</p>
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
    print('User phone number is: $userPhoneNumber');
    print('CO Rate: $coRateValue PPM');
    print('Latitude: $latitude, Longitude: $longitude');
  }

  Future<void> initFirebase() async {
    try {
      await Firebase.initializeApp();
      database = FirebaseDatabase.instance;
      database.reference().child('rate/coRate').onValue.listen((event) {
        final newCoRate = double.tryParse(event.snapshot.value.toString()) ?? 0;
        setState(() {
          previousCoRate = coRate;
          coRate = newCoRate;
          carState = _determineCarState(coRate);
          coDataPoints.add(CODataPoint(DateTime.now(), coRate));
          if (coDataPoints.length > 100) {
            coDataPoints.removeAt(0);
          }
          _saveDataToFirestore();
        });
        if (carState == 'danger') {
          _notifyEmergencyContact();
        } else if (carState == 'warning') {
          _showWarningAlert();
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
    } catch (e) {
      print('Error initializing Firebase: $e');
      // Optionally, show an error dialog or message to the user
    }
  }

  void _showInAppNotification() async {
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
          title: Text('Emergency Alert', style: TextStyle(color: Colors.blue)),
          content: Text('High CO levels detected. Please take necessary action.', style: TextStyle(color: Colors.black)),
          actions: [
            TextButton(
              child: Text('OK', style: TextStyle(color: Colors.blue)),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _showWarningAlert() {
    Noti.showBigTextNotification(title: "Attention: Carbon Monoxide Alert", body: "Your vehicle's CO levels are elevated. Inspect your car with mechanic if possible.", fln: flutterLocalNotificationsPlugin);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Warning', style: TextStyle(color: Colors.blue)),
          content: Text('Warning: Elevated CO levels detected. Please take caution.', style: TextStyle(color: Colors.black)),
          actions: [
            TextButton(
              child: Text('OK', style: TextStyle(color: Colors.blue)),
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
    print('CO rate exceeded 1.7 ppm. Notifying emergency contact...');
    _showInAppNotification();
    _showLocalAlert();
    Noti.showBigTextNotification(title: "DANGER: High CO Level in Vehicle", body: "Evacuate vehicle immediately! Open windows and seek fresh air.", fln: flutterLocalNotificationsPlugin);

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final userId = user.uid;
      final userDocRef = _firestore.collection('users').doc(userId);

      userDocRef.get().then((userSnapshot) {
        if (userSnapshot.exists) {
          final userName = userSnapshot.data()?['profile']['name'] ?? '';
          final userEmail = user.email ?? '';
          final userPhoneNumber = userSnapshot.data()?['profile']['phoneNumber'] ?? '';
          final emergencyContacts = userSnapshot.data()?['emergencyContacts'] ?? [];

          for (var contact in emergencyContacts) {
            final contactEmail = contact['email'] ?? '';
            final contactName = contact['name'] ?? ''; // Extract the emergency contact's name
            sendEmail(this, userEmail, contactEmail, contactName, userName, userPhoneNumber); // Pass the emergency contact's name and user phone number
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

  void _showThresholdsDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Barrier',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) {
        return WillPopScope(
          onWillPop: () async => false, // Disable back button
          child: Center(
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CO Level Thresholds',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.blue),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.0),
                        color: Colors.grey.shade200,
                        border: Border.all(
                          color: carState == 'danger'
                              ? dangerColor
                              : carState == 'warning'
                              ? warningColor
                              : safeColor,
                          width: 2.0,
                        ),
                      ),
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Text(
                            'Safe: CO rate < 0.3 PPM',
                            style: TextStyle(
                              fontSize: 18,
                              color: safeColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Warning: 0.3 <= CO rate < 1.7 PPM',
                            style: TextStyle(
                              fontSize: 18,
                              color: warningColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Danger: CO rate >= 1.7 PPM',
                            style: TextStyle(
                              fontSize: 18,
                              color: dangerColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _hideThresholdsDialog() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  List<CODataPoint> getChartData() {
    return coDataPoints;
  }
}

class CODataPoint {
  final DateTime time;
  final double coRate;

  CODataPoint(this.time, this.coRate);
}

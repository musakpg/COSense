import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'homePage.dart';  // Assuming CODataPoint is defined here

class AdminPage extends StatefulWidget {
  final Function(List<CODataPoint>) onUpdateData;
  final List<CODataPoint> initialDataPoints;

  AdminPage({required this.onUpdateData, required this.initialDataPoints});

  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final TextEditingController _ppmController = TextEditingController();
  List<CODataPoint> adminDataPoints = [];
  final _formKey = GlobalKey<FormState>();
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    adminDataPoints = widget.initialDataPoints;

    _ppmController.addListener(() {
      setState(() {}); // Update the UI based on the controller's text changes
    });
  }

  void addDataPoint() {
    if (_formKey.currentState!.validate()) {
      final ppm = double.tryParse(_ppmController.text) ?? 0;
      final newPoint = CODataPoint(DateTime.now(), ppm);

      setState(() {
        adminDataPoints.add(newPoint);
        if (adminDataPoints.length > 100) {
          adminDataPoints.removeAt(0);
        }
      });

      widget.onUpdateData(adminDataPoints);

      _ppmController.clear();
      setState(() {
        _errorMsg = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Page'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  'Add Custom Data Point',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _ppmController,
                decoration: InputDecoration(
                  labelText: 'CO PPM',
                  border: OutlineInputBorder(),
                  errorText: _errorMsg,
                  suffixIcon: _ppmController.text.isEmpty
                      ? null
                      : IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: () {
                      _ppmController.clear();
                    },
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a value';
                  }
                  final ppm = double.tryParse(value);
                  if (ppm == null || ppm <= 0) {
                    return 'Please enter a valid CO PPM value';
                  }
                  if (ppm > 1000) {
                    return 'This number seem unlogic';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: addDataPoint,
                child: Text('Add Data Point'),
              ),
              SizedBox(height: 20),
              Expanded(
                child: charts.TimeSeriesChart(
                  _createLineData(adminDataPoints),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<charts.Series<CODataPoint, DateTime>> _createLineData(List<CODataPoint> dataPoints) {
    return [
      charts.Series<CODataPoint, DateTime>(
        id: 'Admin CO Data',
        domainFn: (CODataPoint point, _) => point.time,
        measureFn: (CODataPoint point, _) => point.coRate,
        data: dataPoints,
        colorFn: (_, __) => charts.MaterialPalette.red.shadeDefault,
      ),
    ];
  }
}

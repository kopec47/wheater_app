import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';

void main() {
  runApp(const WeatherApp());
}

class WeatherMeasurement {
  final double temperature;
  final double humidity;
  final double pressure;
  final double windSpeed;
  final int batteryLevel;
  final DateTime timestamp;

  WeatherMeasurement({
    required this.temperature,
    required this.humidity,
    required this.pressure,
    required this.windSpeed,
    required this.batteryLevel,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'pressure': pressure,
      'windSpeed': windSpeed,
      'batteryLevel': batteryLevel,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class ChartPoint {
  final DateTime time;
  final double value;
  ChartPoint(this.time, this.value);
}

class DatabaseHelper {
  static Database? _database;
  
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await openDatabase(
      p.join(await getDatabasesPath(), 'weather_data.db'),
      onCreate: (db, version) => db.execute(
        'CREATE TABLE measurements(id INTEGER PRIMARY KEY AUTOINCREMENT, temperature REAL, humidity REAL, pressure REAL, windSpeed REAL, batteryLevel INTEGER, timestamp TEXT)',
      ),
      version: 1,
    );
    return _database!;
  }

  static Future<void> insert(WeatherMeasurement measurement) async {
    final db = await database;
    await db.insert(
      'measurements', measurement.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<WeatherMeasurement>> getHistory() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('measurements', orderBy: "timestamp DESC", limit: 100);
    return List.generate(maps.length, (i) => WeatherMeasurement(
      temperature: maps[i]['temperature'],
      humidity: maps[i]['humidity'],
      pressure: maps[i]['pressure'],
      windSpeed: maps[i]['windSpeed'],
      batteryLevel: maps[i]['batteryLevel'],
      timestamp: DateTime.parse(maps[i]['timestamp']),
    ));
  }

  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('measurements');
  }
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stacja Pogodowa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
        useMaterial3: true,
      ),
      home: const WeatherScreen(),
    );
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  double temperature = 0.0;
  double humidity = 0.0;
  double pressure = 0.0;
  double windSpeed = 0.0;
  int batteryLevel = 0;
  
  String connectionStatus = "Rozłączono";
  bool isConnecting = false;
  List<WeatherMeasurement> history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final data = await DatabaseHelper.getHistory();
    if (mounted) {
      setState(() {
        history = data;
      });
    }
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Resetuj pomiary?"),
        content: const Text("Wszystkie zapisane dane zostaną trwale usunięte."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Anuluj")),
          TextButton(
            onPressed: () async {
              await DatabaseHelper.clearAll();
              await _loadHistory();
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Resetuj", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> connectToEsp() async {
    setState(() {
      isConnecting = true;
      connectionStatus = "Szukanie stacji...";
    });

    try {
      await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
      FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          if (r.device.platformName.toLowerCase().contains("weather")) {
            await FlutterBluePlus.stopScan();
            await r.device.connect(autoConnect: false);
            _discoverServices(r.device);
          }
        }
      });
    } catch (e) {
      if (mounted) setState(() => isConnecting = false);
    }
  }

  void _discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.notify) {
          await characteristic.setNotifyValue(true);
          characteristic.lastValueStream.listen((value) => _processIncomingData(value));
        }
      }
    }
    if (mounted) {
      setState(() {
        connectionStatus = "Odbieranie danych";
        isConnecting = false; 
      });
    }
  }

  void _processIncomingData(List<int> value) {
    try {
      String decoded = utf8.decode(value);
      List<String> parts = decoded.split(',');
      if (parts.length >= 3) {
        double temp = double.tryParse(parts[0]) ?? temperature;
        double hum = double.tryParse(parts[1]) ?? humidity;
        double press = double.tryParse(parts[2]) ?? pressure;
        double wind = windSpeed;
        if (parts.length >= 4) wind = double.tryParse(parts[3]) ?? windSpeed;
        
        setState(() {
          temperature = temp;
          humidity = hum;
          pressure = press;
          windSpeed = wind;
        });

        if (temp != 0.0) {
          final measurement = WeatherMeasurement(
            temperature: temp,
            humidity: hum,
            pressure: press,
            windSpeed: wind,
            batteryLevel: 100,
            timestamp: DateTime.now(),
          );
          DatabaseHelper.insert(measurement).then((_) => _loadHistory());
        }
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    List<ChartPoint> tempChart = history.map((e) => ChartPoint(e.timestamp, e.temperature)).toList().reversed.toList();
    List<ChartPoint> humChart = history.map((e) => ChartPoint(e.timestamp, e.humidity)).toList().reversed.toList();
    List<ChartPoint> pressChart = history.map((e) => ChartPoint(e.timestamp, e.pressure)).toList().reversed.toList();
    List<ChartPoint> windChart = history.map((e) => ChartPoint(e.timestamp, e.windSpeed)).toList().reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Stacja Pogodowa", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 30),
            onPressed: _showResetDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(connectionStatus, style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: WeatherCard(title: "Temperatura", value: "${temperature.toStringAsFixed(1)}°C", icon: "🌡️", chartData: tempChart)),
                  const SizedBox(width: 16),
                  Expanded(child: WeatherCard(title: "Wilgotność", value: "${humidity.toStringAsFixed(1)}%", icon: "💧", chartData: humChart)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: WeatherCard(title: "Ciśnienie", value: "${pressure.toStringAsFixed(0)} hPa", icon: "⏱️", chartData: pressChart)),
                  const SizedBox(width: 16),
                  Expanded(child: WeatherCard(title: "Wiatr", value: "${windSpeed.toStringAsFixed(1)} km/h", icon: "💨", chartData: windChart)),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isConnecting ? null : connectToEsp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: isConnecting 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Połącz z ESP32", style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WeatherCard extends StatelessWidget {
  final String title, value, icon;
  final List<ChartPoint> chartData;

  const WeatherCard({super.key, required this.title, required this.value, required this.icon, required this.chartData});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Card(
        elevation: 6,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => WeatherDetailsScreen(title: title, currentValue: value, chartData: chartData))),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            ],
          ),
        ),
      ),
    );
  }
}

class WeatherDetailsScreen extends StatelessWidget {
  final String title, currentValue;
  final List<ChartPoint> chartData;

  const WeatherDetailsScreen({super.key, required this.title, required this.currentValue, required this.chartData});

  @override
  Widget build(BuildContext context) {
    double overallAvg = chartData.isEmpty ? 0 : chartData.map((e) => e.value).reduce((a, b) => a + b) / chartData.length;
    String unit = currentValue.replaceAll(RegExp(r'[0-9.,]'), '').trim();

    Map<String, List<double>> groupedByDay = {};
    for (var point in chartData) {
      String dayKey = DateFormat('yyyy-MM-dd').format(point.time);
      if (!groupedByDay.containsKey(dayKey)) {
        groupedByDay[dayKey] = [];
      }
      groupedByDay[dayKey]!.add(point.value);
    }

    List<ChartPoint> dailyAverages = [];
    groupedByDay.forEach((dayKey, values) {
      double sum = values.reduce((a, b) => a + b);
      double avg = sum / values.length;
      DateTime dayDate = DateTime.parse(dayKey).add(const Duration(hours: 12)); 
      dailyAverages.add(ChartPoint(dayDate, double.parse(avg.toStringAsFixed(1))));
    });

    dailyAverages.sort((a, b) => a.time.compareTo(b.time));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Obecnie", style: TextStyle(fontSize: 20)),
            Text(currentValue, style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 8),
            Text("Średnia z całej historii: ${overallAvg.toStringAsFixed(1)} $unit"),
            const SizedBox(height: 48),
            Expanded(
              child: dailyAverages.length < 2 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_graph, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text(
                        "Zbyt mało danych",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Wykres trendów pojawi się,\ngdy aplikacja zbierze dane z co najmniej 2 dni.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true, drawVerticalLine: true),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (spot) => Colors.blueGrey,
                        getTooltipItems: (spots) => spots.map((s) {
                          final date = DateTime.fromMillisecondsSinceEpoch(s.x.toInt());
                          return LineTooltipItem("${DateFormat('dd.MM').format(date)}\n${s.y} $unit", const TextStyle(color: Colors.white));
                        }).toList(),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 86400000, 
                          getTitlesWidget: (val, meta) {
                            final date = DateTime.fromMillisecondsSinceEpoch(val.toInt());
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(DateFormat('dd.MM').format(date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 45)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: dailyAverages.map((e) => FlSpot(e.time.millisecondsSinceEpoch.toDouble(), e.value)).toList(),
                        isCurved: true,
                        barWidth: 3,
                        color: Theme.of(context).colorScheme.primary,
                        dotData: const FlDotData(show: true), 
                      ),
                    ],
                  ),
                ),
            ),
          ],
        ),
      ),
    );
  }
}
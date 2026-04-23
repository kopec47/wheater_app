import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:convert';

void main() {
  runApp(const WeatherApp());
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

  List<double> tempHistory = [20.0, 21.5, 22.0, 24.5, 23.0, 22.5, 25.0];

  Future<void> connectToEsp() async {
    setState(() {
      isConnecting = true;
      connectionStatus = "Szukanie stacji...";
    });

    try {
      await [Permission.bluetoothScan, Permission.bluetoothConnect].request();

      if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.off) {
        setState(() {
          connectionStatus = "Włącz Bluetooth!";
          isConnecting = false;
        });
        return;
      }

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

      FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          String name = r.device.platformName.isEmpty ? r.device.advName : r.device.platformName;
          
          if (name.toLowerCase().contains("weather")) {
            await FlutterBluePlus.stopScan();
            
            if (mounted) setState(() => connectionStatus = "Łączenie...");

            try {
              await Future.delayed(const Duration(milliseconds: 500));
              await r.device.connect(autoConnect: false);
              
              if (mounted) {
                setState(() => connectionStatus = "Odkrywanie usług...");
              }
              
              _discoverServices(r.device);
              return;

            } catch (e) {
              if (mounted) {
                setState(() {
                  connectionStatus = "Błąd: $e";
                  isConnecting = false;
                });
              }
            }
          }
        }
      });

      await Future.delayed(const Duration(seconds: 5));
      if (mounted && connectionStatus == "Szukanie stacji...") {
         setState(() {
          connectionStatus = "Nie znaleziono";
          isConnecting = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isConnecting = false);
    }
  }

  void _discoverServices(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      bool foundAnyData = false;

      for (var service in services) {
        for (var characteristic in service.characteristics) {
          // Szukamy charakterystyki, która pozwala na powiadomienia (Notify lub Indicate)
          if (characteristic.properties.notify || characteristic.properties.indicate) {
            
            await characteristic.setNotifyValue(true);
            foundAnyData = true;

            characteristic.lastValueStream.listen((value) {
              if (value.isNotEmpty) {
                _processIncomingData(value);
              }
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          connectionStatus = foundAnyData ? "Odbieranie danych" : "Połączono (brak kanału danych)";
          isConnecting = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => connectionStatus = "Błąd usług: $e");
    }
  }

  void _processIncomingData(List<int> value) {
    try {
      // PRÓBA 1: Dekodowanie jako tekst UTF-8 (np. "22.5,45,1013")
      String decoded = utf8.decode(value);
      List<String> parts = decoded.split(',');

      if (parts.length >= 3) {
        setState(() {
          temperature = double.tryParse(parts[0]) ?? temperature;
          humidity = double.tryParse(parts[1]) ?? humidity;
          if (parts.length >= 4) pressure = double.tryParse(parts[2]) ?? pressure;
          if (parts.length >= 5) windSpeed = double.tryParse(parts[3]) ?? windSpeed;
          if (parts.length >= 5) batteryLevel = int.tryParse(parts[4]) ?? batteryLevel;
          
          tempHistory.add(temperature);
          if (tempHistory.length > 7) tempHistory.removeAt(0);
        });
      }
    } catch (e) {
      // PRÓBA 2: Jeśli to nie tekst, spróbujmy odczytać surowe bajty (diagnostyka)
      // Jeśli ESP32 wysyła np. 1 bajt temperatury
      if (value.isNotEmpty) {
        setState(() {
          temperature = value[0].toDouble();
          connectionStatus = "Surowe dane: ${value.length} bajtów";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              const Text(
                "Stacja Pogodowa",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              Text(connectionStatus, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: WeatherCard(
                      title: "Temperatura",
                      value: "${temperature.toStringAsFixed(1)}°C",
                      icon: "🌡️",
                      weeklyData: tempHistory,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: WeatherCard(
                      title: "Wilgotność",
                      value: "${humidity.toStringAsFixed(1)}%",
                      icon: "💧",
                      weeklyData: const [50, 48, 45, 47, 46, 45, 42],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: WeatherCard(
                      title: "Ciśnienie",
                      value: "${pressure.toStringAsFixed(0)} hPa",
                      icon: "⏱️",
                      weeklyData: const [1012, 1010, 1013, 1015, 1013, 1011, 1012],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: WeatherCard(
                      title: "Wiatr",
                      value: "${windSpeed.toStringAsFixed(1)}km/h",
                      icon: "💨",
                      weeklyData: const [10, 12, 15, 8, 12, 14, 12],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildBatteryCard(),
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
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Połącz z ESP32", style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatteryCard() {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 6,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                batteryLevel > 20 ? Icons.battery_full : Icons.battery_alert,
                color: batteryLevel > 20 ? Colors.green : Colors.red,
                size: 32,
              ),
              const SizedBox(width: 16),
              Text(
                '$batteryLevel%',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
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
  final String title;
  final String value;
  final String icon;
  final List<double> weeklyData;

  const WeatherCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.weeklyData,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Card(
        elevation: 6,
        clipBehavior: Clip.antiAlias,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WeatherDetailsScreen(
                  title: title,
                  currentValue: value,
                  weeklyData: weeklyData,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(icon, style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WeatherDetailsScreen extends StatelessWidget {
  final String title;
  final String currentValue;
  final List<double> weeklyData;

  const WeatherDetailsScreen({
    super.key,
    required this.title,
    required this.currentValue,
    required this.weeklyData,
  });

  @override
  Widget build(BuildContext context) {
    double average = weeklyData.isEmpty ? 0 : weeklyData.reduce((a, b) => a + b) / weeklyData.length;
    String unit = currentValue.replaceAll(RegExp(r'[0-9.,]'), '').trim();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Obecnie", style: TextStyle(fontSize: 20)),
            Text(
              currentValue,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text("Średnia z tygodnia: ${average.toStringAsFixed(1)} $unit"),
            const SizedBox(height: 48),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: weeklyData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                      isCurved: true,
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
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const WeatherApp());
}

class WeatherData {
  final double temperature;
  final double humidity;
  final double pressure;
  final double windSpeed;
  final int timestamp;

  WeatherData({
    required this.temperature,
    required this.humidity,
    required this.pressure,
    required this.windSpeed,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;
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

class WeatherScreen extends StatelessWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mockData = WeatherData(
      temperature: 22.5,
      humidity: 45.0,
      pressure: 1013.2,
      windSpeed: 12.5,
    );

    final int batteryLevel = 85;

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
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: WeatherCard(
                      title: "Temperatura",
                      value: "${mockData.temperature}°C",
                      icon: "🌡️",
                      weeklyData: const [20.0, 21.5, 22.0, 24.5, 23.0, 22.5, 25.0],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: WeatherCard(
                      title: "Wilgotność",
                      value: "${mockData.humidity}%",
                      icon: "💧",
                      weeklyData: const [50.0, 48.0, 45.0, 47.0, 46.0, 45.0, 42.0],
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
                      value: "${mockData.pressure} hPa",
                      icon: "⏱️",
                      weeklyData: const [1012.0, 1010.0, 1013.0, 1015.0, 1013.2, 1011.0, 1012.0],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: WeatherCard(
                      title: "Wiatr",
                      value: "${mockData.windSpeed}km/h",
                      icon: "💨",
                      weeklyData: const [10.0, 12.0, 15.0, 8.0, 12.5, 14.0, 12.0],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              SizedBox(
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
              ),
              
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    print("Szukam stacji ESP32...");
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Połączono z ESP32",
                    style: TextStyle(fontSize: 18),
                  ),
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
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
    double average = weeklyData.reduce((a, b) => a + b) / weeklyData.length;
    String unit = currentValue.replaceAll(RegExp(r'[0-9.,]'), '').trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.black)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Obecnie",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.black87),
            ),
            Text(
              currentValue,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Średnia z tygodnia: ${average.toStringAsFixed(1)} $unit",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.black87.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 48),
            Text(
              "Wykres (ostatnie 7 dni)",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.black87),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => Colors.white,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((touchedSpot) {
                          return LineTooltipItem(
                            touchedSpot.y.toStringAsFixed(1),
                            const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        interval: 0.5,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(1),
                            style: const TextStyle(color: Colors.black54, fontSize: 12),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: weeklyData.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value);
                      }).toList(),
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
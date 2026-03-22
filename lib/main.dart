import 'package:flutter/material.dart';

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
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: WeatherCard(
                      title: "Wilgotność",
                      value: "${mockData.humidity}%",
                      icon: "💧",
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
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: WeatherCard(
                      title: "Wiatr",
                      value: "${mockData.windSpeed}km/h",
                      icon: "💨",
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

  const WeatherCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Card(
        elevation: 6,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
    );
  }
}
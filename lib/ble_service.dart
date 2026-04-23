import 'dart:convert';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class WeatherBLEService {
  static const String SERVICE_UUID = "12345678-1234-1234-1234-123456789abc";
  static const String CHARACTERISTIC_UUID = "abcdefab-1234-5678-1234-56789abcdef0";

  BluetoothDevice? targetDevice;
  BluetoothCharacteristic? targetCharacteristic;

  Future<void> startScanning(Function(String) onStatusUpdate, Function(String) onDataReceived) async {
    onStatusUpdate("Szukanie stacji...");
    
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    var subscription = FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        String name = r.device.platformName.isEmpty ? r.device.advName : r.device.platformName;
        
        if (name.toLowerCase().contains("weather")) {
          print("Znaleziono: $name");
          await FlutterBluePlus.stopScan();
          onStatusUpdate("Łączenie...");
          
          await connectToDevice(r.device, onStatusUpdate, onDataReceived);
          break;
        }
      }
    });
  }

  Future<void> connectToDevice(BluetoothDevice device, Function(String) onStatusUpdate, Function(String) onDataReceived) async {
    try {
      await Future.delayed(const Duration(milliseconds: 600));

      await (device as dynamic).connect(
        autoConnect: false,
        license: "none" as dynamic,
      );

      onStatusUpdate("Połączono! Odkrywanie usług...");
      List<BluetoothService> services = await device.discoverServices();

      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
          for (var char in service.characteristics) {
            if (char.uuid.toString().toLowerCase() == CHARACTERISTIC_UUID.toLowerCase()) {
              targetCharacteristic = char;

              await targetCharacteristic!.setNotifyValue(true);
              targetCharacteristic!.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  String decodedData = utf8.decode(value);
                  onDataReceived(decodedData);
                }
              });
              onStatusUpdate("Odbieranie danych...");
            }
          }
        }
      }
    } catch (e) {
      print("Błąd BLE: $e");
      onStatusUpdate("Błąd połączenia: $e");
    }
  }
}
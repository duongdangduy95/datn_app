import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/api_client.dart';
import '../models/device.dart';
import '../services/device_service.dart';
import 'add_device_screen.dart';
import 'device_detail_screen.dart';
import 'login_screen.dart';
import '../services/audio_recorder_service.dart';
import '../services/voice_service.dart';
import 'package:dio/dio.dart';
import '../services/permission_service.dart';
import '../models/voice_control_response.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  List<Device> devices = [];
  bool loading = true;

  final AudioRecorderService audioRecorderService = AudioRecorderService();

  final VoiceService voiceService = VoiceService(ApiClient.dio);

  @override
  void initState() {
    super.initState();
    loadData();
  }


  Future<void> voiceControl() async {

    final granted = await PermissionService.requestMicPermission();

    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bạn chưa cấp quyền micro"),
        ),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đang ghi âm 5 giây...")),
      );

      final audioPath = await audioRecorderService.record5Seconds();

      if (audioPath == null) return;

      final result = await voiceService.controlByVoice(audioPath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)), // ✅ đúng
      );

      if (result.success) {
        await loadData();
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
  Future<void> loadData() async {
    setState(() {
      loading = true;
    });

    try {
      devices = await DeviceService().getDevices();

      for (final d in devices) {
        print("DEVICE=${d.name} STATUS=${d.status}");
      }

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  Future<void> logout() async {
    const storage = FlutterSecureStorage();

    await storage.delete(key: "token");

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
          (route) => false,
    );
  }

  Future<void> toggleDevice(
      Device device,
      bool value,
      ) async {
    try {

      await DeviceService().controlDevice(
        device.id,
        value,
      );

      if (!mounted) return;

      setState(() {
        device.status = value.toString();
      });

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
  }

  Widget buildDeviceCard(Device device) {
    final isOn =
        device.status.toUpperCase() == "ON" ||
            device.status == "true";

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),

        leading: CircleAvatar(
          child: Icon(
            device.online
                ? Icons.wifi
                : Icons.wifi_off,
          ),
        ),

        title: Text(
          device.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        subtitle: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),

            Text(
              "Code: ${device.deviceCode}",
            ),

            Text(
              "Type: ${device.type}",
            ),

            Text(
              "Role: ${device.role}",
            ),

            Text(
              device.online
                  ? "Online"
                  : "Offline",
            ),
          ],
        ),

        trailing: Switch(
          value: isOn,
          onChanged: (value) {
            toggleDevice(
              device,
              value,
            );
          },
        ),

        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  DeviceDetailScreen(
                    device: device,
                  ),
            ),
          );

          loadData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Thiết bị của tôi",
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout,
            ),
            onPressed: logout,
          ),
        ],
      ),

      floatingActionButton: Column(
      mainAxisSize: MainAxisSize.min,
      children: [

        FloatingActionButton(
          heroTag: "voice",
          onPressed: voiceControl,
          child: const Icon(
            Icons.mic,
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        FloatingActionButton(
          heroTag: "add",
          child: const Icon(
            Icons.add,
          ),
          onPressed: () async {

            final result =
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                const AddDeviceScreen(),
              ),
            );

            if (result == true) {
              loadData();
            }
          },
        ),
      ],
    ),

      body: loading
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : devices.isEmpty
          ? const Center(
        child: Text(
          "Chưa có thiết bị",
        ),
      )
          : RefreshIndicator(
        onRefresh: loadData,
        child: ListView.builder(
          itemCount:
          devices.length,
          itemBuilder:
              (_, index) {
            return buildDeviceCard(
              devices[index],
            );
          },
        ),
      ),
    );
  }
}
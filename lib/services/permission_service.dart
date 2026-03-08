import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// --------------------
/// STATE
/// --------------------
@immutable
class PermissionsState {
  final PermissionStatus camera;
  final PermissionStatus microphone;
  final PermissionStatus location;

  const PermissionsState({
    required this.camera,
    required this.microphone,
    required this.location,
  });

  bool get allGranted =>
      camera.isGranted &&
          microphone.isGranted &&
          location.isGranted;
}

/// --------------------
/// SERVICE (Singleton)
/// --------------------
class PermissionsService {
  PermissionsService._internal();
  static final PermissionsService _instance = PermissionsService._internal();
  factory PermissionsService() => _instance;

  final ValueNotifier<PermissionsState?> notifier = ValueNotifier(null);

  /// Initial + refresh
  Future<void> refresh() async {
    final camera = await Permission.camera.status;
    final mic = await Permission.microphone.status;
    final location = await Permission.location.status;

    notifier.value = PermissionsState(
      camera: camera,
      microphone: mic,
      location: location,
    );
  }

  /// Request missing permissions
  Future<void> requestMissing() async {
    final state = notifier.value;
    if (state == null) return;

    if (!state.camera.isGranted) {
      await Permission.camera.request();
    }
    if (!state.microphone.isGranted) {
      await Permission.microphone.request();
    }
    if (!state.location.isGranted) {
      await Permission.location.request();
    }

    await refresh();
  }
}

/// --------------------
/// UI WRAPPER
/// --------------------
class PermissionsGate extends StatefulWidget {
  final Widget child;

  const PermissionsGate({super.key, required this.child});

  @override
  State<PermissionsGate> createState() => _PermissionsGateState();
}

class _PermissionsGateState extends State<PermissionsGate> {
  final service = PermissionsService();

  @override
  void initState() {
    super.initState();
    service.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PermissionsState?>(
      valueListenable: service.notifier,
      builder: (context, state, _) {
        if (state == null) {
          return const SizedBox.shrink(); // blank screen
        }

        if (state.allGranted) {
          return widget.child;
        }

        return _PermissionsScreen(
          state: state,
          onRequest: service.requestMissing,
        );
      },
    );
  }
}

/// --------------------
/// PERMISSION UI
/// --------------------
class _PermissionsScreen extends StatelessWidget {
  final PermissionsState state;
  final VoidCallback onRequest;

  const _PermissionsScreen({
    required this.state,
    required this.onRequest,
  });

  Widget _row(String label, String subtitle, bool granted) {
    return ListTile(
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        subtitle,
        // style: const TextStyle(fontSize: 16),
      ),
      trailing: Icon(
        granted ? Icons.check_circle : Icons.cancel,
        color: granted ? Colors.green : Colors.red,
      ),
      dense: true,
      // children: [
      //   Icon(
      //     granted ? Icons.check_circle : Icons.cancel,
      //     color: granted ? Colors.green : Colors.red,
      //   ),
      //   const SizedBox(width: 12),
      //   Text(
      //     label,
      //     style: const TextStyle(fontSize: 16),
      //   ),
      // ],
    );
  }

  // Widget _row(String label, bool granted) {
  //   return Row(
  //     children: [
  //       Icon(
  //         granted ? Icons.check_circle : Icons.cancel,
  //         color: granted ? Colors.green : Colors.red,
  //       ),
  //       const SizedBox(width: 12),
  //       Text(
  //         label,
  //         style: const TextStyle(fontSize: 16),
  //       ),
  //     ],
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Permissions Required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10,),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
                ),
                child: const Text(
                  'We require foreground location, camera and microphone '
                      'permissions to let you record your video and overlay speed data. '
                      'Recording starts only when you manually start it.\n\n'
                      'All video, audio, and location data remain on your device. '
                      'This app does not upload, transmit, or store your recordings '
                      'or location data on external servers.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.justify,
                ),
              ),
              const SizedBox(height: 24),

              _row('Location', 'To accurately measure your speed.', state.location.isGranted),
              const SizedBox(height: 1),
              _row('Camera', 'To enable Video Recording', state.camera.isGranted),
              const SizedBox(height: 1),
              _row('Microphone', 'To enable Audio with your Video', state.microphone.isGranted),

              const SizedBox(height: 32),
              MaterialButton(
                color: Colors.blue,
                onPressed: onRequest,
                child: const Text('Grant Permissions'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
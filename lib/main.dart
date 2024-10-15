import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _cameras = await availableCameras();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primaryColor: Color(0xFF4CAF50),
      ),
      home: const detectPage(title: 'Flutter Demo Home Page'),
    );
  }
}

class detectPage extends StatefulWidget {
  const detectPage({super.key, required this.title});

  final String title;

  @override
  State<detectPage> createState() => _detectPageState();
}

class _detectPageState extends State<detectPage> {
  late CameraController controller;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _permissionWithNotification();
    _initialization();

    controller = CameraController(_cameras[0], ResolutionPreset.max);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            break;
          default:
            break;
        }
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // 권한요청
  void _permissionWithNotification() async {
    await [Permission.notification].request();
  }

  void _initialization() async {
    AndroidInitializationSettings android = const AndroidInitializationSettings("@mipmap/ic_launcher");
    InitializationSettings settings = InitializationSettings(android: android);
    await _local.initialize(settings);
  }

  NotificationDetails details = const NotificationDetails(
    android: AndroidNotificationDetails(
      "1",
      "test",
      importance: Importance.max,
      priority: Priority.high,
    ),
  );

  void _incrementCounter() async {
    await _local.show(1, "카메라 갯수", "${_cameras.length}", details);
    final image = await controller.takePicture();
    print(image.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "객체탐지",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).primaryColor),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (!isLoading)
              Column(
                children: [
                  Icon(
                    Icons.camera_alt_rounded,
                    size: 100,
                  ),
                  Text(
                    '객체탐지 버튼을 클릭하면 객체탐지를 시작합니다\n객체탐지는 후면카메라를 사용합니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            if (isLoading) CircularProgressIndicator()
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              backgroundColor: Color(0xFF4CAF50),
              textStyle: TextStyle(color: Colors.white),
            ),
            onPressed: isLoading
                ? null
                : () async {
                    setState(() {
                      isLoading = true;
                    });
                    Dio dio = Dio();

                    XFile picture = await controller.takePicture();

                    FormData formData = FormData.fromMap({"file": await MultipartFile.fromFile(picture.path, filename: picture.name)});

                    Response res = await dio.post('http://192.168.219.149:8000/object_detect',
                        data: formData,
                        options: Options(headers: {
                          "Content-Type": "multipart/form-data",
                        }));

                    setState(() {
                      isLoading = false;
                    });

                    Map<String, dynamic> items = res.data;

                    if (items['result']) return _local.show(1, "탐지결과", "사람이 탐지되었습니다", details);
                    return _local.show(1, "탐지결과", "사람이 탐지되지않았습니다", details);
                  },
            child: Text(
              '객체탐지',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}

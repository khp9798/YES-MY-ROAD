import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/detection_service.dart';
import '../utils/screen_utils.dart';
import '../utils/frame_rate_tester.dart';
import '../models/detection_result.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({Key? key}) : super(key: key);

  @override
  _DetectionScreenState createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  DetectionService? _detectionService;
  StreamSubscription? _subscription;
  final ApiService _apiService = ApiService();
  final FrameRateTester _frameRateTester = FrameRateTester();

  int _detectionCount = 0;
  int _frameSkip = 30;
  int _frameCounter = 0;

  List<String> _detectedClasses = [];
  List<List<double>> _boundingBoxes = [];
  List<double> _confidenceScores = [];

  final StreamController<DetectionResult> _uploadQueue = StreamController<DetectionResult>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSystem();
    _uploadQueue.stream.listen(_uploadDetection);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _stopDetection();
    } else if (state == AppLifecycleState.resumed) {
      _initializeSystem();
    }
  }

  void _initializeSystem() async {
    await _initializeCamera();

    DetectionService.initialize().then((detector) {
      setState(() {
        _detectionService = detector;
        _subscription = detector.resultsStream.stream.listen(_handleDetectionResults);
      });
    });
  }

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) {
      debugPrint('사용 가능한 카메라가 없습니다');
      return;
    }

    _cameraController = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      await _cameraController!.setFlashMode(FlashMode.off);


      if (_cameraController!.value.isInitialized) {
        ScreenUtils.setPreviewSize(_cameraController!.value.previewSize!);
      }

      await _cameraController!.startImageStream(_processFrame);

      setState(() {});

    } catch (e) {
      debugPrint('카메라 초기화 오류: $e');
    }
  }

  void _processFrame(CameraImage cameraImage) {
    _frameRateTester.countFrame();

    if (_frameCounter % (_frameSkip + 1) == 0) {
      _detectionService?.processFrame(cameraImage);
    }

    _frameCounter++;
    if (_frameCounter > 1000) _frameCounter = 0;
  }

  void _handleDetectionResults(Map<String, dynamic> results) {
    setState(() {
      if (results.containsKey('jpegImage')) {
        Uint8List imageData = results['jpegImage'];
        _saveAndUploadDetection(imageData);
      }

      _detectedClasses = results['cls'] ?? [];
      _boundingBoxes = results['box'] ?? [];
      _confidenceScores = results['conf'] ?? [];
    });
  }

  Future<void> _saveAndUploadDetection(Uint8List imageData) async {
    String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    String directory = (await getApplicationDocumentsDirectory()).path;
    String fileName = 'road_defect_$timestamp.jpg';
    File imageFile = File('$directory/$fileName');

    await imageFile.writeAsBytes(imageData);

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('위치 정보 획득 실패: $e');
      position = Position(
          longitude: 0,
          latitude: 0,
          timestamp: DateTime.now(),
          accuracy: -1,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
          floor: 0,
          isMocked: false
      );
    }

    try {
      String defectType = _determineDefectType(_detectedClasses);
      _uploadQueue.add(DetectionResult(
        imageFile: imageFile,
        position: position,
        timestamp: DateTime.now(),
        defectType: defectType,
      ));

      setState(() {
        _detectionCount++;
      });
    } catch (e) {
      debugPrint('감지 결과 처리 오류: $e');
    }
  }

  String _determineDefectType(List<String> classes) {
    if (classes.contains('pothole')) {
      return 'POTHOLE';
    } else if (classes.contains('crack')) {
      return 'CRACK';
    }
    return 'UNKNOWN';
  }

  Future<void> _uploadDetection(DetectionResult detection) async {
    try {
      bool success = await _apiService.reportRoadDefect(
        detection.position.longitude,
        detection.position.latitude,
        detection.position.accuracy,
        detection.timestamp,
        detection.imageFile,
      );

      if (success) {
        debugPrint('도로 손상 데이터 업로드 성공: ${detection.defectType}');
      } else {
        debugPrint('도로 손상 데이터 업로드 실패');
      }
    } catch (e) {
      debugPrint('업로드 오류: $e');
    }
  }

  void _stopDetection() {
    _cameraController?.stopImageStream();
    _detectionService?.stop();
    _subscription?.cancel();
  }

  @override
  void dispose() {
    _stopDetection();
    WidgetsBinding.instance.removeObserver(this);
    _frameRateTester.stopTesting();
    _uploadQueue.close();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [

          CameraPreview(_cameraController!),

          Positioned(
            top: MediaQuery.of(context).padding.top + 10, // 상태바 아래로 10px
            left: 10,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 30,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}
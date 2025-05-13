# SafeWay - 도로 손상 감지 시스템

SafeWay 어플리케이션은 Flutter와 TensorFlow Lite를 활용한 모바일 기반 도로 손상 감지 애플리케이션입니다. 실시간으로 도로의 포트홀(pothole)과 균열(crack)을 감지하고, 위치 정보와 함께 저장 및 업로드할 수 있습니다.

## 주요 기능

### 실시간 감지 모드
- 카메라를 통해 도로 손상을 실시간으로 감지
- 감지된 결함을 서버에 즉시 업로드

### 실시간 녹화 모드
- 속도에 따른 적응형 프레임 스킵으로 배터리 및 저장 공간 최적화
- 차량 속도가 빠를수록 더 자주 촬영 (저속: 31프레임마다, 고속: 2프레임마다)
- FPS 및 처리 통계 실시간 표시

### 기록 관리
- 로컬에 저장된 감지 기록 관리
- 선택적 업로드 기능
- 업로드 완료된 기록 일괄 삭제

## 기술 구현

### 감지 엔진
- YOLO11n.tflite 객체 감지 양자화 모델 활용
- 클래스 감지: pothole(포트홀), crack(균열)

### 이미지 처리
- 다양한 카메라 포맷(YUV420, BGRA8888, JPEG, NV21) 지원
- 원본 이미지에서 모델 입력으로의 전처리(리사이즈, 패딩, 정규화)
- 모델 출력에서 원본 이미지 좌표로의 역변환

### 위치 및 속도 측정
- GPS와 가속도계 센서 데이터 융합
- 정확한 위치 및 속도 정보 수집

### 비최대 억제(NMS)
- 중복 감지 제거를 위한 비최대 억제 알고리즘 구현
- 신뢰도 및 IoU 기반 필터링


## 시스템 요구사항

- Flutter 3.0 이상
- Android 8.0 이상
- 카메라 및 위치 권한 필요

## 설치 방법

```bash

# 디렉토리 이동
cd safeway

# 종속성 설치
flutter pub get

# 애플리케이션 실행
flutter run
```

## 폴더 구조

```
lib/
├── main.dart                     # 애플리케이션 진입점
├── models/                       # 데이터 모델
│   ├── detection_result.dart     # 감지 결과 모델
│   └── local_detection_record.dart # 로컬 저장 기록 모델
├── screens/                      # UI 화면
│   ├── home_screen.dart          # 홈 화면
│   ├── detection_screen.dart     # 실시간 감지 화면
│   ├── recording_detection_screen.dart # 녹화 모드 화면
│   └── record_management_screen.dart # 기록 관리 화면
├── services/                     # 비즈니스 로직
│   ├── api_service.dart          # API 통신
│   ├── detection_service.dart    # 기본 감지 서비스
│   ├── speed_based_detection_service.dart # 속도 기반 감지
│   └── local_storage_service.dart # 로컬 저장소 관리
└── utils/                        # 유틸리티 함수
    ├── image_converter.dart      # 이미지 변환
    ├── nms.dart                  # 비최대 억제
    ├── screen_utils.dart         # 화면 유틸리티
    └── frame_rate_tester.dart    # 프레임 측정
```

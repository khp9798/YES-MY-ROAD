import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img_lib;
import 'dart:io' show Platform;

class PreprocessResult {
  final List<List<List<double>>> tensor;
  final double scale;
  final double padX;
  final double padY;

  PreprocessResult(this.tensor, this.scale, this.padX, this.padY);
}

class ImageConverter {
  // 디바이스 방향을 저장할 정적 변수 추가
  static DeviceOrientation currentOrientation = DeviceOrientation.portraitUp;

  // 방향 설정 메서드 추가
  static void setOrientation(DeviceOrientation orientation) {
    currentOrientation = orientation;
  }

  static Future<img_lib.Image?> convertCameraImageToImage(CameraImage cameraImage) async {
    img_lib.Image? image;

    if (cameraImage.format.group == ImageFormatGroup.yuv420) {
      image = _convertYUV420ToImage(cameraImage);
    } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      image = img_lib.Image.fromBytes(
        width: cameraImage.width,
        height: cameraImage.height,
        bytes: cameraImage.planes[0].bytes.buffer,
        order: img_lib.ChannelOrder.rgba,
      );
    } else if (cameraImage.format.group == ImageFormatGroup.jpeg) {
      image = _convertJPEGToImage(cameraImage);
    } else if (cameraImage.format.group == ImageFormatGroup.nv21) {
      image = _convertNV21ToImage(cameraImage);
    }

    // 회전 로직 수정
    if (image != null && Platform.isAndroid) {
      // 디바이스 방향에 따라 적절하게 이미지 회전
      switch (currentOrientation) {
        case DeviceOrientation.portraitUp:
        // 세로 모드 (기본) - 90도 회전
          image = img_lib.copyRotate(image, angle: 90);
          break;
        case DeviceOrientation.landscapeLeft:
        // 가로 왼쪽 - 원본 유지
        // 이미 정상 작동한다면 회전하지 않음
          break;
        case DeviceOrientation.landscapeRight:
        // 가로 오른쪽 - 180도 회전
          image = img_lib.copyRotate(image, angle: 180);
          break;
        case DeviceOrientation.portraitDown:
        // 세로 아래 - 270도 회전
          image = img_lib.copyRotate(image, angle: 270);
          break;
      }
    }

    return image;
  }

  static img_lib.Image _convertYUV420ToImage(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;

    final uvRowStride = cameraImage.planes[1].bytesPerRow;
    final uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

    final yPlane = cameraImage.planes[0].bytes;
    final uPlane = cameraImage.planes[1].bytes;
    final vPlane = cameraImage.planes[2].bytes;

    final image = img_lib.Image(width: width, height: height);

    var uvIndex = 0;

    for (var y = 0; y < height; y++) {
      var pY = y * width;
      var pUV = uvIndex;

      for (var x = 0; x < width; x++) {
        final yValue = yPlane[pY];
        final uValue = uPlane[pUV];
        final vValue = vPlane[pUV];

        final r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
        final g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).clamp(0, 255).toInt();
        final b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();

        image.setPixelRgba(x, y, r, g, b, 255);

        pY++;
        if (x % 2 == 1 && uvPixelStride == 2) {
          pUV += uvPixelStride;
        } else if (x % 2 == 1 && uvPixelStride == 1) {
          pUV++;
        }
      }

      if (y % 2 == 1) {
        uvIndex += uvRowStride;
      }
    }
    return image;
  }

  static img_lib.Image _convertJPEGToImage(CameraImage cameraImage) {
    final bytes = cameraImage.planes[0].bytes;
    return img_lib.decodeJpg(bytes)!;
  }

  static img_lib.Image _convertNV21ToImage(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;
    final yPlane = cameraImage.planes[0].bytes;
    final uvPlane = cameraImage.planes[1].bytes;

    final image = img_lib.Image(width: width, height: height);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final yIndex = y * width + x;
        final uvIndex = (y ~/ 2) * (width ~/ 2) * 2 + (x ~/ 2) * 2;

        final yValue = yPlane[yIndex];
        final uValue = uvPlane[uvIndex];
        final vValue = uvPlane[uvIndex + 1];

        final r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
        final g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).clamp(0, 255).toInt();
        final b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();

        image.setPixelRgba(x, y, r, g, b, 255);
      }
    }
    return image;
  }

  static Uint8List encodeImageToJpeg(img_lib.Image image, {int quality = 85}) {
    return Uint8List.fromList(img_lib.encodeJpg(image, quality: quality));
  }

  static PreprocessResult preprocessImageWithPadding(img_lib.Image image, int targetSize) {
    final originalWidth = image.width;
    final originalHeight = image.height;

    final scaleW = targetSize / originalWidth;
    final scaleH = targetSize / originalHeight;
    final scale = scaleW < scaleH ? scaleW : scaleH;

    final scaledWidth = (originalWidth * scale).toInt();
    final scaledHeight = (originalHeight * scale).toInt();

    final scaledImage = img_lib.copyResize(
      image,
      width: scaledWidth,
      height: scaledHeight,
      interpolation: img_lib.Interpolation.linear,
    );

    final paddedImage = img_lib.Image(width: targetSize, height: targetSize);
    img_lib.fill(paddedImage, color: img_lib.ColorRgb8(0, 0, 0));

    final padX = (targetSize - scaledWidth) / 2;
    final padY = (targetSize - scaledHeight) / 2;

    img_lib.compositeImage(
      paddedImage,
      scaledImage,
      dstX: padX.toInt(),
      dstY: padY.toInt(),
    );

    final tensor = List.generate(
      targetSize,
          (y) => List.generate(
        targetSize,
            (x) {
          final pixel = paddedImage.getPixel(x, y);
          return [
            pixel.r / 255.0,
            pixel.g / 255.0,
            pixel.b / 255.0
          ];
        },
      ),
    );

    return PreprocessResult(tensor, scale, padX, padY);
  }
}
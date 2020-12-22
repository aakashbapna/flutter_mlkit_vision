// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of mlkit_vision;

enum _ImageType { file, bytes }

/// Indicates the image rotation.
///
/// Rotation is counter-clockwise.
enum ImageRotation { rotation0, rotation90, rotation180, rotation270 }

/// Indicates whether a model is ran on device or in the cloud.
enum ModelType { onDevice, cloud }

/// Detected language from text recognition in regular and document images.
class RecognizedLanguage {
  RecognizedLanguage._(dynamic data) : languageCode = data['languageCode'];

  /// The BCP-47 language code, such as, en-US or sr-Latn. For more information,
  /// see http://www.unicode.org/reports/tr35/#Unicode_locale_identifier.
  final String languageCode;
}

/// The MlKit machine learning vision API.
///
/// You can get an instance by calling [MlKitVision.instance] and then get
/// a detector from the instance:
///
/// ```dart
/// TextRecognizer textRecognizer = MlKitVision.instance.textRecognizer();
/// ```
class MlKitVision {
  MlKitVision._();

  @visibleForTesting
  static const MethodChannel channel =
  MethodChannel('plugins.flutter.io/mlkit_vision');

  @visibleForTesting
  static int nextHandle = 0;

  /// Singleton of [MlKitVision].
  ///
  /// Use this get an instance of a detector:
  ///
  /// ```dart
  /// TextRecognizer textRecognizer = MlKitVision.instance.textRecognizer();
  /// ```
  static final MlKitVision instance = MlKitVision._();

  /// Creates an instance of [BarcodeDetector].
  BarcodeDetector barcodeDetector([BarcodeDetectorOptions options]) {
    return BarcodeDetector._(
      options ?? const BarcodeDetectorOptions(),
      nextHandle++,
    );
  }

}

/// Represents an image object used for both on-device and cloud API detectors.
///
/// Create an instance by calling one of the factory constructors.
class MlKitVisionImage {
  MlKitVisionImage._({
    @required _ImageType type,
    MlKitVisionImageMetadata metadata,
    File imageFile,
    Uint8List bytes,
  })  : _imageFile = imageFile,
        _metadata = metadata,
        _bytes = bytes,
        _type = type;

  /// Construct a [MlKitVisionImage] from a file.
  factory MlKitVisionImage.fromFile(File imageFile) {
    assert(imageFile != null);
    return MlKitVisionImage._(
      type: _ImageType.file,
      imageFile: imageFile,
    );
  }

  /// Construct a [MlKitVisionImage] from a file path.
  factory MlKitVisionImage.fromFilePath(String imagePath) {
    assert(imagePath != null);
    return MlKitVisionImage._(
      type: _ImageType.file,
      imageFile: File(imagePath),
    );
  }

  /// Construct a [MlKitVisionImage] from a list of bytes.
  ///
  /// On Android, expects `android.graphics.ImageFormat.NV21` format. Note:
  /// Concatenating the planes of `android.graphics.ImageFormat.YUV_420_888`
  /// into a single plane, converts it to `android.graphics.ImageFormat.NV21`.
  ///
  /// On iOS, expects `kCVPixelFormatType_32BGRA` format. However, this should
  /// work with most formats from `kCVPixelFormatType_*`.
  factory MlKitVisionImage.fromBytes(
      Uint8List bytes,
      MlKitVisionImageMetadata metadata,
      ) {
    assert(bytes != null);
    assert(metadata != null);
    return MlKitVisionImage._(
      type: _ImageType.bytes,
      bytes: bytes,
      metadata: metadata,
    );
  }

  final Uint8List _bytes;
  final File _imageFile;
  final MlKitVisionImageMetadata _metadata;
  final _ImageType _type;

  Map<String, dynamic> _serialize() => <String, dynamic>{
    'type': _enumToString(_type),
    'bytes': _bytes,
    'path': _imageFile?.path,
    'metadata': _type == _ImageType.bytes ? _metadata._serialize() : null,
  };
}

/// Plane attributes to create the image buffer on iOS.
///
/// When using iOS, [bytesPerRow], [height], and [width] throw [AssertionError]
/// if `null`.
class MlKitVisionImagePlaneMetadata {
  MlKitVisionImagePlaneMetadata({
    @required this.bytesPerRow,
    @required this.height,
    @required this.width,
  })  : assert(defaultTargetPlatform == TargetPlatform.iOS
      ? bytesPerRow != null
      : true),
        assert(defaultTargetPlatform == TargetPlatform.iOS
            ? height != null
            : true),
        assert(
        defaultTargetPlatform == TargetPlatform.iOS ? width != null : true);

  /// The row stride for this color plane, in bytes.
  final int bytesPerRow;

  /// Height of the pixel buffer on iOS.
  final int height;

  /// Width of the pixel buffer on iOS.
  final int width;

  Map<String, dynamic> _serialize() => <String, dynamic>{
    'bytesPerRow': bytesPerRow,
    'height': height,
    'width': width,
  };
}

/// Image metadata used by [MlKitVision] detectors.
///
/// [rotation] defaults to [ImageRotation.rotation0]. Currently only rotates on
/// Android.
///
/// When using iOS, [rawFormat] and [planeData] throw [AssertionError] if
/// `null`.
class MlKitVisionImageMetadata {
  MlKitVisionImageMetadata({
    @required this.size,
    @required this.rawFormat,
    @required this.planeData,
    this.rotation = ImageRotation.rotation0,
  })  : assert(size != null),
        assert(defaultTargetPlatform == TargetPlatform.iOS
            ? rawFormat != null
            : true),
        assert(defaultTargetPlatform == TargetPlatform.iOS
            ? planeData != null
            : true),
        assert(defaultTargetPlatform == TargetPlatform.iOS
            ? planeData.isNotEmpty
            : true);

  /// Size of the image in pixels.
  final Size size;

  /// Rotation of the image for Android.
  ///
  /// Not currently used on iOS.
  final ImageRotation rotation;

  /// Raw version of the format from the iOS platform.
  ///
  /// Since iOS can use any planar format, this format will be used to create
  /// the image buffer on iOS.
  ///
  /// On iOS, this is a `FourCharCode` constant from Pixel Format Identifiers.
  /// See https://developer.apple.com/documentation/corevideo/1563591-pixel_format_identifiers?language=objc
  ///
  /// Not used on Android.
  final dynamic rawFormat;

  /// The plane attributes to create the image buffer on iOS.
  ///
  /// Not used on Android.
  final List<MlKitVisionImagePlaneMetadata> planeData;

  int _imageRotationToInt(ImageRotation rotation) {
    switch (rotation) {
      case ImageRotation.rotation90:
        return 90;
      case ImageRotation.rotation180:
        return 180;
      case ImageRotation.rotation270:
        return 270;
      default:
        assert(rotation == ImageRotation.rotation0);
        return 0;
    }
  }

  Map<String, dynamic> _serialize() => <String, dynamic>{
    'width': size.width,
    'height': size.height,
    'rotation': _imageRotationToInt(rotation),
    'rawFormat': rawFormat,
    'planeData': planeData
        .map((MlKitVisionImagePlaneMetadata plane) => plane._serialize())
        .toList(),
  };
}

String _enumToString(dynamic enumValue) {
  final String enumString = enumValue.toString();
  return enumString.substring(enumString.indexOf('.') + 1);
}

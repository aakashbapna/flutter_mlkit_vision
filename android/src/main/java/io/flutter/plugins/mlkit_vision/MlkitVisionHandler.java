package io.flutter.plugins.mlkit_vision;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Matrix;
import android.net.Uri;
import android.util.Log;
import android.util.SparseArray;
import androidx.exifinterface.media.ExifInterface;
import com.google.mlkit.vision.common.InputImage;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.io.File;
import java.io.IOException;
import java.util.Map;

class MlkitVisionHandler implements MethodChannel.MethodCallHandler {
  private final SparseArray<Detector> detectors = new SparseArray<>();
  private final Context applicationContext;

  MlkitVisionHandler(Context applicationContext) {
    this.applicationContext = applicationContext;
  }

  @Override
  public void onMethodCall(MethodCall call, MethodChannel.Result result) {
    switch (call.method) {
      case "BarcodeDetector#processImage":
      case "FaceDetector#processImage":
      case "ImageLabeler#processImage":
      case "TextRecognizer#processImage":
      case "DocumentTextRecognizer#processImage":
        handleDetection(call, result);
        break;
      case "BarcodeDetector#close":
      case "FaceDetector#close":
      case "ImageLabeler#close":
      case "TextRecognizer#close":
      case "DocumentTextRecognizer#close":
        closeDetector(call, result);
        break;
      default:
        result.notImplemented();
    }
  }

  private void handleDetection(MethodCall call, MethodChannel.Result result) {
    Map<String, Object> options = call.argument("options");

    InputImage image;
    Map<String, Object> imageData = call.arguments();
    try {
      image = dataToVisionImage(imageData);
    } catch (IOException exception) {
      result.error("MLVisionDetectorIOError", exception.getLocalizedMessage(), null);
      return;
    }

    Detector detector = getDetector(call);
    if (detector == null) {
      switch (call.method.split("#")[0]) {
        case "BarcodeDetector":
          detector = new BarcodeDetector(options);
          break;
      }

      final Integer handle = call.argument("handle");
      addDetector(handle, detector);
    }

    detector.handleDetection(image, result);
  }

  private void closeDetector(final MethodCall call, final MethodChannel.Result result) {
    final Detector detector = getDetector(call);

    if (detector == null) {
      final Integer handle = call.argument("handle");
      final String message = String.format("Object for handle does not exists: %s", handle);
      throw new IllegalArgumentException(message);
    }

    try {
      detector.close();
      result.success(null);
    } catch (IOException e) {
      final String code = String.format("%sIOError", detector.getClass().getSimpleName());
      result.error(code, e.getLocalizedMessage(), null);
    } finally {
      final Integer handle = call.argument("handle");
      detectors.remove(handle);
    }
  }

  private InputImage dataToVisionImage(Map<String, Object> imageData) throws IOException {
    String imageType = (String) imageData.get("type");
    assert imageType != null;

    switch (imageType) {
      case "file":
        final String imageFilePath = (String) imageData.get("path");
        final int rotation = getImageExifOrientation(imageFilePath);

        if (rotation == 0) {
          File file = new File(imageFilePath);
          return InputImage.fromFilePath(applicationContext, Uri.fromFile(file));
        }

        final Bitmap bitmap = BitmapFactory.decodeFile(imageFilePath);

        return InputImage.fromBitmap(bitmap, rotation);
      case "bytes":
        @SuppressWarnings("unchecked")
        Map<String, Object> metadataData = (Map<String, Object>) imageData.get("metadata");

         int width =     (int) (double) metadataData.get("width");
         int height =    (int) (double) metadataData.get("height");
         int rotationDeg  = (int) metadataData.get("rotation");

        byte[] bytes = (byte[]) imageData.get("bytes");
        assert bytes != null;

        return InputImage.fromByteArray(bytes, width, height, rotationDeg, InputImage.IMAGE_FORMAT_NV21);
      default:
        throw new IllegalArgumentException(String.format("No image type for: %s", imageType));
    }
  }

  private int getImageExifOrientation(String imageFilePath) throws IOException {
    ExifInterface exif = new ExifInterface(imageFilePath);
    int orientation =
        exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL);

    switch (orientation) {
      case ExifInterface.ORIENTATION_ROTATE_90:
        return 90;
      case ExifInterface.ORIENTATION_ROTATE_180:
        return 180;
      case ExifInterface.ORIENTATION_ROTATE_270:
        return 270;
      default:
        return 0;
    }
  }


  private void addDetector(final int handle, final Detector detector) {
    if (detectors.get(handle) != null) {
      final String message = String.format("Object for handle already exists: %s", handle);
      throw new IllegalArgumentException(message);
    }

    detectors.put(handle, detector);
  }

  private Detector getDetector(final MethodCall call) {
    final Integer handle = call.argument("handle");
    return detectors.get(handle);
  }
}

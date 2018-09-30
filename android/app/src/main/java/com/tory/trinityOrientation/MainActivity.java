package com.tory.trinityOrientation;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.Rect;
import android.media.ExifInterface;
import android.os.Bundle;
import android.util.Log;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;

import io.flutter.app.FlutterActivity;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FlutterActivity implements MethodChannel.MethodCallHandler{

    private static final String IMAGE_CHANNEL = "com.tory.trinityOrientation/image";
    private static final String SAVE_CHANNEL = "com.tory.trinityOrientation/save_image";

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    GeneratedPluginRegistrant.registerWith(this);

    new MethodChannel(getFlutterView(), IMAGE_CHANNEL).setMethodCallHandler(this);
    new MethodChannel(getFlutterView(), SAVE_CHANNEL).setMethodCallHandler(this);
  }

  @Override
  public void onMethodCall(MethodCall methodCall, MethodChannel.Result result) {
    if(methodCall.method.equals("addOverlayToImage")) {
      String imagePath = methodCall.argument("imagePath");
      String overlayPath = methodCall.argument("overlayPath");
      try {
        File imageFile = new File(imagePath);
        File overlayFile = new File(overlayPath);

        ExifInterface exif = new ExifInterface(imagePath);
        String orientString = exif.getAttribute(ExifInterface.TAG_ORIENTATION);
        int orientation = orientString != null ? Integer.parseInt(orientString) :  ExifInterface.ORIENTATION_NORMAL;

        int rotationAngle = 0;
        if (orientation == ExifInterface.ORIENTATION_ROTATE_90) rotationAngle = 90;
        if (orientation == ExifInterface.ORIENTATION_ROTATE_180) rotationAngle = 180;
        if (orientation == ExifInterface.ORIENTATION_ROTATE_270) rotationAngle = 270;

        Log.v("iamge", Integer.toString(rotationAngle));

        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inMutable = true;

        Bitmap imageBitmap = BitmapFactory.decodeFile(imageFile.getAbsolutePath(), options);
        Bitmap overlayBitmap = BitmapFactory.decodeFile(overlayFile.getAbsolutePath(), options);

        Matrix matrix = new Matrix();
        matrix.setRotate(rotationAngle, (float) imageBitmap.getWidth() / 2, (float) imageBitmap.getHeight() / 2);

        Bitmap rotatedBitmap = Bitmap.createBitmap(imageBitmap, 0, 0, imageBitmap.getWidth(), imageBitmap.getHeight(), matrix, true);
        rotatedBitmap = rotatedBitmap.copy(Bitmap.Config.ARGB_8888, true);


        Bitmap finalBitmap = Bitmap.createBitmap(rotatedBitmap.getWidth(), rotatedBitmap.getHeight(), rotatedBitmap.getConfig());


        float aspectRatio = (float)overlayBitmap.getHeight() / (float)overlayBitmap.getWidth();

        int overlayWidth = rotatedBitmap.getWidth();
        int overlayHeight = (int)(rotatedBitmap.getWidth() * aspectRatio);
        int overlayX = 0;
        int overlayY = rotatedBitmap.getHeight() - overlayHeight;

        Canvas canvas = new Canvas(finalBitmap);
        canvas.drawBitmap(rotatedBitmap, new Rect(0, 0, rotatedBitmap.getWidth(), rotatedBitmap.getHeight()), new Rect(0, 0, rotatedBitmap.getWidth(), rotatedBitmap.getHeight()), new Paint());
        canvas.drawBitmap(overlayBitmap, new Rect(0, 0, overlayBitmap.getWidth(), overlayBitmap.getHeight()), new Rect(overlayX, overlayY, rotatedBitmap.getWidth(), overlayY + overlayHeight), new Paint());
       // Rect overlaySource = new Rect(0, 0, overlayBitmap.getWidth(), overlayBitmap.getHeight());
        //Rect overlayDest = new Rect(0, 0, overlayBitmap.getWidth(), overlayBitmap.getHeight());

        //canvas.drawBitmap(overlayBitmap, overlayDest, overlayDest, new Paint());


        FileOutputStream fileOutputStream = new FileOutputStream(imagePath);
        finalBitmap.compress(Bitmap.CompressFormat.JPEG, 100, fileOutputStream);
        fileOutputStream.close();

        result.success(imagePath);
      } catch (FileNotFoundException e) {
        e.printStackTrace();
        result.error("FileNotFoundException", e.getMessage(), null);
      } catch (IOException e) {
        e.printStackTrace();
        result.error("IOException", e.getMessage(), null);
      }
    } else if(methodCall.method.equals("saveImage")) {
      String imagePath = methodCall.argument("imagePath");

      File imageFile = new File(imagePath);
      Bitmap imageBitmap = BitmapFactory.decodeFile(imageFile.getAbsolutePath(), new BitmapFactory.Options());


      try {
        ExifInterface exif = new ExifInterface(imagePath);

        String orientString = exif.getAttribute(ExifInterface.TAG_ORIENTATION);
        int orientation = orientString != null ? Integer.parseInt(orientString) :  ExifInterface.ORIENTATION_NORMAL;

        int rotationAngle = 0;
        if (orientation == ExifInterface.ORIENTATION_ROTATE_90) rotationAngle = 90;
        if (orientation == ExifInterface.ORIENTATION_ROTATE_180) rotationAngle = 180;
        if (orientation == ExifInterface.ORIENTATION_ROTATE_270) rotationAngle = 270;

        Matrix matrix = new Matrix();
        matrix.setRotate(rotationAngle, (float) imageBitmap.getWidth() / 2, (float) imageBitmap.getHeight() / 2);

        Bitmap rotatedBitmap = Bitmap.createBitmap(imageBitmap, 0, 0, imageBitmap.getWidth(), imageBitmap.getHeight(), matrix, true);
        rotatedBitmap = rotatedBitmap.copy(Bitmap.Config.ARGB_8888, false);

        CapturePhotoUtils.insertImage(getContentResolver(), rotatedBitmap
                , "2T2000s", "Taken from the 2T200s app");

        result.success(imagePath);
      } catch (IOException e) {
        e.printStackTrace();
      }

      result.error("could not save image", "Could not save Image", null);
    }
  }
}

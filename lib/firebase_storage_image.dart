import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

enum ImageDownloadState { Idle, GettingURL, Downloading, Done, Error }

class FirebaseStorageImage extends StatefulWidget {
  /// The reference of the image that has to be loaded.
  final StorageReference reference;

  /// The widget that will be displayed when loading if no [placeholderImage] is set.
  final Widget fallbackWidget;

  /// The widget that will be displayed if an error occurs.
  final Widget errorWidget;

  /// The image that will be displayed when loading if no [fallbackWidget] is set.
  final ImageProvider placeholderImage;

  FirebaseStorageImage(
      {Key key,
      @required this.reference,
      @required this.errorWidget,
      this.fallbackWidget,
      this.placeholderImage}) {
    assert(
        (this.fallbackWidget == null && this.placeholderImage != null) ||
            (this.fallbackWidget != null && this.placeholderImage == null),
        "Either [fallbackWidget] or [placeholderImage] must not be null.");
  }

  @override
  _FirebaseStorageImageState createState() => _FirebaseStorageImageState(
      reference, fallbackWidget, errorWidget, placeholderImage);
}

class _FirebaseStorageImageState extends State<FirebaseStorageImage>
    with SingleTickerProviderStateMixin {
  _FirebaseStorageImageState(StorageReference reference, this.fallbackWidget,
      this.errorWidget, this.placeholderImage) {
    var url = reference.getDownloadURL();
    this._imageDownloadState = ImageDownloadState.GettingURL;
    url.then(this._setImageData).catchError((err) {
      print(err);
      this._setError();
    });
  }

  /// The widget that will be displayed when loading if no [placeholderImage] is set.
  final Widget fallbackWidget;

  /// The widget that will be displayed if an error occurs.
  final Widget errorWidget;

  /// The image that will be displayed when loading if no [fallbackWidget] is set.
  final ImageProvider placeholderImage;

  /// The image that will be/has been downloaded from the [reference].
  Image _networkImage;

  /// The state of the [_networkImage].
  ImageDownloadState _imageDownloadState = ImageDownloadState.Idle;

  /// Sets the [_networkImage] to the image downloaded from [url].
  void _setImageData(dynamic url) {
    this._networkImage = Image.network(
      url,
      fit: BoxFit.cover,
    );
    this
        ._networkImage
        .image
        .resolve(ImageConfiguration())
        .addListener(ImageStreamListener((info, bool) {
      if (mounted)
        setState(() => this._imageDownloadState = ImageDownloadState.Done);
    }));
    if (this._imageDownloadState != ImageDownloadState.Done)
      this._imageDownloadState = ImageDownloadState.Downloading;
  }

  /// Sets the [_imageDownloadState] to [ImageDownloadState.Error] and redraws the UI.
  void _setError() {
    if (mounted)
      setState(() => this._imageDownloadState = ImageDownloadState.Error);
  }

  @override
  Widget build(BuildContext context) {
    switch (this._imageDownloadState) {
      case ImageDownloadState.Idle:
      case ImageDownloadState.GettingURL:
      case ImageDownloadState.Downloading:
        return this.fallbackWidget ?? Image(image: this.placeholderImage);
      case ImageDownloadState.Error:
        return this.errorWidget;
      case ImageDownloadState.Done:
        return this._networkImage;
        break;
      default:
        return this.errorWidget;
    }
  }
}

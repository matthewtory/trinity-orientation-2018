#include "AppDelegate.h"
#include "GeneratedPluginRegistrant.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [GeneratedPluginRegistrant registerWithRegistry:self];
    
    FlutterViewController* controller = (FlutterViewController*) self.window.rootViewController;
    
    FlutterMethodChannel* saveChannel = [FlutterMethodChannel methodChannelWithName:@"com.tory.trinityOrientation/save_image" binaryMessenger:controller];
    [saveChannel setMethodCallHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
        if([@"saveImage" isEqualToString:call.method]) {
            NSString *imagePath = call.arguments[@"imagePath"];
            
            UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
            
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
            
            result(imagePath);
        }
    }];
    
    FlutterMethodChannel* imageChannel = [FlutterMethodChannel methodChannelWithName:@"com.tory.trinityOrientation/image" binaryMessenger:controller];
    [imageChannel setMethodCallHandler:^(FlutterMethodCall * _Nonnull call, FlutterResult  _Nonnull result) {
        if([@"addOverlayToImage" isEqualToString:call.method]) {
            NSString *imagePath = call.arguments[@"imagePath"];
            NSString *overlayPath = call.arguments[@"overlayPath"];
            
            UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
            
            UIImage *overlayImage = [UIImage imageWithContentsOfFile:overlayPath];
            
            UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
            [image drawInRect:(CGRect){0, 0, image.size}];
            image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            CGSize imageSize = [image size];
            CGSize overlaySize = [overlayImage size];
            
            CALayer *backgroundLayer = [CALayer layer];
            backgroundLayer.frame = CGRectMake(0, 0, imageSize.width, imageSize.height);
            
            CGFloat aspectRatio = overlaySize.height / overlaySize.width;
            CGFloat overlayHeight = imageSize.width * aspectRatio;
            
            CALayer *overlayLayer = [CALayer layer];
            overlayLayer.frame = CGRectMake(0, imageSize.height - overlayHeight, imageSize.width, imageSize.width * aspectRatio);
            
            [backgroundLayer setContents:(id)[image CGImage]];
            [overlayLayer setContents:(id)[overlayImage CGImage]];
            
            CALayer *parentLayer = [CALayer layer];
            parentLayer.frame = CGRectMake(0, 0, imageSize.width, imageSize.height);
            [parentLayer addSublayer:backgroundLayer];
            [parentLayer addSublayer:overlayLayer];
            
            UIGraphicsBeginImageContext(parentLayer.frame.size);
            [parentLayer renderInContext:UIGraphicsGetCurrentContext()];
            UIImage *outputImage = UIGraphicsGetImageFromCurrentImageContext();
            
            UIGraphicsEndImageContext();
            
            [UIImageJPEGRepresentation(outputImage, 1.0) writeToFile:imagePath atomically:YES];
            
            result(imagePath);
        }
    }];
    // Override point for customization after application launch.
    return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

@end

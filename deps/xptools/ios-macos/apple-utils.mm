//
//  apple-utils.mm
//  xptools
//
//  Created by Gaetan de Villele on 12/05/2025.
//  Copyright © 2025 voxowl. All rights reserved.
//

#import "apple-utils.h"

// apple
#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

// --------------------------------------------------
// MARK: - Objective-C utilities -
// --------------------------------------------------

//
// NSData
//

/// add function to type NSData
@implementation NSData (Base64UrlEncoding)

- (NSString *)base64UrlEncodedString {
    // First, get the regular base64 encoded string
    NSString *base64String = [self base64EncodedStringWithOptions:0];
    // Then make it URL-safe by replacing characters and removing padding
    NSString *base64UrlString = [base64String stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    base64UrlString = [base64UrlString stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    base64UrlString = [base64UrlString stringByReplacingOccurrencesOfString:@"=" withString:@""];
    return base64UrlString;
}

@end

#if TARGET_OS_IPHONE

//
// PopoverPresentationControllerDelegate (iOS)
//

@implementation PopoverPresentationControllerDelegate

+ (id)shared {
    static PopoverPresentationControllerDelegate *sharedDelegate = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedDelegate = [[PopoverPresentationControllerDelegate alloc] init];
    });
    return sharedDelegate;
}

- (id)init {
    if ((self = [super init])) {
      // someProperty = [[NSString alloc] initWithString:@"Default Property Value"];
  }
  return self;
}

- (void)dealloc {
  // Should never be called
}

// called when taping outside the activity view
// not called when share action completed.
// NOTE: animation done in activityViewController.completionWithItemsHandler,
// as it can handle both cases (action completed or not)
//-(void)presentationControllerWillDismiss:(UIPresentationController *)presentationController {
//    UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
//    [UIView animateWithDuration:0.2 animations:^{
//        vc.view.alpha = 1.0;
//    }];
//}

-(void)prepareForPopoverPresentation:(UIPopoverPresentationController *)popoverPresentationController {
    UIViewController *vc = vx::utils::ios::getRootUIViewController();
    [UIView animateWithDuration:0.2 animations:^{
        vc.view.alpha = 0.5;
    }];
}

- (void)popoverPresentationController:(UIPopoverPresentationController *)popoverPresentationController willRepositionPopoverToRect:(inout CGRect *)rect inView:(inout UIView * _Nonnull __autoreleasing *)view {
    UIViewController *vc = vx::utils::ios::getRootUIViewController();
    *rect = CGRectMake(CGRectGetMidX(vc.view.bounds),
                      CGRectGetMidY(vc.view.bounds),
                      0,
                      0);
}

@end

//
// DocumentPickerDelegate (for iOS)
//

@implementation DocumentPickerDelegate

@synthesize callback;

+ (id)shared {
    static DocumentPickerDelegate *sharedDelegate = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedDelegate = [[DocumentPickerDelegate alloc] init];
    });
    return sharedDelegate;
}

- (id)init {
    if ((self = [super init])) {
        // someProperty = [[NSString alloc] initWithString:@"Default Property Value"];
    }
    return self;
}

- (void)dealloc {}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    [self callback](vx::utils::PickerCallbackStatus::CANCELLED, std::string());
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL* fileURL = [urls firstObject];
    if (fileURL == nil) { // should never happen
        [self callback](vx::utils::PickerCallbackStatus::ERROR, std::string());
        return;
    }

    // get access to security scopped resources
    // (this is needed for accessing iCloud Drive files)
    BOOL accessGranted = [fileURL startAccessingSecurityScopedResource];
    if (!accessGranted) {
        [self callback](vx::utils::PickerCallbackStatus::ERROR, std::string());
        return;
    }

    std::string bytes;
    std::string error;

    @try {
        NSError* err = nil;
        NSData *fileData = [NSData dataWithContentsOfURL:fileURL options:0 error:&err];
        if (err) {
            error.assign([err.localizedDescription UTF8String]);
        } else {
            bytes.assign(static_cast<const char*>(fileData.bytes), fileData.length);
        }
    } @catch (NSException *exception) {
        error.assign([exception.reason UTF8String]);
    } @finally {
        [fileURL stopAccessingSecurityScopedResource];
    }

    if (error.empty() == false) {
        NSLog(@"⚠️ documentPicker error: %s", error.c_str());
        [self callback](vx::utils::PickerCallbackStatus::ERROR, std::string());
        return;
    }

    // success
    [self callback](vx::utils::PickerCallbackStatus::OK, bytes);
}

@end

//
// ImagePickerDelegate (for iOS)
//

@implementation ImagePickerDelegate

@synthesize callback;

+ (id)shared {
    static ImagePickerDelegate *sharedDelegate = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedDelegate = [[ImagePickerDelegate alloc] init];
    });
    return sharedDelegate;
}

- (id)init {
    if ((self = [super init])) {
        // someProperty = [[NSString alloc] initWithString:@"Default Property Value"];
    }
    return self;
}

- (void)dealloc {}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:nil];

    if (image == nil) {
        [self callback](vx::utils::PickerCallbackStatus::ERROR, std::string());
        return;
    }

    NSData *imageData = UIImagePNGRepresentation(image);
    if (imageData == nil) {
        // Try JPEG if PNG fails
        imageData = UIImageJPEGRepresentation(image, 0.9);
    }

    if (imageData == nil) {
        [self callback](vx::utils::PickerCallbackStatus::ERROR, std::string());
        return;
    }

    std::string bytes(static_cast<const char*>(imageData.bytes), imageData.length);
    [self callback](vx::utils::PickerCallbackStatus::OK, bytes);
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
    [self callback](vx::utils::PickerCallbackStatus::CANCELLED, std::string());
}

@end

#endif

// --------------------------------------------------
// MARK: - C++ utility functions -
// --------------------------------------------------

namespace vx {
namespace utils {

#if TARGET_OS_IPHONE
namespace ios {

// Helper function to get the root view controller in a modern way
UIViewController* getRootUIViewController() {
    if (@available(iOS 13.0, *)) {
        // iOS 13+ scene-based approach
        UIWindow *window = nil;
        for (UIWindowScene* windowScene in [UIApplication sharedApplication].connectedScenes) {
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *w in windowScene.windows) {
                    if (w.isKeyWindow) {
                        window = w;
                        break;
                    }
                }
                if (window) break;
            }
        }
        if (window) {
            return window.rootViewController;
        }
    }

    // Fallback for iOS 12 and earlier, or if scene approach fails
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [UIApplication sharedApplication].keyWindow.rootViewController;
#pragma clang diagnostic pop
}

} // namespace ios
#endif

} // namespace utils
} // namespace vx

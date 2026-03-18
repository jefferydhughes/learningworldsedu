//
//  apple-utils.h
//  xptools
//
//  Created by Gaetan de Villele on 12/06/2025.
//  Copyright © 2025 voxowl. All rights reserved.
//

#pragma once

// this file can only be included in Objective-C source files
#ifdef __OBJC__

// C/C++
#include <functional>

// apple
#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

// --------------------------------------------------
// MARK: - C++ utilities -
// --------------------------------------------------

namespace vx {
namespace utils {

/// Callback signature for file pickers
enum class PickerCallbackStatus {
    OK = 0,
    ERROR,
    CANCELLED,
};
typedef std::function<void(PickerCallbackStatus status, std::string bytes)> PickerCallback;

#if TARGET_OS_IPHONE
namespace ios {

/// returns the root view controller (iOS)
UIViewController* getRootUIViewController();

} // namespace ios
#endif

} // namespace utils
} // namespace vx

// --------------------------------------------------
// MARK: - Objective-C utilities -
// --------------------------------------------------

//
// NSData
//

@interface NSData (Base64UrlEncoding)
- (NSString *)base64UrlEncodedString;
@end

#if TARGET_OS_IPHONE

//
// PopoverPresentationControllerDelegate
//

@interface PopoverPresentationControllerDelegate: NSObject<UIPopoverPresentationControllerDelegate> {}
+ (id)shared;
@end

//
// DocumentPickerDelegate
//

@interface DocumentPickerDelegate: NSObject<UIDocumentPickerDelegate>
@property (nonatomic, assign) vx::utils::PickerCallback callback;
+ (id)shared;
@end

//
// ImagePickerDelegate
//

@interface ImagePickerDelegate: NSObject<UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, assign) vx::utils::PickerCallback callback;
+ (id)shared;
@end

#endif

#endif

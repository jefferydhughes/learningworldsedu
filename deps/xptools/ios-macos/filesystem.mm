//
//  filesystem.mm
//  xptools
//
//  Created by Gaetan de Villele on 03/03/2020.
//  Copyright © 2020 voxowl. All rights reserved.
//

#include "filesystem.hpp"

// C++
#include <fstream>

// apple
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#if TARGET_OS_IPHONE
#import <Photos/Photos.h>
#elif TARGET_OS_MAC
#import <AppKit/AppKit.h>
#endif

// xptools
#include "apple-utils.h"
#include "vxlog.h"

// --------------------------------------------------
// MARK: - Path separator -
// --------------------------------------------------

char vx::fs::getPathSeparator() {
    return '/';
}

std::string vx::fs::getPathSeparatorStr() {
    return "/";
}

// C symbols definition
extern "C" {

char c_getPathSeparator(void) {
    return '/';
}

const char *c_getPathSeparatorCStr(void) {
    return "/";
}

}

// ------------------------------
// Helper
// ------------------------------

bool vx::fs::Helper::setInMemoryStorage(bool b) {
    this->_inMemoryStorage = b;
    return true;
}

/// --------------------------------------------------
///
/// MARK: - static functions -
///
/// --------------------------------------------------

//static NSString *appGroupName = @"group.com.voxowl.blip";
static NSString *appGroupName = @"9JFN8QQG65.com.voxowl.particubes";
static NSString *legacyAppGroupName = @"9JFN8QQG65.com.voxowl.particubes";

std::string dirname(const std::string& fname)
{
     size_t pos = fname.find_last_of("\\/");
     return (std::string::npos == pos)
         ? ""
         : fname.substr(0, pos);
}

///
static NSString *getStoragePath() {

#if defined(CI_STORAGE_PATH)
    // override absPath
    return @CI_STORAGE_PATH;
#endif

    #if TARGET_OS_IPHONE
        NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask , true);
        if (paths.firstObject == nil) {
            return nil;
        } else {
            return [paths firstObject];
        }
    #elif TARGET_OS_MAC
        NSURL *containerUrl = [NSFileManager.defaultManager containerURLForSecurityApplicationGroupIdentifier:appGroupName];
        NSString *containerPath = [containerUrl path];
        if (containerPath == nil) {
            return nil;
        } else {
            NSString *prefixPath = [NSString stringWithUTF8String:vx::fs::Helper::shared()->getStorageRelPathPrefix().c_str()];
            if ([prefixPath length] > 0) {
                containerPath = [containerPath stringByAppendingPathComponent:prefixPath];
            }

            // create the container directory if necessary
            if ([NSFileManager.defaultManager fileExistsAtPath:containerPath] == NO) {
                NSError *error = nil;
                [NSFileManager.defaultManager createDirectoryAtURL:containerUrl withIntermediateDirectories:YES attributes:nil error:&error];
                if (error != nil) {
                    NSLog(@"🔥 failed to create app group container directory: %@", error.localizedDescription);
                    return nil;
                }
            }
        }
        return containerPath;
    #endif
}

#if TARGET_OS_IPHONE

void showIOSPhotosPickerForImport(vx::fs::ImportFileCallback importFileCallback) {

    // define callback function for the picker delegate
    vx::utils::PickerCallback pickerCallback = [importFileCallback](vx::utils::PickerCallbackStatus status, std::string bytes){
        switch (status) {
            case vx::utils::PickerCallbackStatus::OK:
                importFileCallback(vx::fs::ImportFileCallbackStatus::OK, bytes);
                break;
            case vx::utils::PickerCallbackStatus::ERROR:
                importFileCallback(vx::fs::ImportFileCallbackStatus::ERR, bytes);
                break;
            case vx::utils::PickerCallbackStatus::CANCELLED:
                importFileCallback(vx::fs::ImportFileCallbackStatus::CANCELLED, bytes);
                break;
        }
    };

    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if(status == PHAuthorizationStatusNotDetermined) {
        // Request photo authorization
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus authStatus) {
            if (authStatus == PHAuthorizationStatusAuthorized) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIImagePickerController* imagePicker = [[UIImagePickerController alloc]init];
                    if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
                        imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
                        imagePicker.allowsEditing = false;
                        ImagePickerDelegate *delegate = [ImagePickerDelegate shared];
                        delegate.callback = pickerCallback;
                        imagePicker.delegate = delegate;

                        UIViewController *rootController = vx::utils::ios::getRootUIViewController();
                        [rootController presentViewController:imagePicker animated:true completion:nil];
                    }
                });
            } else {
                importFileCallback(vx::fs::ImportFileCallbackStatus::CANCELLED, std::string());
            }
        }];
    } else if (status == PHAuthorizationStatusAuthorized) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIImagePickerController* imagePicker = [[UIImagePickerController alloc]init];
            if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
                imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
                imagePicker.allowsEditing = false;
                ImagePickerDelegate *delegate = [ImagePickerDelegate shared];
                delegate.callback = pickerCallback;
                imagePicker.delegate = delegate;

                UIViewController *rootController = vx::utils::ios::getRootUIViewController();
                [rootController presentViewController:imagePicker animated:true completion:nil];
            }
        });
    } else {
        // Permission denied or restricted
        importFileCallback(vx::fs::ImportFileCallbackStatus::CANCELLED, std::string());
    }
}

void showIOSFilesPickerForImport(vx::fs::ImportFileCallback importFileCallback) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *vc = vx::utils::ios::getRootUIViewController();

        UIDocumentPickerViewController *pickerVC = nil;
        
        // Use modern UTType approach for iOS 14+ when available
        if (@available(iOS 14.0, *)) {
            // Create UTType objects for each file type - modern approach
            NSMutableArray<UTType *> *allowedTypes = [NSMutableArray arrayWithObjects:
                                                     // Standard image types
                                                     UTTypePNG,
                                                     UTTypeJPEG,
                                                     UTTypeGIF,
                                                     // Custom voxel/3D model types
                                                     [UTType typeWithFilenameExtension:@"vox"],
                                                     [UTType typeWithFilenameExtension:@"pcubes"],
                                                     [UTType typeWithFilenameExtension:@"3zh"],
                                                     [UTType typeWithFilenameExtension:@"glb"],
                                                     [UTType typeWithFilenameExtension:@"gltf"],
                                                     nil];
            pickerVC = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:allowedTypes];
        } else {
            // Fallback for iOS 13 and earlier
            NSArray<NSString *> *documentTypes = @[@"public.png",
                                                   @"public.jpeg", 
                                                   @"com.compuserve.gif",
                                                   @"com.voxowl.particubes.vox",
                                                   @"com.voxowl.particubes.pcubes",
                                                   @"com.voxowl.particubes.3zh",
                                                   @"com.voxowl.particubes.glb",
                                                   @"com.voxowl.particubes.gltf"];
            // TODO: gaetan: disable deprecation warning
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            pickerVC = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:documentTypes inMode:UIDocumentPickerModeImport];
#pragma clang diagnostic pop
        }

        DocumentPickerDelegate *d = [DocumentPickerDelegate shared];
        d.callback = [importFileCallback](vx::utils::PickerCallbackStatus status, std::string bytes){
            switch (status) {
                case vx::utils::PickerCallbackStatus::OK:
                    importFileCallback(vx::fs::ImportFileCallbackStatus::OK, bytes);
                    break;
                case vx::utils::PickerCallbackStatus::ERROR:
                    importFileCallback(vx::fs::ImportFileCallbackStatus::ERR, bytes);
                    break;
                case vx::utils::PickerCallbackStatus::CANCELLED:
                    importFileCallback(vx::fs::ImportFileCallbackStatus::CANCELLED, bytes);
                    break;
            }
        };
        pickerVC.delegate = d;
        [vc presentViewController:pickerVC animated:YES completion:nil];
    });
}

void showImportFileOptions(vx::fs::ImportFileCallback callback) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *vc = vx::utils::ios::getRootUIViewController();

        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Import File" 
                                                                                 message:@"Choose the source for your file" 
                                                                          preferredStyle:UIAlertControllerStyleActionSheet];
        
        UIAlertAction *photosAction = [UIAlertAction actionWithTitle:@"Photo Library" 
                                                               style:UIAlertActionStyleDefault 
                                                             handler:^(UIAlertAction * action) {
            showIOSPhotosPickerForImport(callback);
        }];
        
        UIAlertAction *filesAction = [UIAlertAction actionWithTitle:@"Files" 
                                                              style:UIAlertActionStyleDefault 
                                                            handler:^(UIAlertAction * action) {
            showIOSFilesPickerForImport(callback);
        }];
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" 
                                                               style:UIAlertActionStyleCancel 
                                                             handler:^(UIAlertAction * action) {
            callback(vx::fs::ImportFileCallbackStatus::CANCELLED, std::string());
        }];
        
        [alertController addAction:photosAction];
        [alertController addAction:filesAction];
        [alertController addAction:cancelAction];
        
        // For iPad
        if (alertController.popoverPresentationController != nil) {
            alertController.popoverPresentationController.sourceView = vc.view;
            alertController.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(vc.view.bounds),
                                                                                 CGRectGetMidY(vc.view.bounds),
                                                                                 0,
                                                                                 0);
        }
        
        [vc presentViewController:alertController animated:YES completion:nil];
    });
}
#endif

void ::vx::fs::importFile(ImportFileCallback callback) {
#if TARGET_OS_IPHONE
    
    // Show options to user to choose between Photos and Files
    showImportFileOptions(callback);

#elif TARGET_OS_MAC

    // Create UTType objects for each file type
    NSMutableArray<UTType *> *allowedContentTypes = [NSMutableArray arrayWithObjects:
                                                     // Standard image types
                                                     UTTypePNG,
                                                     UTTypeJPEG,
                                                     UTTypeGIF,
                                                     // Custom voxel/3D model types - create UTTypes from file extensions
                                                     [UTType typeWithFilenameExtension:@"vox"],
                                                     [UTType typeWithFilenameExtension:@"pcubes"],
                                                     [UTType typeWithFilenameExtension:@"3zh"],
                                                     [UTType typeWithFilenameExtension:@"glb"],
                                                     [UTType typeWithFilenameExtension:@"gltf"],
                                                     nil];

    NSOpenPanel *op = [NSOpenPanel openPanel];
    [op setCanChooseFiles:YES];
    [op setCanChooseDirectories:NO];
    [op setAllowsMultipleSelection:NO];
    [op setAllowedContentTypes:allowedContentTypes];

    [op beginWithCompletionHandler:^(NSInteger result){
        if (result == NSModalResponseOK) {
            NSURL* fileURL = [[op URLs] objectAtIndex:0];
            NSError* error = nil;
            NSData* data = [NSData dataWithContentsOfURL:fileURL options:NSDataReadingUncached error:&error];
            if (error) {
                callback(ImportFileCallbackStatus::ERR, std::string());
            } else {
                std::string bytes(static_cast<const char*>(data.bytes), data.length);
                callback(ImportFileCallbackStatus::OK, bytes);
            }
        } else if (result == NSModalResponseCancel) {
            callback(ImportFileCallbackStatus::CANCELLED, std::string());
        }
    }];

#endif

}

FILE *vx::fs::openFile(const std::string& filePath, const std::string& mode) {
    FILE *result = fopen(filePath.c_str(), mode.c_str());
    return result;
}

std::string vx::fs::getBundleFilePath(const std::string& relFilePath) {
    NSString *bundlePath = nil;

    NSString *relPath = [NSString stringWithUTF8String:relFilePath.c_str()];
    if (relPath == nil) {
        return "";
    }
    
#if TARGET_OS_IPHONE
    bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *absPath = [bundlePath stringByAppendingPathComponent:relPath];
#elif TARGET_OS_MAC

#ifdef ONLINE_GAMESERVER

    NSString *absPath = nil;
    if (relFilePath.compare(0, 8, "modules/") == 0) {
        bundlePath = @PROJECT_LUA_MODULES_PATH;
        absPath = [bundlePath stringByAppendingPathComponent:relPath];
    } else {
        bundlePath = @PROJECT_BUNDLE_PATH;
        absPath = [bundlePath stringByAppendingPathComponent:relPath];
    }

#else // CLIENT

#if DEBUG
    NSString *absPath = nil;
    if (relFilePath.compare(0, 8, "modules/") == 0) {
        bundlePath = @PROJECT_LUA_MODULES_PATH;
        absPath = [bundlePath stringByAppendingPathComponent:relPath];
    } else {
        bundlePath = [[NSBundle mainBundle] bundlePath];
        absPath = [bundlePath stringByAppendingPathComponent:@"Contents"];
        absPath = [absPath stringByAppendingPathComponent:@"Resources"];
        absPath = [absPath stringByAppendingPathComponent:relPath];
    }
#else
    bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *absPath = [bundlePath stringByAppendingPathComponent:@"Contents"];
    absPath = [absPath stringByAppendingPathComponent:@"Resources"];
    absPath = [absPath stringByAppendingPathComponent:relPath];
#endif

#if defined(CI_BUNDLE_PATH)
    if (relFilePath.compare(0, 8, "modules/") == 0) {
        absPath = @CI_MODULES_PATH;
        absPath = [absPath stringByAppendingPathComponent:relPath];
    } else {
        absPath = @CI_BUNDLE_PATH;
        absPath = [absPath stringByAppendingPathComponent:relPath];
    }
#endif

#endif
#endif
    
    return std::string([absPath UTF8String]);
}

/// Opens a file located in the bundle directory.
/// @param relFilePath name of the file to open. It should not start with a '/'.
FILE *vx::fs::openBundleFile(std::string relFilePath, std::string mode) {
    std::string absPath = getBundleFilePath(relFilePath);
    FILE *result = fopen(absPath.c_str(), mode.c_str());
    if (result == nullptr) {
        // try within storage (where we put dynamically loaded "bundle" files).
        result = openStorageFile(std::string("bundle/") + relFilePath, mode);
    }
    return result;
}

///
FILE *vx::fs::openStorageFile(std::string relFilePath, std::string mode, size_t writeSize) {

    if (Helper::shared()->inMemoryStorage()) {

        /*
         FROM: https://man7.org/linux/man-pages/man3/fmemopen.3.html
         When a stream that has been opened for writing is flushed
         (fflush(3)) or closed (fclose(3)), a null byte is written at the
         end of the buffer if there is space. The caller should ensure
         that an extra byte is available in the buffer (and that size
         counts that byte) to allow for this

         /!\ the "if there is space" condition doesn't seem to be verified
         the same way on all platforms. We spent a full day debugging a crash
         caused by this... And that's why we don't take chances and add
         an extra byte when creating an in memory file.
         When opening the file for reading, the size if decreased not to read
         that last byte.
         */

        FILE* f = nullptr;

        if (mode == "rb") {

            InMemoryFile *inMemFile = Helper::shared()->getInMemoryFile("storage/" + relFilePath);
            if (inMemFile != nullptr) {
                f = fmemopen(inMemFile->bytes, inMemFile->size - 1, mode.c_str());
            }

        } else if (mode == "wb" && writeSize != 0) {
            InMemoryFile *inMemFile = Helper::shared()->createInMemoryFile("storage/" + relFilePath, writeSize + 1);
            if (inMemFile != nullptr) {
                f = fmemopen(inMemFile->bytes, inMemFile->size, mode.c_str());
            }
        }

        return f;

    } else {

        NSString *storagePath = getStoragePath();
        if (storagePath == nil) {
            return nullptr;
        }

        // create parent directories if missing when opening for writing
        bool writing = (mode.size() > 0 && (mode.at(0) == 'w' || mode.at(0) == 'a'));
        if (writing) {

            std::string parent = dirname(relFilePath);
            if (parent.empty() == false) { // expects parent dir(s)
                NSString *parentRelPath = [NSString stringWithUTF8String:parent.c_str()];
                if (parentRelPath == nil) {
                    return nil;
                }
                NSString *absoluteParentPath = [storagePath stringByAppendingPathComponent:parentRelPath];

                if ([[NSFileManager defaultManager] createDirectoryAtPath:absoluteParentPath withIntermediateDirectories:YES attributes:nil error:nil] == NO) {
                    return nil;
                }
            }
        }

        NSString *relPath = [NSString stringWithUTF8String:relFilePath.c_str()];
        if (relPath == nil) {
            return nil;
        }

        // generate absolute file path
        NSString *absoluteFilePath = [storagePath stringByAppendingPathComponent:relPath];

        // open file
        return fopen([absoluteFilePath UTF8String], mode.c_str());
    }
}

//
std::vector<std::string> vx::fs::listStorageDirectory(const std::string& relStoragePath) {
    std::vector<std::string> result;

    // convert relative path to NSString
    NSString *relPath = [NSString stringWithUTF8String:relStoragePath.c_str()];
    if (relPath == nil) {
        // error
        return result;
    }

    // get storage directory path
    NSString *storagePath = getStoragePath();
    if (storagePath == nil) {
        // error
        return result;
    }

    // append relative path to storage directory path
    NSString *absStorageDir = [storagePath stringByAppendingPathComponent:relPath];

    // make sure a file exists at the given path and that it's a directory
    BOOL isDirectory = NO;
    BOOL fileExists = NO;
    fileExists = [[NSFileManager defaultManager] fileExistsAtPath:absStorageDir isDirectory:&isDirectory];
    if (fileExists == NO || isDirectory == NO) {
        // error
        return result;
    }

    NSDirectoryEnumerator *dirEnumerator = [[NSFileManager defaultManager] enumeratorAtPath: absStorageDir];
    for (NSString *path in dirEnumerator) {
        // only consider top level items (NSDirectoryEnumerator is recursive)
        if (dirEnumerator.level == 1) {
            NSString *pathRelativeToStorageRoot = [relPath stringByAppendingPathComponent:path];
            result.push_back(std::string([pathRelativeToStorageRoot UTF8String]));
        }
    }

    return result;
}

//
bool vx::fs::removeStorageFileOrDirectory(std::string relFilePath) {
    NSString *storagePath = getStoragePath();
    if (storagePath == nil) {
        return false;
    }

    NSString *relPath = [NSString stringWithUTF8String:relFilePath.c_str()];
    if (relPath == nil) {
        return false;
    }

    // generate absolute file path
    NSString *absoluteFilePath = [storagePath stringByAppendingPathComponent:relPath];
    // remove file
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:absoluteFilePath error:&error];
    return error == nil ? true : false;
}

///
bool vx::fs::bundleFileExists(const std::string& relFilePath, bool& isDir) {
    const std::string absPathStr = vx::fs::getBundleFilePath(relFilePath);
    NSString *absPath = [NSString stringWithUTF8String:absPathStr.c_str()];

    BOOL isDirectory = NO;
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:absPath isDirectory:&isDirectory];

    isDir = isDirectory;

    return fileExists;
}

///
bool vx::fs::storageFileExists(const std::string& relFilePath, bool& isDir) {

    BOOL fileExists = NO;
    BOOL isDirectory = NO;
    NSString *absoluteFilePath = nil;

    if (Helper::shared()->inMemoryStorage()) {

        InMemoryFile *inMemFile = Helper::shared()->getInMemoryFile("storage/" + relFilePath);
        fileExists = inMemFile != nullptr;

    } else {

        NSString *storagePath = getStoragePath();
        if (storagePath == nil) {
            return false;
        }

        NSString *relPath = [NSString stringWithUTF8String:relFilePath.c_str()];
        if (relPath == nil) {
            return false;
        }

        // generate absolute file path
        absoluteFilePath = [storagePath stringByAppendingPathComponent:relPath];

        fileExists = [[NSFileManager defaultManager] fileExistsAtPath:absoluteFilePath isDirectory:&isDirectory];

        isDir = isDirectory;
    }

    return fileExists;
}

///
void vx::fs::shareFile(const std::string& filepath,
                       const std::string& title,
                       const std::string& filename,
                       const fs::FileType type) {
    
    vxlog_info("📸 [shareFile] %s", filepath.c_str());
#if TARGET_OS_IPHONE
    UIViewController *vc = vx::utils::ios::getRootUIViewController();

    NSString *filepathStr = [NSString stringWithCString:filepath.c_str() encoding:NSUTF8StringEncoding];
    NSString *srcFullpath = [NSString stringWithFormat:@"%@/%@", getStoragePath(), filepathStr];
    NSURL *srcURL = [NSURL fileURLWithPath:srcFullpath];

    NSArray *share = @[srcURL];
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:share applicationActivities:nil];
    
    // for iPadOS
    if (activityViewController.popoverPresentationController != nil) {
        activityViewController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirection();
        activityViewController.popoverPresentationController.sourceView = vc.view;
        activityViewController.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(vc.view.bounds),
                                                                                     CGRectGetMidY(vc.view.bounds),
                                                                                     0,
                                                                                     0);
        activityViewController.popoverPresentationController.delegate = [PopoverPresentationControllerDelegate shared];
        
        activityViewController.completionWithItemsHandler = ^(NSString *activityType,
                                                              BOOL completed,
                                                              NSArray *returnedItems,
                                                              NSError *activityError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.2 animations:^{
                    vc.view.alpha = 1.0;
                }];
            });
        };
    }
    
    [vc presentViewController:activityViewController animated:YES completion:nil];

#elif TARGET_OS_MAC
    NSString *nsFileName = [NSString stringWithCString:filename.c_str() encoding:NSUTF8StringEncoding];
    NSString *filenameWithExtension = @"";
    
    switch (type) {
        case FileType::NONE:
            filenameWithExtension = [NSString stringWithFormat:@"%@", nsFileName];
            break;
        case FileType::PNG:
            filenameWithExtension = [NSString stringWithFormat:@"%@.png", nsFileName];
            break;
        case FileType::PCUBES:
            filenameWithExtension = [NSString stringWithFormat:@"%@.pcubes", nsFileName];
            break;
        case FileType::CUBZH:
            filenameWithExtension = [NSString stringWithFormat:@"%@.3zh", nsFileName];
            break;
        case FileType::VOX:
            filenameWithExtension = [NSString stringWithFormat:@"%@.vox", nsFileName];
            break;
        case FileType::OBJ:
            filenameWithExtension = [NSString stringWithFormat:@"%@.obj", nsFileName];
            break;
    }
    
    NSSavePanel *dialog = [NSSavePanel savePanel];
    dialog.title = [NSString stringWithCString:title.c_str() encoding:NSUTF8StringEncoding];
    dialog.showsResizeIndicator = YES;
    dialog.canCreateDirectories = YES;
    dialog.showsHiddenFiles = NO;
    dialog.nameFieldStringValue = filenameWithExtension;

    if ([dialog runModal] == NSModalResponseOK) {
        std::string srcFullpath = std::string(getStoragePath().UTF8String) + "/" + filepath;
        // copy
        std::ifstream src(srcFullpath, std::ios::binary);
        std::ofstream dst(std::string(dialog.URL.path.UTF8String), std::ios::binary);
        dst << src.rdbuf();
    } else {
        // User clicked on "Cancel"
    }
#endif
}

bool vx::fs::removeStorageFilesWithPrefix(const std::string& directory,
                                          const std::string& prefix) {
    if (prefix.empty()) {
        return false;
    }
    
    // storage directory path
    NSString *storagePath = getStoragePath();
    if (storagePath == nil) {
        return false;
    }
    NSString* relPath = [NSString stringWithUTF8String:directory.c_str()];
    if (relPath == nil) {
        return false;
    }
    NSString *absStorageDir = [storagePath stringByAppendingPathComponent:relPath];

    
    // enumerate files located in directory
    NSDirectoryEnumerator *dirEnumerator = [[NSFileManager defaultManager] enumeratorAtPath: absStorageDir];

    BOOL isDirectory = NO;
    BOOL fileExists = NO;
    NSString *fileAbsPath = nil;
    NSString *nsprefix = [NSString stringWithUTF8String:prefix.c_str()];
    bool success = true;
    
    for (NSString *path in dirEnumerator) {
        fileAbsPath = [absStorageDir stringByAppendingPathComponent:path];
        fileExists = [[NSFileManager defaultManager] fileExistsAtPath:fileAbsPath isDirectory:&isDirectory];
        if (fileExists == NO || isDirectory == YES) {
            continue;
        }
        
        if ([path hasPrefix:nsprefix]) {
            if ([[NSFileManager defaultManager] removeItemAtPath:fileAbsPath error:nil] == NO) {
                success = false;
            }
        }
    }
    
    return success;
}

//
//  xp_http.cpp
//  xptools
//
//  Created by Gaetan de Villele on 16/06/2025.
//  Copyright © 2025 voxowl. All rights reserved.
//

#include "xp_http.hpp"

// Apple platforms have their own implementation
#if !defined(__VX_PLATFORM_MACOS) && !defined(__VX_PLATFORM_IOS)

// xptools
#include "filesystem.hpp"

#include "BZMD5.hpp"

namespace vx {
namespace http {

void clearSystemHttpCache() {
    // remove all HTTP cache files
    fs::removeStorageDirectoryRecurse("http_cache");
}

void clearSystemHttpCacheForURL(const std::string &urlString) {
    // remove HTTP cache file if present
    const std::string urlHash = md5(urlString);
    const std::string filepath = std::string(VX_HTTP_CACHE_DIR_NAME) + "/" + urlHash;
    vx::fs::removeStorageFileOrDirectory(filepath);
}

} // namespace http
} // namespace vx

#endif

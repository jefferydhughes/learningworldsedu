//
//  xp_http.mm
//  xptools
//
//  Created by Gaetan de Villele on 12/06/2025.
//  Copyright © 2025 voxowl. All rights reserved.
//

#include "xp_http.hpp"

// apple
#import <Foundation/Foundation.h>

namespace vx {
namespace http {

void clearSystemHttpCache() {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

void clearSystemHttpCacheForURL(const std::string &urlString) {
    NSString *nsUrlString = [NSString stringWithUTF8String:urlString.c_str()];
    NSURL *nsUrl = [NSURL URLWithString:nsUrlString];
    [[NSURLCache sharedURLCache] removeCachedResponseForRequest:[NSURLRequest requestWithURL:nsUrl]];
}

} // namespace http
} // namespace vx

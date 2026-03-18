//
//  encoding_base64.hpp
//  xptools
//
//  Created by Gaetan de Villele on 02/06/2025.
//  Copyright © 2025 voxowl. All rights reserved.
//

// C++
#include <string>

namespace vx {
namespace encoding {
namespace base64 {

// Base64 variant
enum class Variant {
    Standard,
    URL
};

// Encode bytes to base64
std::string encode(const std::string &data, const Variant variant = Variant::Standard);

// Decode base64 string to bytes
std::string decode(std::string input, std::string &out, const Variant variant = Variant::Standard);

}
}
}

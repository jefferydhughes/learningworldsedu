//
//  json.cpp
//  xptools
//
//  Created by Xavier Legland on 1/28/22.
//

#include "json.hpp"

// C++
#include <cstdio>
#include <cstring>

// xptools
#include "vxlog.h"

namespace vx {

namespace json {

bool hasField(const cJSON * const obj, const std::string& field) {
    if (obj == nullptr || cJSON_IsObject(obj) == false) {
        return false;
    }
    return cJSON_HasObjectItem(obj, field.c_str());
}

bool readStringField(const cJSON *const src, const std::string& field, std::string& value, bool canBeOmitted) {
    if (cJSON_IsObject(src) == false) {
        return false;
    }

    if (cJSON_HasObjectItem(src, field.c_str())) {
        const cJSON *tagEntry = cJSON_GetObjectItem(src, field.c_str());
        if (cJSON_IsString(tagEntry)) {
            char *str = tagEntry->valuestring;
            if (str != nullptr) {
                value.assign(str);
                return true;
            }
        }
    } else if (canBeOmitted) {
        // the field has been omitted, use default value
        value = "";
        return true;
    }
    return false;
}

bool writeStringField(cJSON * const obj, const std::string& field, const std::string& value, bool omitIfEmpty) {
    if (obj == nullptr) {
        return false;
    }

    if (field.empty()) {
        return false;
    }

    if (value.empty() && omitIfEmpty) {
        return true; // success
    }

    cJSON * const item = cJSON_CreateString(value.c_str());
    if (item == nullptr) {
        vxlog_error("can't create json string");
        return false; // failure
    }
    cJSON_AddItemToObject(obj, field.c_str(), item);
    return true; // success
}

bool readIntField(const cJSON *src, const std::string &field, int &value, bool canBeOmitted) {
    if (cJSON_IsObject(src) == false) {
        return false;
    }

    if (cJSON_HasObjectItem(src, field.c_str())) {
        const cJSON *tagEntry = cJSON_GetObjectItem(src, field.c_str());
        if (cJSON_IsNumber(tagEntry)) {
            value = tagEntry->valueint;
            return true;
        }
    } else if (canBeOmitted) {
        // the field has been omitted, use default value
        value = 0;
        return true;
    }
    return false;
}

bool readUInt8Field(const cJSON *src, const std::string &field, uint8_t &value, bool canBeOmitted) {
    int intValue = 0;
    const bool ok = readIntField(src, field, intValue, canBeOmitted);
    if (ok == false) {
        return false;
    }
    if (intValue < 0 || intValue > UINT8_MAX) {
        return false;
    }
    value = static_cast<uint8_t>(intValue);
    return true;
}

void writeIntField(cJSON *dest, const std::string &field, const int value) {
    cJSON *jnum = cJSON_CreateNumber(static_cast<double>(value));
    if (jnum == nullptr) {
        vxlog_error("can't create json int");
        return;
    }
    cJSON_AddItemToObject(dest, field.c_str(), jnum);
}

void writeInt64Field(cJSON *dest, const std::string& field, const int64_t value) {
    cJSON *jnum = cJSON_CreateNumber(static_cast<double>(value));
    if (jnum == nullptr) {
        vxlog_error("can't create json int");
        return;
    }
    cJSON_AddItemToObject(dest, field.c_str(), jnum);
}

bool readBoolField(const cJSON *src,
                             const std::string& field,
                             bool& value,
                             bool canBeOmitted) {
    if (cJSON_IsObject(src) == false) {
        return false;
    }

    if (cJSON_HasObjectItem(src, field.c_str())) {
        const cJSON *tagEntry = cJSON_GetObjectItem(src, field.c_str());
        if (cJSON_IsBool(tagEntry)) {
            value = cJSON_IsTrue(tagEntry);
            return true;
        }
    } else if (canBeOmitted) {
        // the field has been omitted, use default value
        value = false;
        return true;
    }
    return false;
}

void writeBoolField(cJSON *dest, const std::string &field, const bool value) {
    cJSON *jbool = cJSON_CreateBool(value);
    if (jbool == nullptr) {
        vxlog_error("can't create json bool");
        return;
    }
    cJSON_AddItemToObject(dest, field.c_str(), jbool);
}

void writeNullField(cJSON *dest, const std::string &field) {
    cJSON *jnull = cJSON_CreateNull();
    if (jnull == nullptr) {
        vxlog_error("can't create json null");
        return;
    }
    cJSON_AddItemToObject(dest, field.c_str(), jnull);
}

// Parses this kind of JSON and returns the array of strings : [str1, str2] here.
// ["str1", "str2"]
bool readStringArray(const cJSON * const array, std::vector<std::string>& out) {
    if (array == nullptr || cJSON_IsArray(array) == false) {
        return false;
    }
    const int arrayLength = cJSON_GetArraySize(array);
    for (int i = 0; i < arrayLength; ++i) {
        cJSON *arrayItem = cJSON_GetArrayItem(array, i);
        if (cJSON_IsString(arrayItem) == false) {
            out.clear();
            return false;
        }
        out.push_back(std::string(cJSON_GetStringValue(arrayItem)));
    }
    return true;
}

//// Parses this kind of JSON and returns the array of strings : [str1, str2] here.
//// { "field" : ["str1", "str2"] }
//bool readStringArrayField(const cJSON *const src,
//                                const std::string& field,
//                                std::vector<std::string>& value,
//                                bool canBeOmitted) {
//    if (cJSON_IsObject(src) == false) {
//        return false;
//    }
//
//    if (cJSON_HasObjectItem(src, field.c_str())) {
//        const cJSON *arrEntry = cJSON_GetObjectItem(src, field.c_str());
//        if (cJSON_IsArray(arrEntry)) {
//            const int size = cJSON_GetArraySize(arrEntry);
//            for (int i = 0; i < size; ++i) {
//                cJSON* idJSON = cJSON_GetArrayItem(arrEntry, i);
//                if (cJSON_IsString(idJSON)) {
//                    value.push_back(std::string(cJSON_GetStringValue(idJSON)));
//                } else {
//                    value.clear();
//                    return false;
//                }
//            }
//            return true;
//        }
//    } else if (canBeOmitted) {
//        // the field has been omitted, use empty value
//        value.clear();
//        return true;
//    }
//    return false;
//}

bool readMapStringString(const cJSON * const obj, std::unordered_map<std::string, std::string>& result) {
    if (obj == nullptr || cJSON_IsObject(obj) == false) {
        return false;
    }

    result.clear();

    cJSON *child = obj->child;
    // int tableIndex = 1;
    while (child != nullptr) {
        // key
        const char* key = child->string;
        if (cJSON_IsString(child) == false) {
            return false;
        }
        result[key] = child->valuestring;

        child = child->next;
    }

    return true;
}

} // namespace json

} // namespace vx

/*
 * Skybox fragment shader variant: cubemap
 */

// Cubemap
#define SKYBOX_VARIANT_CUBEMAP 1
#define SKYBOX_VARIANT_CUBEMAPLERP 0

// No multiple render target
#define SKYBOX_VARIANT_MRT_CLEAR 0
#define SKYBOX_VARIANT_MRT_CLEAR_LINEAR_DEPTH 0

#include "./fs_skybox_common.sh"

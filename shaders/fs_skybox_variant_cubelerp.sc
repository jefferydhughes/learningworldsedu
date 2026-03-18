/*
 * Skybox fragment shader variant: cubemap
 */

// Cubemaps lerp
#define SKYBOX_VARIANT_CUBEMAP 1
#define SKYBOX_VARIANT_CUBEMAPLERP 1

// No multiple render target
#define SKYBOX_VARIANT_MRT_CLEAR 0
#define SKYBOX_VARIANT_MRT_CLEAR_LINEAR_DEPTH 0

#include "./fs_skybox_common.sh"

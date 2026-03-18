/*
 * Skybox fragment shader variant: cubemap, clear MRT
 */

// Cubemaps lerp
#define SKYBOX_VARIANT_CUBEMAP 1
#define SKYBOX_VARIANT_CUBEMAPLERP 1

// Clear multiple render target buffer
#define SKYBOX_VARIANT_MRT_CLEAR 1
#define SKYBOX_VARIANT_MRT_CLEAR_LINEAR_DEPTH 1

#include "./fs_skybox_common.sh"

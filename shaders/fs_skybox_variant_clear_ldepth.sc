/*
 * Skybox fragment shader variant: clear MRT
 */

// No cubemap
#define SKYBOX_VARIANT_CUBEMAP 0
#define SKYBOX_VARIANT_CUBEMAPLERP 0

// Clear multiple render target buffer
#define SKYBOX_VARIANT_MRT_CLEAR 1
#define SKYBOX_VARIANT_MRT_CLEAR_LINEAR_DEPTH 1

#include "./fs_skybox_common.sh"

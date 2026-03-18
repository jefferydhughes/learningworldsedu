// -------------------------------------------------------------
//  Cubzh Core
//  quad.c
//  Created by Arthur Cormerais on May 3, 2023.
// -------------------------------------------------------------

#include "quad.h"

#include <stdlib.h>
#include <string.h>
#include <zlib.h>

#include "weakptr.h"
#include "config.h"

#define QUAD_FLAG_NONE 0
#define QUAD_FLAG_DOUBLESIDED 1
#define QUAD_FLAG_SHADOW 2
#define QUAD_FLAG_UNLIT 4
#define QUAD_FLAG_MASK 8
#define QUAD_FLAG_ALPHABLEND 16
#define QUAD_FLAG_VCOLOR 32
#define QUAD_FLAG_9SLICE 64
#define QUAD_FLAG_FILTERING 128

#define QUAD_DEFAULT_9SLICE_UV 0.5f
#define QUAD_DEFAULT_9SLICE_SCALE 1.0f
#define QUAD_DEFAULT_9SLICE_CORNER_WIDTH -1.0f

#define QUAD_DRAWMODES_FLAG_NONE 0
#define QUAD_DRAWMODES_FLAG_BLENDING_SHIFT 0
#define QUAD_DRAWMODES_FLAG_BLENDING_MASK 3 // 1st to 2nd bit
#define QUAD_DRAWMODES_FLAG_BILLBOARD_SHIFT 2
#define QUAD_DRAWMODES_FLAG_BILLBOARD_MASK 28 // 3rd to 5th bit

typedef struct {
    uint8_t blendingFactor; /* 1 byte */
    uint8_t flags;          /* 1 byte */

    char pad[3];
} QuadDrawmodes;

struct _Quad {
    Transform *transform;
    uint32_t *rgba;
    Weakptr *data;
    QuadDrawmodes *drawmodes;
    uint32_t size;          /* 4 bytes */
    uint32_t hash;          /* 4 bytes */
    float width, height;    /* 2x4 bytes */
    float anchorX, anchorY; /* 2x4 bytes */
    float tilingU, tilingV; /* 2x4 bytes */ // if 9-slice, used for UV
    float offsetU;          /* 2x4 bytes */ // if 9-slice, used for scale
    float offsetV;          /* 2x4 bytes */ // if 9-slice, used for corner width (-1 = automatic)
    float cutout;           /* 4 bytes */
    uint16_t layers;        /* 2 bytes */
    uint8_t flags;          /* 1 byte */
    uint8_t sortOrder;      /* 1 byte */
    
    // no padding
};

void _quad_toggle_flag(Quad *q, uint8_t flag, bool toggle) {
    if (toggle) {
        q->flags |= flag;
    } else {
        q->flags &= ~flag;
    }
}

bool _quad_get_flag(const Quad *q, uint8_t flag) {
    return (q->flags & flag) != 0;
}

void _quad_drawmode_toggle_flag(Quad *q, uint8_t flag, bool toggle) {
    if (toggle) {
        if (q->drawmodes == NULL) {
            quad_toggle_drawmodes(q, true);
        }
        q->drawmodes->flags |= flag;
    } else if (q->drawmodes != NULL) {
        q->drawmodes->flags &= ~flag;
    }
}

void _quad_void_free(void *o) {
    Quad *q = (Quad *)o;
    quad_free(q);
}

Quad *quad_new(void) {
    Quad *q = (Quad *)malloc(sizeof(Quad));
    q->transform = transform_new_with_ptr(QuadTransform, q, &_quad_void_free);
    q->data = NULL;
    q->drawmodes = NULL;
    q->size = 0;
    q->hash = 0;
    q->width = 1.0f;
    q->height = 1.0f;
    q->anchorX = 0.0f;
    q->anchorY = 0.0f;
    q->tilingU = 1.0f;
    q->tilingV = 1.0f;
    q->offsetU = 0.0f;
    q->offsetV = 0.0f;
    q->cutout = -1.0f;
    q->layers = CAMERA_LAYERS_DEFAULT;
    q->flags = QUAD_FLAG_DOUBLESIDED | QUAD_FLAG_FILTERING;
    q->sortOrder = 0;

    q->rgba = (uint32_t *)malloc(sizeof(uint32_t));
    *q->rgba = 0xffffffff;

    return q;
}

Quad *quad_new_copy(const Quad* q) {
    Quad *copy = quad_new();
    transform_copy(copy->transform, q->transform);
    quad_set_data(copy, q->data, q->size); // TODO: use registry (see lua_quad)
    if (q->drawmodes != NULL) {
        copy->drawmodes = (QuadDrawmodes*)malloc(sizeof(QuadDrawmodes));
        memcpy(copy->drawmodes, q->drawmodes, sizeof(QuadDrawmodes));
    }
    copy->width = q->width;
    copy->height = q->height;
    copy->anchorX = q->anchorX;
    copy->anchorY = q->anchorY;
    copy->tilingU = q->tilingU;
    copy->tilingV = q->tilingV;
    copy->offsetU = q->offsetU;
    copy->offsetV = q->offsetV;
    copy->cutout = q->cutout;
    copy->layers = q->layers;
    copy->flags = q->flags;
    copy->sortOrder = q->sortOrder;
    if (_quad_get_flag(q, QUAD_FLAG_VCOLOR)) {
        free(copy->rgba);
        copy->rgba = (uint32_t *)malloc(4 * sizeof(uint32_t));
        memcpy(copy->rgba, q->rgba, 4 * sizeof(uint32_t));
    } else {
        *copy->rgba = *q->rgba;
    }

    return copy;
}

void quad_release(Quad *q) {
    transform_release(q->transform);
}

void quad_free(Quad *q) {
    if (q->data != NULL) {
        weakptr_release(q->data);
    }
    free(q->drawmodes);
    free(q->rgba);
    free(q);
}

Transform *quad_get_transform(const Quad *q) {
    return q->transform;
}

void quad_set_data(Quad *q, Weakptr *data, uint32_t size) {
    if (q->data == data) {
        return;
    } else if (q->data != NULL) {
        weakptr_release(q->data);
    }
    const void *payload = weakptr_get(data);
    if (payload != NULL && size > 0) {
        weakptr_retain(data);
        q->data = data;
        q->size = size;
        q->hash = (uint32_t)crc32(0, payload, (uInt)q->size);
    } else {
        q->data = NULL;
        q->size = 0;
        q->hash = 0;
    }
}

void *quad_get_data(const Quad *q) {
    return weakptr_get(q->data);
}

uint32_t quad_get_data_size(const Quad *q) {
    return q->size;
}

uint32_t quad_get_data_hash(const Quad *q) {
    return q->hash;
}

void quad_toggle_drawmodes(Quad *q, bool toggle) {
    if (toggle && q->drawmodes == NULL) {
        q->drawmodes = (QuadDrawmodes*)malloc(sizeof(QuadDrawmodes));
        q->drawmodes->blendingFactor = QUAD_BLENDING_FACTOR_DEFAULT;
        q->drawmodes->flags = QUAD_DRAWMODES_FLAG_NONE;
    } else if (toggle == false && q->drawmodes != NULL) {
        free(q->drawmodes);
        q->drawmodes = NULL;
    }
}

bool quad_uses_drawmodes(const Quad *q) {
    return q->drawmodes != NULL;
}

void quad_check_and_clear_drawmodes(Quad *q) {
    if (q->drawmodes != NULL
        && q->drawmodes->flags == QUAD_DRAWMODES_FLAG_NONE) {

        free(q->drawmodes);
        q->drawmodes = NULL;
    }
}

void quad_set_width(Quad *q, float value) {
    q->width = value;
    quad_fit_collider_to_bounding_box(q);
    transform_set_physics_dirty(q->transform);
}

float quad_get_width(const Quad *q) {
    return q->width;
}

void quad_set_height(Quad *q, float value) {
    q->height = value;
    quad_fit_collider_to_bounding_box(q);
    transform_set_physics_dirty(q->transform);
}

float quad_get_height(const Quad *q) {
    return q->height;
}

void quad_set_anchor_x(Quad *q, float value) {
    q->anchorX = value;
    transform_set_physics_dirty(q->transform);
}

float quad_get_anchor_x(const Quad *q) {
    return q->anchorX;
}

void quad_set_anchor_y(Quad *q, float value) {
    q->anchorY = value;
    transform_set_physics_dirty(q->transform);
}

float quad_get_anchor_y(const Quad *q) {
    return q->anchorY;
}

void quad_set_tiling_u(Quad *q, float value) {
    if (_quad_get_flag(q, QUAD_FLAG_9SLICE) == false) {
        q->tilingU = value;
    }
}

float quad_get_tiling_u(const Quad *q) {
    return q->tilingU;
}

void quad_set_tiling_v(Quad *q, float value) {
    if (_quad_get_flag(q, QUAD_FLAG_9SLICE) == false) {
        q->tilingV = value;
    }
}

float quad_get_tiling_v(const Quad *q) {
    return q->tilingV;
}

void quad_set_offset_u(Quad *q, float value) {
    if (_quad_get_flag(q, QUAD_FLAG_9SLICE) == false) {
        q->offsetU = WRAP01(value);
    }
}

float quad_get_offset_u(const Quad *q) {
    return q->offsetU;
}

void quad_set_offset_v(Quad *q, float value) {
    if (_quad_get_flag(q, QUAD_FLAG_9SLICE) == false) {
        q->offsetV = WRAP01(value);
    }
}

float quad_get_offset_v(const Quad *q) {
    return q->offsetV;
}

void quad_set_cutout(Quad *q, float value) {
    q->cutout = value;
}

float quad_get_cutout(const Quad *q) {
    return q->cutout;
}

void quad_set_color(Quad *q, uint32_t color) {
    if (_quad_get_flag(q, QUAD_FLAG_VCOLOR)) {
        q->rgba[0] = q->rgba[1] = q->rgba[2] = q->rgba[3] = color;
    } else {
        *q->rgba = color;
    }
}

uint32_t quad_get_color(const Quad *q) {
    return *q->rgba;
}

void quad_set_vertex_color(Quad *q, uint32_t c, uint8_t idx) {
    if (idx > 3) {
        return;
    }
    if (_quad_get_flag(q, QUAD_FLAG_VCOLOR) == false) {
        const uint32_t color = *q->rgba;
        free(q->rgba);
        q->rgba = (uint32_t *)malloc(4 * sizeof(uint32_t));
        for (uint8_t i = 0; i < 3; ++i) {
            q->rgba[i] = color;
        }
        _quad_toggle_flag(q, QUAD_FLAG_VCOLOR, true);
    }
    q->rgba[idx] = c;
}

uint32_t quad_get_vertex_color(const Quad *q, uint8_t idx) {
    if (_quad_get_flag(q, QUAD_FLAG_VCOLOR) == false) {
        return q->rgba[0];
    } else {
        return idx <= 3 ? q->rgba[idx] : 0x00000000;
    }
}

bool quad_uses_vertex_colors(const Quad *q) {
    bool equals = true;
    for (uint8_t i = 1; i < 4; ++i) {
        equals &= q->rgba[i] == q->rgba[0];
    }
    return _quad_get_flag(q, QUAD_FLAG_VCOLOR) && equals == false;
}

void quad_set_layers(Quad *q, uint16_t value) {
    q->layers = value;
}

uint16_t quad_get_layers(const Quad *q) {
    return q->layers;
}

void quad_set_doublesided(Quad *q, bool toggle) {
    _quad_toggle_flag(q, QUAD_FLAG_DOUBLESIDED, toggle);
}

bool quad_is_doublesided(const Quad *q) {
    return _quad_get_flag(q, QUAD_FLAG_DOUBLESIDED);
}

void quad_set_shadow(Quad *q, bool toggle) {
    _quad_toggle_flag(q, QUAD_FLAG_SHADOW, toggle);
}

bool quad_has_shadow(const Quad *q) {
    return _quad_get_flag(q, QUAD_FLAG_SHADOW);
}

void quad_set_unlit(Quad *q, bool toggle) {
    _quad_toggle_flag(q, QUAD_FLAG_UNLIT, toggle);
}

bool quad_is_unlit(const Quad *q) {
    return _quad_get_flag(q, QUAD_FLAG_UNLIT);
}

void quad_set_mask(Quad *q, bool toggle) {
    _quad_toggle_flag(q, QUAD_FLAG_MASK, toggle);
}

bool quad_is_mask(const Quad *q) {
    return _quad_get_flag(q, QUAD_FLAG_MASK);
}

void quad_set_alpha_blending(Quad *q, bool toggle) {
    _quad_toggle_flag(q, QUAD_FLAG_ALPHABLEND, toggle);
}

bool quad_uses_alpha_blending(const Quad *q) {
    return _quad_get_flag(q, QUAD_FLAG_ALPHABLEND);
}

void quad_set_filtering(Quad *q, bool toggle) {
    _quad_toggle_flag(q, QUAD_FLAG_FILTERING, toggle);
}

bool quad_uses_filtering(const Quad *q) {
    return _quad_get_flag(q, QUAD_FLAG_FILTERING);
}

void quad_set_sort_order(Quad *q, uint8_t value) {
    q->sortOrder = value;
}

uint8_t quad_get_sort_order(const Quad *q) {
    return q->sortOrder;
}

void quad_set_9slice(Quad *q, bool toggle) {
    if (_quad_get_flag(q, QUAD_FLAG_9SLICE) == false && toggle) {
        q->tilingU = q->tilingV = QUAD_DEFAULT_9SLICE_UV;
        q->offsetU = QUAD_DEFAULT_9SLICE_SCALE;
        q->offsetV = QUAD_DEFAULT_9SLICE_CORNER_WIDTH;
    }
    _quad_toggle_flag(q, QUAD_FLAG_9SLICE, toggle);
}

bool quad_uses_9slice(const Quad *q) {
    return _quad_get_flag(q, QUAD_FLAG_9SLICE);
}

void quad_set_9slice_uv(Quad *q, float u, float v) {
    q->tilingU = u;
    q->tilingV = v;
    if (_quad_get_flag(q, QUAD_FLAG_9SLICE) == false) {
        q->offsetU = QUAD_DEFAULT_9SLICE_SCALE;
        q->offsetV = QUAD_DEFAULT_9SLICE_CORNER_WIDTH;
    }
    _quad_toggle_flag(q, QUAD_FLAG_9SLICE, true);
}

float quad_get_9slice_u(const Quad *q) {
    return _quad_get_flag(q, QUAD_FLAG_9SLICE) ? q->tilingU : QUAD_DEFAULT_9SLICE_UV;
}

float quad_get_9slice_v(const Quad *q) {
    return _quad_get_flag(q, QUAD_FLAG_9SLICE) ? q->tilingV : QUAD_DEFAULT_9SLICE_UV;
}

void quad_set_9slice_scale(Quad *q, float value) {
    q->offsetU = value;
    if (_quad_get_flag(q, QUAD_FLAG_9SLICE) == false) {
        q->tilingU = q->tilingV = QUAD_DEFAULT_9SLICE_UV;
        q->offsetV = QUAD_DEFAULT_9SLICE_CORNER_WIDTH;
    }
    _quad_toggle_flag(q, QUAD_FLAG_9SLICE, true);
}

float quad_get_9slice_scale(const Quad *q) {
    return _quad_get_flag(q, QUAD_FLAG_9SLICE) ? q->offsetU : QUAD_DEFAULT_9SLICE_SCALE;
}

void quad_set_9slice_corner_width(Quad *q, float value) {
    q->offsetV = value;
    if (_quad_get_flag(q, QUAD_FLAG_9SLICE) == false) {
        q->tilingU = q->tilingV = QUAD_DEFAULT_9SLICE_UV;
        q->offsetU = QUAD_DEFAULT_9SLICE_SCALE;
    }
    _quad_toggle_flag(q, QUAD_FLAG_9SLICE, true);
}

float quad_get_9slice_corner_width(const Quad *q) {
    return _quad_get_flag(q, QUAD_FLAG_9SLICE) ? q->offsetV : QUAD_DEFAULT_9SLICE_CORNER_WIDTH;
}

void quad_fit_collider_to_bounding_box(const Quad *q) {
    RigidBody *rb = transform_get_rigidbody(q->transform);
    if (rb == NULL || rigidbody_is_collider_custom_set(rb))
        return;
    Box bb = { { 0.0f, 0.0f, 0.0f }, { q->width, q->height, EPSILON_COLLISION } };
    rigidbody_set_collider(rb, &bb, false);
}

// MARK: - Draw modes -

void quad_drawmode_set_billboard(Quad *q, BillboardMode mode) {
    if (mode != BillboardMode_None) {
        if (q->drawmodes == NULL) {
            quad_toggle_drawmodes(q, true);
        }
        q->drawmodes->flags &= ~QUAD_DRAWMODES_FLAG_BILLBOARD_MASK;
        q->drawmodes->flags |= ((uint8_t)mode << QUAD_DRAWMODES_FLAG_BILLBOARD_SHIFT);
    } else if (q->drawmodes != NULL) {
        q->drawmodes->flags &= ~QUAD_DRAWMODES_FLAG_BILLBOARD_MASK;
    }
}

BillboardMode quad_drawmode_get_billboard(const Quad *q) {
    return q->drawmodes != NULL ? ((BillboardMode)((q->drawmodes->flags & QUAD_DRAWMODES_FLAG_BILLBOARD_MASK) >> QUAD_DRAWMODES_FLAG_BILLBOARD_SHIFT)) : BillboardMode_None;
}

void quad_drawmode_set_blending(Quad *q, BlendingMode mode) {
    if (mode != BlendingMode_Default) {
        if (q->drawmodes == NULL) {
            quad_toggle_drawmodes(q, true);
        }
        q->drawmodes->flags &= ~QUAD_DRAWMODES_FLAG_BLENDING_MASK;
        q->drawmodes->flags |= ((uint8_t)mode << QUAD_DRAWMODES_FLAG_BLENDING_SHIFT);
    } else if (q->drawmodes != NULL) {
        q->drawmodes->flags &= ~QUAD_DRAWMODES_FLAG_BLENDING_MASK;
    }
}

BlendingMode quad_drawmode_get_blending(const Quad *q) {
    return q->drawmodes != NULL ? ((BlendingMode)((q->drawmodes->flags & QUAD_DRAWMODES_FLAG_BLENDING_MASK) >> QUAD_DRAWMODES_FLAG_BLENDING_SHIFT)) : BlendingMode_Default;
}

void quad_drawmode_set_blending_factor(Quad *q, uint8_t value) {
    if (q->drawmodes == NULL) {
        quad_toggle_drawmodes(q, true);
    }
    q->drawmodes->blendingFactor = value;
}

uint8_t quad_drawmode_get_blending_factor(const Quad *q) {
    return q->drawmodes != NULL ? q->drawmodes->blendingFactor : QUAD_BLENDING_FACTOR_DEFAULT;
}

// MARK: - Utils -

float quad_utils_get_diagonal(const Quad *q) {
    return sqrtf(q->width * q->width + q->height * q->height);
}

bool quad_utils_get_visibility(const Quad *q, bool *isOpaque) {
    const bool transparentTex = q->size > 0 && _quad_get_flag(q, QUAD_FLAG_ALPHABLEND);
    const bool defaultBlending = quad_drawmode_get_blending(q) == BlendingMode_Default;
    if (_quad_get_flag(q, QUAD_FLAG_VCOLOR)) {
        const uint16_t alpha = (uint16_t)(q->rgba[0] >> 24) + (uint16_t)(q->rgba[1] >> 24) +
                               (uint16_t)(q->rgba[2] >> 24) + (uint16_t)(q->rgba[3] >> 24);
        *isOpaque = defaultBlending && transparentTex == false && alpha == 1020;
        return alpha > 0;
    } else {
        const uint8_t alpha = (uint8_t)(*q->rgba >> 24);
        *isOpaque = defaultBlending && transparentTex == false && alpha == 255;
        return alpha > 0;
    }
}

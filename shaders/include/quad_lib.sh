#ifndef __QUAD_LIB_SH__
#define __QUAD_LIB_SH__

#include "./config.sh"

void unpackQuadFullMetadata(float f, out float metadata[8]) {
	float unpack = f;
	float b = floor((unpack + UNPACK_FUDGE) / 65536.0);
	unpack -= b * 65536.0;
	float g = floor((unpack + UNPACK_FUDGE) / 4096.0);
	unpack -= g * 4096.0;
	float r = floor((unpack + UNPACK_FUDGE) / 256.0);
	unpack -= r * 256.0;
	float s = floor((unpack + UNPACK_FUDGE) / 16.0);
	unpack -= s * 16.0;
	float greyscale = floor((unpack + UNPACK_FUDGE) / 8.0);
	unpack -= greyscale * 8.0;
	float cutout = floor((unpack + UNPACK_FUDGE) / 4.0);
	unpack -= cutout * 4.0;
	float unpack9SliceNormal = floor((unpack + UNPACK_FUDGE) / 2.0);
	float unlit = unpack - unpack9SliceNormal * 2.0;

	metadata[0] = unlit;
	metadata[1] = unpack9SliceNormal;
	metadata[2] = cutout;
	metadata[3] = greyscale;
	if (unlit > 0.5) {
		metadata[4] = (s + r * 16.0);
		metadata[5] = 0.0;
		metadata[6] = 0.0;
		metadata[7] = 0.0;
	} else {
		metadata[4] = s / VOXEL_LIGHT_MAX;
		metadata[5] = r / VOXEL_LIGHT_MAX;
		metadata[6] = g / VOXEL_LIGHT_MAX;
		metadata[7] = b / VOXEL_LIGHT_MAX;
	}
}

vec2 unpackQuadMetadata_OIT(float f) {
	float unpack = f - floor((f + UNPACK_FUDGE) / 16.0);
	float greyscale = floor((unpack + UNPACK_FUDGE) / 8.0);
	unpack -= greyscale * 8.0;
	float cutout = floor((unpack + UNPACK_FUDGE) / 4.0);
	return vec2(cutout, greyscale);
}

float sliceUV(float uv, vec2 borders, float slice) {
	if (uv < borders[0]) {
		return uv / borders[0] * slice;
	} else if (uv > borders[1]) {
		return slice + (uv - borders[1]) / (1.0 - borders[1]) * (1.0 - slice);
	} else {
		return slice;
	}
}

#endif // __QUAD_LIB_SH__
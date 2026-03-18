$input v_color0, v_texcoord0
	#define v_dir v_color0
	#define v_uv v_texcoord0.xy
	#define v_pos v_texcoord0.zw

#include "./include/bgfx.sh"
#include "./include/config.sh"
#include "./include/game_uniforms.sh"
#include "./include/global_lighting_uniforms.sh"
#include "./include/dithering_lib.sh"

#if SKYBOX_VARIANT_CUBEMAPLERP
uniform vec4 u_params_fs;
	#define u_lerp u_params_fs.x
#endif

#if SKYBOX_VARIANT_CUBEMAP
SAMPLERCUBE(s_fb1, 0);
#endif
#if SKYBOX_VARIANT_CUBEMAPLERP
SAMPLERCUBE(s_fb2, 1);
#endif

void main() {
	vec3 dir = normalize(v_dir).xyz;

	vec3 color = mix(mix(u_horizonColor.xyz, u_abyssColor.xyz, abs(dir.y)),
		mix(u_horizonColor.xyz, u_skyColor.xyz, dir.y),
		step(0.0, dir.y));

#if SKYBOX_VARIANT_CUBEMAP
#if SKYBOX_VARIANT_CUBEMAPLERP
	color *= mix(textureCube(s_fb1, dir).xyz, textureCube(s_fb2, dir).xyz, u_lerp);
#else
	color *= textureCube(s_fb1, dir).xyz;
#endif
#endif // SKYBOX_VARIANT_CUBEMAP

#if SKYBOX_COLOURING_ENABLED
	color *= u_sunColor.xyz;
#endif

#if SKYBOX_DITHERING
	color = dither(v_pos, v_uv, color);
#endif

#if SKYBOX_VARIANT_MRT_CLEAR
	gl_FragData[0] = vec4(color, 1.0);
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, LIGHTING_UNLIT_FLAG);
	gl_FragData[2] = vec4_splat(0.0);
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, LIGHTING_UNLIT_FLAG);
#if SKYBOX_VARIANT_MRT_CLEAR_LINEAR_DEPTH
	gl_FragData[4] = vec4_splat(0.0);
#endif // SKYBOX_VARIANT_MRT_CLEAR_LINEAR_DEPTH
#else
	gl_FragColor = vec4(color, 1.0);
#endif // SKYBOX_VARIANT_MRT_CLEAR
}

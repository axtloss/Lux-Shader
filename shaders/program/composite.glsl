/* 
----------------------------------------------------------------
Lux Shader by https://github.com/TechDevOnGithub/
Based on BSL Shaders v7.1.05 by Capt Tatsu https://bitslablab.com 
See AGREEMENT.txt for more information.
----------------------------------------------------------------
*/ 

// Global Include
#include "/lib/global.glsl"

// Fragment Shader
#ifdef FSH

// Varyings
varying vec2 texCoord;

varying vec3 sunVec, upVec;

// Uniforms
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;

uniform float blindFactor;
uniform float far, near;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float timeAngle, timeBrightness;
uniform float viewWidth, viewHeight, aspectRatio;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;

#ifdef VOLUMETRIC_FOG
uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;
#endif

// Attributes

// Optifine Constants
const bool colortex5Clear = false;

// Common Variables
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility = clamp(dot(sunVec, upVec) + 0.05, 0.0, 0.1) * 10.0;
float moonVisibility = clamp(dot(sunVec, -upVec) + 0.05, 0.0, 0.1) * 10.0;

// Common Functions
float GetLinearDepth(float depth)
{
   	return (2.0 * near) / (far + near - depth * (far - near));
}

// Includes
#include "/lib/color/waterColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/atmospherics/waterFog.glsl"
#include "/lib/lighting/ambientOcclusion.glsl"
#include "/lib/color/dimensionColor.glsl"

#ifdef VOLUMETRIC_FOG
#include "/lib/atmospherics/volumetricLight.glsl"
#endif

#ifdef BLACK_OUTLINE
#include "/lib/color/skyColor.glsl"
#include "/lib/color/blocklightColor.glsl"
#include "/lib/atmospherics/fog.glsl"
#include "/lib/outline/blackOutline.glsl"
#endif

#if defined BORDER_FOG || defined PROMO_OUTLINE
#include "/lib/outline/promoOutline.glsl"
#include "/lib/atmospherics/sky.glsl"
#include "/lib/color/ambientColor.glsl"
#endif

// Program
void main()
{
    vec4 color = texture2D(colortex0, texCoord);
    vec3 translucent = texture2D(colortex1,texCoord).rgb;
	float z0 = texture2D(depthtex0, texCoord).r;
	float z1 = texture2D(depthtex1, texCoord).r;
	
	vec4 screenPos = vec4(texCoord.x, texCoord.y, z0, 1.0);
	vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
	viewPos /= viewPos.w;

	#if defined AO || defined VOLUMETRIC_FOG
	float dither = InterleavedGradientNoise(gl_FragCoord.xy);
	#endif

	#ifdef AO
    float lz0 = GetLinearDepth(z0) * far;
	if (z1 - z0 > 0.0 && lz0 < 32.0)
	{
		if (dot(translucent, translucent) < 0.02)
		{
            float ao = AmbientOcclusion(depthtex0, dither);
            float aoMix = clamp(0.03125 * lz0, 0.0 , 1.0);
            color.rgb *= mix(ao, 1.0, aoMix);
        }
	}
	#endif

	if (isEyeInWater == 1) 
	{
		vec3 a = exp2((vec3(0.6196, 0.9098, 1.0) - 1.0) * (4.0 + GetLinearDepth(z0) * 120.0));
		color.rgb *= a * (1.0 - rainStrength) + 1.0 * rainStrength;
	}

	#ifdef FOG
	if (isEyeInWater == 1.0)
	{
        vec4 screenPos = vec4(texCoord.x, texCoord.y, z0, 1.0);
		vec4 viewPos = gbufferProjectionInverse * (screenPos * 2.0 - 1.0);
		viewPos /= viewPos.w;

		WaterFog(color.rgb, viewPos.xyz, waterFog * (1.0 + 0.4 * eBS));
	}
	#endif

	#if defined BLACK_OUTLINE || defined PROMO_OUTLINE
	vec3 skyEnvAmbientApprox = GetAmbientColor(vec3(0, 1, 0), lightCol);
	#endif

	#ifdef BLACK_OUTLINE
	float outlineMask = BlackOutlineMask(depthtex0, depthtex1);
	float wFogMult = 1.0 + eBS;
	if (outlineMask > 0.5 || isEyeInWater > 0.5)
		BlackOutline(color.rgb, depthtex0, wFogMult, skyEnvAmbientApprox);
	#endif
	
	#ifdef PROMO_OUTLINE
	if (z1 - z0 > 0.0)
		PromoOutline(color.rgb, depthtex0);
	#endif
	
	
	#ifdef VOLUMETRIC_FOG
	vec3 vl = GetVolumetricLight(z0, z1, translucent, dither) + (dither - 0.5) / 255.0;
	#else
	vec3 vl = vec3(0.0);
    #endif
	
    /* DRAWBUFFERS:01 */
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(vl, 1.0);
	
    #ifdef REFLECTION_PREVIOUS
    /* DRAWBUFFERS:015 */
	gl_FragData[2] = vec4(pow(color.rgb, vec3(0.125)) * 0.5, float(z0 < 1.0));
	#endif
}

#endif

// Vertex Shader
#ifdef VSH

// Varyings
varying vec2 texCoord;

varying vec3 sunVec, upVec;

// Uniforms
uniform float timeAngle;

uniform mat4 gbufferModelView;

// Program
void main()
{
	texCoord = gl_MultiTexCoord0.xy;
	gl_Position = ftransform();

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngle - 0.25);
	ang = (ang + (cos(ang * PI) * -0.5 + 0.5 - ang) / 3.0) * TAU;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);
	upVec = normalize(gbufferModelView[1].xyz);
}

#endif

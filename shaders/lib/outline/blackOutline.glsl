/* 
----------------------------------------------------------------
Lux Shader by https://github.com/TechDevOnGithub/
Based on BSL Shaders v7.1.05 by Capt Tatsu https://bitslablab.com 
See AGREEMENT.txt for more information.
----------------------------------------------------------------
*/ 

#include "/lib/outline/blackOutlineOffset.glsl"

void BlackOutline(inout vec3 color, sampler2D depth, float wFogMult, vec3 ambientCol)
{
	float ph = 1.0 / 1080.0;
	float pw = ph / aspectRatio;

	float outline = 1.0;
	float z = GetLinearDepth(texture2D(depth, texCoord).r) * far * 2.0;
	float minZ = 1.0, sampleZA = 0.0, sampleZB = 0.0;

	for (int i = 0; i < 12; i++)
	{
		vec2 offset = vec2(pw, ph) * blackOutlineOffsets[i];
		sampleZA = texture2D(depth, texCoord + offset).r;
		sampleZB = texture2D(depth, texCoord - offset).r;
		float sampleZsum = GetLinearDepth(sampleZA) + GetLinearDepth(sampleZB);
		outline *= Saturate(1.0 - (z - sampleZsum * far));
		minZ = min(minZ, min(sampleZA, sampleZB));
	}
	
	vec4 viewPos = gbufferProjectionInverse * (vec4(texCoord.x, texCoord.y, minZ, 1.0) * 2.0 - 1.0);
	viewPos /= viewPos.w;

	vec3 fog = vec3(0.0);
	#ifdef FOG
	if (outline < 1.0)
	{
		Fog(fog, viewPos.xyz, ambientCol);
		
		if (isEyeInWater == 1.0)
			WaterFog(fog, viewPos.xyz, waterFog * wFogMult);
	}
	#endif

	color = mix(fog, color, outline);
}

float BlackOutlineMask(sampler2D depth0, sampler2D depth1)
{
	float ph = 1.0 / 1080.0;
	float pw = ph / aspectRatio;

	float mask = 0.0;
	for (int i = 0; i < 12; i++)
	{
		vec2 offset = vec2(pw, ph) * blackOutlineOffsets[i];
		mask += float(texture2D(depth0, texCoord + offset).r <
		              texture2D(depth1, texCoord + offset).r);
		mask += float(texture2D(depth0, texCoord - offset).r < 
		              texture2D(depth1, texCoord - offset).r);
	}

	return Saturate(mask);
}
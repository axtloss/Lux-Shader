/* 
----------------------------------------------------------------
Lux Shader by https://github.com/TechDevOnGithub/
Based on BSL Shaders v7.1.05 by Capt Tatsu https://bitslablab.com 
See AGREEMENT.txt for more information.
----------------------------------------------------------------
*/ 

#include "/lib/outline/blackOutlineOffset.glsl"

void DepthOutline(inout float z)
{
	float ph = 1.0 / 1080.0;
	float pw = ph / aspectRatio;
	
	for(int i = 0; i < 12; i++)
	{
		vec2 offset = vec2(pw, ph) * blackOutlineOffsets[i];
		z = min(z, texture2D(depthtex1, texCoord + offset).r);
		z = min(z, texture2D(depthtex1, texCoord - offset).r);
	}
}
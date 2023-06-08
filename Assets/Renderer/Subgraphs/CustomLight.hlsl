#ifndef CUSTOM_LIGHTING_INCLUDED
#define CUSTOM_LIGHTING_INCLUDED

#if defined(SHADERGRAPH_PREVIEW)
#else
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
#pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
#pragma multi_compile_fragment _ _SHADOWS_SOFT
#pragma multi_compile _ SHADOWS_SHADOWMASK
#pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
#pragma multi_compile _ LIGHTMAP_ON
#pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
#endif

void MainLight_float(float3 WorldPos, out float3 Direction, out float3 Color, out float ShadowAtten)
{
#if defined(SHADERGRAPH_PREVIEW)
    Direction = float3(0.5, 0.5, 0);
    Color = 1;
    ShadowAtten = 1;
#else
	float4 shadowCoord = TransformWorldToShadowCoord(WorldPos);

    Light mainLight = GetMainLight(shadowCoord);
    Direction = mainLight.direction;
    Color = mainLight.color;

	//#if !defined(_MAIN_LIGHT_SHADOWS) || defined(_RECEIVE_SHADOWS_OFF)
	//	ShadowAtten = 1.0h;
    //#else
	    ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
	    float shadowStrength = GetMainLightShadowStrength();
	    ShadowAtten = SampleShadowmap(shadowCoord, 
            TEXTURE2D_ARGS(_MainLightShadowmapTexture,sampler_MainLightShadowmapTexture),
	        shadowSamplingData, shadowStrength, false
        );

        ShadowAtten = mainLight.shadowAttenuation;

        //ShadowAtten = MainLightRealtimeShadow(TransformWorldToShadowCoord(WorldPos));
        // #if USE_FORWARD_PLUS
        // ShadowAtten = 0.0;//mainLight.shadowAttenuation;
        // #else
        // ShadowAtten = 1.0;
        // #endif
    //#endif
#endif 
//     float4 shadowCoord = TransformWorldToShadowCoord(WorldPos);
//     Light mainLight = GetMainLight(shadowCoord);
//     Direction = mainLight.direction;
//     Color = mainLight.color;

//     ShadowSamplingData shadowSamplingData = GetAdditionalLightShadowSamplingData();
 
//     half4 shadowParams = GetAdditionalLightShadowParams(0);
 
//     int shadowSliceIndex = shadowParams.w;
 
//     UNITY_BRANCH
//     if (shadowSliceIndex < 0)
//     {
//         ShadowAtten = 1.0;
//         return;
//     }
 
//     half isPointLight = shadowParams.z;
 
//     UNITY_BRANCH
//     if (isPointLight)
//     {
//         // This is a point light, we have to find out which shadow slice to sample from
//         float cubemapFaceId = CubeMapFaceID(-lightDirection);
//         shadowSliceIndex += cubemapFaceId;
//     }
 
// #if USE_STRUCTURED_BUFFER_FOR_LIGHT_DATA
//     float4 shadowCoord = mul(_AdditionalLightsWorldToShadow_SSBO[shadowSliceIndex], float4(WorldPos, 1.0));
// #else
//     float4 shadowCoord = mul(_AdditionalLightsWorldToShadow[shadowSliceIndex], float4(WorldPos, 1.0));
// #endif
 
//     ShadowAtten = SampleShadowmap(TEXTURE2D_ARGS(_AdditionalLightsShadowmapTexture, sampler_AdditionalLightsShadowmapTexture), shadowCoord, shadowSamplingData, shadowParams, true);
// #endif
}


void DirectSpecular_float(float Smoothness, float3 Direction, float3 WorldNormal, float3 WorldView, out float3 Out)
{
    float4 White = 1;

#if defined(SHADERGRAPH_PREVIEW)
    Out = 0;
#else
    Smoothness = exp2(10 * Smoothness + 1);
    WorldNormal = normalize(WorldNormal);
    WorldView = SafeNormalize(WorldView);
    Out = LightingSpecular(White, Direction, WorldNormal, WorldView, White, Smoothness);
#endif
}

void AdditionalLights_float(float Smoothness, float3 WorldPosition, float3 WorldNormal, float3 WorldView, out float3 Diffuse, out float3 Specular)
{
    float3 diffuseColor = 0;
    float3 specularColor = 0;
    float4 White = 1;

#if !defined(SHADERGRAPH_PREVIEW)
    Smoothness = exp2(10 * Smoothness + 1);
    WorldNormal = normalize(WorldNormal);
    WorldView = SafeNormalize(WorldView);
    int pixelLightCount = GetAdditionalLightsCount();
    for (int i = 0; i < pixelLightCount; ++i)
    {
        Light light = GetAdditionalLight(i, WorldPosition);
        half3 attenuatedLightColor = light.color * (light.distanceAttenuation * light.shadowAttenuation);
        diffuseColor += LightingLambert(attenuatedLightColor, light.direction, WorldNormal);
        specularColor += LightingSpecular(attenuatedLightColor, light.direction, WorldNormal, WorldView, White, Smoothness);
    }
#endif

    Diffuse = diffuseColor;
    Specular = specularColor;
}

#endif
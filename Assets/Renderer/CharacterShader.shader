Shader "Cel/CharacterShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }

//    HLSLINCLUDE
//    #include "UnityCG.cginc"
//    #include "AutoLight.cginc"
//    #include "Lighting.cginc"
//    ENDHLSL

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"
        } //"LightMode" = "ForwardBase"
        LOD 300

        Pass
        {
            Lighting On
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            //#pragma multi_compile_fwdbase

//             #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
// #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
// #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
// #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
// #pragma multi_compile_fragment _ _SHADOWS_SOFT
// #pragma multi_compile _ SHADOWS_SHADOWMASK
// #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
// #pragma multi_compile _ LIGHTMAP_ON
// #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Debug/Debugging3D.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl"

            struct VSIn {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };
            
            struct VSOut
            {
                float4 position_cs : SV_POSITION;
                float2 uv : TEXCOORD1;
                float3 position_ws : POSITION_WS;
               // LIGHTING_COORDS(3, 4)
            };

            VSOut vert(VSIn v)
            {
                VSOut o;
                 const float3 position_ws = TransformObjectToWorld(v.vertex.xyz);
				o.position_cs = TransformWorldToHClip(position_ws);
                o.uv = v.uv;
                o.position_ws = position_ws;
                //TRANSFER_VERTEX_TO_FRAGMENT(o);
                return o;
            }

            float4 frag(VSOut i) : COLOR
            {
                // float3 lightColor = _LightColor0.rgb;
                // float3 lightDir = _WorldSpaceLightPos0;
                // //float4 colorTex = tex2D(_MainTex, i.uv.xy * float2(25.0f));
                // float atten = LIGHT_ATTENUATION(i);
                // float3 N = float3(0.0f, 1.0f, 0.0f);
                // float NL = saturate(dot(N, lightDir));
                // float3 color = lightColor * NL * atten;

               // float4 shadowCoord = TransformWorldToShadowCoord(i.pos);
                //Light mainLight = GetMainLight(shadowCoord);

                const float4 shadow_coord = TransformWorldToShadowCoord(i.position_ws);
                Light light = GetMainLight(shadow_coord);

                float atten = SAMPLE_TEXTURE2D_SHADOW(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture, shadow_coord);
                atten = lerp(light.shadowAttenuation, 1, GetMainLightShadowFade(i.position_ws));
                
                return float4(float3(atten, atten, atten), 1.0);
            }
            ENDHLSL
 
        }
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM

            #pragma vertex shadow_vert
            #pragma fragment shadow_frag

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            float3 _LightDirection;

            struct Attributes
            {
                float4 position_os   : POSITION;
                float3 normal_os     : NORMAL;
                float2 uv     : TEXCOORD0;
            };

            struct Varyings
            {
                float2 uv           : TEXCOORD0;
                float4 position_cs   : SV_POSITION;
            };

            float4 get_shadow_position_h_clip(Attributes input)
            {
                const float3 position_ws = TransformObjectToWorld(input.position_os.xyz);
                const float3 normal_ws = TransformObjectToWorldNormal(input.normal_os);
                const float3 light_direction_ws = _LightDirection;
                float4 position_cs = TransformWorldToHClip(ApplyShadowBias(position_ws, normal_ws, light_direction_ws));

            #if UNITY_REVERSED_Z
                position_cs.z = min(position_cs.z, UNITY_NEAR_CLIP_VALUE);
            #else
                positionCS.z = max(position_cs.z, UNITY_NEAR_CLIP_VALUE);
            #endif

                return position_cs;
            }

            Varyings shadow_vert(const Attributes input)
            {
                Varyings output;

                output.uv = input.uv;
                output.position_cs = get_shadow_position_h_clip(input);
                return output;
            }

            half4 shadow_frag() : SV_TARGET
            {
                return 0;
            }
            
            ENDHLSL
        }
    }
}
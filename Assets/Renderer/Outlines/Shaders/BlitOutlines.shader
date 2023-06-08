Shader "Hidden/BlitOutlines"
{
    Properties
    {
        _OutlineScale("OutlineScale", Float) = 1
        _RobertsCrossMultiplier("RobertsCrossMultiplier", Float) = 100
        _DepthThreshold("DepthThreshold", Float) = 1.5
        _NormalThreshold("NormalThreshold", Float) = 0.2
        _SteepAngleThreshold("SteepAngleThreshold", Float) = 0.4
        _SteepAngleMultiplier("SteepAngleMultiplier", Float) = 10.5
        _OutlineColor("OutlineColor", Color) = (0, 0, 0, 1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            //            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                /*float4 positionHCS   : POSITION;
                float2 uv           : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID*/

                uint vertexID : SV_VertexID;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4  positionCS  : SV_POSITION;
                float2  uv          : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };


            #ifdef USE_FULL_PRECISION_BLIT_TEXTURE
                TEXTURE2D_X_FLOAT(_BlitTexture);
            #else
                TEXTURE2D_X(_BlitTexture);
            #endif
            SAMPLER(sampler_BlitTexture);

            float4 _BlitTexture_TexelSize;
            float4 _BlitTexture_ST;

            float4 _OutlineColor;

            float _OutlineScale;
            float _NormalThreshold;
            float _DepthThreshold;
            float _RobertsCrossMultiplier;

            float4 _SceneViewSpaceNormals_TexelSize;
            TEXTURE2D_X(_SceneViewSpaceNormals);
            SAMPLER(sampler_SceneViewSpaceNormals);
            
            TEXTURE2D_X(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            
            Varyings vert(Attributes input)
            {
                /*Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                // Note: The pass is setup with a mesh already in clip
                // space, that's why, it's enough to just output vertex
                // positions
                output.positionCS = float4(input.positionHCS.xyz, 1.0);

                #if UNITY_UV_STARTS_AT_TOP
                    output.positionCS.y *= -1;
                #endif

                output.uv = input.uv;
                return output;*/

                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                float4 pos = GetFullScreenTriangleVertexPosition(input.vertexID);
                float2 uv  = GetFullScreenTriangleTexCoord(input.vertexID);

                output.positionCS = pos;
                //output.uv   = DYNAMIC_SCALING_APPLY_SCALEBIAS(uv);
                output.uv = uv;

                return output;
            }

            inline half CheckSame (half2 centerNormal, half4 theSample)
            {
                // Difference in normals
                // do not bother decoding normals - there's no need here
                half2 _Sensitivity = _NormalThreshold;
                half2 diff = abs(centerNormal - theSample.xy) * _Sensitivity.y;
                half isSameNormal = 1 - step(0.1, (diff.x + diff.y) * _Sensitivity.y);
                // Difference in depth
                //float sampleDepth = DecodeFloatRG(theSample.zw);
                //float zdiff = abs(centerDepth-sampleDepth);
                // Scale the required threshold by the distance
                //half isSameDepth = 1 - step(0.09 * centerDepth, zdiff * _Sensitivity.x);
                
                // return:
                // 1 - if normals and depth are similar enough
                // 0 - otherwise
                return (isSameNormal);// * isSameDepth);
            }

            float dot_self(float3 x) {
                return dot(x, x);
            }


            half4 frag (Varyings i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                float4 color = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv);
                // float4 color = SAMPLE_TEXTURE2D_X(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, input.uv);

                float centerDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv);
                
                float2 offset = _SceneViewSpaceNormals_TexelSize.xy * _OutlineScale;
                
                // Retrieve the normals
                float3 centerNormal = SAMPLE_TEXTURE2D_X(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, i.uv);
                float3 leftNormal = SAMPLE_TEXTURE2D_X(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, i.uv + float2(-offset.x, 0.0));
                float3 rightNormal = SAMPLE_TEXTURE2D_X(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, i.uv + float2(offset.x, 0.0));
                float3 topNormal = SAMPLE_TEXTURE2D_X(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, i.uv + float2(0.0, -offset.y));
                float3 bottomNormal = SAMPLE_TEXTURE2D_X(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, i.uv + float2(0.0, offset.y));

                // Calculate the difference
                float diff = dot_self(centerNormal - leftNormal) + dot_self(centerNormal - rightNormal) + dot_self(centerNormal - topNormal) + dot_self(centerNormal - bottomNormal);

                
                float leftDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv + float2(-offset.x, 0.0));
                float rightDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv + float2(offset.x, 0.0));
                float topDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv + float2(0.0, -offset.y));
                float bottomDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv + float2(0.0, offset.y));

                // Calculate the depth difference
                float depthDiff = pow(centerDepth - leftDepth, 2.) + pow(centerDepth - rightDepth, 2.) + pow(centerDepth - topDepth, 2.) + pow(centerDepth - bottomDepth, 2.0);
                depthDiff = sqrt(depthDiff);

                // Apply a threshold
                float smooth = 0.2;
                float edge = smoothstep(_NormalThreshold-smooth, _NormalThreshold+smooth, diff * centerDepth * 100);
                float depthEdge = smoothstep(_DepthThreshold-smooth, _DepthThreshold+smooth, depthDiff * _RobertsCrossMultiplier);

                edge = max(edge, depthEdge);

                // Output the edge detection
               // return half4(edge, edge, edge, 1.0);//
               return lerp(color, color - half4(_OutlineColor, 1.0), edge);
                
                //return float4(color.rgb, 1.0); //* float4(0, _Intensity, 0, 1);
            }
            ENDHLSL
        }
    }
}

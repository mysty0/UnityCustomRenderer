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
            #pragma shader_feature ROBERTCROSS_NORMAL
            #pragma shader_feature ROBERTCROSS_DEPTH
            #pragma shader_feature NORMAL_DETECTION
            #pragma shader_feature DEPTH_DETECTION

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
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
           // SAMPLER(sampler_CameraDepthTexture);
           SamplerState sampler_linear_repeat;

            
            Varyings vert(Attributes input)
            {

                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                float4 pos = GetFullScreenTriangleVertexPosition(input.vertexID);
                float2 uv  = GetFullScreenTriangleTexCoord(input.vertexID);

                output.positionCS = pos;
                output.uv = uv;

                return output;
            }

            inline float dot_self(float3 x) {
                return dot(x, x);
            }

            #define SAMPLE_DEPTH_TEXTURE_BILINEAR(tex, samp, uv) tex.Sample(sampler_linear_repeat, uv).r
            #define edge_step(t, x) smoothstep(0., t, x)

            float4 frag (Varyings i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                float4 color = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv);
                // float4 color = SAMPLE_TEXTURE2D_X(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, input.uv);

                float centerDepth = SAMPLE_DEPTH_TEXTURE_BILINEAR(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv);
                
                float2 offset = _SceneViewSpaceNormals_TexelSize.xy * _OutlineScale;
                
#ifdef ROBERTCROSS_NORMAL
                // Retrieve the normals
                float3 centerNormal = SAMPLE_TEXTURE2D_X(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, i.uv);
                float3 leftNormal = SAMPLE_TEXTURE2D_X(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, i.uv + float2(-offset.x, 0.0));
                float3 rightNormal = SAMPLE_TEXTURE2D_X(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, i.uv + float2(offset.x, 0.0));
                float3 topNormal = SAMPLE_TEXTURE2D_X(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, i.uv + float2(0.0, -offset.y));
                float3 bottomNormal = SAMPLE_TEXTURE2D_X(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, i.uv + float2(0.0, offset.y));

                // Calculate the difference
                half normalDiff = dot_self(centerNormal - leftNormal) + dot_self(centerNormal - rightNormal) + dot_self(centerNormal - topNormal) + dot_self(centerNormal - bottomNormal);
                normalDiff *= (centerNormal.x > 0.99 + leftNormal.x > 0.99 + rightNormal.x > 0.99 + topNormal.x > 0.99 + bottomNormal.x > 0.99) > 0.0 ? 0.0 : 1.0;
#else
                float3 centerNormal = SAMPLE_TEXTURE2D_X(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, i.uv);
                float3 leftNormalX = SAMPLE_TEXTURE2D_X(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, i.uv + float2(-offset.x, 0.0));
                float3 rightNormalX = SAMPLE_TEXTURE2D_X(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, i.uv + float2(offset.x, 0.0));
                float3 topNormalY = SAMPLE_TEXTURE2D_X(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, i.uv + float2(0.0, -offset.y));
                float3 bottomNormalY = SAMPLE_TEXTURE2D_X(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, i.uv + float2(0.0, offset.y));

                float3 topLeftNormal = SAMPLE_TEXTURE2D_X(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, i.uv + float2(-offset.x, -offset.y));
                float3 topRightNormal = SAMPLE_TEXTURE2D_X(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, i.uv + float2(offset.x, -offset.y));
                float3 bottomLeftNormal = SAMPLE_TEXTURE2D_X(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, i.uv + float2(-offset.x, offset.y));
                float3 bottomRightNormal = SAMPLE_TEXTURE2D_X(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, i.uv + float2(offset.x, offset.y));

                // Sobel operator
                float3 normalGradientX = -topLeftNormal - 2.0 * leftNormalX - bottomLeftNormal + topRightNormal + 2.0 * rightNormalX + bottomRightNormal;
                float3 normalGradientY = -topLeftNormal - 2.0 * topNormalY - topRightNormal + bottomLeftNormal + 2.0 * bottomNormalY + bottomRightNormal;

                float mask = SAMPLE_TEXTURE2D_X(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, i.uv).a;

                // Magnitude of gradient
                half normalDiff = length(normalGradientX * normalGradientX + normalGradientY * normalGradientY);
                normalDiff *= 1.0 - (mask > 0.1 && mask < 0.5);
#endif

#ifdef ROBERTCROSS_DEPTH
                float leftDepth = SAMPLE_DEPTH_TEXTURE_BILINEAR(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv + float2(-offset.x, 0.0));
                float rightDepth = SAMPLE_DEPTH_TEXTURE_BILINEAR(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv + float2(offset.x, 0.0));
                float topDepth = SAMPLE_DEPTH_TEXTURE_BILINEAR(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv + float2(0.0, -offset.y));
                float bottomDepth = SAMPLE_DEPTH_TEXTURE_BILINEAR(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv + float2(0.0, offset.y));

                // Calculate the depth difference
                float depthDiff = pow(centerDepth - leftDepth, 2.) + pow(centerDepth - rightDepth, 2.) + pow(centerDepth - topDepth, 2.) + pow(centerDepth - bottomDepth, 2.0);
                depthDiff = sqrt(depthDiff);
#else
                float leftDepthX = SAMPLE_DEPTH_TEXTURE_BILINEAR(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv + float2(-offset.x, 0.0));
                float rightDepthX = SAMPLE_DEPTH_TEXTURE_BILINEAR(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv + float2(offset.x, 0.0));
                float topDepthY = SAMPLE_DEPTH_TEXTURE_BILINEAR(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv + float2(0.0, -offset.y));
                float bottomDepthY = SAMPLE_DEPTH_TEXTURE_BILINEAR(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv + float2(0.0, offset.y));

                float topLeftDepth = SAMPLE_DEPTH_TEXTURE_BILINEAR(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv + float2(-offset.x, -offset.y));
                float topRightDepth = SAMPLE_DEPTH_TEXTURE_BILINEAR(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv + float2(offset.x, -offset.y));
                float bottomLeftDepth = SAMPLE_DEPTH_TEXTURE_BILINEAR(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv + float2(-offset.x, offset.y));
                float bottomRightDepth = SAMPLE_DEPTH_TEXTURE_BILINEAR(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv + float2(offset.x, offset.y));

                // Sobel operator
                float depthGradientX = -topLeftDepth - 2.0 * leftDepthX - bottomLeftDepth + topRightDepth + 2.0 * rightDepthX + bottomRightDepth;
                float depthGradientY = -topLeftDepth - 2.0 * topDepthY - topRightDepth + bottomLeftDepth + 2.0 * bottomDepthY + bottomRightDepth;

                // Magnitude of gradient
                float depthDiff = sqrt(depthGradientX * depthGradientX + depthGradientY * depthGradientY);
#endif

                // Apply a threshold
#if defined(NORMAL_DETECTION) && defined(DEPTH_DETECTION)
                float edge = edge_step(_NormalThreshold, normalDiff * centerDepth * 100);
                float depthEdge = edge_step(_DepthThreshold, depthDiff * _RobertsCrossMultiplier);

                edge = max(edge, depthEdge);
#elif defined(NORMAL_DETECTION)
                float edge = edge_step(_NormalThreshold, normalDiff * centerDepth * 100);
#elif defined(DEPTH_DETECTION)
                float edge = edge_step(_DepthThreshold, depthDiff * _RobertsCrossMultiplier);
#else
                float edge = 1.;
#endif

                // Output the edge detection
               // return half4(edge, edge, edge, 1.0);//
               return float4(lerp(0., color - _OutlineColor, edge).rgb, edge);
                
                //return float4(color.rgb, 1.0); //* float4(0, _Intensity, 0, 1);
            }
            ENDHLSL
        }
    }
}

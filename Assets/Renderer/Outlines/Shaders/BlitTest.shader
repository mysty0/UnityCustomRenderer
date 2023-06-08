Shader "BlitTest"
{
        SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"}
        LOD 100
        ZWrite Off Cull Off
        ZTest always
        Pass
        {
            Name "ColorBlitPass"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
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

            #ifdef USE_FULL_PRECISION_BLIT_TEXTURE
            TEXTURE2D_X_FLOAT(_BlitTexture);
            #else
            TEXTURE2D_X(_BlitTexture);
            #endif
            SAMPLER(sampler_BlitTexture);


            TEXTURE2D_X(_SceneViewSpaceNormals);
            SAMPLER(sampler_SceneViewSpaceNormals);

            half4 frag (Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                //float4 color = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, input.uv);
                float4 color = SAMPLE_TEXTURE2D_X(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, input.uv);
                return float4(color.rgb, 1.0); //* float4(0, _Intensity, 0, 1);
            }
            ENDHLSL
        }
    }
}
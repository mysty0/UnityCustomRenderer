#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

struct Attributes
{
    uint vertexID : SV_VertexID;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4  pos  : SV_POSITION;
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

    output.pos = pos;
    output.uv = uv;

    return output;
}

#ifdef USE_FULL_PRECISION_BLIT_TEXTURE
TEXTURE2D_X_FLOAT(_BlitTexture);
#else
TEXTURE2D_X(_BlitTexture);
#endif

SAMPLER(sampler_BlitTexture);
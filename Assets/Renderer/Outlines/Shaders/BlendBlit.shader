Shader "Hidden/BlendBlit"
{

     Properties
    {
        _Color("_Color", Color) = (0, 0, 0, 1)
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "Assets/Renderer/BlitUtils.hlsl"

            TEXTURE2D_X(_SecondTex);
            SAMPLER(sampler_SecondTex);

            float4 _Color;

            float4 frag(Varyings i) : SV_Target
            {
                // sample the texture
                float4 col = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, i.uv);
                float4 second = SAMPLE_TEXTURE2D(_SecondTex, sampler_SecondTex, i.uv);

                return lerp(col, second, second.a);
            }
            ENDHLSL
        }
    }
}

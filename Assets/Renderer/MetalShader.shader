Shader "Unlit/MetalShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            float height(in float2 p, in float seed) {
                float2 uv = p;
                float res = 1.;
                for (int i = 0; i < 3; i++) {
                    res += cos(uv.y*12.345 - seed*2. + cos(res*6.234)*.2 + cos(uv.x*16.2345 + cos(uv.y*8.234)) ) + cos(uv.x*6.345);
                    uv = uv.yx;
                    uv.x += res * pow(2., -float(i)) * 0.1;
                }
                return res;
            }
            float2 normal(in float2 p, in float seed) {
                const float2 NE = float2(.1,0.);
                return normalize(float2( height(p+NE, seed)-height(p-NE, seed),
                                       height(p+NE.yx, seed)-height(p-NE.yx, seed) ));
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return fixed4(abs(normal(i.uv, 1.0).g), 0., 0., 1.0);
            }
            ENDCG
        }
    }
}

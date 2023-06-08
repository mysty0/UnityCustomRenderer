// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/BluredNormalsLit"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200
        
        Pass {
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            //#include "UnityCG.cginc"
            #include "HLSLSupport.cginc"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
            };

            struct Varyings
            {
                float2 uv           : TEXCOORD0;
                float4 uv_custom           : TEXCOORD1;
                half3 normalWS      : NORMAL;
                float4 positionWS : POSITION;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            float4 _BaseColor;

            sampler2D _BlurNormalsTexture;
            float4 _BlurNormalsTexture_TexelSize;

            Varyings vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                #if UNITY_UV_STARTS_AT_TOP
	            float scale = -1.0;
	            #else
	            float scale = 1.0;
	            #endif
                //output.positionWS = UnityObjectToClipPos(v.vertex);
                output.positionWS = mul(UNITY_MATRIX_MVP, input.positionOS);
                output.uv_custom.xy = (float2(output.positionWS.x, output.positionWS.y*scale) + output.positionWS.w) * 0.5;
	            output.uv_custom.zw = output.positionWS.zw;
                
                output.uv = input.uv;
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                /*output.tangentWS = TransformObjectToWorldDir(input.tangentOS.xyz);
                output.binormalWS = cross(output.normalWS, output.tangentWS) * input.tangentOS.w;*/
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
              //  input.uv_custom.xy = 1.0 * input.uv_custom.z + input.uv_custom.xy;
                half4 col = tex2Dproj (_BlurNormalsTexture, UNITY_PROJ_COORD(input.uv_custom));

                return col;
            }

            ENDHLSL
    
        }

        /*CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows// vertex:vert
        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        sampler2D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
        	float4 uv_custom;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        
        

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        void vert (inout appdata_full v, out Input o) {
          UNITY_INITIALIZE_OUTPUT(Input,o);
        	#if UNITY_UV_STARTS_AT_TOP
			float scale = -1.0;
			#else
			float scale = 1.0;
			#endif
            //o.uv_custom.xy = (float2(v.vertex.x, v.vertex.y*scale) + v.vertex.w) * 0.5;
            //o.uv_custom.zw = v.vertex.zw;
      }


        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            // Albedo comes from a texture tinted by color
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb;//float3(1., 1., 1.);//IN.uv_custom.xyz;//tex2Dproj (_BlurNormalsTexture, UNITY_PROJ_COORD(IN.uv_custom));//c.rgb;
            // Metallic and smoothness come from slider variables
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = 1.0;//c.a;
           // o.Normal = 
        }
        ENDCG*/
    }
    FallBack "Diffuse"
}

Shader "Hidden/BasicBlur" {
	Properties {
	}


	
	Subshader {
		Pass {
			ZTest Always Cull Off ZWrite Off
			Fog { Mode off }

			HLSLPROGRAM
			#pragma fragmentoption ARB_precision_hint_fastest
			#pragma vertex vert
			#pragma fragment frag

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			
			struct appdata
			{
				uint vertexID : SV_VertexID;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			struct v2f {
				float4 pos : POSITION;
				float2 uv : TEXCOORD0;

				float4 uv01 : TEXCOORD1;
				float4 uv23 : TEXCOORD2;
				float4 uv45 : TEXCOORD3;
			};
			
			float4 offsets;
			
			sampler2D _MainTex;
			
			v2f vert (appdata v) {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				float4 pos = GetFullScreenTriangleVertexPosition(v.vertexID);
				float2 uv  = GetFullScreenTriangleTexCoord(v.vertexID);

				o.pos = pos;
				o.uv.xy = uv.xy;

				o.uv01 =  uv.xyxy + offsets.xyxy * float4(1,1, -1,-1);
				o.uv23 =  uv.xyxy + offsets.xyxy * float4(1,1, -1,-1) * 2.0;
				o.uv45 =  uv.xyxy + offsets.xyxy * float4(1,1, -1,-1) * 3.0;

				return o;
			}

			#ifdef USE_FULL_PRECISION_BLIT_TEXTURE
				TEXTURE2D_X_FLOAT(_BlitTexture);
			#else
				TEXTURE2D_X(_BlitTexture);
			#endif
			SAMPLER(sampler_BlitTexture);
			
			float4 frag (v2f i) : COLOR {
				float4 color = float4 (0,0,0,0);

				color += 0.40 * SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv);
				color += 0.15 * SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv01.xy);
				color += 0.15 * SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv01.zw);
				color += 0.10 * SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv23.xy);
				color += 0.10 * SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv23.zw);
				color += 0.05 * SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv45.xy);
				color += 0.05 * SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, i.uv45.zw);
				
				return color;
			}
			ENDHLSL
		}
	}

	Fallback off


} // shader

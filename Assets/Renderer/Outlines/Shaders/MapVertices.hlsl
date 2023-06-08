#ifndef CEL_SHADING_INCLUDED
#define CEL_SHADING_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

void MapVertex_float(uint VertexPosition, out float3 Position, out float2 UV){
//UNITY_SETUP_INSTANCE_ID(input);
     //           UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
    
   Position = GetFullScreenTriangleVertexPosition(VertexPosition);
    UV  = GetFullScreenTriangleTexCoord(VertexPosition);
}

#endif
#ifndef CEL_SHADING_INCLUDED
#define CEL_SHADING_INCLUDED

void Specular_float(float3 Light, float3 Normal, float3 View, float SpecularIntensity, float Shininess, out float Specular){
    const float3 r = normalize(2 * dot(-Light, Normal) * Normal + Light);
    const float3 v = View;//normalize(mul(normalize(View), World));

    const float dotProduct = saturate(dot(r, v));//saturate(dot(r, v));
    Specular = SpecularIntensity * max(pow(dotProduct, Shininess), 0);
    Specular = saturate(Specular);
}

void DerivedNormal_float(float3 Position, out float3 Normal) {
    float3 posddx = ddx(Position);
    float3 posddy = ddy(Position);
    float3 derivedNormal = cross(normalize(posddx), normalize(posddy));
    Normal = normalize(derivedNormal);
}

#endif
//#ifndef CUSTOM_NOISE_INCLUDED
#define CUSTOM_NOISE_INCLUDED

float hash(float2 p) // replace this by something better
{
    p = 50.0 * frac(p * 0.3183099 + float2(0.71, 0.113));
    return -1.0 + 2.0 * frac(p.x * p.y * (p.x + p.y));
}

float noise(in float2 p)
{
    float2 i = floor(p);
    float2 f = frac(p);

    float2 u = f * f * (3.0 - 2.0 * f);

    return lerp(lerp(hash(i + float2(0.0, 0.0)),
                     hash(i + float2(1.0, 0.0)), u.x),
                lerp(hash(i + float2(0.0, 1.0)),
                     hash(i + float2(1.0, 1.0)), u.x), u.y);
}

const int octaves = 6;

float fbm1(in float2 _st) {
    float v = 0.0;
    float a = 0.5;
    float2 shift = float2(100.0, 100.0);
    // Rotate to reduce axial bias
    float2x2 rot = float2x2(cos(0.5), sin(0.5),
                    -sin(0.5), cos(0.50));
    float2 st = _st.xy;
    for (int i = 0; i < octaves; ++i) {
        v += noise(st) * a;
        st = mul(rot, st) * 2.0 + shift;
        a *= 0.4;
    }
    return v;
}
  
float pattern(float2 uv, float time, out float2 q, out float2 r) {
    q = float2( fbm1( uv * .1 + float2(0.0,0.0) ),
                   fbm1( uv + float2(5.2,1.3) ) );

    r = float2( fbm1( uv * .1 + 4.0*q + float2(1.7 - time / 2.,9.2) ),
                   fbm1( uv + 4.0*q + float2(8.3 - time / 2.,2.8) ) );

    float2 s = float2( fbm1( uv + 5.0*r + float2(21.7 - time / 2.,90.2) ),
                   fbm1( uv * .05 + 5.0*r + float2(80.3 - time / 2.,20.8) ) ) * .25;

    return fbm1( uv * .05 + 4.0 * s );
}

float random(float x) {
 
    return frac(sin(x) * 10000.);
          
}

float noisePerlin(float2 p) {

    return random(p.x + p.y * 10000.);
            
}

float2 sw(float2 p) { return float2(floor(p.x), floor(p.y)); }
float2 se(float2 p) { return float2(ceil(p.x), floor(p.y)); }
float2 nw(float2 p) { return float2(floor(p.x), ceil(p.y)); }
float2 ne(float2 p) { return float2(ceil(p.x), ceil(p.y)); }

float smoothNoise(float2 p) {

    float2 interp = smoothstep(0., 1., frac(p));
    float s = lerp(noisePerlin(sw(p)), noisePerlin(se(p)), interp.x);
    float n = lerp(noisePerlin(nw(p)), noisePerlin(ne(p)), interp.x);
    return lerp(s, n, interp.y);
        
}

float fractalNoise(float2 p) {

    float x = 0.;
    x += smoothNoise(p      );
    x += smoothNoise(p * 2. ) / 2.;
    x += smoothNoise(p * 4. ) / 4.;
    x += smoothNoise(p * 8. ) / 8.;
    x += smoothNoise(p * 16.) / 16.;
    x /= 1. + 1./2. + 1./4. + 1./8. + 1./16.;
    return x;
            
}

float movingNoise(float2 p, float time) {
    float x = fractalNoise(p + time);
    float y = fractalNoise(p - time);
    return fractalNoise(p + float2(x, y));   
}

// call this for water noise function
float nestedNoise(float2 p, float time) {
    float x = movingNoise(p, time);
    float y = movingNoise(p + 100., time);
    return movingNoise(p + float2(x, y), time);
    
}


//
// Water Color
// https://www.shadertoy.com/view/lt2BRm

#define _PerlinPrecision 8.0
#define _PerlinOctaves 8.0
#define _PerlinSeed 0.0

float rnd(float2 xy)
{
    return frac(sin(dot(xy, float2(12.9898-_PerlinSeed, 78.233+_PerlinSeed)))* (43758.5453+_PerlinSeed));
}
float inter(float a, float b, float x)
{
    //return a*(1.0-x) + b*x; // Linear interpolation

    float f = (1.0 - cos(x * 3.1415927)) * 0.5; // Cosine interpolation
    return a*(1.0-f) + b*f;
}
float perlin(float2 uv)
{
    float a,b,c,d, coef1,coef2, t, p;

    t = _PerlinPrecision;					// Precision
    p = 0.0;								// Final heightmap value

    for(float i=0.0; i<_PerlinOctaves; i++)
    {
        a = rnd(float2(floor(t*uv.x)/t, floor(t*uv.y)/t));	//	a----b
        b = rnd(float2(ceil(t*uv.x)/t, floor(t*uv.y)/t));		//	|    |
        c = rnd(float2(floor(t*uv.x)/t, ceil(t*uv.y)/t));		//	c----d
        d = rnd(float2(ceil(t*uv.x)/t, ceil(t*uv.y)/t));

        if((ceil(t*uv.x)/t) == 1.0)
        {
            b = rnd(float2(0.0, floor(t*uv.y)/t));
            d = rnd(float2(0.0, ceil(t*uv.y)/t));
        }

        coef1 = frac(t*uv.x);
        coef2 = frac(t*uv.y);
        p += inter(inter(a,b,coef1), inter(c,d,coef1), coef2) * (1.0/pow(2.0,(i+0.6)));
        t *= 2.0;
    }
    return p;
}

// Sinusoidal warp.
// https://www.shadertoy.com/view/Ml2XDV
float2 W(float2 p, float t){
    // Planar sine distortion.
    for (int i=0; i<3; i++)
        p += cos(p.yx*3. + float2(t, 1.57))/3.,
        p += cos(p.yx + float2(0, -1.57) + t)/2.,
        p *= 1.3;
    
    // Sparkle. Not really needed, but I like it.
    p += frac(sin(dot(p, float2(41, 289)))*5e5)*.02 - .01;
    
    // Domain repetition.
    return fmod(p, 2.)-1.;
}


float m_height(in float2 p, in float seed) {
    float2 uv = p;
    float res = 1.;
    for (int i = 0; i < 3; i++) {
        res += cos(uv.y*12.345 - seed*2. + cos(res*6.234)*.2 + cos(uv.x*16.2345 + cos(uv.y*8.234)) ) + cos(uv.x*6.345);
        uv = uv.yx;
        uv.x += res * pow(2., -float(i)) * 0.1;
    }
    return res;
}

float2 m_normal(in float2 p, in float seed) {
    const float2 NE = float2(.1,0.);
    return normalize(float2( m_height(p+NE, seed)-m_height(p-NE, seed),
                           m_height(p+NE.yx, seed)-m_height(p-NE.yx, seed) ));
}

void Hash_float(float2 UV, out float Hash) {
    Hash = hash(UV);
}

void MetalNoise_float(float2 UV, float Seed, out float2 Noise) {
    Noise = m_normal(UV, Seed);
}

void ValueNoise_float(float2 UV, out float Noise) {
    Noise = noise(UV);
}

void WrappedNoise_float(float2 UV, float Time, out float2 Q, out float2 R, out float Noise) {
    Noise = pattern(UV, Time, Q, R);
}

void NestedPerlinNoise_float(float2 UV, float Time, out float Noise) {
    Noise = nestedNoise(UV, Time);
}

//11.75
void WaterColorPerlin_float(float2 UV, float Seed, float LayersCount, out float Noise) {
    float r = 0.15;//length(p);
    float seed = Seed;
    
    float noise_scale = 0.15+0.075*fmod(seed, 3.);
    float num_layers = 3.+2.*fmod(seed, 5.);
    seed *= num_layers;
    
    float v = 0.;
    
    for (float i = 0.; i < LayersCount; i++) {
        float h = noise_scale*perlin(UV+(i+seed))+r;
        if (h < 0.4) { v += 1./num_layers; }
    }

    Noise = v;
}

void SinusoidalWarp_float(float2 UV, float Seed, out float2 Noise)
{
    Noise = W(UV, Seed);
}


//#endif

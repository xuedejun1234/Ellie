#ifndef HAIR_SHADING_INCLUDED
#define HAIR_SHADING_INCLUDED
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
real Pow2(real x)
{
    return (x * x);
}

real Pow5(real x)
{
    return (x * x * x * x * x);
}

//--------------------漫反射项计算--------------------
half3 KajiyaKayDiffuseAttenuation(float3 BaseColor, half atten, float3 L, float3 V, half3 B)
{
    // Use soft Kajiya Kay diffuse attenuation
    float KajiyaDiffuse = 1 - abs(dot(B, L));

    float3 FakeNormal = normalize(V - B * dot(V, B));
    B = FakeNormal;

    // Hack approximation for multiple scattering.
    float Wrap = 1;
    float BdotL = saturate((dot(B, L) + Wrap) / Pow2(1 + Wrap));
    float DiffuseScatter = (1 / PI) * lerp(BdotL, KajiyaDiffuse, 0.33);
    float Luma = Luminance(BaseColor);
    float3 ScatterTint = pow(BaseColor / Luma, 1 - (atten + 1) * 0.5);
    return sqrt(BaseColor) * DiffuseScatter * ScatterTint;
}

half3 DiffuseCal(Light Light, half atten, float3 BaseColor, float3 L, float3 V, half3 B)
{
    half3 kkDiffuseAtten =  max(KajiyaKayDiffuseAttenuation(BaseColor, atten, L, V, B), 0.0);
    half3 lightColor = Light.color * PI;
    return kkDiffuseAtten * lightColor;
}

struct HairTempData
{
    float Alpha[3];// R、TT、TRT 的偏移参数
    float B[3]; // R、TT、TRT 的粗糙度宽度
    
    float VdotL;
    float SinThetaL;
    float SinThetaV;
    float CosThetaD;
    float CosPhi;
    float CosHalfPhi;
    float n_prime;
};


float Hair_g(float sigma, float theta)
{
    sigma = max(sigma, 1e-4); // 防止宽度为 0
    return exp(-0.5 * theta * theta / (sigma * sigma))
         / (2.50662827 * sigma); // sqrt(2 * PI)
}

float Hair_F(float cosTheta)
{
    const float ior = 1.55;
    float f0 = ((1.0 - ior) / (1.0 + ior)) *
               ((1.0 - ior) / (1.0 + ior));

    float x = 1.0 - saturate(cosTheta);
    float x2 = x * x;
    float x5 = x2 * x2 * x;

    return f0 + (1.0 - f0) * x5;
}



half3 R_Function(HairTempData HairTemp, float Specular)
{
    const float sa = sin(HairTemp.Alpha[0]);
    const float ca = cos(HairTemp.Alpha[0]);
    float Shift = 2 * sa * (ca * HairTemp.CosHalfPhi * sqrt(1 - pow(HairTemp.SinThetaV, 2)) + sa * HairTemp.SinThetaV);
    
    float Mp = Hair_g(HairTemp.B[0] * sqrt(2.0) * HairTemp.CosHalfPhi, HairTemp.SinThetaL + HairTemp.SinThetaV - Shift);
    float Np = 0.25 * HairTemp.CosHalfPhi;
    float Fp = Hair_F(sqrt(saturate(0.5 + 0.5 * HairTemp.VdotL)));
    return Mp * Np * Fp * Specular * 2;
}

half3 TT_Function(HairTempData HairTemp, float3 BaseColor)
{
    float a = 1 / HairTemp.n_prime;
    float h = HairTemp.CosHalfPhi * (1 + a * (0.6 - 0.8 * HairTemp.CosPhi));
    float3 Tp = pow(BaseColor, 0.5 * sqrt(1 - Pow2(h * a)) / HairTemp.CosThetaD);
    
    float f = Hair_F(HairTemp.CosThetaD * sqrt(saturate(1 - h * h)));
    float Fp = Pow2(1 - f);
    
    float Mp = Hair_g( HairTemp.B[1], HairTemp.SinThetaL + HairTemp.SinThetaV - HairTemp.Alpha[1] );
    float Np = exp(-3.65 * HairTemp.CosPhi - 3.98);
    return Mp * Np * Fp * Tp;
}

half3 TRT_Function(HairTempData HairTemp, float3 BaseColor)
{
    float Mp = Hair_g(HairTemp.B[2], HairTemp.SinThetaL + HairTemp.SinThetaV - HairTemp.Alpha[2]);

    float f = Hair_F(HairTemp.CosThetaD * 0.5);
    float Fp = Pow2(1 - f) * f;

    float3 Tp = pow(BaseColor, 0.8 / HairTemp.CosThetaD);

    float Np = exp(17 * HairTemp.CosPhi - 16.78);
    return Mp * Np * Fp * Tp;
}

half3 SpecularCal(HairTempData HairTemp, Light Light, half3 BaseColor, float Specular)
{
    //乘3和0.5操作是我自己增加的，源码中并没有
    half3 R = R_Function(HairTemp, Specular) * 3;
    half3 TT = TT_Function(HairTemp, BaseColor) * 0.5;
    half3 TRT = TRT_Function(HairTemp, BaseColor) * 3;
    return (R + TT + TRT) * Light.color * PI;
    
}


void HairBaseDataCal(out HairTempData HairTemp, float3 B, float3 V, float3 L, float roughness)
{
    const float Shift = 0.035;
    HairTemp.Alpha[0] = -Shift * 2;//R_shift
    HairTemp.Alpha[1] = Shift;//TT_shift
    HairTemp.Alpha[2] = Shift * 4;//TRT_shift
    
    float ClampedRoughness = clamp(roughness, 1 / 255.0f, 1.0f);
    HairTemp.B[0] = pow(ClampedRoughness,2);//R_roughness
    HairTemp.B[1] = pow(ClampedRoughness,2) / 2;//TT_roughness
    HairTemp.B[2] = pow(ClampedRoughness,2) * 2;//TRT_roughness

    //N是指向发根的方向
    HairTemp.VdotL     = saturate(dot(V,L));                                                      
    HairTemp.SinThetaL = clamp(dot(B,L), -1.f, 1.f);
    HairTemp.SinThetaV = clamp(dot(B,V), -1.f, 1.f);
    HairTemp.CosThetaD = cos(0.5 * abs(FastASin(HairTemp.SinThetaV) - FastASin(HairTemp.SinThetaL)));

    const float3 Lp = L - HairTemp.SinThetaL * B;
    const float3 Vp = V - HairTemp.SinThetaV * B;
    HairTemp.CosPhi = dot(Lp, Vp) * rsqrt(dot(Lp, Lp) * dot(Vp, Vp) + 1e-4) ;
    HairTemp.CosHalfPhi = sqrt(saturate(0.5 + 0.5 * HairTemp.CosPhi));

    HairTemp.n_prime = 1.19 / HairTemp.CosThetaD + 0.36 * HairTemp.CosThetaD;
}


#endif
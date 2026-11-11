Shader "Unlit/denimShirt"
{
    Properties
    {
        _Albedo("Albedo",2D) = "white"{}
        _NormalMap("NormalMap",2D) = "white"{}
        _AO("AO", 2D) = "white"{}
        _DetailNormalMap("_DetailNormalMap", 2D) = "bump"{}
        _FabricCharlieLUT("Fabric Charlie LUT", 2D) = "white" {}
        _Fabric("_Fabric", 2D) = "white"{}
        
        
        _Roughness("Roughness", Float) = 0.5
        _SpecularInstensity("_SpecularInstensity", Float) = 1
        _RoughnessDiff("RoughnessDiff", Float) = 0.5
        _IndirDiffuseIntensity("IndirDiffuseIntensity", Float) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        ZWrite On
        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"  
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"  
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            
            //常量区
            CBUFFER_START(UnityPerMaterial)
            half _Roughness;
            half _SpecularInstensity;
            half _RoughnessDiff;
            half _IndirDiffuseIntensity;
            float4 _Fabric_ST;
            
            CBUFFER_END
            static const half3 F0 = half3(0.04, 0.04, 0.04);
            
            TEXTURE2D(_Albedo);
            SAMPLER(sampler_Albedo);
            
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
            
            TEXTURE2D(_AO);
            SAMPLER(sampler_AO);
            
            TEXTURE2D(_DetailNormalMap);
            SAMPLER(sampler_DetailNormalMap);
            
            TEXTURE2D(_FabricCharlieLUT);
            SAMPLER(sampler_FabricCharlieLUT);
            
             TEXTURE2D(_Fabric);
            SAMPLER(sampler_Fabric);
            
            struct appdata
            {
               half4 vertex : POSITION;
               half2 uv : TEXCOORD0;
               half3 normalOS : NORMAL;
               half4 tangentOS : TANGENT;
            };

            struct v2f
            {
               half2 uv : TEXCOORD0;
               half4 positionCS : SV_POSITION;
               half3 positionWS : TEXCOORD1;
               half3 normalWS : TEXCOORD2;
               half3 tangentWS : TEXCOORD3;
               half3 bitangentWS : TEXCOORD4;
            };

            struct clothOutPut
            {
               half3 Color;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(v.vertex.xyz);
                o.positionWS = TransformObjectToWorld(v.vertex.xyz);
                VertexNormalInputs n = GetVertexNormalInputs(v.normalOS, v.tangentOS);
                o.normalWS = normalize(n.normalWS);
                o.tangentWS = normalize(n.tangentWS);
                o.bitangentWS = normalize(n.bitangentWS);
                o.uv = v.uv;
                return o;
            }
            //AshikhminD的反射模型 高光
           half AshikhminD(half roughness,half ndoth) 
            { 
               half m2  = max(roughness * roughness, 1e-4);
               half cos2h = saturate(ndoth);
                cos2h *= cos2h;
               half sin2h = max(1.0 - cos2h, 1e-5);
               half sin4h = sin2h * sin2h; 
                return (sin4h + 4. * exp(-cos2h / (sin2h * m2))) / (PI * (1.0 + 4.0 * m2) * sin4h); 
            }   
           half AshikhminV(half ndotv,half ndotl)
            {
                return 1.0 / (4.0 * max(ndotl + ndotv - ndotl * ndotv, 1e-4));
            }   
           //间接光高光
            float4 PreIntegratedFGD (float NV, float roughness, float3 specCol)
            {
                float2 uv = 0.99 * float2(sqrt(saturate(NV)), saturate(roughness));
                float3 fgd = SAMPLE_TEXTURE2D(_FabricCharlieLUT, sampler_FabricCharlieLUT, uv).rgb;

                return float4(lerp(fgd.xxx, fgd.yyy, specCol) * 2.0 * PI, fgd.z);
            }
 
            
            
            
            
            clothOutPut Cloth( v2f i)
            {
                clothOutPut o;
               half4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
               half3 viewDir = normalize(GetCameraPositionWS() - i.positionWS); //可能不顺滑
                half3 DetailnormalTS =  UnpackNormal(SAMPLE_TEXTURE2D(_DetailNormalMap, sampler_DetailNormalMap, i.uv));
               half3 BlentnormalTS =  UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv));
                //Fabric
                half2 detailUV = TRANSFORM_TEX(i.uv, _Fabric);
                float4 packed = SAMPLE_TEXTURE2D(_Fabric, sampler_Fabric, detailUV);
                float2 detailXY = packed.rg * 2.0 - 1.0;
                float3 FabricNormalTS = float3(detailXY,sqrt(saturate(1.0 - dot(detailXY, detailXY))));
                half3 MnormalTS = BlendNormal(DetailnormalTS, BlentnormalTS);//N
                half3 normalTS = BlendNormal(MnormalTS, FabricNormalTS);
               half3 T = normalize(i.tangentWS);
               half3 B = normalize(i.bitangentWS);
               half3 N = normalize(i.normalWS);
               half3 normalWS = normalize(T * normalTS.x + B * normalTS.y + N * normalTS.z);
                
                
                
               half3 L = normalize(mainLight.direction);
               half3 baseColor = SAMPLE_TEXTURE2D(_Albedo, sampler_Albedo, i.uv);
               half3 H = normalize(viewDir + mainLight.direction);
               half NdotL = saturate(dot(L , normalWS));//NdotL
               half VdotH = saturate(dot(viewDir, H));//VdotH
               half NdotH = saturate(dot(normalWS, H));
               half NdotV = saturate(dot(normalWS, viewDir));
                half LdotH = saturate(dot(L, H));
               half ao = SAMPLE_TEXTURE2D(_AO, sampler_AO, i.uv);
               half attenuation = mainLight.distanceAttenuation * mainLight.shadowAttenuation * ao;//头的阴影太粗糙了
               // half3 diffColor = baseColor * attenuation * NdotL * mainLight.color; lambert
                half diffColorBRDF = DisneyDiffuse(NdotV, NdotL, LdotH, saturate(_RoughnessDiff));//DisneyDiffuse
                // half diffColorBRDF = FabricLambertNoPI(_RoughnessDiff);
                half diffColor = baseColor * diffColorBRDF * NdotL * mainLight.color;
                //BRDF
                
               
               // half D = AshikhminD(_Roughness, NdotH);
               // half V = AshikhminV(NdotV, NdotL);
               // half3 specular = mainLight.color * F * D * V * PI * NdotL * attenuation * _SpecularInstensity;//高光不明显
                //Charlie 直接高光
                float r = max(saturate(_Roughness), 0.05);
                half3 specular = 0;
                if (NdotL > 0.0 && NdotV > 0.0)
                {
                    half3 F = F0 + (1.0 - F0) * pow(1.0 - VdotH, 5.0);
                    half D = D_Charlie(NdotH, r);
                    half V = V_Charlie(NdotL, NdotV, r);
                    specular = mainLight.color * F * D * V * NdotL * attenuation * _SpecularInstensity;
                }
                //
                half3 reflectionDir = reflect(-viewDir, normalWS);
                half3 envir = GlossyEnvironmentReflection(reflectionDir, i.positionWS, saturate(_Roughness),ao);
                half4 fgd =PreIntegratedFGD(NdotV, _Roughness, F0);
                half3 indirSpecular = envir * fgd.rgb;
                //
                half diffuseFGD = fgd.a; 
                half3 indirectDffuse = SampleSH(normalWS)* baseColor * diffuseFGD * ao * _IndirDiffuseIntensity;
                
                
                o.Color =diffColor + specular + indirSpecular + indirectDffuse;


                return o;
            }
            
            
            
            
            
            
        ENDHLSL

        Pass
        {
            Tags {"LightMode" = "UniversalForward"}
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag


            

           half4 frag (v2f i) : SV_Target
            {
                clothOutPut o = Cloth(i);
               
                return half4(o.Color, 1);
            }
            ENDHLSL
        }
    }
}

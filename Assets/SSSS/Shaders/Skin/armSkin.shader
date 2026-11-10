Shader "Unlit/armSkin"
{
    Properties
    {
        //贴图
        _AlbedoMap("AlbedoMap", 2D) = "white" {}
        _NormalMap("NormalMap", 2D) = "bump" {}
        _NormalDetailMap("NormalDetailMap", 2D) = "bump" {}

        _ThicknessMap("ThicknessMap", 2D) = "white" {}
        _LUT("LUT", 2D) = "bump" {}
        _CurvatureMap("CurvatureMap", 2D) = "white" {}
        _Cavity("Cavity", 2D) = "white" {}
        _AO("AO", 2D) = "white" {}
        _TransCol("TransCol", Color) = (1, 1, 1, 1)
        _KeleLUT("KeleLUT", 2D) = "white" {}
        _Roughness("Roughness", 2D) = "white" {}
        
        _NormalScale("NormalScale", Float) = 1
        _NormalDetailScale("NormalDetailScale", Float) = 1
        _ThicknessScale("ThicknessScale", Float) = 1
        _Distort("Distort", Float) = 1
        _RoughnessOffset0("RoughnessOffset0", Range(0,1)) = 0
        _RoughnessOffset1("RoughnessOffset1", Range(0,1)) = 1
        _SpecularScale0("SpecularScale0", Range(0,2)) = 0
        _SpecularScale1("SpecularScale1", Range(0,2)) = 0
        _IndirIntensity("IndirIntensity", Float) = 1
    }
    SubShader
    {

        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
        }
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
        
        struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct v2f
            {
                
                float4 positionCS : SV_POSITION;
                half3 positionWS : TEXCOORD4;
                float2 uv : TEXCOORD0;
                half3 normalWS : TEXCOORD1; 
                half3 tangentWS : TEXCOORD2;
                half3 bitangentWS : TEXCOORD3;
                
            };



            v2f vert (appdata v)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(v.vertex.xyz);
                VertexNormalInputs n = GetVertexNormalInputs(v.normalOS, v.tangentOS);
                o.normalWS = n.normalWS;
                o.tangentWS = n.tangentWS;
                o.bitangentWS = n.bitangentWS;
                o.uv = v.uv;
                
                VertexPositionInputs pos = GetVertexPositionInputs(v.vertex.xyz);
                o.positionCS = pos.positionCS;
                o.positionWS = pos.positionWS;
                return o;
            }
        
            
            TEXTURE2D(_AlbedoMap);
            SAMPLER(sampler_AlbedoMap);
            
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
            
            TEXTURE2D(_NormalDetailMap);
            SAMPLER(sampler_NormalDetailMap);
            
            TEXTURE2D(_LUT);
            SAMPLER(sampler_LUT);
            
            TEXTURE2D(_CurvatureMap);
            SAMPLER(sampler_CurvatureMap);
            
            TEXTURE2D(_AO);
            SAMPLER(sampler_AO);
            
            TEXTURE2D(_Cavity);
            SAMPLER(sampler_Cavity);
            
            TEXTURE2D(_ThicknessMap);
            SAMPLER(sampler_ThicknessMap);
            
            TEXTURE2D(_KeleLUT);
            SAMPLER(sampler_KeleLUT);
            
            TEXTURE2D(_Roughness);
            SAMPLER(sampler_Roughness);

            
            CBUFFER_START(UnityPerMaterial)
            
                float _NormalScale;
                float _NormalDetailScale;

            
            
                float _ThicknessScale;
                float _Distort;
                half3 _TransCol;
            
                float _RoughnessOffset0;
                float _RoughnessOffset1;
            
                float _SpecularScale0;
                float _SpecularScale1;
                
                float _IndirIntensity;
            
                float4 _BlushMask_ST;
                half4 _BlushColor;
                half _BlushStrength;
            CBUFFER_END
            
             half3 TransmissionCal(Light light, half3 albedo, half3 viewDir, half3 normalDir,
                half distort, half thickness,half thicknessScale)
            {
                float3 transLightDir = normalize(light.direction + normalDir * distort);
                half3 transColor = saturate(dot(viewDir, -transLightDir)) * thickness * thicknessScale * albedo;
                return transColor;
            }
            
            //F项直接光（UE的拟合函数）
            half F_Function(half HdotV, half F0)
            {
                float fre = exp2((-5.55473 * HdotV - 6.98316) * HdotV);
                return F0 + (1 - F0) * fre;
            }
            //Keleman高光计算
            struct MyBaseData
            {
                half NdotH;
                half HdotV;
                half NdotV;
                half halfLambert;
            };
            half3 SkinDirSpecCal(Light light, MyBaseData baseData, half specular0, half specular1, half SpecularScale0, half SpecularScale1)
            {
                specular0 = Pow4(2.0 * specular0) * SpecularScale0;
                specular1 = Pow4(2.0 * specular1) * SpecularScale1;
                half F = F_Function(baseData.HdotV, 0.028);
                half3 specCal = (specular0 + specular1) * F * baseData.halfLambert * light.color;
                return  specCal;
            }
            //间接光的菲涅尔
            half IndirF_Function(half NdotV, half F0, half roughness)
            {
                float Fre = exp2((-5.55473 * NdotV - 6.98316) * NdotV);
                return F0 + Fre * saturate(1 - roughness - F0);
            }
            
            half IndirDiffCal(half3 albedo, float3 normalWS, half NdotV, half roughness)
            {
                half3 ambientCol = SampleSH(normalWS);
                half3 ambient = 0.03 * albedo.rgb;
                half3 iblDiffuse = max(half3(0, 0, 0), ambient.rgb + ambientCol);
                half3 Flast = IndirF_Function(NdotV, 0.028, roughness);
                half3 kdLast = 1 - Flast;
                return iblDiffuse * kdLast * albedo.rgb;
            }
            
        
        ENDHLSL
        
        Pass
        {
            Name "Skin"
            Tags {"LightMode"= "UniversalForward"}
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            
            
            
            half4 frag (v2f i) : SV_Target
            {
                half3 albedo = SAMPLE_TEXTURE2D(_AlbedoMap, sampler_AlbedoMap, i.uv);
                //TBN
                
                //正常法线
                half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv), _NormalScale);
                //毛孔法线
                half3 detailNormalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalDetailMap, sampler_NormalDetailMap, i.uv), _NormalDetailScale);
                //融合法线
                half3 finalNormalTs = normalize(BlendNormalRNM(normalTS,detailNormalTS));
                half3 normalWS = normalize(TransformTangentToWorld(finalNormalTs,
                    half3x3(i.tangentWS, i.bitangentWS, i.normalWS)
                    ));//N
                half4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);
                Light mainLight = GetMainLight(shadowCoord);//L
                half3 viewDir = normalize(GetCameraPositionWS() - i.positionWS);//V
                MyBaseData baseData ;
                half3 H = normalize(viewDir + mainLight.direction);//H
                baseData.NdotH = saturate(dot(normalWS, H));
                baseData.HdotV = saturate(dot(H, viewDir));
                baseData.NdotV = saturate(dot(normalWS, viewDir));
                baseData.halfLambert = saturate(dot(normalWS, mainLight.direction)* 0.5 + 0.5);
                
                //SSS漫反射
                half sssHalfLambert = dot(normalWS, mainLight.direction) * 0.5 + 0.5;//halflambert
                // half curvature = SAMPLE_TEXTURE2D(_CurvatureMap, sampler_CurvatureMap, i.uv);
                half curvature = 0.8;
                float ao = SAMPLE_TEXTURE2D(_AO, sampler_AO, i.uv);
                float cavity = SAMPLE_TEXTURE2D(_Cavity, sampler_Cavity, i.uv);
                half sssAtten = (mainLight.distanceAttenuation * mainLight.shadowAttenuation * ao * cavity * 0.5 + 0.5);//光照衰减
                half3 sss = SAMPLE_TEXTURE2D(_LUT, sampler_LUT, float2(sssHalfLambert, curvature)).rgb;//sss



                half3 dirDiffCol = albedo.rgb * sssAtten * sss * sssHalfLambert * mainLight.color;
                //BTDF
                half thickness = SAMPLE_TEXTURE2D(_ThicknessMap, sampler_ThicknessMap, i.uv);
                half3 transCol = TransmissionCal(mainLight, albedo.rgb, viewDir, normalWS, _Distort, thickness, _ThicknessScale)* _TransCol.rgb * sssAtten;
                //kelemen高光
                float roughness = SAMPLE_TEXTURE2D(_Roughness, sampler_Roughness, i.uv);
                float specular0 = SAMPLE_TEXTURE2D(_KeleLUT, sampler_KeleLUT, half2(baseData.NdotH, _RoughnessOffset0 * roughness)).x;//roughness作为高光权重
                float specular1 = SAMPLE_TEXTURE2D(_KeleLUT, sampler_KeleLUT, half2(baseData.NdotH, _RoughnessOffset1 * roughness)).x;
                half3 dirSpecCol = SkinDirSpecCal(mainLight, baseData, specular0, specular1,_SpecularScale0, _SpecularScale1) * sssAtten;
                //间接光漫反射 （解决暗部死黑的问题）
                half3 indirDiffCol = IndirDiffCal(albedo.rgb, normalWS, baseData.NdotV, roughness) * sssAtten * _IndirIntensity;
                
                
                half3 finalColor = transCol + dirDiffCol + indirDiffCol;
                return float4(finalColor, 1);
            }
            ENDHLSL
        }
        
        Pass
        {
            Name "specular"
            Tags {"LightMode" = "SkinSpecular"}
            Cull back
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
           
            
            
           
            half4 frag (v2f i) : SV_Target
            {
                half3 albedo = SAMPLE_TEXTURE2D(_AlbedoMap, sampler_AlbedoMap, i.uv);
                //TBN
                //正常法线
                half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv), _NormalScale);
                //毛孔法线
                half3 detailNormalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalDetailMap, sampler_NormalDetailMap, i.uv), _NormalDetailScale);
                //融合法线
                float ao = SAMPLE_TEXTURE2D(_AO, sampler_AO, i.uv);
                float cavity = SAMPLE_TEXTURE2D(_Cavity, sampler_Cavity, i.uv);
                
                half3 finalNormalTs = normalize(BlendNormalRNM(normalTS,detailNormalTS));
                half3 normalWS = normalize(TransformTangentToWorld(finalNormalTs,
                    half3x3(i.tangentWS, i.bitangentWS, i.normalWS)
                    ));//N
                half4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);
                Light mainLight = GetMainLight(shadowCoord);//L
                half3 viewDir = normalize(GetCameraPositionWS() - i.positionWS);//V

                MyBaseData baseData ;
                half3 H = normalize(viewDir + mainLight.direction);//H
                baseData.NdotH = saturate(dot(normalWS, H));
                baseData.HdotV = saturate(dot(H, viewDir));
                baseData.NdotV = saturate(dot(normalWS, viewDir));
                baseData.halfLambert = saturate(dot(normalWS, mainLight.direction)* 0.5 + 0.5);
                float roughness = SAMPLE_TEXTURE2D(_Roughness, sampler_Roughness, i.uv);
                float specular0 = SAMPLE_TEXTURE2D(_KeleLUT, sampler_KeleLUT, half2(baseData.NdotH, _RoughnessOffset0 * roughness)).x;//roughness作为高光权重
                float specular1 = SAMPLE_TEXTURE2D(_KeleLUT, sampler_KeleLUT, half2(baseData.NdotH, _RoughnessOffset1 * roughness)).x;

                
                
                half sssAtten = (mainLight.distanceAttenuation * mainLight.shadowAttenuation * ao * cavity * 0.5 + 0.5);//光照衰减

                
                //kelemen高光
                
                half3 dirSpecCol = SkinDirSpecCal(mainLight, baseData, specular0, specular1,_SpecularScale0, _SpecularScale1) * sssAtten;
                
                half3 finalColor = dirSpecCol ;
                return float4(finalColor, 1);
            }
            ENDHLSL
        }

        
        
    }
}

Shader "Unlit/Hair"
{
    Properties
    {
        _Albedo ("Albedo", 2D) = "white" {}
        _alphaMap("alphaMap", 2D) = "white"{}
        _AO("AO", 2D) = "white"{}
        _NormalMap("NormalMap", 2D) = "bump"{}

        
        _Threshold("Threshold", Range(0, 1)) = 0.5
        _Specular("Specular", Range(0, 1)) = 0.5
        _Roughness("Roughness", Range(0, 1)) = 0.5
        _ShadowStrength("ShadowStrength", Range(0, 1)) = 0.5
        
    }
    SubShader
    {
        Cull off
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"

        }
        LOD 100

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
        #include "HairShading.hlsl"
        
        TEXTURE2D(_alphaMap);
        SAMPLER(sampler_alphaMap);
        float _Threshold;
        
        TEXTURE2D(_NormalMap);
        SAMPLER(sampler_NormalMap);
        
        float _NormalScale;
        float _NormalDetailScale;
        
        TEXTURE2D(_Albedo);
        SAMPLER(sampler_Albedo);
        
        TEXTURE2D(_AO);
        SAMPLER(sampler_AO);
        
        float _Roughness;
        float _Specular;
        struct appdata
        {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
            float2 uv2 : TEXCOORD1;
            float3 normalOS : NORMAL;
            float4 tangentOS : TANGENT;
        };

        struct v2f
        {
            float4 positionCS : SV_POSITION;
            float3 positionWS : TEXCOORD5;
            float2 uv : TEXCOORD0;
            float2 shadowUV : TEXCOORD4;
            float3 normalWS : TEXCOORD1;
            float3 tangentWS : TEXCOORD2;
            float3 bitangentWS : TEXCOORD3;
        };



        v2f vert (appdata v)
        {
            v2f o;
            o.positionCS = TransformObjectToHClip(v.vertex.xyz);
            o.positionWS = TransformObjectToWorld(v.vertex.xyz);
            o.uv = v.uv;
            o.shadowUV = v.uv2;
            VertexNormalInputs n = GetVertexNormalInputs(v.normalOS, v.tangentOS);
            o.normalWS = n.normalWS;
            o.tangentWS = n.tangentWS;
            o.bitangentWS = n.bitangentWS;
            return o;
        }
        struct MyBaseData
        {
            half NdotH;
            half HdotV;
            half NdotV;
            half halfLambert;
        };
        
        ENDHLSL
        
        
        
        Pass
        {
            Cull off
            AlphaToMask On
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            
            half4 frag (v2f i) : SV_Target
            {
                half3 geometricNormalWS = normalize(i.normalWS);
                half3 BiTangent = normalize(i.bitangentWS - dot(geometricNormalWS, i.bitangentWS));//B
                half3 Tangent = normalize(i.tangentWS - dot(geometricNormalWS, i.tangentWS));//T
                 half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv), _NormalScale);
                half3 normalWS = normalize(Tangent * normalTS.x + BiTangent * normalTS.y + geometricNormalWS * normalTS.z);//N
                half4 shadowCoord = TransformWorldToShadowCoord(i.positionCS);
                Light mainLight = GetMainLight(shadowCoord);//L
                half3 viewDir = GetWorldSpaceViewDir(i.positionWS);//V
                normalWS *= (dot(normalWS , viewDir) < 0.0)? -1.0 : 1.0;
                half3 H = normalize(viewDir + mainLight.direction);//H
            

                HairTempData HairTemp;
                HairBaseDataCal( HairTemp, BiTangent, viewDir, mainLight.direction, _Roughness);
                float ao = SAMPLE_TEXTURE2D(_AO, sampler_AO, i.uv);
                half atten = mainLight.distanceAttenuation * mainLight.shadowAttenuation * ao  * 0.5 + 0.5;//光照衰减
            
                half mask = SAMPLE_TEXTURE2D(_alphaMap, sampler_alphaMap, i.uv).r;
                float width = max(fwidth(mask), 1e-4);
                float coverage = smoothstep(_Threshold - width,
                                    _Threshold + width,
                                    mask);
                
                half3 base_Color = SAMPLE_TEXTURE2D(_Albedo, sampler_Albedo, i.uv);
                half3 diffColor = DiffuseCal(mainLight, atten, base_Color, mainLight.direction, viewDir, normalize(i.bitangentWS));
                //高光
                half3 specular = SpecularCal(HairTemp, mainLight, base_Color, _Specular);
                
            
            
            
                half3 final_Color = diffColor + specular;
                final_Color *= atten;
                return float4(diffColor, coverage);
            }
            ENDHLSL
        }
    }
}

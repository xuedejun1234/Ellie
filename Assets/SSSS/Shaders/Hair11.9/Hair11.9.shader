Shader "Unlit/Hair11.9"
{
    Properties
    {

        _AlphaCutoff("AlphaCutoff", Range(0, 1)) = 0.5
        _Mask("Mask", 2D) = "White"{}
        _ThicknessScale("ThicknessScale", Range(0,2)) = 0.5
        _ThicknessBias("ThicknessBias", Range(0,1)) = 0.5
        _albedo("albedo", 2D) = "black"{}
        _ao("ao", 2d) = "white"{}
        _SpecularScale("SpecularScale", Float) = 1
        _SpecularInstensity("SpecularInstensity", Float) = 1
        _SpecularShift("SpecularShift", Range(0,1)) = 0
    }
    SubShader
    {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "TransparentCutout"
            "Queue" = "AlphaTest"
            
        }
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"  
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" 
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
        #pragma multi_compile_fragment _ _SHADOWS_SOFT
        float _AlphaCutoff;
        TEXTURE2D(_Mask);
        SAMPLER(sampler_Mask);
        float _ThicknessScale;
        float _ThicknessBias;
        
        TEXTURE2D(_albedo);
        SAMPLER(sampler_albedo);
        
        TEXTURE2D(_ao);
        SAMPLER(sampler_ao);
        
        float _SpecularScale;
        float _SpecularInstensity;
        float _SpecularShift;
        
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
                float3 positionWS : TEXCOORD4;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 tangentWS : TEXCOORD2;
                float3 bitangentWS : TEXCOORD3;
            };
        

            v2f vert (appdata v)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(v.vertex.xyz);
                o.positionWS = TransformObjectToWorld(v.vertex.xyz);
                VertexNormalInputs n = GetVertexNormalInputs(v.normalOS, v.tangentOS);
                o.normalWS = n.normalWS;
                o.tangentWS = n.tangentWS;
                o.bitangentWS = n.bitangentWS;
                o.uv = v.uv;
                return o;
            }
        
        struct HairFragmentOutput
        {
            half3 color;
            half alpha;
        };
        
        HairFragmentOutput ShadeHair(v2f i)
        {
            HairFragmentOutput o;
            //球形法线
            float3 sphereNorm = float3(sin(i.positionWS.x + i.uv.x * 6.283) * _ThicknessScale,
    _ThicknessBias + 0.2, // 略微向上的分量，模拟头顶隆起
    cos(i.positionWS.z + i.uv.y * 6.283) * _ThicknessScale);
            float4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);
            Light mainlight = GetMainLight(shadowCoord);
            float NdotL = saturate(dot(sphereNorm,mainlight.direction));
            half3 base_Color = SAMPLE_TEXTURE2D(_albedo, sampler_albedo, i.uv);
            //ao
            half ao = SAMPLE_TEXTURE2D(_ao, sampler_ao, i.uv);
            half aoFactor = mainlight.shadowAttenuation * mainlight.distanceAttenuation * ao;
            float3 diffuseTotal = base_Color * NdotL * aoFactor; 
            //kk
            half3 viewDir = normalize(GetWorldSpaceViewDir(i.positionWS)); 
            half3 T =normalize(i.bitangentWS + _SpecularShift * i.normalWS);
            float3 H = normalize(viewDir + mainlight.direction);
            half TdotH = dot(T, H);
            float sinTH = sqrt(1.0 - TdotH * TdotH);
            half3 Specular = pow(max(0.0, sinTH), _SpecularScale) * _SpecularInstensity * aoFactor * diffuseTotal;
            
            
            
            
            
            float3 finalDiffuse = diffuseTotal + Specular;
            o.color = finalDiffuse;
            o.alpha = SAMPLE_TEXTURE2D(_Mask, sampler_Mask, i.uv);
            return  o;
        }
        
        ENDHLSL
        
        
        
        
        Pass
        {
            Name "Hair_Opaque"
            Tags{"LightMode"="UniversalForward"}
            Cull Back
            ZWrite On
            ZTest LEqual
            Blend One Zero
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            

            half4 frag (v2f i) : SV_Target
            {
                 
                
                
                HairFragmentOutput o = ShadeHair(i);
                clip(o.alpha - _AlphaCutoff); // 剔除半透明
                return half4(o.color, 1.0);
            }
            ENDHLSL
        }


        Pass
        {
            Name "Hair_Transparent"
            Tags{"LightMode"="HairTransparent"}
            Cull Back
            ZWrite Off
            ZTest Less
            Blend SrcAlpha OneMinusSrcAlpha
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            

            half4 frag (v2f i) : SV_Target
            {
            
                HairFragmentOutput o = ShadeHair(i);
                clip(o.alpha - 0.01); // 仅剔除完全透明
                // 依靠 ZTest Less 避免重复渲染实心部分
                return half4(o.color, o.alpha);
            
            }
            ENDHLSL
        }

        Pass
        {
            Name "SkinShelter"
            Tags { "LightMode" = "SkinShelter" }
            Cull Off
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex SkinShelterVertex
            #pragma fragment SkinShelterFragment
            #pragma multi_compile_instancing

            struct SkinShelterVaryings
            {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
            };

            SkinShelterVaryings SkinShelterVertex(appdata i)
            {
                UNITY_SETUP_INSTANCE_ID(input);
                SkinShelterVaryings output;
                output.positionCS = TransformObjectToHClip(i.vertex.xyz);
                output.uv = i.uv;
                return output;
            }

            half4 SkinShelterFragment(SkinShelterVaryings input) : SV_Target
            {
                half alpha = SAMPLE_TEXTURE2D(_Mask, sampler_Mask, input.uv).r;
                clip(alpha - 0.5);
                return half4(0, 0, 0, 0);
            }
            ENDHLSL
        }
    }
}

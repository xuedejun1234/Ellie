Shader "Unlit/denimShirt"
{
    Properties
    {

    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        
        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"  
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"  
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            
            
            TEXTURE2D(_Albedo);
            SAMPLER(sampler_Albedo);
            
            
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
            };

            struct clothOutPut
            {
                half4 Color;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(v.vertex.xyz);
                o.positionWS = TransformObjectToWorld(v.vertex.xyz);
                VertexNormalInputs n = GetVertexNormalInputs(v.normalOS, v.tangentOS);
                
                o.uv = v.uv;
                return o;
            }
            
            clothOutPut Cloth( v2f i)
            {
                clothOutPut o;
                float4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                half3 normalWS = SAMPLE_TEXTURE2D(_NormalMap, )
                half3 L = normalize(mainLight.direction);
                half3 baseColor = SAMPLE_TEXTURE2D(_Albedo, sampler_Albedo, i.uv);
                half halflambert = saturate(L * normalWS);
                
                
                
                
                return o;
            }
            
            
            
            
            
            CBUFFER_START(UnityPerMaterial)
            
            
            
            
            CBUFFER_END
        ENDHLSL

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag


            

            half4 frag (v2f i) : SV_Target
            {
                half3 finalColor = Cloth(i);
               
                return half4(finalColor, 1);
            }
            ENDHLSL
        }
    }
}

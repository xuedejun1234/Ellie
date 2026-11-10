Shader "Hidden/PostProcess/SkinMask"
{
    Properties
    {
        [HideInInspector]_MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        ZTest LEqual
        ZWrite On
        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
            };
            
            v2f vert (appdata v)
            {
                v2f o;
                o.positionCS =  TransformObjectToHClip(v.vertex.xyz);
                return o;
            }
        ENDHLSL

        Pass
        {
            Name "Mask"
            Tags{"LightMode" = "UniversalForward"}
            Cull back
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            half4 frag (v2f i) : SV_Target
            {
                return half4(1, 1, 1, 1);
            }
            ENDHLSL
        }

        Pass
        {
            Name "Shelter"
            Tags{"LightMode" = "UniversalForward"}
            Cull back
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            half4 frag (v2f i) : SV_Target
            {
                return half4(0, 0, 0, 0);
            }
            ENDHLSL
        }
    }
}

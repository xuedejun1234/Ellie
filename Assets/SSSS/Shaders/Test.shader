Shader "Unlit/Test"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"


            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;

                float4 position : SV_POSITION;
            };

            TEXTURE2D(_MainTex);
            float4 _MainTex_ST;
            SAMPLER(sampler_MainTex);
            v2f vert (appdata v)
            {
                v2f o;
                o.position = TransformObjectToHClip(v.vertex.xyz);
                o.uv = v.uv;

                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                
                half3 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,i.uv);


                return float4(col, 1);
            }
            ENDHLSL
        }
    }
}

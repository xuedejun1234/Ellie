Shader "Hidden/PostProcess/SkinSSS"
{
    Properties
    {
        _MainTex ("MainTex", 2D) = "white" {}
        _Color("Color", Color) = (1, 1, 1, 1)
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalRenderPipeline"
        }
        LOD 100
        ZTest LEqual
        ZWrite Off
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        
        
        TEXTURE2D(_SkinMaskTexture);
        SAMPLER(sampler_SkinMaskTexture);
        
        TEXTURE2D(_SourceTexture);
        SAMPLER(sampler_SourceTexture);
        
        
        TEXTURE2D(_SpecularRendertexture);
        SAMPLER(sampler_SpecularRendertexture);
        
        CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_TexelSize;
            float _BlurSize;
            float4 _Color;
        CBUFFER_END
        
        
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
        SAMPLER(sampler_MainTex);

        v2f vert(appdata v)
        {
            v2f o;
            o.uv = v.uv;
            o.position = TransformObjectToHClip(v.vertex.xyz);
            return o;
        }
            
        struct v2fBlur
        {
            float2 uv[5] : TEXCOORD0;
            float4 positionCS : SV_POSITION;
        };
         
        v2fBlur vertBlurVertical(appdata v)
        {
            v2fBlur o;
            o.positionCS = TransformObjectToHClip(v.vertex.xyz);
            float2 uv = v.uv;
            o.uv[0] = uv;
            o.uv[1] = uv + float2(0.0, _MainTex_TexelSize.y * 1.0) * _BlurSize;
            o.uv[2] = uv - float2(0.0, _MainTex_TexelSize.y * 1.0) * _BlurSize;
            o.uv[3] = uv + float2(0.0, _MainTex_TexelSize.y * 2.0) * _BlurSize;
            o.uv[4] = uv - float2(0.0, _MainTex_TexelSize.y * 2.0) * _BlurSize;
            
            return o;
        }
        
        v2fBlur vertBlurHorizontal(appdata v)
        {
            v2fBlur o;
            o.positionCS = TransformObjectToHClip(v.vertex.xyz);
            float2 uv = v.uv;
            o.uv[0] = uv;
            o.uv[1] = uv + float2(_MainTex_TexelSize.x * 1.0, 0.0) * _BlurSize;
            o.uv[2] = uv - float2(_MainTex_TexelSize.x * 1.0, 0.0) * _BlurSize;
            o.uv[3] = uv + float2(_MainTex_TexelSize.x * 2.0, 0.0) * _BlurSize;
            o.uv[4] = uv - float2(_MainTex_TexelSize.x * 2.0, 0.0) * _BlurSize;
            return o;
        }
        
        float4 fragBlur(v2fBlur i): SV_Target
        {
            //高斯模糊算子
            float weight[3] = {0.4026, 0.2442, 0.0545};
            //中心像素值
            float3 sum = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv[0]).rgb * weight[0];
            for (int j = 1; j <3; j++)
            {
                sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv[j *  2 - 1]).rgb * weight[j];
                sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv[j *  2]).rgb * weight[j];
            }//颜色 * 权重 （防止变亮或变暗）
            return float4(sum, 1.0);
            
        }
        
            
        ENDHLSL
        
        
        
        Pass//Pass0
        {
            Name "BlurVertical"
            HLSLPROGRAM
            #pragma vertex vertBlurVertical
            #pragma fragment fragBlur
            
            ENDHLSL
        }

        pass//Pass1
        {
            Name "BlurHorizontal"
            HLSLPROGRAM
            #pragma vertex vertBlurHorizontal
            #pragma fragment fragBlur
            
            ENDHLSL
        }
        
        pass//Pass2
        {
            Name "Mix"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            half4 frag(v2f i):SV_Target
            {
                half mask = SAMPLE_TEXTURE2D(_SkinMaskTexture, sampler_SkinMaskTexture, i.uv).x;
                half3 sssTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).rgb * _Color.rgb;
                half3 baseTex = SAMPLE_TEXTURE2D(_SourceTexture, sampler_SourceTexture, i.uv).rgb;
                half3 specTex = SAMPLE_TEXTURE2D(_SpecularRendertexture, sampler_SpecularRendertexture, i.uv).rgb;
                half3 mix = lerp(baseTex, sssTex + baseTex, mask) + specTex * mask;
                return  half4(mix, 1);
            
            }
            
            ENDHLSL
        }
        
    }
}
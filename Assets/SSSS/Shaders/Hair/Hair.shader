Shader "Unlit/Hair"
{
    Properties
    {
        [MainTexture] _MainTex ("Albedo", 2D) = "white" {}
        [MainColor] _Color ("Color Tint", Color) = (1, 1, 1, 1)
        _alphaMap ("Alpha", 2D) = "white" {}
        _NormalMap ("Tangent Normal", 2D) = "bump" {}
        _AO ("Ambient Occlusion", 2D) = "white" {}
        _ExtraAOMap ("Extra AO Mask", 2D) = "white" {}
        _SpecMap ("Specular Mask (G)", 2D) = "white" {}
        _NoiseMap ("Detail Noise", 2D) = "gray" {}
        _TangentShiftMap ("Tangent Shift Noise", 2D) = "gray" {}
        _SnowMask ("Snow Mask", 2D) = "black" {}
        _SnowColor ("Snow Color", Color) = (0.9, 0.94, 1, 1)

        _Threshold ("Alpha Cutoff", Range(0, 1)) = 0.25
        _Roughness ("Hair Roughness", Range(0, 1)) = 0.38
        _Specular ("Specular Strength", Range(0, 2)) = 0.8
        _SecondarySpecular ("Secondary Lobe Strength", Range(0, 1)) = 0.3
        _SpecularTint ("Specular Tint", Range(0, 1)) = 0.25
        _NormalScale ("Normal Strength", Range(0, 2)) = 0.6
        _AOIntensity ("AO Strength", Range(0, 1)) = 0.7
        _ExtraAOIntensity ("Extra AO Strength", Range(0, 1)) = 0
        _DiffuseWrap ("Diffuse Wrap", Range(0, 1)) = 0.35
        _ShadowStrength ("Realtime Shadow Strength", Range(0, 1)) = 0.85
        _NoiseStrength ("Tangent Noise Strength", Range(0, 1)) = 0.15
        _NoiseTiling ("Detail Noise Tiling", Range(0.1, 16)) = 4
        _TangentNoiseTiling ("Tangent Noise Tiling", Range(0.1, 16)) = 2
        _HairAxis ("Strand Axis (0=UV V, 1=UV U)", Range(0, 1)) = 0
        _SnowAmount ("Snow Amount", Range(0, 1)) = 0
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "TransparentCutout"
            "Queue" = "AlphaTest"
        }

        LOD 300
        Cull Off

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"

        TEXTURE2D(_MainTex);         SAMPLER(sampler_MainTex);
        TEXTURE2D(_alphaMap);        SAMPLER(sampler_alphaMap);
        TEXTURE2D(_NormalMap);       SAMPLER(sampler_NormalMap);
        TEXTURE2D(_AO);              SAMPLER(sampler_AO);
        TEXTURE2D(_ExtraAOMap);      SAMPLER(sampler_ExtraAOMap);
        TEXTURE2D(_SpecMap);         SAMPLER(sampler_SpecMap);
        TEXTURE2D(_NoiseMap);        SAMPLER(sampler_NoiseMap);
        TEXTURE2D(_TangentShiftMap); SAMPLER(sampler_TangentShiftMap);
        TEXTURE2D(_SnowMask);        SAMPLER(sampler_SnowMask);

        CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float4 _alphaMap_ST;
            float4 _NormalMap_ST;
            float4 _AO_ST;
            float4 _ExtraAOMap_ST;
            float4 _SpecMap_ST;
            float4 _NoiseMap_ST;
            float4 _TangentShiftMap_ST;
            float4 _SnowMask_ST;
            float4 _Color;
            float4 _SnowColor;
            float _Threshold;
            float _Roughness;
            float _Specular;
            float _SecondarySpecular;
            float _SpecularTint;
            float _NormalScale;
            float _AOIntensity;
            float _ExtraAOIntensity;
            float _DiffuseWrap;
            float _ShadowStrength;
            float _NoiseStrength;
            float _NoiseTiling;
            float _TangentNoiseTiling;
            float _HairAxis;
            float _SnowAmount;
        CBUFFER_END

        struct Attributes
        {
            float4 positionOS : POSITION;
            float3 normalOS : NORMAL;
            float4 tangentOS : TANGENT;
            float2 uv : TEXCOORD0;
            UNITY_VERTEX_INPUT_INSTANCE_ID
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float3 positionWS : TEXCOORD0;
            float2 uv : TEXCOORD1;
            float3 normalWS : TEXCOORD2;
            float3 tangentWS : TEXCOORD3;
            float3 bitangentWS : TEXCOORD4;
            float fogFactor : TEXCOORD5;
            UNITY_VERTEX_INPUT_INSTANCE_ID
            UNITY_VERTEX_OUTPUT_STEREO
        };

        Varyings HairVertex(Attributes input)
        {
            Varyings output = (Varyings)0;
            UNITY_SETUP_INSTANCE_ID(input);
            UNITY_TRANSFER_INSTANCE_ID(input, output);
            UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

            VertexPositionInputs positionInputs = GetVertexPositionInputs(input.positionOS.xyz);
            VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS, input.tangentOS);

            output.positionCS = positionInputs.positionCS;
            output.positionWS = positionInputs.positionWS;
            output.uv = input.uv;
            output.normalWS = normalInputs.normalWS;
            output.tangentWS = normalInputs.tangentWS;
            output.bitangentWS = normalInputs.bitangentWS;
            output.fogFactor = ComputeFogFactor(positionInputs.positionCS.z);
            return output;
        }
        //kk高光
        float HairAnisotropicLobe(float3 strandDirWS, float3 normalWS, float3 halfDirWS, float shift, float power)
        {
            float3 shiftedDir = normalize(strandDirWS + normalWS * shift);
            float tangentHalf = dot(shiftedDir, halfDirWS);
            float sinThetaH = sqrt(saturate(1.0 - tangentHalf * tangentHalf));
            return pow(sinThetaH, max(power, 1.0));
        }

        half3 EvaluateHairLight(
            Light light,
            float attenuation,
            half3 baseColor,
            float specMask,
            float detailNoise,
            float3 normalWS,
            float3 strandDirWS,
            float3 viewDirWS)
        {
            float3 lightDirWS = normalize(light.direction);
            float3 halfDirWS = normalize(lightDirWS + viewDirWS);

            float nDotL = abs(dot(normalWS, lightDirWS));
            float wrappedDiffuse = saturate((nDotL + _DiffuseWrap) / (1.0 + _DiffuseWrap));//保证 nDotL = 1 时结果仍是 1
            float strandDiffuse = saturate(1.0 - abs(dot(strandDirWS, lightDirWS)));
            float diffuse = lerp(wrappedDiffuse, strandDiffuse, 0.4);

            float localRoughness = saturate(_Roughness + (1.0 - specMask) * 0.2);
            float primaryPower = lerp(112.0, 8.0, localRoughness);
            float secondaryPower = lerp(32.0, 3.0, localRoughness);
            float primaryLobe = HairAnisotropicLobe(strandDirWS, normalWS, halfDirWS, -0.08 +0.5, primaryPower);
            float secondaryLobe = HairAnisotropicLobe(strandDirWS, normalWS, halfDirWS, 0.22 +0.5, secondaryPower);

            float noiseVariation = lerp(0.85, 1.15, saturate(detailNoise));
            float specStrength = _Specular * specMask * noiseVariation;
            half3 specColor = lerp(half3(1.0, 1.0, 1.0), baseColor, _SpecularTint);
            half3 diffuseColor = baseColor * diffuse;
            half3 specularColor = specColor * specStrength *
                (primaryLobe + secondaryLobe * _SecondarySpecular);

            
            // return specularColor;
            return (diffuseColor + specularColor) * light.color * attenuation;//漫反射 + 两道高光
        }

        half4 HairFragment(Varyings input) : SV_Target
        {
            UNITY_SETUP_INSTANCE_ID(input);
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

            float2 alphaUV = TRANSFORM_TEX(input.uv, _alphaMap);
            float alphaMask = SAMPLE_TEXTURE2D(_alphaMap, sampler_alphaMap, alphaUV).r;
            float edgeWidth = max(fwidth(alphaMask), 1e-4);
            clip(alphaMask - (_Threshold - edgeWidth));
            half coverage = smoothstep(_Threshold - edgeWidth, _Threshold + edgeWidth, alphaMask);

            float3 viewDirWS = normalize(GetWorldSpaceViewDir(input.positionWS));
            float3 geometricNormalWS = normalize(input.normalWS);
            float3 tangentWS = normalize(input.tangentWS - geometricNormalWS * dot(input.tangentWS, geometricNormalWS));
            float3 bitangentWS = normalize(input.bitangentWS - geometricNormalWS * dot(input.bitangentWS, geometricNormalWS));

            float2 normalUV = TRANSFORM_TEX(input.uv, _NormalMap);
            half3 normalTS = UnpackNormalScale(
                SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, normalUV),
                _NormalScale);
            float3 normalWS = normalize(
                tangentWS * normalTS.x +
                bitangentWS * normalTS.y +
                geometricNormalWS * normalTS.z);
            normalWS *= (dot(normalWS, viewDirWS) < 0.0) ? -1.0 : 1.0;//为了你的头发发片使用了 Cull Off，正反两面都会渲染。

            float3 strandDirWS = normalize(lerp(bitangentWS, tangentWS, _HairAxis));
            float2 tangentNoiseUV = input.uv * _TangentNoiseTiling;
            tangentNoiseUV = TRANSFORM_TEX(tangentNoiseUV, _TangentShiftMap);
            float tangentNoise = SAMPLE_TEXTURE2D(_TangentShiftMap, sampler_TangentShiftMap, tangentNoiseUV).r;
            strandDirWS = normalize(strandDirWS + normalWS * ((tangentNoise - 0.5) * _NoiseStrength));

            half3 baseColor = SAMPLE_TEXTURE2D(
                _MainTex,
                sampler_MainTex,
                TRANSFORM_TEX(input.uv, _MainTex)).rgb * _Color.rgb;
            float snowMask = SAMPLE_TEXTURE2D(
                _SnowMask,
                sampler_SnowMask,
                TRANSFORM_TEX(input.uv, _SnowMask)).r;
            baseColor = lerp(baseColor, _SnowColor.rgb, saturate(snowMask * _SnowAmount));

            float specMask = SAMPLE_TEXTURE2D(
                _SpecMap,
                sampler_SpecMap,
                TRANSFORM_TEX(input.uv, _SpecMap)).g;
            float2 detailNoiseUV = input.uv * _NoiseTiling;
            detailNoiseUV = TRANSFORM_TEX(detailNoiseUV, _NoiseMap);
            float detailNoise = SAMPLE_TEXTURE2D(
                _NoiseMap,
                sampler_NoiseMap,
                detailNoiseUV).r;
            specMask = saturate(specMask);

            float ao = SAMPLE_TEXTURE2D(
                _AO,
                sampler_AO,
                TRANSFORM_TEX(input.uv, _AO)).r;
            float extraAO = SAMPLE_TEXTURE2D(
                _ExtraAOMap,
                sampler_ExtraAOMap,
                TRANSFORM_TEX(input.uv, _ExtraAOMap)).r;
            float ambientOcclusion =
                lerp(1.0, ao, _AOIntensity) *
                lerp(1.0, extraAO, _ExtraAOIntensity);

            half3 color = SampleSH(normalWS) * baseColor * ambientOcclusion;

            float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
            Light mainLight = GetMainLight(shadowCoord);
            float mainAttenuation = mainLight.distanceAttenuation *
                lerp(1.0, mainLight.shadowAttenuation, _ShadowStrength);
            color += EvaluateHairLight(
                mainLight, mainAttenuation, baseColor, specMask, detailNoise,
                normalWS, strandDirWS, viewDirWS);

            #if defined(_ADDITIONAL_LIGHTS)
                uint additionalLightCount = GetAdditionalLightsCount();
                for (uint lightIndex = 0u; lightIndex < additionalLightCount; ++lightIndex)
                {
                    Light additionalLight = GetAdditionalLight(lightIndex, input.positionWS);
                    float additionalAttenuation = additionalLight.distanceAttenuation *
                        lerp(1.0, additionalLight.shadowAttenuation, _ShadowStrength);
                    color += EvaluateHairLight(
                        additionalLight, additionalAttenuation, baseColor, specMask, detailNoise,
                        normalWS, strandDirWS, viewDirWS);
                }
            #endif

            color = MixFog(color, input.fogFactor);
            return half4(color, saturate(coverage));
        }
        ENDHLSL

        Pass
        {
            Name "Forward"
            Tags { "LightMode" = "UniversalForward" }
            Cull Off
            ZWrite On
            AlphaToMask On

            HLSLPROGRAM
            #pragma target 3.0
            #pragma multi_compile_instancing
            #pragma vertex HairVertex
            #pragma fragment HairFragment
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
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

            SkinShelterVaryings SkinShelterVertex(Attributes input)
            {
                UNITY_SETUP_INSTANCE_ID(input);
                SkinShelterVaryings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = TRANSFORM_TEX(input.uv, _alphaMap);
                return output;
            }

            half4 SkinShelterFragment(SkinShelterVaryings input) : SV_Target
            {
                half alpha = SAMPLE_TEXTURE2D(_alphaMap, sampler_alphaMap, input.uv).r;
                clip(alpha - _Threshold);
                return half4(0, 0, 0, 0);
            }
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            Cull Off
            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma target 3.0
            #pragma multi_compile_instancing

            struct DepthVaryings
            {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
            };

            DepthVaryings DepthVertex(Attributes input)
            {
                DepthVaryings output;
                UNITY_SETUP_INSTANCE_ID(input);
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = TRANSFORM_TEX(input.uv, _alphaMap);
                return output;
            }

            half4 DepthFragment(DepthVaryings input) : SV_Target
            {
                half alpha = SAMPLE_TEXTURE2D(_alphaMap, sampler_alphaMap, input.uv).r;
                clip(alpha - _Threshold);
                return 0;
            }

            #pragma vertex DepthVertex
            #pragma fragment DepthFragment
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            Cull Off
            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma target 3.0
            #pragma multi_compile_instancing
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            float3 _LightDirection;
            float3 _LightPosition;

            struct ShadowAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct ShadowVaryings
            {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
            };

            ShadowVaryings ShadowVertex(ShadowAttributes input)
            {
                ShadowVaryings output;
                UNITY_SETUP_INSTANCE_ID(input);

                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
                #else
                    float3 lightDirectionWS = _LightDirection;
                #endif

                float3 biasedPositionWS = ApplyShadowBias(positionWS, normalWS, lightDirectionWS);
                output.positionCS = TransformWorldToHClip(biasedPositionWS);

                #if UNITY_REVERSED_Z
                    output.positionCS.z = min(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #else
                    output.positionCS.z = max(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #endif

                output.uv = TRANSFORM_TEX(input.uv, _alphaMap);
                return output;
            }

            half4 ShadowFragment(ShadowVaryings input) : SV_Target
            {
                half alpha = SAMPLE_TEXTURE2D(_alphaMap, sampler_alphaMap, input.uv).r;
                clip(alpha - _Threshold);
                return 0;
            }

            #pragma vertex ShadowVertex
            #pragma fragment ShadowFragment
            ENDHLSL
        }
    }

    FallBack Off
}

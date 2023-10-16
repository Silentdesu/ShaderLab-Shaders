#ifndef SAMPLE_FUNCTIONS_INCLUDED
#define SAMPLE_FUNCTIONS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

half4 SampleSpecularSmoothness(
    float2 uv,
    half alpha,
    half4 specColor,
    TEXTURE2D_PARAM(specMap, sampler_specMap)
)
{
    half4 specularSmoothness = half4(0, 0, 0, 1);
    #ifdef _SPECGLOSSMAP
    specularSmoothness = SAMPLE_TEXTURE2D(specMap, sampler_specMap, uv) * specColor;
    #elif defined(_SPECULAR_COLOR)
    specularSmoothness = specColor;
    #endif

    #ifdef _GLOSSINESS_FROM_BASE_ALPHA
    specularSmoothness.a = alpha;
    #endif

    return specularSmoothness;
}

half3 SampleNormal(
    float2 uv,
    TEXTURE2D_PARAM(bumpMap, sampler_bumpMap),
    half scale = half(1.0))
{
#ifdef _NORMALMAP
    half4 n = SAMPLE_TEXTURE2D(bumpMap, sampler_bumpMap, uv);
    #if BUMP_SCALE_NOT_SUPPORTED
        return UnpackNormal(n);
    #else
        return UnpackNormalScale(n, scale);
    #endif
#else
    return half3(0.0h, 0.0h, 1.0h);
#endif
}

half3 SampleEmission(
    float2 uv,
    half3 emissionColor,
    TEXTURE2D_PARAM(emissionMap, sampler_emissionMap))
{
#ifndef _EMISSION
    return 0;
#else
    return SAMPLE_TEXTURE2D(emissionMap, sampler_emissionMap, uv).rgb * emissionColor;
#endif
}
#endif

#ifndef SHADOW_CASTER_ARRAY_PASS_INCLUDED
#define SHADOW_CASTER_ARRAY_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

// shadow casting light geometric parameters. these variables are used when applying the shadow normal bias and are set by unityengine.rendering.universal.shadowutils.setupshadowcasterconstantbuffer in com.unity.render-pipelines.universal/runtime/shadowutils.cs
// for directional lights, _lightdirection is used when applying shadow normal bias.
// for spot lights and point lights, _lightposition is used to compute the actual light direction because it is different at each shadow caster geometry vertex.
float3 _lightdirection;
float3 _lightposition;

struct Attributes
{
    float4 positionOS   : position;
    float3 normalOS     : normal;
    float3 texcoord     : texcoord0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float3 uv           : texcoord0;
    float4 positionCS   : sv_position;
};

float4 GetShadowPositionHClip(Attributes input)
{
    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

#if _casting_punctual_light_shadow
    float3 lightdirectionWS = normalize(_lightposition - positionWS);
#else
    float3 lightdirectionWS = _lightdirection;
#endif

    float4 positionCS = TransformObjectToHClip(ApplyShadowBias(positionWS, normalWS, lightdirectionWS));

#if unity_reversed_z
    positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#else
    positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#endif

    return positionCS;
}

Varyings ShadowPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);

    output.uv.xy = TRANSFORM_TEX(input.texcoord, _BaseMap).xy;
    output.positionCS = GetShadowPositionHClip(input);
    return output;
}

half4 ShadowPassFragment(Varyings input) : sv_target
{
    Alpha(SampleAlbedoAlphaArray(input.uv, TEXTURE2D_ARRAY_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
    return 0;
}

#endif

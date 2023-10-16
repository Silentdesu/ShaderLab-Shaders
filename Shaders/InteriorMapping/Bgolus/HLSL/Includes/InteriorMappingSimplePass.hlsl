

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Includes/InteriorUVFunction.hlsl"
#include "Includes/TangentSpaceFunction.hlsl"

struct appdata
{
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
    float3 normal : NORMAL;
    float4 tangent : TANGENT;
};

struct v2f
{
    float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 tangentViewDir : TEXCOORD1;
};

sampler2D _RoomTex;
sampler2D _WindowFrameTex;
sampler2D _DirtTex;

CBUFFER_START(UnityPerMaterial)
    float4 _RoomTex_ST;
    float4 _WindowFrameTex_ST;
    float4 _DirtTex_ST;
    float _RoomMaxDepth01;
    float2 _RoomCount;
    half _DirtAlpha;
CBUFFER_END

v2f vert(appdata v)
{
    v2f o;

    //regular
    o.pos = TransformObjectToHClip(v.vertex);

    //tile uv base on room count in vertex shader
    o.uv = v.uv * _RoomCount;

    //find view dir Object Space
    const float3 camPosObjectSpace = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0)).xyz;
    const float3 viewDirObjectSpace = v.vertex.xyz - camPosObjectSpace;

    //get tangent space view vector
    o.tangentViewDir = DirOSToTS(viewDirObjectSpace, v.normal, v.tangent);

    return o;
}

half4 frag(v2f i) : SV_Target
{
    float2 interiorUV = ConvertOriginalRawUVToInteriorUV(frac(i.uv), i.tangentViewDir, _RoomMaxDepth01);
    interiorUV /= _RoomCount;
    interiorUV = TRANSFORM_TEX(interiorUV, _RoomTex);

    //map to differrent room if needed
    const float2 roomIndex = floor(i.uv);
    interiorUV += roomIndex / _RoomCount;

    const half4 roomTexSample = tex2D(_RoomTex, interiorUV);
    const half4 windowFrameTexSample = tex2D(_WindowFrameTex, i.uv);
    const half4 dirtTexSample = tex2D(_WindowFrameTex, i.uv);

    half4 outputColor = lerp(roomTexSample, windowFrameTexSample.r, windowFrameTexSample.a);
    outputColor = lerp(outputColor, dirtTexSample, _DirtAlpha);

    return outputColor;
}

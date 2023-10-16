using System;
using UnityEditor;
using UnityEditor.Rendering.Universal.ShaderGUI;
using UnityEngine;

namespace Project.ShaderGUI
{
    public sealed class SimpleLit2DArray : BaseShaderGUI
    {
        private SimpleLitGUI.SimpleLitProperties _shadingModelProperties;
        
        private readonly int EmissionColor = Shader.PropertyToID("_EmissionColor");
        private readonly int Emission = Shader.PropertyToID("_Emission");
        private readonly int AlphaClip = Shader.PropertyToID("_AlphaClip");
        private readonly int Blend = Shader.PropertyToID("_Blend");
        private readonly int Surface = Shader.PropertyToID("_Surface");

        public override void FindProperties(MaterialProperty[] properties)
        {
            base.FindProperties(properties);
            _shadingModelProperties = new SimpleLitGUI.SimpleLitProperties(properties);
        }

        public override void ValidateMaterial(Material material)
        {
            SetMaterialKeywords(material, SimpleLitGUI.SetMaterialKeywords);
        }

        public override void DrawSurfaceOptions(Material material)
        {
            if (material == null) throw new ArgumentNullException("material");

            EditorGUIUtility.labelWidth = 0.0f;
            
            base.DrawSurfaceOptions(material);
        }

        public override void DrawSurfaceInputs(Material material)
        {
            base.DrawSurfaceInputs(material);
            SimpleLitGUI.Inputs(_shadingModelProperties, materialEditor, material);
            DrawEmissionProperties(material, true);
            DrawTileOffset(materialEditor, baseMapProp);
        }

        public override void DrawAdvancedOptions(Material material)
        {
            SimpleLitGUI.Advanced(_shadingModelProperties);
            base.DrawAdvancedOptions(material);
        }

        public override void AssignNewShaderToMaterial(Material material, Shader oldShader, Shader newShader)
        {
            if (material == null) throw new ArgumentNullException("material");

            if (material.HasProperty("_Emission"))
            {
                material.SetColor(EmissionColor, material.GetColor(Emission));
            }
            
            base.AssignNewShaderToMaterial(material, oldShader, newShader);

            if (oldShader == null || !oldShader.name.Contains("Legacy Shaders/"))
            {
                SetupMaterialBlendMode(material);
                return;
            }

            SurfaceType surfaceType = SurfaceType.Opaque;
            BlendMode blendMode = BlendMode.Alpha;
            if (oldShader.name.Contains("/Transparent/Cutout/"))
            {
                surfaceType = SurfaceType.Opaque;
                material.SetFloat(AlphaClip, 1);
            }
            else if (oldShader.name.Contains("/Transparent/"))
            {
                surfaceType = SurfaceType.Transparent;
                blendMode = BlendMode.Alpha;
            }
            material.SetFloat(Surface, (float)surfaceType);
            material.SetFloat(Blend, (float)blendMode);
        }
    }
}
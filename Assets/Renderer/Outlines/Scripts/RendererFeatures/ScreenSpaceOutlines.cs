using System.Collections.Generic;

using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;

public enum EdgeDectectionMethod { RobertsCross, Sobel }

public class ScreenSpaceOutlines : ScriptableRendererFeature {

    [System.Serializable]
    private class ScreenSpaceOutlineSettings {

        [Header("General Outline Settings")]
        public Color outlineColor = Color.black;
        [Range(0.0f, 20.0f)]
        public float outlineScale = 1.0f;
        public bool blurEnabled = false;
        public float blurIntensity = 0.1f;
        
        [Header("Depth Settings")]
        public bool depthDetectionEnabled = true;
        [Range(0.0f, 100.0f)]
        public float depthThreshold = 1.5f;
        [Range(0.0f, 500.0f)]
        public float robertsCrossMultiplier = 100.0f;
        public EdgeDectectionMethod depthEdgeDetectionMethod = EdgeDectectionMethod.Sobel;

        [Header("Normal Settings")]
        public bool normalDetectionEnabled = true;
        [Range(0.0f, 1.0f)]
        public float normalThreshold = 0.4f;
        public EdgeDectectionMethod normalEdgeDetectionMethod = EdgeDectectionMethod.Sobel;

        [Header("Depth Normal Relation Settings")]
        [Range(0.0f, 2.0f)]
        public float steepAngleThreshold = 0.2f;
        [Range(0.0f, 500.0f)]
        public float steepAngleMultiplier = 25.0f;
    }

    [System.Serializable]
    private class ViewSpaceNormalsTextureSettings {

        [Header("General Scene View Space Normal Texture Settings")]
        public RenderTextureFormat colorFormat;
        public int depthBufferBits = 16;
        public FilterMode filterMode;
        public Color backgroundColor = Color.black;

        [Header("View Space Normal Texture Object Draw Settings")]
        public PerObjectData perObjectData;
        public bool enableDynamicBatching;
        public bool enableInstancing;

    }

    private static List<ShaderTagId> shaderTagIdList;

    private class ViewSpaceNormalsTexturePass : ScriptableRenderPass {

        private ViewSpaceNormalsTextureSettings normalsTextureSettings;
        private FilteringSettings filteringSettings;
        private FilteringSettings occluderFilteringSettings;
        private float textureResolutionScale;

        private readonly Material normalsMaterial;
        private readonly Material occludersMaterial;

        private RTHandle normals;

        int normalsId = Shader.PropertyToID("_SceneViewSpaceNormals");

        public ViewSpaceNormalsTexturePass(RenderPassEvent renderPassEvent, LayerMask layerMask, LayerMask occluderLayerMask, ViewSpaceNormalsTextureSettings settings, float textureResolutionScale) {
            this.renderPassEvent = renderPassEvent;
            this.textureResolutionScale = textureResolutionScale;
            normalsTextureSettings = settings;
            filteringSettings = new FilteringSettings(RenderQueueRange.opaque, layerMask);
            occluderFilteringSettings = new FilteringSettings(RenderQueueRange.opaque, occluderLayerMask);

            normalsMaterial = new Material(Shader.Find("Hidden/VSNormals"));
            if(normalsMaterial == null) {
                Debug.Log("Cannot create VSNormal material");
            }

            occludersMaterial = new Material(Shader.Find("Hidden/UnlitSingleColor"));
            occludersMaterial.SetColor("_Color", normalsTextureSettings.backgroundColor);
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor) {
            RenderTextureDescriptor normalsTextureDescriptor = cameraTextureDescriptor;
            normalsTextureDescriptor.colorFormat = normalsTextureSettings.colorFormat;
            normalsTextureDescriptor.depthBufferBits = normalsTextureSettings.depthBufferBits;
            normalsTextureDescriptor.width = (int)(normalsTextureDescriptor.width * textureResolutionScale);
            normalsTextureDescriptor.height = (int)(normalsTextureDescriptor.height * textureResolutionScale);

            normals = RTHandles.Alloc("_SceneViewSpaceNormals", name: "_SceneViewSpaceNormals");
            cmd.GetTemporaryRT(normalsId, normalsTextureDescriptor, FilterMode.Bilinear);

            ConfigureTarget(normals);
            ConfigureClear(ClearFlag.All, normalsTextureSettings.backgroundColor);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData) {
            if (!normalsMaterial || !occludersMaterial) {
                Debug.Log($"normals or occluders material missng {normalsMaterial} {occludersMaterial}");
                return;
            }

            CommandBuffer cmd = CommandBufferPool.Get();
            using (new ProfilingScope(cmd, new ProfilingSampler("SceneViewSpaceNormalsTextureCreation"))) {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                DrawingSettings drawSettings = CreateDrawingSettings(shaderTagIdList, ref renderingData, renderingData.cameraData.defaultOpaqueSortFlags);
                drawSettings.perObjectData = normalsTextureSettings.perObjectData;
                drawSettings.enableDynamicBatching = normalsTextureSettings.enableDynamicBatching;
                drawSettings.enableInstancing = normalsTextureSettings.enableInstancing;
                //drawSettings.perObjectData = PerObjectData.None;
                drawSettings.overrideMaterial = normalsMaterial;
                //drawSettings.overrideMaterialPassIndex = 0;

                DrawingSettings occluderSettings = drawSettings;
                occluderSettings.overrideMaterial = occludersMaterial;
                
                context.DrawRenderers(renderingData.cullResults, ref drawSettings, ref filteringSettings);
                context.DrawRenderers(renderingData.cullResults, ref occluderSettings, ref occluderFilteringSettings);
                
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd) {
            cmd.ReleaseTemporaryRT(normalsId);
        }

    }

    private class ScreenSpaceOutlinePass : ScriptableRenderPass {

        private readonly Material screenSpaceOutlineMaterial;
        private readonly Material blurMaterial;
        private readonly Material blitMaterial;
        private readonly Material occludersMaterial;

        private FilteringSettings occluderFilteringSettings;

        RTHandle cameraColorTarget;
        RTHandle outlinesBuffer;
        int outlinesBufferId = Shader.PropertyToID("_Outlines");

        RTHandle temporaryBuffer;
        RTHandle temporaryBuffer2;

        bool blurEnabled;
        float blurIntensity;

        private float textureResolutionScale;

        public ScreenSpaceOutlinePass(RenderPassEvent renderPassEvent, LayerMask occluderLayerMask, ScreenSpaceOutlineSettings settings, float textureResolutionScale) {
            this.renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;

            blurEnabled = settings.blurEnabled;
            blurIntensity = settings.blurIntensity;        
            occluderFilteringSettings = new FilteringSettings(RenderQueueRange.opaque, occluderLayerMask);
            this.textureResolutionScale = textureResolutionScale;


            screenSpaceOutlineMaterial = new Material(Shader.Find("Hidden/BlitOutlines"));
            screenSpaceOutlineMaterial.SetColor("_OutlineColor", settings.outlineColor);
            screenSpaceOutlineMaterial.SetFloat("_OutlineScale", settings.outlineScale);

            screenSpaceOutlineMaterial.SetFloat("_DepthThreshold", settings.depthThreshold);
            screenSpaceOutlineMaterial.SetFloat("_RobertsCrossMultiplier", settings.robertsCrossMultiplier);

            screenSpaceOutlineMaterial.SetFloat("_NormalThreshold", settings.normalThreshold);

            screenSpaceOutlineMaterial.SetFloat("_SteepAngleThreshold", settings.steepAngleThreshold);
            screenSpaceOutlineMaterial.SetFloat("_SteepAngleMultiplier", settings.steepAngleMultiplier);

            switch(settings.depthEdgeDetectionMethod) {
                case EdgeDectectionMethod.RobertsCross:
                    screenSpaceOutlineMaterial.EnableKeyword("ROBERTCROSS_DEPTH");
                    break;
                case EdgeDectectionMethod.Sobel:
                    //screenSpaceOutlineMaterial.DisableKeyword("ROBERTCROSS_DEPTH");
                    break;
            }

            switch(settings.normalEdgeDetectionMethod) {
                case EdgeDectectionMethod.RobertsCross:
                    screenSpaceOutlineMaterial.EnableKeyword("ROBERTCROSS_NORMAL");
                    break;
                case EdgeDectectionMethod.Sobel:
                   // screenSpaceOutlineMaterial.DisableKeyword("ROBERTCROSS_NORMAL");
                    break;
            }

            if(settings.normalDetectionEnabled) {
                screenSpaceOutlineMaterial.EnableKeyword("NORMAL_DETECTION");
            }

            if(settings.depthDetectionEnabled) {
                screenSpaceOutlineMaterial.EnableKeyword("DEPTH_DETECTION");
            }

            blurMaterial = new Material(Shader.Find("Hidden/BasicBlur"));    
            blitMaterial = new Material(Shader.Find("Hidden/BlendBlit"));    
            blitMaterial.SetColor("_Color", settings.outlineColor);

            occludersMaterial = new Material(Shader.Find("Hidden/UnlitSingleColor"));
            occludersMaterial.SetColor("_Color", Color.black);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData) {
            RenderTextureDescriptor temporaryTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            temporaryTargetDescriptor.depthBufferBits = 0;
            temporaryTargetDescriptor.colorFormat = RenderTextureFormat.ARGB32;
            temporaryTargetDescriptor.width = (int)(temporaryTargetDescriptor.width * textureResolutionScale);
            temporaryTargetDescriptor.height = (int)(temporaryTargetDescriptor.height * textureResolutionScale);
            
            RenderingUtils.ReAllocateIfNeeded(ref temporaryBuffer, temporaryTargetDescriptor, FilterMode.Bilinear, name: "_TemporaryBuffer");
            RenderingUtils.ReAllocateIfNeeded(ref temporaryBuffer2, temporaryTargetDescriptor, FilterMode.Bilinear, name: "_TemporaryBuffer2");

            cameraColorTarget = renderingData.cameraData.renderer.cameraColorTargetHandle;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData) {         
            if (!screenSpaceOutlineMaterial)
                return;

            if (cameraColorTarget.rt == null)
            {
                return;
            }

            CommandBuffer cmd = CommandBufferPool.Get();
            using (new ProfilingScope(cmd, new ProfilingSampler("ScreenSpaceOutlines"))) {
                // draw outlines
                Blit(cmd, cameraColorTarget, temporaryBuffer2, screenSpaceOutlineMaterial);
                
                // remove ocluded outlines
                //DrawingSettings drawSettings = CreateDrawingSettings(shaderTagIdList, ref renderingData, renderingData.cameraData.defaultOpaqueSortFlags);
                //drawSettings.overrideMaterial = occludersMaterial;
                //context.DrawRenderers(renderingData.cullResults, ref drawSettings, ref occluderFilteringSettings);

                if(blurEnabled || ((double)blurIntensity).AboutEquals(0)) {
                    // horizontal blur
                    cmd.SetGlobalVector("offsets", new Vector4(2.0f/Screen.width * blurIntensity,0,0,0));
                    Blit (cmd, temporaryBuffer2, temporaryBuffer, blurMaterial);
                    // vertical blur
                    cmd.SetGlobalVector("offsets", new Vector4(0,2.0f/Screen.height * blurIntensity,0,0));
                    Blit (cmd, temporaryBuffer, temporaryBuffer2, blurMaterial);
                    // horizontal blur
                    cmd.SetGlobalVector("offsets", new Vector4(4.0f/Screen.width * blurIntensity,0,0,0));
                    Blit (cmd, temporaryBuffer2, temporaryBuffer, blurMaterial);
                    // vertical blur
                    cmd.SetGlobalVector("offsets", new Vector4(0,4.0f/Screen.height * blurIntensity,0,0));
                    Blit(cmd, temporaryBuffer, temporaryBuffer2, blurMaterial);
                }
                
                cmd.SetGlobalTexture("_SecondTex", temporaryBuffer2);
                Blit(cmd, cameraColorTarget, temporaryBuffer);
                Blit(cmd, temporaryBuffer, cameraColorTarget, blitMaterial);
            }

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd) {
        }

        public void Dispose() {
            temporaryBuffer?.Release();
            temporaryBuffer2?.Release();
        }

    }

    [SerializeField] private RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    [SerializeField] private LayerMask outlinesLayerMask;
    [SerializeField] private LayerMask outlinesOccluderLayerMask;

    [SerializeField] private float textureResolutionScale = 1.0f;
    
    [SerializeField] private ScreenSpaceOutlineSettings outlineSettings = new ScreenSpaceOutlineSettings();
    [SerializeField] private ViewSpaceNormalsTextureSettings viewSpaceNormalsTextureSettings = new ViewSpaceNormalsTextureSettings();

    private ViewSpaceNormalsTexturePass viewSpaceNormalsTexturePass;
    private ScreenSpaceOutlinePass screenSpaceOutlinePass;
   // private BlurPass blurPass;
    
    public override void Create() {
       shaderTagIdList = new List<ShaderTagId> {
        new("UniversalForward"),
        new("UniversalForwardOnly"),
        new("LightweightForward"),
        new("SRPDefaultUnlit")
    };

        if (renderPassEvent < RenderPassEvent.BeforeRenderingPrePasses)
            renderPassEvent = RenderPassEvent.BeforeRenderingPrePasses;

        viewSpaceNormalsTexturePass = new ViewSpaceNormalsTexturePass(renderPassEvent, outlinesLayerMask, outlinesOccluderLayerMask, viewSpaceNormalsTextureSettings, textureResolutionScale);
        screenSpaceOutlinePass = new ScreenSpaceOutlinePass(renderPassEvent, outlinesOccluderLayerMask, outlineSettings, textureResolutionScale);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData) {
        renderer.EnqueuePass(viewSpaceNormalsTexturePass);
        renderer.EnqueuePass(screenSpaceOutlinePass);
    }

}

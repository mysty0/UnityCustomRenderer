using System.Collections.Generic;

using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;

public class ScreenSpaceOutlines : ScriptableRendererFeature {

    [System.Serializable]
    private class ScreenSpaceOutlineSettings {

        [Header("General Outline Settings")]
        public Color outlineColor = Color.black;
        [Range(0.0f, 20.0f)]
        public float outlineScale = 1.0f;
        public float blurIntensity = 0.1f;
        
        [Header("Depth Settings")]
        [Range(0.0f, 100.0f)]
        public float depthThreshold = 1.5f;
        [Range(0.0f, 500.0f)]
        public float robertsCrossMultiplier = 100.0f;

        [Header("Normal Settings")]
        [Range(0.0f, 1.0f)]
        public float normalThreshold = 0.4f;

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

    private class ViewSpaceNormalsTexturePass : ScriptableRenderPass {

        private ViewSpaceNormalsTextureSettings normalsTextureSettings;
        private FilteringSettings filteringSettings;
        private FilteringSettings occluderFilteringSettings;

        private readonly List<ShaderTagId> shaderTagIdList;
        private readonly Material normalsMaterial;
        private readonly Material occludersMaterial;

        private RTHandle normals;
        
        int normalsId = Shader.PropertyToID("_SceneViewSpaceNormals");

        public ViewSpaceNormalsTexturePass(RenderPassEvent renderPassEvent, LayerMask layerMask, LayerMask occluderLayerMask, ViewSpaceNormalsTextureSettings settings) {
            this.renderPassEvent = renderPassEvent;
            normalsTextureSettings = settings;
            filteringSettings = new FilteringSettings(RenderQueueRange.opaque, layerMask);
            occluderFilteringSettings = new FilteringSettings(RenderQueueRange.opaque, occluderLayerMask);

            shaderTagIdList = new List<ShaderTagId> {
                new("UniversalForward"),
                new("UniversalForwardOnly"),
                new("LightweightForward"),
                new("SRPDefaultUnlit")
            };

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

        RTHandle cameraColorTarget;

        RTHandle outlinesBuffer;
        int outlinesBufferId = Shader.PropertyToID("_Outlines");

        RTHandle temporaryBuffer;
        RTHandle temporaryBuffer2;

        float blurIntensity;

        public ScreenSpaceOutlinePass(RenderPassEvent renderPassEvent, ScreenSpaceOutlineSettings settings) {
            this.renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;

            blurIntensity = settings.blurIntensity;

            screenSpaceOutlineMaterial = new Material(Shader.Find("Hidden/BlitOutlines"));
            screenSpaceOutlineMaterial.SetColor("_OutlineColor", settings.outlineColor);
            screenSpaceOutlineMaterial.SetFloat("_OutlineScale", settings.outlineScale);

            screenSpaceOutlineMaterial.SetFloat("_DepthThreshold", settings.depthThreshold);
            screenSpaceOutlineMaterial.SetFloat("_RobertsCrossMultiplier", settings.robertsCrossMultiplier);

            screenSpaceOutlineMaterial.SetFloat("_NormalThreshold", settings.normalThreshold);

            screenSpaceOutlineMaterial.SetFloat("_SteepAngleThreshold", settings.steepAngleThreshold);
            screenSpaceOutlineMaterial.SetFloat("_SteepAngleMultiplier", settings.steepAngleMultiplier);

            blurMaterial = new Material(Shader.Find("Hidden/BasicBlur"));    
            blitMaterial = new Material(Shader.Find("Hidden/BlendBlit"));    
            blitMaterial.SetColor("_Color", settings.outlineColor);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData) {
            RenderTextureDescriptor temporaryTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            temporaryTargetDescriptor.depthBufferBits = 0;
            temporaryTargetDescriptor.colorFormat = RenderTextureFormat.ARGB32;
            RenderingUtils.ReAllocateIfNeeded(ref temporaryBuffer, temporaryTargetDescriptor, FilterMode.Bilinear, name: "_TemporaryBuffer");
            RenderingUtils.ReAllocateIfNeeded(ref temporaryBuffer2, temporaryTargetDescriptor, FilterMode.Bilinear, name: "_TemporaryBuffer2");

            cameraColorTarget = renderingData.cameraData.renderer.cameraColorTargetHandle;

        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData) {         
            if (!screenSpaceOutlineMaterial)
                return;

            CommandBuffer cmd = CommandBufferPool.Get();
            using (new ProfilingScope(cmd, new ProfilingSampler("ScreenSpaceOutlines"))) {
                Blit(cmd, cameraColorTarget, temporaryBuffer2, screenSpaceOutlineMaterial);


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
    
    [SerializeField] private ScreenSpaceOutlineSettings outlineSettings = new ScreenSpaceOutlineSettings();
    [SerializeField] private ViewSpaceNormalsTextureSettings viewSpaceNormalsTextureSettings = new ViewSpaceNormalsTextureSettings();

    private ViewSpaceNormalsTexturePass viewSpaceNormalsTexturePass;
    private ScreenSpaceOutlinePass screenSpaceOutlinePass;
   // private BlurPass blurPass;
    
    public override void Create() {
        if (renderPassEvent < RenderPassEvent.BeforeRenderingPrePasses)
            renderPassEvent = RenderPassEvent.BeforeRenderingPrePasses;

        viewSpaceNormalsTexturePass = new ViewSpaceNormalsTexturePass(renderPassEvent, outlinesLayerMask, outlinesOccluderLayerMask, viewSpaceNormalsTextureSettings);
        screenSpaceOutlinePass = new ScreenSpaceOutlinePass(renderPassEvent, outlineSettings);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData) {
        renderer.EnqueuePass(viewSpaceNormalsTexturePass);
        renderer.EnqueuePass(screenSpaceOutlinePass);
    }

}

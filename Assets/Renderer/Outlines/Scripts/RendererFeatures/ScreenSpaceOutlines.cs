using System.Collections;
using System.Collections.Generic;

using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Experimental.Rendering;

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

           // normals = RTHandles.Alloc("_SceneViewSpaceNormals", name: "_SceneViewSpaceNormals");//.Init("_SceneViewSpaceNormals");
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
            //RenderingUtils.ReAllocateIfNeeded(ref normals, normalsTextureDescriptor, name: "_SceneViewSpaceNormals", filterMode: normalsTextureSettings.filterMode);
            normals = RTHandles.Alloc("_SceneViewSpaceNormals", name: "_SceneViewSpaceNormals");
            cmd.GetTemporaryRT(normalsId, normalsTextureDescriptor, FilterMode.Bilinear);
           // cmd.GetTemporaryRT(Shader.PropertyToID(normals.name), normalsTextureDescriptor, normalsTextureSettings.filterMode);

            ConfigureTarget(normals);
            //Debug.Log(normals.nameID);
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
                
                //cmd.SetRenderTarget(normals);
                
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
                //    screenSpaceOutlineMaterial = new Material(Shader.Find("BlitTest"));
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData) {
            RenderTextureDescriptor temporaryTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            temporaryTargetDescriptor.depthBufferBits = 0;
            temporaryTargetDescriptor.colorFormat = RenderTextureFormat.ARGB32;
            RenderingUtils.ReAllocateIfNeeded(ref temporaryBuffer, temporaryTargetDescriptor, FilterMode.Bilinear, name: "_TemporaryBuffer");
            RenderingUtils.ReAllocateIfNeeded(ref temporaryBuffer2, temporaryTargetDescriptor, FilterMode.Bilinear, name: "_TemporaryBuffer2");
           // RenderingUtils.ReAllocateIfNeeded(ref outlinesBuffer, temporaryTargetDescriptor, FilterMode.Bilinear, name: "_Outlines");
            
           // outlinesBuffer = RTHandles.Alloc("_Outlines", name: "_Outlines");
           // cmd.GetTemporaryRT(outlinesBufferId, temporaryTargetDescriptor, FilterMode.Bilinear);

            //temporaryBuffer = RTHandles.Alloc(temporaryTargetDescriptor, name: "_TemporaryBuffer", filterMode: FilterMode.Bilinear);//RTHandles.Alloc("_TemporaryBuffer", name: "_TemporaryBuffer");
            //cmd.GetTemporaryRT(Shader.PropertyToID(temporaryBuffer.name), temporaryTargetDescriptor, FilterMode.Bilinear);
            //temporaryBuffer = RTHandles.Alloc(temporaryBufferID);//new RenderTargetIdentifier(temporaryBufferID);

            cameraColorTarget = renderingData.cameraData.renderer.cameraColorTargetHandle;

            //ConfigureTarget(outlinesBuffer);
            //ConfigureClear(ClearFlag.All, Color.clear);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData) {
           // if (cameraColorTarget.rt == null) {
            //    Debug.Log("Camera rt null idk why");
           //     return;
           // }
            
            if (!screenSpaceOutlineMaterial)
                return;

            CommandBuffer cmd = CommandBufferPool.Get();
            using (new ProfilingScope(cmd, new ProfilingSampler("ScreenSpaceOutlines"))) {
                //Debug.Log(outlinesBuffer.rt);
               // Debug.Log(temporaryBuffer.rt);
                //Debug.Log(cameraColorTarget.rt.filterMode);
                //Blit(cmd, cameraColorTarget, outlinesBuffer);
                //Debug.Log(temporaryBuffer.rt);
                //cmd.ClearRenderTarget(true, true, Color.yellow);
               // Blit(cmd, outlinesBuffer, temporaryBuffer, screenSpaceOutlineMaterial);
                //CoreUtils.DrawFullScreen(cmd, screenSpaceOutlineMaterial);
               // cmd.SetRenderTarget(cameraColorTarget);
                //cmd.ClearRenderTarget(true, true, Color.red);
                //cmd.Blit(temporaryBuffer, cameraColorTarget, screenSpaceOutlineMaterial);
               // cmd.SetRenderTarget(temporaryBuffer);
               // cmd.ClearRenderTarget(true, true, Color.clear);
                //cmd.Blit(cameraColorTarget, temporaryBuffer);
                //Blitter.BlitCameraTexture(cmd, temporaryBuffer, cameraColorTarget, screenSpaceOutlineMaterial, 0);
                
                // int blurredID = Shader.PropertyToID("_Temp1");
                // int blurredID2 = Shader.PropertyToID("_Temp2");
                // cmd.GetTemporaryRT (blurredID, -2, -2, 0, FilterMode.Bilinear);
                // cmd.GetTemporaryRT (blurredID2, -2, -2, 0, FilterMode.Bilinear);
                
                // // downsample screen copy into smaller RT, release screen RT
                // cmd.Blit (screenCopyID, blurredID);
                // cmd.ReleaseTemporaryRT (screenCopyID); 
                
              
                //int blurredID = Shader.PropertyToID("_Temp1");
                //cmd.GetTemporaryRT(blurredID, Screen.width, Screen.height, 0, FilterMode.Bilinear);
              //  cmd.Blit(temporaryBuffer, blurredID, screenSpaceOutlineMaterial);
                //cmd.SetRenderTarget(temporaryBuffer);
                //cmd.ClearRenderTarget(true, true, Color.white);
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

               // Blitter.BlitCameraTexture(cmd, cameraColorTarget, cameraColorTarget, screenSpaceOutlineMaterial, 0);

            }

            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd) {
           //cmd.ReleaseTemporaryRT(outlinesBufferId);
        }

        public void Dispose() {
            temporaryBuffer?.Release();
            temporaryBuffer2?.Release();
        }

    }

    //  private class BlurPass : ScriptableRenderPass {

    //     private readonly Material blurMaterial;

    //     RTHandle cameraColorTarget;

    //     RTHandle temporaryBuffer;

    //     public BlurPass(RenderPassEvent renderPassEvent) {
    //         this.renderPassEvent = renderPassEvent;

    //         blurMaterial = new Material(Shader.Find("Hidden/BasicBlur"));            
    //     }

    //     public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData) {
    //         RenderTextureDescriptor temporaryTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
    //         temporaryTargetDescriptor.depthBufferBits = 0;
    //         RenderingUtils.ReAllocateIfNeeded(ref temporaryBuffer, temporaryTargetDescriptor, FilterMode.Bilinear, name: "_TemporaryBuffer");

    //         cameraColorTarget = renderingData.cameraData.renderer.cameraColorTargetHandle;
    //     }

    //     public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData) {
    //         if (cameraColorTarget.rt == null) {
    //             Debug.Log("Camera rt null idk why");
    //             return;
    //         }
            
    //         if (!blurMaterial)
    //             return;

    //         CommandBuffer cmd = CommandBufferPool.Get();
    //         using (new ProfilingScope(cmd, new ProfilingSampler("BlurOutlines"))) {
    //             Blit(cmd, cameraColorTarget, temporaryBuffer);
    //             Blit(cmd, temporaryBuffer, temporaryBuffer, blurMaterial);
    //         }

    //         context.ExecuteCommandBuffer(cmd);
    //         cmd.Clear();
    //         CommandBufferPool.Release(cmd);
    //     }

    //     public override void OnCameraCleanup(CommandBuffer cmd) {
    //        // cmd.ReleaseTemporaryRT(temporaryBufferID);
    //     }

    //     public void Dispose() {
    //         temporaryBuffer?.Release();
    //     }

    // }

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
     //   blurPass = new BlurPass(renderPassEvent);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData) {
        renderer.EnqueuePass(viewSpaceNormalsTexturePass);
        renderer.EnqueuePass(screenSpaceOutlinePass);
      //  renderer.EnqueuePass(blurPass);
    }

}

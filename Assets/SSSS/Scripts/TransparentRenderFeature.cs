using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class TransparentRenderFeature : ScriptableRendererFeature
{
    
    private sealed class HairTransparentPass : ScriptableRenderPass
    {
        private static readonly ShaderTagId HairTag = new ShaderTagId("HairTransparent");
        private FilteringSettings filteringSettings;

        public HairTransparentPass(LayerMask layerMask)
        {
            // 头发材质可能放在 Opaque 或 AlphaTest 队列，
            // 用 all 避免被 Transparent 队列过滤掉。
            filteringSettings = new FilteringSettings(RenderQueueRange.all, layerMask.value);
        }
        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            DrawingSettings drawingSettings = CreateDrawingSettings(HairTag, ref renderingData, SortingCriteria.CommonTransparent);
            
            context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref filteringSettings);
        }
    }
    
    [SerializeField] private LayerMask hairLayer = ~0;
    private HairTransparentPass pass;
    
    public override void Create()
    {
        pass = new HairTransparentPass(hairLayer)
        {
            renderPassEvent = RenderPassEvent.AfterRenderingTransparents
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(pass);
    }
}

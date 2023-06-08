using System;
using UnityEngine;
using UnityEngine.Rendering;
using System.Collections.Generic;
using Object = UnityEngine.Object;

[ExecuteInEditMode]
public class SmoothNormals : MonoBehaviour
{
	public Shader blurShader;
	private Material _material;
	private Material _normalMaterial;
	Renderer _objectRenderer;

	//private Camera _cam;

	// We'll want to add a command buffer on any camera that renders us,
	// so have a dictionary of them.
	private Dictionary<Camera, CommandBuffer> _cameras = new();

	private void Start()
	{
		_normalMaterial = new Material(Shader.Find("Custom/NormalShader"));
		_objectRenderer = GetComponent<MeshRenderer>();
	}

	// Remove command buffers from all cameras we added into
	private void Cleanup()
	{
		foreach (var cam in _cameras)
		{
			if (cam.Key)
			{
				cam.Key.RemoveCommandBuffer (CameraEvent.AfterSkybox, cam.Value);
			}
		}
		_cameras.Clear();
		Object.DestroyImmediate (_material);
	}

	public void OnEnable()
	{
		Cleanup();
	}

	public void OnDisable()
	{
		Cleanup();
	}

	// Whenever any camera will render us, add a command buffer to do the work on it
	public void OnWillRenderObject()
	{
		var act = gameObject.activeInHierarchy && enabled;
		if (!act)
		{
			Cleanup();
			return;
		}
		
		var cam = Camera.current;
		if (!cam)
			return;

		CommandBuffer buf = null;
		// Did we already add the command buffer on this camera? Nothing to do then.
		if (_cameras.ContainsKey(cam))
			return;

		if (!_material)
		{
			_material = new Material(blurShader);
			_material.hideFlags = HideFlags.HideAndDontSave;
		}

		buf = new CommandBuffer();
		buf.name = "Grab screen and blur";
		_cameras[cam] = buf;
		
		/*buf.SetRenderTarget(BuiltinRenderTextureType.CameraTarget);
		buf.ClearRenderTarget(true, true, Color.red, 1f);
		cam.AddCommandBuffer (CameraEvent.AfterEverything, buf);
		return;*/
		
		/*var normalTextureId = Shader.PropertyToID("_NormalTexture");
		var normalTexture = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.ARGB32);
		buf.GetTemporaryRT(normalTextureId, normalTexture.descriptor);
		buf.SetRenderTarget(normalTextureId);
		buf.ClearRenderTarget(true, true, Color.clear);
		buf.DrawRenderer(_objectRenderer, _normalMaterial);
		cam.AddCommandBuffer (CameraEvent.BeforeForwardOpaque, buf);


		return;*/

		// copy screen into temporary RT
		var screenCopyID = Shader.PropertyToID("_ScreenCopyTexture");//_CameraNormalsTexture _ScreenCopyTexture
		buf.GetTemporaryRT (screenCopyID, -1, -1, 0, FilterMode.Bilinear);
		buf.Blit (BuiltinRenderTextureType.CurrentActive, screenCopyID);
		buf.SetGlobalTexture("_BlurNormalsTexture", screenCopyID);
		
		// get two smaller RTs
		var blurredID = Shader.PropertyToID("_Temp1");
		var blurredID2 = Shader.PropertyToID("_Temp2");
		buf.GetTemporaryRT (blurredID, -2, -2, 0, FilterMode.Bilinear);
		buf.GetTemporaryRT (blurredID2, -2, -2, 0, FilterMode.Bilinear);
		
		// downsample screen copy into smaller RT, release screen RT
		buf.Blit (screenCopyID, blurredID);
		buf.ReleaseTemporaryRT (screenCopyID); 
		
		// horizontal blur
		buf.SetGlobalVector("offsets", new Vector4(2.0f/Screen.width,0,0,0));
		buf.Blit (blurredID, blurredID2, _material);
		// vertical blur
		buf.SetGlobalVector("offsets", new Vector4(0,2.0f/Screen.height,0,0));
		buf.Blit (blurredID2, blurredID, _material);
		// horizontal blur
		buf.SetGlobalVector("offsets", new Vector4(4.0f/Screen.width,0,0,0));
		buf.Blit (blurredID, blurredID2, _material);
		// vertical blur
		buf.SetGlobalVector("offsets", new Vector4(0,4.0f/Screen.height,0,0));
		buf.Blit (blurredID2, blurredID, _material);

	//	buf.SetGlobalTexture("_BlurNormalsTexture", blurredID);

		cam.AddCommandBuffer (CameraEvent.AfterSkybox, buf);
	}	
}

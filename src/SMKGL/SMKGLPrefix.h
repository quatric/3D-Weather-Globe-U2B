// Shared declarations for the SMKGL sources.
#import "WGSystem.h"
#include "SMK_GL_math.h"


@class SMK_GL_2DTexture;
@class SMK_GL_BaseTexture;
@class SMK_GL_Camera;
@class SMK_GL_Config;
@class SMK_GL_Context;
@class SMK_GL_Control;
@class SMK_GL_CubeTexture;
@class SMK_GL_Drawable;
@class SMK_GL_Font;
@class SMK_GL_FragmentProgram;
@class SMK_GL_GenericBuffer;
@class SMK_GL_IndexBuffer;
@class SMK_GL_Light;
@class SMK_GL_Material;
@class SMK_GL_Mesh;
@class SMK_GL_MeshPart;
@class SMK_GL_Object;
@class SMK_GL_ObjectsContainer;
@class SMK_GL_OrthoCamera;
@class SMK_GL_ParticlesRepresentation;
@class SMK_GL_ParticlesSolver;
@class SMK_GL_ParticlesSystem;
@class SMK_GL_Program;
@class SMK_GL_RenderTarget;
@class SMK_GL_Scene;
@class SMK_GL_StaticText;
@class SMK_GL_StaticTextCaptionID;
@class SMK_GL_TextureCore;
@class SMK_GL_VertexBuffer;
@class SMK_GL_VertexProgram;
@class SMK_GL_View;
@class SMK_GL_VolumeTexture;
@class WindowTransformer;
@class _CocoaLayerView;
@class _PlaneScene;
@class _SMK_GL_BufferImp;
@class _SMK_GL_BufferImpGeneric;
@class _SMK_GL_BufferImpVAR;
@class _SMK_GL_BufferImpVBO;
@class _TransformWindow;
@class _Transform_GL_View;
@class _TransformerScene;

struct SMKGL_anon11 {
    float f0;
    unsigned int f1;
    unsigned int f2;
    unsigned int f3;
    unsigned int f4;
    unsigned int f5;
    unsigned int f6;
};

// a texture pixel format and the bitmap layout it is made from
typedef struct SMK_GL_TexFormat {
    unsigned int bitsPerSample;
    unsigned int samplesPerPixel;
    unsigned int bitsPerPixel;
    unsigned int components;    // four-character tag: 'rgba', 'gray', 'argb', 'luma', 'mask'
    unsigned int internalFormat;
    unsigned int compactInternalFormat;
    unsigned int format;
    unsigned int type;
} SMK_GL_TexFormat;
#define SMKGL_anon12 SMK_GL_TexFormat


// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Buffers.m
#import "SMKGLPrefix.h"

// vertex formats: which components each vertex has, in this order
enum {
	kSMK_GL_FVF_Position = 0x002,     // 3 floats
	kSMK_GL_FVF_Normal = 0x010,       // 3 floats
	kSMK_GL_FVF_Diffuse = 0x040,      // 4 unsigned bytes
	kSMK_GL_FVF_Specular = 0x080,     // 4 unsigned bytes (secondary color)
	kSMK_GL_FVF_TexCoordMask = 0xf00, // number of 2-float texture coordinate sets
	kSMK_GL_FVF_TexCoordShift = 8,
};
#define SMK_GL_FVF_TEXCOORDS(n) ((n) << kSMK_GL_FVF_TexCoordShift)

// buffer usage; the low 12 bits are the GL usage hint
enum {
	kSMK_GL_UsageStatic = 0,
	kSMK_GL_UsageDynamic = 1,
	kSMK_GL_UsageStream = 2,
	kSMK_GL_UsageSystemMemory = 0x1000,
};

// lock: types
enum {
	kSMK_GL_LockReadWrite = 0,
	kSMK_GL_LockReadOnly = 1,
	kSMK_GL_LockWriteOnly = 2,
};
#import "SMK_GL_object.h"


@interface SMK_GL_GenericBuffer : SMK_GL_Object
{
    unsigned int _count;
    unsigned int _elementSize;
    int _usage;
    NSMutableData *_bufferData;
    _SMK_GL_BufferImp *_bufferImp;
    void *_lockedPointer;
    BOOL _updateOnUnlock;
    BOOL _autoUpdateBounds;
    BOOL _requiresVAO;
    unsigned int _vertexArrayObject;
}
- (BOOL)isDirty;
- (void)stopDrawing;
- (void)startDrawing;
- (void)unbind;
- (void)rebind;
- (void)bind;
- (void)unlock;
- (void *)lock:(NSInteger)aLock;
- (void)contextWillBeDetached;
- (NSUInteger)length;
- (NSInteger)usage;
- (NSUInteger)elementSize;
- (NSUInteger)count;
- (void)dealloc;
- (id)initWithContainer:(id)aContainer count:(NSUInteger)aCount elementSize:(NSUInteger)aSize usage:(NSInteger)aUsage;
@end

@interface SMK_GL_IndexBuffer : SMK_GL_GenericBuffer
{
    BOOL _drawRangeElements;
    BOOL _elementArrayAPPLE;
    unsigned int _indexType;
    void *_boundPointer;
    unsigned int _minIndex;
    unsigned int _maxIndex;
}
- (void)drawInMode:(NSUInteger)aMode first:(NSUInteger)aFirst count:(NSUInteger)aCount;
- (void)contextWillBeDetached;
- (void)contextWasAttached:(id)aAttached;
- (void)unbind;
- (void)bind;
- (void)_updateBufferBounds;
- (NSUInteger)indicesCount;
- (NSUInteger)maxIndex;
- (NSUInteger)minIndex;
- (BOOL)are32BitIndices;
- (NSUInteger)indexType;
- (id)initWithContainer:(id)aContainer count:(NSUInteger)aCount usage:(NSInteger)aUsage indexType:(NSUInteger)aType;
- (id)initWithContainer:(id)aContainer count:(NSUInteger)aCount usage:(NSInteger)aUsage;
@end

@interface SMK_GL_VertexBuffer : SMK_GL_GenericBuffer
{
    unsigned int _fvf;
    SMK_GL_Vec3 _minCorner;
    SMK_GL_Vec3 _maxCorner;
}
+ (NSUInteger)vertexSizeForFVF:(NSUInteger)aFVF;
- (void)_unbindPointers;
- (void)_bindPointers:(char *)aPointers;
- (void)_updateBufferBounds;
- (SMK_GL_Vec3 *)maxCorner;
- (SMK_GL_Vec3 *)minCorner;
- (void)setAutoUpdateBounds:(BOOL)aBounds;
- (void)drawNonIndexedInMode:(NSUInteger)aMode first:(NSUInteger)aFirst count:(NSUInteger)aCount;
- (void)contextWillBeDetached;
- (void)contextWasAttached:(id)aAttached;
- (NSUInteger)vertexSize;
- (NSUInteger)fvf;
- (id)initWithContainer:(id)aContainer count:(NSUInteger)aCount usage:(NSInteger)aUsage fvf:(NSUInteger)aFvf;
@end

@interface _SMK_GL_BufferImp : NSObject
{
}
- (void)unlock:(NSRange)aUnlock;
- (void *)lock:(NSUInteger)aLock;
- (void)unbind;
- (void *)rebind;
- (void *)bind;
- (BOOL)isDirty;
- (void)stopDrawing;
- (void)startDrawing;
@end

@interface _SMK_GL_BufferImpGeneric : _SMK_GL_BufferImp
{
    NSMutableData *_data;
}
- (void)unlock:(NSRange)aUnlock;
- (void *)lock:(NSInteger)aLock;
- (void)unbind;
- (void *)bind;
- (void)dealloc;
- (id)initWithData:(id)aData capacity:(NSUInteger)aCapacity;
@end

@interface _SMK_GL_BufferImpVAR : _SMK_GL_BufferImp
{
    SMK_GL_Context *_context;
    int _usage;
    unsigned int _target;
    unsigned int _bufferFences[4];
    NSRange _bufferRanges[4];
    int _currentBufferIndex;
    BOOL _isDirty;
}
- (void)unlock:(NSRange)aUnlock;
- (void *)lock:(NSInteger)aLock;
- (void)unbind;
- (void *)rebind;
- (void *)bind;
- (BOOL)isDirty;
- (void)stopDrawing;
- (void)startDrawing;
- (void)dealloc;
- (id)initWithData:(id)aData capacity:(NSUInteger)aCapacity target:(NSUInteger)aTarget usage:(NSInteger)aUsage context:(id)aContext;
@end

@interface _SMK_GL_BufferImpVBO : _SMK_GL_BufferImp
{
    unsigned int _object;
    unsigned int _target;
    SMK_GL_Context *_ctx;
}
- (void)unlock:(NSRange)aUnlock;
- (void *)lock:(NSInteger)aLock;
- (void)unbind;
- (void *)bind;
- (void)dealloc;
- (id)initWithData:(id)aData capacity:(NSUInteger)aCapacity target:(NSUInteger)aTarget usage:(NSInteger)aUsage context:(id)aContext;
@end


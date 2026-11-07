// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Textures.m
#import "SMKGLPrefix.h"
#import "SMK_GL_TextureCore.h"

// texture flags
enum {
	kSMK_GL_TextureNo2DRectangle = 0x1,
	kSMK_GL_TextureMipmaps = 0x2,
	kSMK_GL_TextureReflectionMap = 0x10000,  // cube textures: generate reflection coordinates
};
// texture usage
enum {
	kSMK_GL_TextureUsageShared = 0x1,  // storage hint for rectangle textures
};


@interface SMK_GL_BaseTexture : SMK_GL_TextureCore
{
    const SMK_GL_TexFormat *_format;
    unsigned int _flags;
    int _usage;
    NSRecursiveLock *_locker;
    SMK_GL_Matrix _transformMatrix;
    unsigned int _fence;
    BOOL _useFenceSynchr;
}
+ (const SMK_GL_TexFormat *)_formatForBitmap:(id)aBitmap;
+ (id)_supportedColorSpaces;
+ (id)_supportedFormats;
+ (id)_formatKeyForFormat:(const SMK_GL_TexFormat *)aFormat;
+ (id)_formatKeyForBPS:(NSUInteger)aBPS SPP:(NSUInteger)aSPP BPP:(NSUInteger)aBPP components:(NSUInteger)aComponents;
- (void)unbindAtStage:(NSInteger)aStage;
- (void)bindAtStage:(NSInteger)aStage;
- (BOOL)isDirty;
- (void)unlock;
- (void)lock;
- (void)contextWillBeDetached;
- (void)contextWasAttached:(id)aAttached;
- (void)_deleteTexture;
- (void)_createTexture;
- (void)setTransformMatrix:(const SMK_GL_Matrix *)aMatrix;
- (void)dealloc;
- (id)initWithContainer:(id)aContainer flags:(NSUInteger)aFlags usage:(NSInteger)aUsage;
- (void)_createTextureImage;
@end

@interface SMK_GL_VolumeTexture : SMK_GL_BaseTexture
{
    NSArray *_depthLayers;
    BOOL _rWrapModeChanged;
    unsigned int _rWrapMode;
}
- (void)bindAtStage:(NSInteger)aStage;
- (void)setWrapS:(NSUInteger)aS T:(NSUInteger)aT R:(NSUInteger)aR;
- (void)_createTextureImage;
- (NSUInteger)textureTarget;
- (void)dealloc;
- (id)initWithContainer:(id)aContainer flags:(NSUInteger)aFlags usage:(NSInteger)aUsage filePaths:(id)aPaths;
@end

@interface SMK_GL_CubeTexture : SMK_GL_BaseTexture
{
    NSString *_xPosFilePath;
    NSString *_xNegFilePath;
    NSString *_yPosFilePath;
    NSString *_yNegFilePath;
    NSString *_zPosFilePath;
    NSString *_zNegFilePath;
}
- (void)unbindAtStage:(NSInteger)aStage;
- (void)bindAtStage:(NSInteger)aStage;
- (void)_createTextureImage;
- (NSUInteger)textureTarget;
- (void)dealloc;
- (id)initWithContainer:(id)aContainer flags:(NSUInteger)aFlags usage:(NSInteger)aUsage xPosPath:(id)aPath xNegPath:(id)aPath2 yPosPath:(id)aPath3 yNegPath:(id)aPath4 zPosPath:(id)aPath5 zNegPath:(id)aPath6;
@end

@interface SMK_GL_2DTexture : SMK_GL_BaseTexture
{
    BOOL _rectangleExt;
    BOOL _alphaFirst;
    BOOL _isSquare;
    BOOL _lockedNotFromTheMainThread;
    NSString *_filePath;
    NSBitmapImageRep *_fileRepresentation;
    int _width;
    int _height;
    int _glTextureWidth;
    int _glTextureHeight;
    int _bitsPerPixel;
    int _bytesPerRow;
    void *_imageData;
    BOOL _wasLockedOnce;
    unsigned int _imagePtrFormat;
    NSWindow *_cocoaDrawingWindow;
    NSImage *_lockedImage;
    struct CGContext *_lockedContext;
    NSMutableData *_threadSafeLoockedData;
}
+ (id)textureForContainer:(id)aContainer flags:(NSUInteger)aFlags usage:(NSInteger)aUsage filePath:(id)aPath;
- (void)unlockFocus;
- (void)lockFocus;
- (void)unlock;
- (struct CGContext *)lockAndCreateCGContextWithClear:(BOOL)aClear;
- (void *)lock;
- (NSInteger)bytesPerRow;
- (NSInteger)bitsPerPixel;
- (NSInteger)height;
- (NSInteger)width;
- (void)_createTextureImage;
- (void)contextWillBeDetached;
- (void)contextWasAttached:(id)aAttached;
- (void)unbindAtStage:(NSInteger)aStage;
- (void)bindAtStage:(NSInteger)aStage;
- (void)_updateTexture;
- (NSUInteger)textureTarget;
- (void)dealloc;
- (id)initWithContainer:(id)aContainer flags:(NSUInteger)aFlags usage:(NSInteger)aUsage width:(NSInteger)aWidth height:(NSInteger)aHeight dataFormat:(NSUInteger)aFormat alphaFirst:(BOOL)aFirst;
- (id)initWithContainer:(id)aContainer flags:(NSUInteger)aFlags usage:(NSInteger)aUsage width:(NSInteger)aWidth height:(NSInteger)aHeight dataFormat:(NSUInteger)aFormat;
- (id)initWithContainer:(id)aContainer flags:(NSUInteger)aFlags usage:(NSInteger)aUsage filePath:(id)aPath;
@end


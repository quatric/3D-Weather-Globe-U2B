// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Mesh.m
#import "SMKGLPrefix.h"


@interface SMK_GL_MeshPart : NSObject
{
    SMK_GL_IndexBuffer *_indexBuffer;
    SMK_GL_Material *_material;
    unsigned int _drawMode;
}
+ (id)meshPartWithIndexBuffer:(id)aBuffer material:(id)aMaterial drawMode:(NSUInteger)aMode;
+ (id)meshPartWithContainer:(id)aContainer indicesUsage:(NSInteger)aUsage indicesCount:(NSUInteger)aCount indicesType:(NSUInteger)aType material:(id)aMaterial drawMode:(NSUInteger)aMode;
- (NSUInteger)primitivesCount;
- (void)drawInContext:(id)aContext;
- (void)setMaterial:(id)aMaterial;
- (id)material;
- (id)indexBuffer;
- (NSUInteger)drawMode;
- (void)dealloc;
- (id)initWithIndexBuffer:(id)aBuffer material:(id)aMaterial drawMode:(NSUInteger)aMode;
- (id)initWithContainer:(id)aContainer indicesUsage:(NSInteger)aUsage indicesCount:(NSUInteger)aCount indicesType:(NSUInteger)aType material:(id)aMaterial drawMode:(NSUInteger)aMode;
@end

@interface SMK_GL_Mesh : NSObject
{
    SMK_GL_VertexBuffer *_vertexBuffer;
    SMK_GL_Material *_defaultMaterial;
    NSMutableArray *_parts;
    BOOL _pointsMesh;
    unsigned int _verticesCount;
}
- (void)drawPart:(NSUInteger)aPart inContext:(id)aContext;
- (void)drawInContext:(id)aContext;
- (void)setMaterial:(id)aMaterial;
- (id)material;
- (void)addPart:(id)aPart;
- (id)allParts;
- (NSUInteger)verticesCount;
- (NSUInteger)primitivesCount;
- (id)indexBuffer;
- (id)vertexBuffer;
- (void)dealloc;
- (id)initWithContainer:(id)aContainer fvf:(NSUInteger)aFvf usage:(NSInteger)aUsage verticesCount:(NSUInteger)aCount primitivesPerPart:(id)aPart primitiveType:(NSUInteger)aType;
- (id)initWithContainer:(id)aContainer fvf:(NSUInteger)aFvf usage:(NSInteger)aUsage verticesCount:(NSUInteger)aCount primitivesCount:(NSUInteger)aCount2 primitiveType:(NSUInteger)aType;
- (id)initWithContainer:(id)aContainer fvf:(NSUInteger)aFvf usage:(NSInteger)aUsage verticesCount:(NSUInteger)aCount meshPart:(id)aPart;
- (id)initWithContainer:(id)aContainer fvf:(NSUInteger)aFvf usage:(NSInteger)aUsage verticesCount:(NSUInteger)aCount meshParts:(id)aParts;
- (id)initWithContainer:(id)aContainer fvf:(NSUInteger)aFvf usage:(NSInteger)aUsage verticesCount:(NSUInteger)aCount partsCapacity:(NSUInteger)aCapacity;
@end

@interface SMK_GL_Mesh (SMK_GL_MeshCreation)
+ (id)createCylinderWithRadius:(CGFloat)aRadius height:(CGFloat)aHeight heightSegments:(NSUInteger)aSegments rSegments:(NSUInteger)aSegments2 container:(id)aContainer fvf:(NSUInteger)aFvf usage:(NSInteger)aUsage;
+ (id)createSpherePartWithParams:(struct SMKGL_anon11 *)aParams container:(id)aContainer fvf:(NSUInteger)aFvf usage:(NSInteger)aUsage;
+ (id)createSphereWithRadius:(CGFloat)aRadius segments:(NSUInteger)aSegments stacks:(NSUInteger)aStacks container:(id)aContainer fvf:(NSUInteger)aFvf usage:(NSInteger)aUsage;
+ (id)createXYPlaneWithRect:(NSRect)aRect xSegments:(NSUInteger)aSegments ySegments:(NSUInteger)aSegments2 container:(id)aContainer fvf:(NSUInteger)aFvf usage:(NSInteger)aUsage;
@end


// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/ASEMeshCreator.m
#import "SMKGLPrefix.h"
#import "SMK_GL_Mesh.h"

// keys of a parsed ASE file property list
extern NSString *kObjectsKey;
extern NSString *kObjectNameKey;
extern NSString *kObjectMatrixKey;
extern NSString *kObjectMaterialKey;
extern NSString *kObjectMeshKey;
extern NSString *kMeshVerticesKey;
extern NSString *kMeshIndicesKey;


@interface SMK_GL_Mesh (ASEMeshCreator)
+ (id)meshWithASEParsedFile:(id)aFile container:(id)aContainer usage:(NSInteger)aUsage fvf:(NSUInteger)aFvf normalize:(BOOL)aNormalize mergeParts:(BOOL)aParts;
@end


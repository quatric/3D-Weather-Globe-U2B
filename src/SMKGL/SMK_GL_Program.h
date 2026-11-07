// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Program.m
#import "SMKGLPrefix.h"
#import "SMK_GL_object.h"


// supplies a program's local parameters, each a run of vec4 constants
@interface NSObject (SMK_GL_ProgramDataSource)
- (NSUInteger)numberOfParametersForProgram:(id)aProgram;
- (NSUInteger)program:(id)aProgram sizeOfParameterAtIndex:(NSUInteger)aIndex;
- (BOOL)program:(id)aProgram fillParameter:(void *)aParameter atIndex:(NSUInteger)aIndex;
@end

@interface SMK_GL_Program : SMK_GL_Object
{
    NSString *_code;
    id _dataSource;
    unsigned int _numConstants;
    unsigned int *_constSizesArray;
    NSMutableData *_constSizes;
    NSMutableData *_constsBuffer;
    unsigned int _program;
}
- (void)unbind;
- (void)bind;
- (void)contextWillBeDetached;
- (void)contextWasAttached:(id)aAttached;
- (NSUInteger)_programTarget;
- (void)dealloc;
- (id)initWithContainer:(id)aContainer string:(id)aString dataSource:(id)aSource;
@end

@interface SMK_GL_FragmentProgram : SMK_GL_Program
{
}
- (NSUInteger)_programTarget;
@end

@interface SMK_GL_VertexProgram : SMK_GL_Program
{
}
- (NSUInteger)_programTarget;
@end


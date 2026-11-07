// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_StaticText.m
#import "SMKGLPrefix.h"


// what a static text expects of its layouter
@interface NSObject (SMK_GL_StaticTextLayouter)
- (BOOL)haveNewLayout;
- (NSPoint)basePointInRectForCaptionAtIndex:(NSUInteger)aIndex;
- (void)setNewPosition:(const SMK_GL_Vec2 *)aPosition forCaptionAtIndex:(NSUInteger)aIndex;
- (void)recordCaptionWithSize:(NSSize)aSize atPosition:(NSPoint)aPosition;
- (void)beginRecordBlockWithFlag:(NSInteger)aFlag;
- (void)endRecordBlock;
@end

@interface SMK_GL_StaticText : NSObject
{
    SMK_GL_ObjectsContainer *_container;
    SMK_GL_Font *_font;
    SMK_GL_VertexBuffer *_vertexBuffer;
    SMK_GL_IndexBuffer *_indexBuffer;
    SMK_GL_Material *_material;
    int _primitivesCount;
    int _charactersCount;
    NSSize _prevContextSize;
    SMK_GL_Vec2 _translationVec;
    SMK_GL_Vec2 _scaleVec;
    int _numChars;
    NSMutableData *_captions;
    NSMutableData *_captionPositions;
    BOOL _dataIsDraft;
    BOOL _recordBlockIsActive;
    NSObject *_layouter;
}
- (void)drawInContext:(id)aContext foreColor:(const SMK_GL_Color *)aColor backColor:(const SMK_GL_Color *)aColor2;
- (void)_setNewPosition:(const SMK_GL_Vec2 *)aPosition forCaptionAtIndex:(NSUInteger)aIndex;
- (void)_recalcBuffersForContextSize:(NSSize)aSize;
- (void)setScale:(const SMK_GL_Vec2 *)aScale;
- (void)setTranslation:(const SMK_GL_Vec2 *)aTranslation;
- (void)setLayouter:(id)aLayouter;
- (id)layouter;
- (void)setNewPosition:(const SMK_GL_Vec2 *)aPosition forCaption:(id)aCaption;
- (NSUInteger)captionsCount;
- (void)endRecordBlock;
- (id)recordCaption:(id)aCaption atPosition:(const SMK_GL_Vec2 *)aPosition outCaptionSize:(NSSize *)aSize;
- (id)recordCaption:(id)aCaption atPosition:(const SMK_GL_Vec2 *)aPosition;
- (void)beginRecordBlockWithLayouterOptions:(NSInteger)aOptions;
- (id)glFont;
- (void)dealloc;
- (id)initWithContainer:(id)aContainer glFont:(id)aFont;
@end

@interface SMK_GL_StaticTextCaptionID : NSObject
{
    unsigned int _index;
    id _object;
}
+ (id)captionIDWithIndex:(NSUInteger)aIndex;
- (void)attachObject:(id)aObject;
- (id)attachedObject;
- (NSUInteger)index;
- (void)dealloc;
@end


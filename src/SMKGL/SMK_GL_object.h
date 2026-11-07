// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_object.m
#import "SMKGLPrefix.h"

extern NSString *kSMK_GL_ObjectsContainerWillDieNotification;


@interface SMK_GL_Object : NSObject
{
    SMK_GL_ObjectsContainer *_container;
    SMK_GL_Context *_context;
}
- (void)contextWillBeDetached;
- (void)contextWasAttached:(id)aAttached;
- (id)context;
- (id)currentContext;
- (void)_markContainerAsDead;
- (void)dealloc;
- (id)initWithContainer:(id)aContainer;
@end

@interface SMK_GL_ObjectsContainer : NSObject
{
    NSMutableSet *_objects;
    NSMutableSet *_accumObjects;
    NSMutableSet *_particleSystems;
    SMK_GL_Context *_context;
    double _currentTime;
}
- (id)context;
- (id)currentContext;
- (void)adjustFrameDependedObjects:(double)aObjects;
- (double)currentFrameTime;
- (void)contextWillBeDetached;
- (void)contextWasAttached:(id)aAttached;
- (void)endAccumulationBlock;
- (void)beginAccumulationBlock;
- (void)removeParticlesSystem:(id)aSystem;
- (void)addParticlesSystem:(id)aSystem;
- (void)removeObject:(id)aObject;
- (void)addObject:(id)aObject;
- (void)dealloc;
- (id)init;
@end


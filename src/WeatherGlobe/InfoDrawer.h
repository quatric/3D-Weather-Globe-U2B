#import "WeatherGlobePrefix.h"


@interface InfoDrawer : NSObject
{
    BaseAtlasScene *_scene;
    SMK_GL_VertexBuffer *_vertexBuffer;
    SMK_GL_IndexBuffer *_indexBuffer;
    unsigned int _iconsNumOnWidth;
    unsigned int _iconsNumOnHeight;
    struct __opaqueLMContext *_layoutManagerContext;
    NSPoint _previousCameraPosition;
    float _previousScale;
    BOOL _dataWasChanged;
}
- (void)_drawDataWasChanged:(id)aChanged;
- (void)drawInfoInContext:(id)aContext;
- (void)dealloc;
- (id)initWithContainer:(id)aContainer scene:(id)aScene;
@end


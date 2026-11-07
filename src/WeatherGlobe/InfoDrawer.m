#import "InfoDrawer.h"

// Draws the weather of the info drawer's cities over the map: a backdrop
// and weather icon at each city, with its temperature and name beside it,
// all laid out by the label layout manager so they don't overlap.

static const SMK_GL_Color _hiliteColor = {1.0f, 1.0f, 1.0f, 1.0f};

// the backdrop is icon 36 of the weather icons texture
static const int _kBackdropIconIndex = 36;

typedef struct IconEntry {
    BOOL enabled;
    const int *index;
    float x, y, width, height;
    float uOffset, uPadding;
} IconEntry;

// a city on screen; one city can show up twice on the flat map
typedef struct ViewPoint {
    float x, y;
    int record;
} ViewPoint;

@implementation InfoDrawer

- (void)_drawDataWasChanged:(id)aChanged
{
    _dataWasChanged = YES;
}

- (void)drawInfoInContext:(id)aContext
{
    if (![Preferences usesInternet] || ![Preferences doShowWeatherOnMap])
        return;
    SMK_GL_Context *context = aContext;
    AtlasPanelController *controller = [_scene sceneController];
    MainWindowController *windowController = [controller windowController];
    [context setFont:[windowController normalFont]];
    SMK_GL_2DTexture *icons = [windowController weatherIconsTexture];
    _iconsNumOnWidth = (unsigned int)((int)[icons width] / 36);
    _iconsNumOnHeight = (unsigned int)((int)[icons height] / 36);
    if (![context isIn2DMode])
        [context enter2DMode];
    [context setVertexBuffer:_vertexBuffer];
    [context setIndexBuffer:_indexBuffer];
    [context setColor:&_hiliteColor];
    glColor4fv(&_hiliteColor.r);
    [icons setEnvMode:GL_REPLACE];
    SMK_GL_Color white = {1.0f, 1.0f, 1.0f, 1.0f};
    [icons setConstantColor:white];

    // sizes of 25 and 18 pixels in normalized view units
    NSRect frame = [[windowController glView] frame];
    float iconHeight = 25.0f / (float)frame.size.height;
    float iconWidth = 25.0f / (float)frame.size.width;
    float backdropHeight = 18.0f / (float)frame.size.height;
    float backdropWidth = 18.0f / (float)frame.size.width;
    NSRect screen = [[NSScreen mainScreen] frame];
    float screenWidth = (float)screen.size.width, screenHeight = (float)screen.size.height;
    if (_layoutManagerContext == NULL)
        _layoutManagerContext = _LMCreate((backdropWidth * 1.7f + backdropWidth) * screenWidth, backdropWidth * screenWidth, 1.6f, 0.53f);

    [context setVertexBuffer:_vertexBuffer];
    [context setIndexBuffer:_indexBuffer];
    [context setTexture:icons atStage:0];
    [context setTexture:nil atStage:1];
    NSSize contextSize = [context size];
    SMK_GL_Font *font = [context currentFont];
    BOOL showsNames = [Preferences showLocationNamesEnabled];
    NSData *drawInfo = [[windowController infoDrawerController] drawInfo];
    const InfoDrawerRecord *records = [drawInfo bytes];
    int recordsCount = (int)([drawInfo length] / sizeof(InfoDrawerRecord));
    int capacity = recordsCount > 0 ? recordsCount : 1;
    IconEntry *entries = malloc(capacity * 2 * sizeof(IconEntry));
    ViewPoint *viewPoints = malloc(capacity * sizeof(ViewPoint));

    // lay the labels out again only when the view or the data changed
    float scale = (float)[controller scale];
    NSPoint position = [controller position];
    BOOL relayout = NO;
    if (fabsf(_previousScale - scale) > 1e-05f
        || fabsf((float)_previousCameraPosition.x - (float)position.x) > 1e-05f
        || fabsf((float)_previousCameraPosition.y - (float)position.y) > 1e-05f
        || _dataWasChanged) {
        _previousScale = scale;
        _previousCameraPosition.y = (float)position.y;
        _previousCameraPosition.x = (float)position.x;
        _dataWasChanged = NO;
        _LMBeginBlock(_layoutManagerContext);
        relayout = YES;
    }
    float iconLabelHeight = screenHeight * (iconWidth + iconWidth * 0.19f);
    float iconLabelWidth = iconWidth * screenWidth;
    int count = 0;
    for (int i = 0; i < recordsCount; i++) {
        const InfoDrawerRecord *record = &records[i];
        NSArray *points = [controller normalizedViewPointsFromMapPoint:_mapPointFromGeoPoint(NSMakePoint(record->x, record->y))];
        int pointsCount = (int)[points count];
        for (int k = 0; k < pointsCount; k++) {
            if (count == capacity) {
                capacity *= 2;
                entries = realloc(entries, capacity * 2 * sizeof(IconEntry));
                viewPoints = realloc(viewPoints, capacity * sizeof(ViewPoint));
            }
            NSPoint p = [[points objectAtIndex:k] pointValue];
            float x = ((float)p.x + (float)p.x) - 1.0f;
            float y = ((float)p.y + (float)p.y) - 1.0f;
            viewPoints[count].x = x;
            viewPoints[count].y = y;
            viewPoints[count].record = i;
            if (relayout) {
                // rectangles 3n, 3n+1, 3n+2: name, temperature and icon
                int base = _LMAddBasePoint(_layoutManagerContext, (x * 0.5f + 0.5f) * screenWidth, (y * 0.5f + 0.5f) * screenHeight);
                NSSize size = _StringSizeForFont(record->name, font, 2.0f / (float)contextSize.width, 2.0f / (float)contextSize.height);
                _LMAddRectangle(_layoutManagerContext, ((backdropWidth * 1.1f + x) * 0.5f + 0.5f) * screenWidth,
                                ((y - backdropHeight) * 0.5f + 0.5f) * screenHeight,
                                screenWidth * (float)size.width, screenHeight * (float)size.height, base);
                size = _StringSizeForFont(record->temperature, font, 2.0f / (float)contextSize.width, 2.0f / (float)contextSize.height);
                _LMAddRectangle(_layoutManagerContext, (x * 0.5f + 0.5f) * screenWidth,
                                ((iconHeight * -0.1f + y + 0.05f) * 0.5f + 0.5f) * screenHeight,
                                screenWidth * (float)size.width, screenHeight * (float)size.height, base);
                _LMAddRectangle(_layoutManagerContext, (((x - iconWidth) - 0.0575f) * 0.5f + 0.5f) * screenWidth,
                                (((y - iconHeight) + 0.0575f) * 0.5f + 0.5f) * screenHeight,
                                iconLabelWidth, iconLabelHeight, base);
            }
            IconEntry *backdrop = &entries[count * 2];
            backdrop->enabled = YES;
            backdrop->index = &_kBackdropIconIndex;
            backdrop->x = x - backdropWidth;
            backdrop->y = y - backdropHeight;
            backdrop->width = backdropWidth + backdropWidth;
            backdrop->height = backdropHeight + backdropHeight;
            backdrop->uOffset = 0.022f;
            backdrop->uPadding = -0.001f;
            IconEntry *icon = &entries[count * 2 + 1];
            icon->enabled = (char)record->imageIndex != 0;
            icon->index = &record->imageIndex;
            icon->x = (x - iconWidth) - 0.0575f;
            icon->y = (y - iconHeight) + 0.0575f;
            icon->width = iconWidth + iconWidth;
            icon->height = iconHeight + iconHeight;
            icon->uOffset = 0.005f;
            icon->uPadding = 0.0f;
            count++;
        }
    }
    if (relayout && count > 0) {
        _LMEndBlock(_layoutManagerContext);
        _LMCalculateLayout(_layoutManagerContext);
    }

    // icons, two quads at a time; weather icons go where the layout put them
    SMK_GL_Color backColor = {0.0f, 0.0f, 0.0f, 1.0f};
    float *vertices = [_vertexBuffer lock:2];
    int iconRectangle = 2;
    int quads = 0;
    for (int n = 0; n < count; n++) {
        for (int k = 0; k < 2; k++) {
            IconEntry *entry = &entries[n * 2 + k];
            if (!entry->enabled)
                continue;
            float x = entry->x, y = entry->y;
            if (k & 1) {
                float rect[4];
                _LMGetRectangle(_layoutManagerContext, iconRectangle, rect);
                _ConvertScreenRectToNormalized(rect, screenWidth, screenHeight);
                x = rect[0];
                y = rect[1];
                iconRectangle += 3;
            }
            _FillVerticesForIcon(&vertices, *entry->index, x, y, entry->width, entry->height,
                                 entry->uOffset, entry->uPadding, _iconsNumOnWidth, _iconsNumOnHeight);
            quads++;
            if (quads > 1) {
                [_vertexBuffer unlock];
                [context drawIndexedInMode:4 first:0 count:quads * 6];
                vertices = [_vertexBuffer lock:2];
                quads = 0;
            }
        }
    }
    [_vertexBuffer unlock];
    if (quads > 0)
        [context drawIndexedInMode:4 first:0 count:quads * 6];
    free(entries);

    // names and temperatures
    int rectangle = 0;
    for (int n = 0; n < count; n++) {
        const InfoDrawerRecord *record = &records[viewPoints[n].record];
        float rect[4];
        _LMGetRectangle(_layoutManagerContext, rectangle, rect);
        _ConvertScreenCoordsToNormalized(rect, screenWidth, screenHeight);
        if (showsNames)
            [context drawString:[NSString stringWithUTF8String:record->name] atPosition:NSMakePoint(rect[0], rect[1]) backColor:&backColor];
        _LMGetRectangle(_layoutManagerContext, rectangle + 1, rect);
        _ConvertScreenCoordsToNormalized(rect, screenWidth, screenHeight);
        [context drawString:[NSString stringWithUTF8String:record->temperature] atPosition:NSMakePoint(rect[0], rect[1]) backColor:&backColor];
        rectangle += 3;
    }
    free(viewPoints);
    [context exit2DMode];
}

- (void)dealloc
{
    [_vertexBuffer release];
    [_indexBuffer release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _LMDestroy(_layoutManagerContext);
    [super dealloc];
}

- (id)initWithContainer:(id)aContainer scene:(id)aScene
{
    self = [super init];
    if (self == nil)
        return nil;
    _scene = aScene;
    [aContainer beginAccumulationBlock];
    // room for two quads
    _vertexBuffer = [[SMK_GL_VertexBuffer alloc] initWithContainer:aContainer count:8 usage:0x1001 fvf:0x102];
    _indexBuffer = [[SMK_GL_IndexBuffer alloc] initWithContainer:aContainer count:12 usage:0x102];
    [aContainer endAccumulationBlock];
    _previousCameraPosition.x = -2147483648.0f;
    _previousCameraPosition.y = -2147483648.0f;
    _previousScale = -2147483648.0f;
    _dataWasChanged = NO;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_drawDataWasChanged:) name:kDrawDataWasChanged object:[[[_scene sceneController] windowController] infoDrawerController]];
    void *indices = [_indexBuffer lock:2];
    BOOL wide = [_indexBuffer are32BitIndices];
    for (int quad = 0; quad < 2; quad++) {
        int first = quad * 4;
        int quadIndices[6] = {first, first + 1, first + 2, first + 1, first + 2, first + 3};
        for (int i = 0; i < 6; i++) {
            if (wide)
                ((uint32_t *)indices)[quad * 6 + i] = quadIndices[i];
            else
                ((uint16_t *)indices)[quad * 6 + i] = (uint16_t)quadIndices[i];
        }
    }
    [_indexBuffer unlock];
    return self;
}

@end

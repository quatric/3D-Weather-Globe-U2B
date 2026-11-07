#import "CloudsMaterial.h"

@implementation CloudsMaterial

- (SMK_GL_2DTexture *)_newFrameTexture
{
    NSSize size = [_manager frameTextureSize];
    NSUInteger format = [_manager frameTextureFormat];
    SMK_GL_2DTexture *texture = [[SMK_GL_2DTexture alloc] initWithContainer:_container flags:0 usage:1 width:(NSInteger)size.width height:(NSInteger)size.height dataFormat:format];
    [texture setWrapS:GL_CLAMP_TO_EDGE T:GL_CLAMP_TO_EDGE];
    return texture;
}

static void _setupInterpolation(SMK_GL_2DTexture *texture)
{
    [texture setCombinerMode:GL_INTERPOLATE];
    [texture setCombinerAlphaMode:GL_INTERPOLATE];
    [texture setCombinerRGBArg0:GL_TEXTURE arg1:GL_PREVIOUS arg2:GL_CONSTANT];
    [texture setCombinerAlphaArg0:GL_TEXTURE arg1:GL_PREVIOUS arg2:GL_CONSTANT];
}

- (void)bind
{
    SMK_GL_Color color = {1.0f, 1.0f, 1.0f, 1.0f};
    if (_textureEastNext != nil || _textureWestNext != nil) {
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        float t = (float)((now - _prevCloudsChangeTime) / (double)(float)[Preferences cloudsAnimationDeltaTime]);
        if (t <= 1.0f) {
            float v = t >= 0.0f ? t : 0.0f;
            color.r = color.g = color.b = color.a = v;
        }
    }
    SMK_GL_2DTexture *next;
    if (_eastMode) {
        [self setTexture:_textureEast atStage:0];
        [self setTexture:_textureEastNext atStage:1];
        next = _textureEastNext;
    } else {
        [self setTexture:_textureWest atStage:0];
        [self setTexture:_textureWestNext atStage:1];
        next = _textureWestNext;
    }
    [next setConstantColor:color];
    [super bind];
}

- (void)checkCloudsTextures
{
    NSInteger framesCount = [_manager framesCount];
    if (framesCount == 0)
        return;
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now - _prevCloudsChangeTime < (double)(float)[Preferences cloudsAnimationDeltaTime])
        return;
    _prevCloudsChangeTime = now;
    _cloudsFrameCount = _cloudsFrameCount % framesCount;
    NSInteger frame = framesCount - 1 - _cloudsFrameCount;
    NSInteger quality = [Preferences cloudsAnimationQuality];
    if (quality != 2) {
        [_textureEastNext release];
        [_textureWestNext release];
        _textureEastNext = nil;
        _textureWestNext = nil;
    }
    if (quality == 0) {
        if (!_cloudsWereChanged)
            return;
        _cloudsWereChanged = NO;
        frame = 0;
    } else {
        _cloudsWereChanged = YES;
    }

    SMK_GL_Matrix matrix;
    matrix_make_identity(&matrix);
    matrix._22 = -1.0f;
    matrix._24 = 1.0f;

    if (_textureEast == nil) {
        [_container beginAccumulationBlock];
        _textureEast = [self _newFrameTexture];
        [_textureEast setEnvMode:GL_MODULATE];
        [_manager updateTexture:_textureEast withContentsOfFrame:frame forEast:YES];
        [_container endAccumulationBlock];
        [_textureEast setTransformMatrix:&matrix];
    } else if (_textureEastNext == nil) {
        [_textureEast setEnvMode:GL_MODULATE];
        [_manager updateTexture:_textureEast withContentsOfFrame:frame forEast:YES];
    } else {
        SMK_GL_2DTexture *tmp = _textureEast;
        _textureEast = _textureEastNext;
        _textureEastNext = tmp;
        [_textureEast setCombinerMode:GL_REPLACE];
        [_textureEast setCombinerAlphaMode:GL_REPLACE];
        _setupInterpolation(_textureEastNext);
    }

    if (_textureWest == nil) {
        [_container beginAccumulationBlock];
        _textureWest = [self _newFrameTexture];
        [_textureWest setEnvMode:GL_MODULATE];
        [_manager updateTexture:_textureWest withContentsOfFrame:frame forEast:NO];
        [_container endAccumulationBlock];
        [_textureWest setTransformMatrix:&matrix];
    } else if (_textureWestNext == nil) {
        [_textureWest setEnvMode:GL_MODULATE];
        [_manager updateTexture:_textureWest withContentsOfFrame:frame forEast:NO];
    } else {
        SMK_GL_2DTexture *tmp = _textureWest;
        _textureWest = _textureWestNext;
        _textureWestNext = tmp;
        [_textureWest setCombinerMode:GL_REPLACE];
        [_textureWest setCombinerAlphaMode:GL_REPLACE];
        _setupInterpolation(_textureWestNext);
    }

    if (framesCount > 1 && quality == 2) {
        NSInteger nextFrame = frame - 1;
        if (nextFrame < 0)
            nextFrame = framesCount - 1;
        if (_textureEastNext == nil) {
            [_container beginAccumulationBlock];
            _textureEastNext = [self _newFrameTexture];
            [_manager updateTexture:_textureEastNext withContentsOfFrame:nextFrame forEast:YES];
            _setupInterpolation(_textureEastNext);
            [_container endAccumulationBlock];
            [_textureEastNext setTransformMatrix:&matrix];
            [_textureEast setCombinerMode:GL_REPLACE];
            [_textureEast setCombinerAlphaMode:GL_REPLACE];
        } else {
            [_manager updateTexture:_textureEastNext withContentsOfFrame:nextFrame forEast:YES];
        }
        if (_textureWestNext == nil) {
            [_container beginAccumulationBlock];
            _textureWestNext = [self _newFrameTexture];
            [_manager updateTexture:_textureWestNext withContentsOfFrame:nextFrame forEast:NO];
            _setupInterpolation(_textureWestNext);
            [_container endAccumulationBlock];
            [_textureWestNext setTransformMatrix:&matrix];
            [_textureWest setCombinerMode:GL_REPLACE];
            [_textureWest setCombinerAlphaMode:GL_REPLACE];
        } else {
            [_manager updateTexture:_textureWestNext withContentsOfFrame:nextFrame forEast:NO];
        }
    }
    _cloudsFrameCount++;
}

- (BOOL)hasTexturesForWest
{
    return _textureWest != nil;
}

- (BOOL)hasTexturesForEast
{
    return _textureEast != nil;
}

- (void)setLightingEnabled:(BOOL)aEnabled
{
    float diffuse;
    if (aEnabled) {
        [self setAmbient:(SMK_GL_Color){0.4f, 0.5f, 0.6f, 1.0f}];
        diffuse = 1.1f;
    } else {
        [self setAmbient:(SMK_GL_Color){1.1f, 1.1f, 1.1f, 1.0f}];
        diffuse = 0.0f;
    }
    [self setDiffuse:(SMK_GL_Color){diffuse, diffuse, diffuse, 1.0f}];
    _isDirty = YES;
}

- (void)setIsEastBinding:(BOOL)aBinding
{
    _eastMode = aBinding;
    _isDirty = YES;
}

- (void)_cloudsTextureSizeWasChanged:(id)aChanged
{
    [self cleanup];
    [self restoreAfterCleanup];
}

- (void)_cloudMapWasDecompressed:(id)aDecompressed
{
    _cloudsWereChanged = YES;
    _isDirty = YES;
}

- (void)restoreAfterCleanup
{
    [_manager restoreAfterCleanup];
    _cloudsWereChanged = YES;
}

- (void)cleanup
{
    [_textureEast release];
    [_textureWest release];
    [_textureEastNext release];
    [_textureWestNext release];
    _textureEast = nil;
    _textureWest = nil;
    _textureEastNext = nil;
    _textureWestNext = nil;
    [_manager cleanup];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_textureEast release];
    [_textureWest release];
    [_textureEastNext release];
    [_textureWestNext release];
    [super dealloc];
}

- (id)initWithContainer:(id)aContainer cloudsManager:(id)aManager
{
    self = [super initWithContainer:aContainer];
    if (self != nil) {
        _manager = aManager;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_cloudMapWasDecompressed:) name:SingleCloudMapWasDecompressedNotification object:nil];
        [self setLightingEnabled:YES];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_cloudsTextureSizeWasChanged:) name:kCloudsTextureSizeWasChanged object:nil];
        _cloudsWereChanged = YES;
    }
    return self;
}

@end

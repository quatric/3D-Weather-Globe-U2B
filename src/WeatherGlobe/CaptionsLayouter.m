#import "CaptionsLayouter.h"

// Origin of a caption of aSize put in one of the 8 directions around the
// marker at aPosition: 0 above, 1 below, 2 right, 3 left, then the corners.
static NSPoint _captionOrigin(int aDirection, NSPoint aPosition, NSSize aSize, float aRadius)
{
    float x = aPosition.x, y = aPosition.y;
    switch (aDirection) {
    case 0:
        x += aSize.width * -0.5f;
        y += aRadius;
        break;
    case 1:
        x += aSize.width * -0.5f;
        y -= aSize.height + aRadius;
        break;
    case 2:
        x += aRadius;
        y += aSize.height * -0.5f;
        break;
    case 3:
        x -= aSize.width + aRadius;
        y += aSize.height * -0.5f;
        break;
    case 4:
        x += aRadius;
        y += aRadius;
        break;
    case 5:
        x += aRadius;
        y -= aRadius;
        break;
    case 6:
        x -= aSize.width + aRadius;
        y += aRadius;
        break;
    case 7:
        x -= aSize.width + aRadius;
        y -= aSize.height + aRadius;
        break;
    }
    return NSMakePoint(x, y);
}

static float _intersectionArea(NSRect aRect, NSRect aRect2)
{
    NSRect rect = NSIntersectionRect(aRect, aRect2);
    return rect.size.width * rect.size.height;
}

@implementation CaptionsLayouter

- (BOOL)haveNewLayout
{
    return _dataIsDraft;
}

- (NSPoint)basePointInRectForCaptionAtIndex:(NSUInteger)aIndex
{
    if (_dataIsDraft)
        [self _layoutCaptions];
    return ((const NSPoint *)[_layoutedPositions bytes])[aIndex];
}

- (void)_layoutCaptions
{
    _dataIsDraft = NO;
    if (_layoutedPositions == nil)
        return;
    NSUInteger length = [_captionPositions length];
    [_layoutedPositions setLength:length];
    _numCaptions = (unsigned int)(length / sizeof(NSPoint));
    if (length == 0)
        return;
    _layoutedPositionsBytes = [_layoutedPositions mutableBytes];
    _tempCaptionSizes = [NSMutableData dataWithData:_captionSizes];
    _captionSizesBytes = [(NSMutableData *)_tempCaptionSizes mutableBytes];
    _tempCaptionPositions = [NSMutableData dataWithData:_captionPositions];
    _captionPositionsBytes = [(NSMutableData *)_tempCaptionPositions mutableBytes];
    for (unsigned int i = 0; i < _numCaptions; i++) {
        _captionSizesBytes[i].width *= _sizeScaleVec.x;
        _captionSizesBytes[i].height *= _sizeScaleVec.y;
        _captionPositionsBytes[i].x *= _positionScaleVec.x;
        _captionPositionsBytes[i].y *= _positionScaleVec.y;
    }
    if (!_needLayout && [_layoutedDirections length] != 0) {
        _layoutedDirectionsBytes = [_layoutedDirections mutableBytes];
        [self _repositionCaptionsInOldDirections];
    } else {
        [_layoutedDirections setLength:_numCaptions];
        _layoutedDirectionsBytes = [_layoutedDirections mutableBytes];
        _startRelayout = (int)time(NULL);
        if (_numCaptions < 100 && _useRecursiveLayoutAlgorithm)
            [self _recursiveRecalcLayoutWithIndex:0];
        else
            [self _linearRecalcLayoutWithIndex:0];
    }
    for (unsigned int i = 0; i < _numCaptions; i++) {
        _layoutedPositionsBytes[i].x *= _invertPositionScaleVec.x;
        _layoutedPositionsBytes[i].y *= _invertPositionScaleVec.y;
    }
    _layoutedPositionsBytes = NULL;
    _captionSizesBytes = NULL;
    _captionPositionsBytes = NULL;
}

- (void)_repositionCaptionsInOldDirections
{
    for (unsigned int i = 0; i < _numCaptions; i++)
        _layoutedPositionsBytes[i] = _captionOrigin(_layoutedDirectionsBytes[i], _captionPositionsBytes[i], _captionSizesBytes[i], _markerRadius);
}

// How much a caption at aRect for caption aIndex overlaps the captions laid
// out before it, their markers, and the markers of the ones still to come.
- (float)_overlapOfRect:(NSRect)aRect forCaptionAtIndex:(NSUInteger)aIndex
{
    float overlap = 0.0f;
    float diameter = _markerRadius + _markerRadius;
    for (unsigned int i = 0; i < _numCaptions; i++) {
        NSPoint position = _captionPositionsBytes[i];
        if (i < aIndex) {
            NSRect caption = {_layoutedPositionsBytes[i], _captionSizesBytes[i]};
            // as in the original, the marker's y comes from its x
            NSRect marker = NSMakeRect(position.x - _markerRadius, position.x - _markerRadius, diameter, diameter);
            overlap += _intersectionArea(aRect, caption) + _intersectionArea(aRect, marker);
        } else if (i != aIndex) {
            NSRect marker = NSMakeRect(position.x - _markerRadius, position.y - _markerRadius, diameter, diameter);
            overlap += _intersectionArea(aRect, marker);
        }
    }
    return overlap;
}

- (BOOL)_recursiveRecalcLayoutWithIndex:(NSUInteger)aIndex
{
    if (aIndex >= _numCaptions)
        return YES;
    NSSize size = _captionSizesBytes[aIndex];
    NSPoint position = _captionPositionsBytes[aIndex];
    int bestDirection = 0;
    float bestOverlap = FLT_MAX;
    NSPoint bestOrigin = NSZeroPoint;
    for (int direction = 0; direction < 8; direction++) {
        NSPoint origin = _captionOrigin(direction, position, size, _markerRadius);
        float overlap = [self _overlapOfRect:(NSRect){origin, size} forCaptionAtIndex:aIndex];
        if (overlap < bestOverlap) {
            bestDirection = direction;
            bestOverlap = overlap;
            bestOrigin = origin;
        }
        if (overlap <= 0.0001f) {
            _layoutedPositionsBytes[aIndex] = origin;
            _layoutedDirectionsBytes[aIndex] = (char)direction;
            if ([self _recursiveRecalcLayoutWithIndex:aIndex + 1])
                return YES;
        }
    }
    _layoutedPositionsBytes[aIndex] = bestOrigin;
    _layoutedDirectionsBytes[aIndex] = (char)bestDirection;
    [self _linearRecalcLayoutWithIndex:aIndex + 1];
    return difftime(time(NULL), (time_t)_startRelayout) > (double)_smartLayoutTime;
}

- (void)_linearRecalcLayoutWithIndex:(NSUInteger)aIndex
{
    for (NSUInteger index = aIndex; index < _numCaptions; index++) {
        NSSize size = _captionSizesBytes[index];
        NSPoint position = _captionPositionsBytes[index];
        int bestDirection = 0;
        float bestOverlap = FLT_MAX;
        NSPoint bestOrigin = NSZeroPoint;
        BOOL placed = NO;
        for (int direction = 0; direction < 8; direction++) {
            NSPoint origin = _captionOrigin(direction, position, size, _markerRadius);
            float overlap = [self _overlapOfRect:(NSRect){origin, size} forCaptionAtIndex:index];
            if (overlap < bestOverlap) {
                bestDirection = direction;
                bestOverlap = overlap;
                bestOrigin = origin;
            }
            if (overlap <= 0.0001f) {
                _layoutedPositionsBytes[index] = origin;
                _layoutedDirectionsBytes[index] = (char)direction;
                placed = YES;
                break;
            }
        }
        if (!placed) {
            _layoutedPositionsBytes[index] = bestOrigin;
            _layoutedDirectionsBytes[index] = (char)bestDirection;
        }
    }
}

- (void)setNeedLayout:(BOOL)aLayout
{
    if (!_needLayout && aLayout)
        _dataIsDraft = YES;
    _needLayout = aLayout;
}

- (void)setSmartLayoutTime:(CGFloat)aTime
{
    _smartLayoutTime = aTime;
}

- (void)setMarkerRadius:(CGFloat)aRadius
{
    if ((float)aRadius != _markerRadius) {
        _markerRadius = aRadius;
        _dataIsDraft = YES;
    }
}

- (void)setSizesScale:(struct WeatherGlobe_anon5 *)aScale
{
    if (_sizeScaleVec.x != aScale->f0 || _sizeScaleVec.y != aScale->f1) {
        _dataIsDraft = YES;
        _sizeScaleVec.x = aScale->f0;
        _sizeScaleVec.y = aScale->f1;
    }
}

- (void)setPositionsScale:(struct WeatherGlobe_anon5 *)aScale
{
    if (_positionScaleVec.x != aScale->f0 || _positionScaleVec.y != aScale->f1) {
        _dataIsDraft = YES;
        _positionScaleVec.x = aScale->f0;
        _positionScaleVec.y = aScale->f1;
        _invertPositionScaleVec.x = 1.0f / aScale->f0;
        _invertPositionScaleVec.y = 1.0f / aScale->f1;
    }
}

- (void)setNewPosition:(struct WeatherGlobe_anon5 *)aPosition forCaptionAtIndex:(NSUInteger)aIndex
{
    NSAssert(aIndex < [_captionPositions length] / sizeof(NSPoint), @"Incorrect captionID in 'setNewPosition:forCaption:'");
    NSPoint position = NSMakePoint(aPosition->f0, aPosition->f1);
    [_captionPositions replaceBytesInRange:NSMakeRange(aIndex * sizeof(NSPoint), sizeof(NSPoint)) withBytes:&position];
    _dataIsDraft = YES;
}

- (void)endRecordBlock
{
    _recordBlockIsActive = NO;
}

- (void)recordCaptionWithSize:(NSSize)aSize atPosition:(NSPoint)aPosition
{
    [_captionPositions appendBytes:&aPosition length:sizeof(NSPoint)];
    [_captionSizes appendBytes:&aSize length:sizeof(NSSize)];
}

// flag bit 0 asks for layout, bit 1 for the recursive algorithm
- (void)beginRecordBlockWithFlag:(NSInteger)aFlag
{
    [_captionPositions release];
    [_captionSizes release];
    [_layoutedPositions release];
    [_layoutedDirections release];
    _captionPositions = [NSMutableData new];
    _useRecursiveLayoutAlgorithm = NO;
    if ((aFlag & 3) == 0) {
        _captionSizes = nil;
        _layoutedPositions = nil;
        _layoutedDirections = nil;
    } else {
        _captionSizes = [NSMutableData new];
        _layoutedPositions = [NSMutableData new];
        _layoutedDirections = [NSMutableData new];
        if (aFlag & 2)
            _useRecursiveLayoutAlgorithm = YES;
    }
    _recordBlockIsActive = YES;
    _dataIsDraft = YES;
}

- (void)dealloc
{
    [_captionPositions release];
    [_captionSizes release];
    [_layoutedPositions release];
    [_layoutedDirections release];
    [super dealloc];
}

- (id)init
{
    self = [super init];
    if (self != nil) {
        _positionScaleVec.x = _positionScaleVec.y = 1.0f;
        _invertPositionScaleVec.x = _invertPositionScaleVec.y = 1.0f;
        _sizeScaleVec.x = _sizeScaleVec.y = 1.0f;
        _smartLayoutTime = 0.1f;
        _needLayout = YES;
    }
    return self;
}

@end

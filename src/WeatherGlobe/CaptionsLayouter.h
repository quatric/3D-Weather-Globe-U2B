#import "WeatherGlobePrefix.h"


@interface CaptionsLayouter : NSObject <SMK_GL_StaticTextLayouter>
{
    struct WeatherGlobe_anon10 _positionScaleVec;
    struct WeatherGlobe_anon10 _invertPositionScaleVec;
    struct WeatherGlobe_anon10 _sizeScaleVec;
    NSMutableData *_captionPositions;
    NSData *_tempCaptionPositions;
    NSPoint *_captionPositionsBytes;
    BOOL _needLayout;
    NSMutableData *_layoutedPositions;
    NSPoint *_layoutedPositionsBytes;
    NSMutableData *_layoutedDirections;
    char *_layoutedDirectionsBytes;
    int _startRelayout;
    unsigned int _numCaptions;
    NSMutableData *_captionSizes;
    NSData *_tempCaptionSizes;
    NSSize *_captionSizesBytes;
    float _markerRadius;
    float _smartLayoutTime;
    BOOL _useRecursiveLayoutAlgorithm;
    BOOL _dataIsDraft;
    BOOL _recordBlockIsActive;
}
- (BOOL)haveNewLayout;
- (NSPoint)basePointInRectForCaptionAtIndex:(NSUInteger)aIndex;
- (void)_layoutCaptions;
- (void)_repositionCaptionsInOldDirections;
- (float)_overlapOfRect:(NSRect)aRect forCaptionAtIndex:(NSUInteger)aIndex;
- (BOOL)_recursiveRecalcLayoutWithIndex:(NSUInteger)aIndex;
- (void)_linearRecalcLayoutWithIndex:(NSUInteger)aIndex;
- (void)setNeedLayout:(BOOL)aLayout;
- (void)setSmartLayoutTime:(CGFloat)aTime;
- (void)setMarkerRadius:(CGFloat)aRadius;
- (void)setSizesScale:(struct WeatherGlobe_anon5 *)aScale;
- (void)setPositionsScale:(struct WeatherGlobe_anon5 *)aScale;
- (void)setNewPosition:(struct WeatherGlobe_anon5 *)aPosition forCaptionAtIndex:(NSUInteger)aIndex;
- (void)endRecordBlock;
- (void)recordCaptionWithSize:(NSSize)aSize atPosition:(NSPoint)aPosition;
- (void)beginRecordBlockWithFlag:(NSInteger)aFlag;
- (void)dealloc;
- (id)init;
@end


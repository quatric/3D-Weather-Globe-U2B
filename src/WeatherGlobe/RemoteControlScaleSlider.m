#import "RemoteControlScaleSlider.h"

@implementation RemoteControlScaleSlider

+ (Class)cellClass
{
    return [RemoteControlScaleSliderCell class];
}

- (id)initWithCoder:(id)aCoder
{
    self = [super initWithCoder:aCoder];
    if (self != nil) {
        NSSliderCell *oldCell = [[[self cell] retain] autorelease];
        RemoteControlScaleSliderCell *cell = [[[RemoteControlScaleSliderCell allocWithZone:[self zone]] init] autorelease];
        [cell setTarget:[oldCell target]];
        [cell setAction:[oldCell action]];
        [cell setControlSize:[oldCell controlSize]];
        [self setCell:cell];
    }
    return self;
}

@end

@implementation RemoteControlScaleSliderCell

- (void)drawKnob:(NSRect)aKnob
{
    NSImage *image = [NSImage imageNamed:[NSColor smkCurrentControlTint] == NSGraphiteControlTint
                      ? @"RC_slider_knob_grpht.tiff" : @"RC_slider_knob.tiff"];
    NSSize size = [image size];
    NSRect rect = NSMakeRect(NSMinX(aKnob) + ceilf((NSWidth(aKnob) - size.width) * 0.5f) - 1.0,
                             NSMinY(aKnob) + ceilf((NSHeight(aKnob) - size.height) * 0.5f),
                             size.width, size.height);
    [image drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0
       respectFlipped:YES hints:nil];
}

@end

// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/GridControl/Views/SMKGridTableView.m
#import "SMKControlsPrefix.h"


@interface SMKGridTableView : NSTableView
{
    BOOL _doAutofitTextDuringLiveResize;
}
- (void)setAutofitTextDuringLiveResize:(BOOL)aResize;
- (id)dragImageForRows:(id)aRows event:(id)aEvent dragImageOffset:(NSPoint *)aOffset;
- (BOOL)inLiveResize;
- (void)viewDidEndLiveResize;
- (void)viewWillStartLiveResize;
- (id)initWithCoder:(id)aCoder;
- (id)initWithFrame:(NSRect)aFrame;
- (void)_initVars;
@end


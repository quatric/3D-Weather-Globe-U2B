// Original module: /Volumes/Work/Projects/SMKControls_all/SMKControls_sources/Framework/SMKBackgroundPopUpButton.m
#import "SMKBackgroundPopUpButton.h"

// a pop-up button drawn with SMKBackgroundPopUpButtonCell
@implementation SMKBackgroundPopUpButton

+ (Class)cellClass
{
	return [SMKBackgroundPopUpButtonCell class];
}

- (BOOL)isFlipped
{
	return [super isFlipped];
}

@end

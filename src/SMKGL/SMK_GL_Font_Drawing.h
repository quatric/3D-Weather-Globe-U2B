// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Font_Drawing.m
#import "SMKGLPrefix.h"
#import "SMK_GL_Font.h"


@interface SMK_GL_Font (Drawing)
- (void)drawString:(id)aString inRect:(NSRect)aRect hAlignment:(NSInteger)aAlignment vAlignment:(NSInteger)aAlignment2 fontColor:(const SMK_GL_Color *)aColor backColor:(const SMK_GL_Color *)aColor2;
- (void)drawString:(id)aString atPoint:(NSPoint)aPoint fontColor:(const SMK_GL_Color *)aColor backColor:(const SMK_GL_Color *)aColor2;
- (void)_calculateTextDimension:(id)aDimension outLineCount:(int *)aCount outMaxWidth:(float *)aWidth;
- (void)_drawBackgroundInContext:(id)aContext rect:(NSRect)aRect color:(const SMK_GL_Color *)aColor;
@end


// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Config.m
#import "SMK_GL_Config.h"

// Config.plist in the framework's resources switches OpenGL extensions on
// and off; a missing file means everything is on.
static NSDictionary *__smk_gl_config_map;

@implementation SMK_GL_Config

+ (BOOL)textureRangeIsEnabled
{
	return NO;
}

+ (BOOL)rectangleIsEnabled
{
	if (__smk_gl_config_map == nil) {
		return YES;
	}
	return [[__smk_gl_config_map objectForKey:@"RectangleExt"] boolValue];
}

+ (BOOL)vertexBufferObjectIsEnabled
{
	if (__smk_gl_config_map == nil) {
		return YES;
	}
	return [[__smk_gl_config_map objectForKey:@"VertexBuffers"] boolValue];
}

+ (BOOL)vertexArrayRangeIsEnabled
{
	if (__smk_gl_config_map == nil) {
		return YES;
	}
	return [[__smk_gl_config_map objectForKey:@"ArrayRange"] boolValue];
}

+ (void)initialize
{
	__smk_gl_config_map = [[NSDictionary alloc] initWithContentsOfFile:
		[[NSBundle bundleForClass:self] pathForResource:@"Config" ofType:@"plist"]];
}

@end

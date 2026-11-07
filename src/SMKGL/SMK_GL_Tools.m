// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Tools.m
#import "SMK_GL_Tools.h"

// The first renderer on the screen's display that reports the property.
static GLint cglValueForKey(CGLRendererProperty key, NSScreen *screen)
{
	CGDirectDisplayID display = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] intValue];
	CGLRendererInfoObj info;
	GLint count, value;
	if (CGLQueryRendererInfo(CGDisplayIDToOpenGLDisplayMask(display), &info, &count) == kCGLNoError) {
		for (GLint i = 0; i < count; i++) {
			if (CGLDescribeRenderer(info, i, key, &value) == kCGLNoError) {
				CGLDestroyRendererInfo(info);
				return value;
			}
		}
		CGLDestroyRendererInfo(info);
	}
	return 0;
}

// The original asked for kCGLRPVideoMemory and kCGLRPTextureMemory in bytes,
// which overflow a GLint on today's GPUs; the megabyte versions don't.
int videoMemoryForScreen(NSScreen *screen)
{
	return cglValueForKey(kCGLRPVideoMemoryMegabytes, screen) * 1024;
}

int texturesMemoryForScreen(NSScreen *screen)
{
	return cglValueForKey(kCGLRPTextureMemoryMegabytes, screen) * 1024;
}

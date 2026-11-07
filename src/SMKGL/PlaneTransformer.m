// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/ViewTransform/PlaneTransformer.m
#import "PlaneTransformer.h"

// Flips the window over like a card, old content on the front and new
// content on the back.
@implementation _PlaneScene

// room around the window for the plane's perspective
+ (NSRect)windowRectForContentRect:(NSRect)aRect
{
	float width = (float)aRect.size.width;
	return NSInsetRect(aRect, -floorf(width * 0.2f), -floorf(width * 0.15f));
}

- (double)transformDuration
{
	return 0.6;
}

- (void)drawObjectsInContext:(id)aContext
{
	[super drawObjectsInContext:aContext];
	glDisable(GL_BLEND);
	NSSize frameSize = [self frameSize];
	float aspect = (float)frameSize.width / (float)frameSize.height;
	NSRect rect = [self contentRect];
	float width = (float)rect.size.width;
	float height = (float)rect.size.height;
	// ease in and out around the middle
	float t = _progress + _progress - 1.0f;
	float progress = _progress + (t * -0.5f + t / (t * t + 1.0f)) * 0.7f;
	SMK_GL_Vec3 axis = { 0.0f, 1.0f, 0.0f };
	SMK_GL_Matrix rotation;
	rotateMatrix(&rotation, progress * 3.1415927f, &axis);
	SMK_GL_Vec3 scale = { width * aspect, height * aspect, 1.0f };
	SMK_GL_Matrix scaling;
	scaleMatrix(&scaling, &scale);
	scaling._14 = width * -0.5f * aspect;
	scaling._24 = height * -0.5f * aspect;
	if (progress < 0.5f) {
		scaling._11 = -scaling._11;
		scaling._14 = -scaling._14;
	}
	SMK_GL_Matrix m;
	matrix_mul(&m, &rotation, &scaling);
	id material = [[_plane mesh] material];
	id texture = progress < 0.5f ? [self currentTexture] : [self nextTexture];
	[material setTexture:texture atStage:0];
	[_plane setMatrix:&m];
	[_plane drawInContext:aContext];
	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
}

- (void)drawSceneInContext:(id)aContext withFrameSize:(NSSize)aSize
{
	NSRect rect = [self contentRect];
	float distance = (((float)aSize.width / (float)rect.size.width) * (float)rect.size.width) / _prespectiveFactor;
	[_camera setMinZ:distance / 10.0f maxZ:distance + distance];
	SMK_GL_Vec3 position = { 0.0f, 0.0f, -distance };
	[_camera setPosition:&position];
	SMK_GL_Vec3 direction = { 0.0f, 0.0f, 1.0f };
	[_camera setViewDirection:&direction];
	[super drawSceneInContext:aContext withFrameSize:aSize];
}

- (void)dealloc
{
	[_plane release];
	[super dealloc];
}

- (id)initWithTransformer:(id)aTransformer type:(NSInteger)aType
{
	self = [super initWithTransformer:aTransformer type:aType];
	if (self == nil) {
		return nil;
	}
	_prespectiveFactor = 0.6f;
	[self setCamera:[[[SMK_GL_Camera alloc] init] autorelease]];
	[_camera setFov:(float)((atan((double)_prespectiveFactor * 0.5) * 360.0) / 3.1415927)];
	SMK_GL_Vec3 up = { 0.0f, 1.0f, 0.0f };
	[_camera setUpVector:&up];
	[_container beginAccumulationBlock];
	SMK_GL_Mesh *mesh = [SMK_GL_Mesh createXYPlaneWithRect:NSMakeRect(0.0, 0.0, 1.0, 1.0) xSegments:4 ySegments:4
		container:_container fvf:kSMK_GL_FVF_Position | kSMK_GL_FVF_Normal | SMK_GL_FVF_TEXCOORDS(1) usage:0];
	SMK_GL_Material *material = [[[SMK_GL_Material alloc] initWithContainer:_container] autorelease];
	SMK_GL_Color white = { 1.0f, 1.0f, 1.0f, 1.0f };
	[material setAmbient:white];
	[material setDiffuse:white];
	[mesh setMaterial:material];
	_plane = [[SMK_GL_Drawable drawableWithMesh:mesh] retain];
	[_container endAccumulationBlock];
	return self;
}

@end

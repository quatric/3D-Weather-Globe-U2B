#import "BaseDrawView.h"


// shifts a caption into the view horizontally; aX is the caption's left edge
static float _fitCaptionX(float aX, float aWidth, NSRect aDestination, NSRect aBounds, BOOL aStrict)
{
	if (aStrict) {
		if (aX < (float)aDestination.origin.x && aWidth + aX + 0.001f < (float)aDestination.origin.x)
			aX += (float)aDestination.size.width;
	} else if (aWidth * 0.5f + aX < (float)aDestination.origin.x) {
		aX += (float)aDestination.size.width;
	}
	if (aX < (float)aBounds.origin.x)
		aX = (float)aBounds.origin.x;
	if ((float)aBounds.size.width < aWidth + aX)
		aX -= (aWidth + aX - (float)aBounds.size.width) + 2.0f;
	return aX;
}

@implementation BaseDrawView

- (void)drawRect:(NSRect)aRect
{
	NSRect destination = [self destinationRect];
	NSRect rect = NSIntersectionRect(destination, aRect);
	if ([self drawsMap])
		[self drawMapInRect:destination enableClouds:[self drawsClouds] enableDayNight:[self drawsDayNight]];
	if ([self drawsGrid])
		[self drawGridInRect:rect];
	if ([self drawsStateBorders])
		[self drawStateBordersInRect:rect];
	if ([self drawsCountryBorders])
		[self drawCountryBordersInRect:rect];
	if ([self drawsAllCities])
		[self drawAllCitiesInRect:rect];
	if ([self drawsStateBorders] && [self drawsStateNames])
		[self drawStateNames];
	if ([self drawsCountryBorders] && [self drawsCountryNames])
		[self drawCountryNames];
	if ([self drawsAppleStores])
		[self drawAppleStores];
	if ([self drawsRouteMarkers]) {
		if ([self drawsRouteLines])
			[self drawRoutes];
		[self drawRouteMarkersInRect:rect];
	}
}

- (void)drawAppleStores
{
	NSArray *stores = [[AtlasDatabase database] appleStores];
	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithDictionary:[self appleStoresAttributes]];
	NSDictionary *shadowAttributes = [self appleStoresShadowAttributes];
	NSInteger count = [stores count];
	NSString *marker = [[NSString alloc] initWithString:[[NSBundle mainBundle] localizedStringForKey:@"AppleIconCharacter" value:@"" table:nil]];
	for (NSInteger i = 0; i < count; i++) {
		AppleStoreEntry *store = [stores objectAtIndex:i];
		BOOL visible;
		NSPoint point = [self convertGeoPoint:[store coordinates] isVisible:&visible];
		if (!visible)
			continue;
		NSSize size = [marker sizeWithAttributes:shadowAttributes];
		[marker drawAtPoint:NSMakePoint((float)point.x + (float)size.width * -0.5f, (float)point.y + (float)size.height * -0.5f)
		     withAttributes:shadowAttributes];
		size = [marker sizeWithAttributes:attributes];
		struct WeatherGlobe_anon7 color = [store markerColor];
		[attributes setObject:[NSColor colorWithCalibratedRed:color.f0 green:color.f1 blue:color.f2 alpha:color.f3]
		               forKey:NSForegroundColorAttributeName];
		[marker drawAtPoint:NSMakePoint((float)point.x + (float)size.width * -0.5f, (float)point.y + (float)size.height * -0.5f)
		     withAttributes:attributes];
	}
	[marker release];
}

- (void)drawRouteMarkersInRect:(NSRect)aRect
{
	AtlasPanelController *controller = [self atlasPanelController];
	NSArray *entries = [controller routeEntries];
	NSColor *lineColor = [self lineColor];
	NSDictionary *captionAttributes = [self routeCaptionAttributes];
	NSRect destination = [self destinationRect];
	float radius = (float)[self routeMarkerRadius];
	NSInteger count = [entries count];
	BOOL drawsNames = [self drawsRouteNames];
	if (drawsNames) {
		if (_captionsLayouter == nil) {
			_captionsLayouter = [[CaptionsLayouter alloc] init];
			[_captionsLayouter setMarkerRadius:[self routeMarkerRadius]];
		}
		[_captionsLayouter beginRecordBlockWithFlag:([_panelController class] == [FlatMapController class]) + 1];
	}
	NSMutableArray *names = nil;
	for (NSInteger i = 0; i < count; i++) {
		id entry = [entries objectAtIndex:i];
		BOOL visible;
		NSPoint point = [self convertGeoPoint:[entry coordinates] isVisible:&visible];
		if (!visible)
			continue;
		float x = (float)point.x;
		if (x < (float)destination.origin.x)
			x += (float)destination.size.width;
		NSBezierPath *oval = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x - radius, (float)point.y - radius, radius + radius, radius + radius)];
		struct WeatherGlobe_anon7 *color = [entry cityMarkerColor];
		[[NSColor colorWithCalibratedRed:color->f0 green:color->f1 blue:color->f2 alpha:color->f3] set];
		[oval fill];
		[lineColor set];
		[oval stroke];
		if (drawsNames) {
			NSPoint caption = [self convertGeoPoint:_geoPointFromMapPoint([controller captionPositionForEntryAtIndex:i]) isVisible:NULL];
			float captionX = (float)caption.x;
			if (captionX < (float)destination.origin.x)
				captionX += (float)destination.size.width;
			NSString *name = [[entries objectAtIndex:i] ownName];
			if (names == nil)
				names = [NSMutableArray array];
			[names addObject:name];
			[_captionsLayouter recordCaptionWithSize:[name sizeWithAttributes:captionAttributes]
			                              atPosition:NSMakePoint(captionX, (float)caption.y)];
		}
	}
	if (!drawsNames || names == nil)
		return;
	[_captionsLayouter endRecordBlock];
	NSDictionary *shadowAttributes = [self routeCaptionShadowAttributes];
	NSInteger namesCount = [names count];
	for (NSInteger i = 0; i < namesCount; i++) {
		NSString *name = [names objectAtIndex:i];
		NSPoint base = [_captionsLayouter basePointInRectForCaptionAtIndex:i];
		NSSize size = [name sizeWithAttributes:captionAttributes];
		float x = _fitCaptionX((float)base.x + 1.0f, (float)size.width, destination, [self bounds], YES);
		[name drawAtPoint:NSMakePoint(x, base.y) withAttributes:shadowAttributes];
		[name drawAtPoint:NSMakePoint(x - 1.0f, (float)base.y + 1.0f) withAttributes:captionAttributes];
	}
}

- (void)drawRoutes
{
	SMK_GL_Mesh *mesh = [[_panelController scene] routePathsMesh];
	SMK_GL_VertexBuffer *vertexBuffer = [mesh vertexBuffer];
	const char *vertices = [vertexBuffer lock:1];
	SMK_GL_IndexBuffer *indexBuffer = [mesh indexBuffer];
	NSBezierPath *path = [NSBezierPath bezierPath];
	NSInteger lines = [mesh primitivesCount];
	BOOL is32Bit = [indexBuffer are32BitIndices];
	const char *indices = [indexBuffer lock:1];
	NSPoint points[2];
	BOOL visible[2];
	for (NSInteger i = 0; i < lines * 2; i++) {
		int end = (int)(i % 2);
		unsigned index = is32Bit ? *(const uint32_t *)indices : *(const uint16_t *)indices;
		indices += is32Bit ? 4 : 2;
		// route vertices are a position and a packed colour, 16 bytes
		const float *vertex = (const float *)(vertices + index * 16);
		struct WeatherGlobe_anon2 position = { vertex[0], vertex[1], vertex[2] };
		points[end] = [self convertVertexPoint:position isVisible:&visible[end]];
		if (end != 0 && visible[0] && visible[1]) {
			[path moveToPoint:points[0]];
			[path lineToPoint:points[1]];
		}
	}
	[indexBuffer unlock];
	[vertexBuffer unlock];
	[(NSColor *)[self lineColor] set];
	[path stroke];
}

- (void)drawAllCitiesInRect:(NSRect)aRect
{
	SMK_GL_Mesh *mesh = [[_panelController scene] allCitiesMesh];
	SMK_GL_VertexBuffer *vertexBuffer = [mesh vertexBuffer];
	const float *vertex = [vertexBuffer lock:1];
	NSColor *lineColor = [self lineColor];
	NSColor *cityColor = [self cityColor];
	NSInteger count = [mesh verticesCount];
	float radius = (float)[self cityRadius];
	BOOL drawsBorder = [self drawsCityBorder];
	for (NSInteger i = 0; i < count; i++, vertex += 3) {
		BOOL visible;
		struct WeatherGlobe_anon2 position = { vertex[0], vertex[1], vertex[2] };
		NSPoint point = [self convertVertexPoint:position isVisible:&visible];
		if (!visible || !NSPointInRect(point, aRect))
			continue;
		NSBezierPath *oval = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect((float)point.x - radius, (float)point.y - radius,
		                                                                       radius + radius, radius + radius)];
		[cityColor set];
		[oval fill];
		if (drawsBorder) {
			[lineColor set];
			[oval setLineWidth:radius * 0.5f];
			[oval stroke];
		}
	}
	[vertexBuffer unlock];
}

- (void)drawStateNames
{
	[self _drawShapeNamesWithType:1];
}

- (void)drawStateBordersInRect:(NSRect)aRect
{
	[self _drawShapeBordersWithType:1 InRect:aRect];
}

- (void)drawCountryNames
{
	[self _drawShapeNamesWithType:0];
}

- (void)drawCountryBordersInRect:(NSRect)aRect
{
	[self _drawShapeBordersWithType:0 InRect:aRect];
}

- (void)_drawShapeNamesWithType:(NSInteger)aType
{
	AtlasDatabase *database = [AtlasDatabase database];
	NSArray *uids = [database allUIDsForShapeType:aType];
	NSDictionary *attributes, *shadowAttributes;
	if (aType == 1) {
		attributes = [self stateNameAttributes];
		shadowAttributes = [self stateNameShadowAttributes];
	} else {
		attributes = [self countryNameAttributes];
		shadowAttributes = [self countryNameShadowAttributes];
	}
	NSRect destination = [self destinationRect];
	NSInteger count = [uids count];
	for (NSInteger i = 0; i < count; i++) {
		id info = [database infoWithShapeUID:[uids objectAtIndex:i] lod:3];
		if (![self isCountryVisible:info])
			continue;
		NSString *name = [info ownShapeName];
		NSSize size = [name sizeWithAttributes:attributes];
		NSSize geoSize = [self convertSizeToGeoSize:size];
		NSRect captionRect = [self captionRectForCountryInfo:info];
		NSRect geoRect = _captionGeoRect(captionRect, captionRect, info, (float)geoSize.width, (float)geoSize.height, NULL);
		BOOL visible;
		NSPoint point = [self convertGeoPoint:geoRect.origin isVisible:&visible];
		if (!visible)
			continue;
		float x = _fitCaptionX((float)point.x + 1.0f, (float)size.width, destination, [self bounds], NO);
		[name drawAtPoint:NSMakePoint(x, point.y) withAttributes:shadowAttributes];
		[name drawAtPoint:NSMakePoint(x - 1.0f, (float)point.y + 1.0f) withAttributes:attributes];
	}
}

- (void)_drawShapeBordersWithType:(NSInteger)aType InRect:(NSRect)aRect
{
	AtlasDatabase *database = [AtlasDatabase database];
	NSArray *uids = [database allUIDsForShapeType:aType];
	NSInteger count = [uids count];
	[(NSColor *)[self countryBorderColor] set];
	[NSGraphicsContext saveGraphicsState];
	[NSBezierPath clipRect:aRect];
	for (NSInteger i = 0; i < count; i++) {
		id info = [database infoWithShapeUID:[uids objectAtIndex:i] lod:3];
		if (![self isCountryVisible:info])
			continue;
		NSArray *paths = [info borderPaths];
		NSInteger pathsCount = [paths count];
		for (NSInteger p = 0; p < pathsCount; p++) {
			NSBezierPath *geoPath = [paths objectAtIndex:p];
			if (![self isGeoPathVisible:geoPath])
				continue;
			NSBezierPath *path = [self transformGeoPath:geoPath];
			if (path != nil && [path elementCount] > 0 && NSIntersectsRect([path bounds], aRect)) {
				[path setLineJoinStyle:NSRoundLineJoinStyle];
				[path stroke];
			}
		}
	}
	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawGridInRect:(NSRect)aRect
{
}

- (void)drawMapInRect:(NSRect)aRect enableClouds:(BOOL)aClouds enableDayNight:(BOOL)aNight
{
}

- (void)invalidateCashes
{
}

- (NSRect)captionRectForCountryInfo:(id)aInfo
{
	return [self geoRect];
}

- (id)transformGeoPath:(id)aPath
{
	NSBezierPath *result = [NSBezierPath bezierPath];
	NSInteger count = [aPath elementCount];
	BOOL previousVisible = NO;
	for (NSInteger i = 0; i < count; i++) {
		NSPoint points[3];
		NSBezierPathElement element = [aPath elementAtIndex:i associatedPoints:points];
		BOOL visible;
		NSPoint point = [self convertGeoPoint:points[0] isVisible:&visible];
		if (element == NSMoveToBezierPathElement) {
			if (visible)
				[result moveToPoint:point];
		} else if (element == NSLineToBezierPathElement && visible) {
			if (previousVisible)
				[result lineToPoint:point];
			else
				[result moveToPoint:point];
		}
		previousVisible = visible;
	}
	return result;
}

- (NSSize)convertSizeToGeoSize:(NSSize)aSize
{
	return aSize;
}

- (NSPoint)convertVertexPoint:(struct WeatherGlobe_anon2)aPoint isVisible:(BOOL *)aVisible
{
	if (aVisible != NULL)
		*aVisible = YES;
	return NSMakePoint(aPoint.f0, aPoint.f1);
}

- (NSPoint)convertGeoPoint:(NSPoint)aPoint isVisible:(BOOL *)aVisible
{
	if (aVisible != NULL)
		*aVisible = YES;
	return aPoint;
}

- (BOOL)isGeoPathVisible:(id)aVisible
{
	return YES;
}

- (BOOL)isCountryVisible:(id)aVisible
{
	return YES;
}

- (NSRect)destinationRect
{
	return [self bounds];
}

- (NSRect)geoRect
{
	return NSZeroRect;
}

- (id)appleStoresShadowAttributes
{
	float size = (float)[[[self appleStoresAttributes] objectForKey:NSFontAttributeName] pointSize];
	return [NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:size + 0.5f], NSFontAttributeName,
	                                                  [NSColor blackColor], NSForegroundColorAttributeName, nil];
}

- (id)appleStoresAttributes
{
	float size = _scale * 10.0f;
	if (size < 1.0f)
		size = 1.0f;
	return [NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:size], NSFontAttributeName, nil];
}

- (id)stateNameShadowAttributes
{
	return [NSDictionary dictionaryWithObjectsAndKeys:[[self stateNameAttributes] objectForKey:NSFontAttributeName], NSFontAttributeName,
	                                                  [NSColor colorWithCalibratedWhite:0.0 alpha:1.0], NSForegroundColorAttributeName, nil];
}

- (id)stateNameAttributes
{
	float size = ((float)[_panelController scale] * 4.0f + 8.0f) * _scale;
	if (size < 1.0f)
		size = 1.0f;
	return [NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:size], NSFontAttributeName,
	                                                  [NSColor colorWithCalibratedWhite:0.8 alpha:1.0], NSForegroundColorAttributeName, nil];
}

- (id)countryNameShadowAttributes
{
	return [NSDictionary dictionaryWithObjectsAndKeys:[[self countryNameAttributes] objectForKey:NSFontAttributeName], NSFontAttributeName,
	                                                  [NSColor colorWithCalibratedWhite:0.0 alpha:1.0], NSForegroundColorAttributeName, nil];
}

- (id)countryNameAttributes
{
	float size = ((float)[_panelController scale] * 4.0f + 8.0f) * _scale;
	if (size < 1.0f)
		size = 1.0f;
	return [NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:size], NSFontAttributeName,
	                                                  [NSColor colorWithCalibratedWhite:0.8 alpha:1.0], NSForegroundColorAttributeName, nil];
}

- (id)countryBorderColor
{
	return [NSColor colorWithCalibratedRed:0.8 green:0.4 blue:0.1 alpha:1.0];
}

- (id)gridMarkerAttributes
{
	static NSDictionary *attributes = nil;
	if (attributes == nil)
		attributes = [[NSDictionary alloc] initWithObjectsAndKeys:[NSFont systemFontOfSize:8.0], NSFontAttributeName,
		                                                          [self gridColor], NSForegroundColorAttributeName, nil];
	return attributes;
}

- (id)gridColor
{
	return [NSColor lightGrayColor];
}

- (id)lineColor
{
	return [NSColor blackColor];
}

- (id)routeCaptionShadowAttributes
{
	return [NSDictionary dictionaryWithObjectsAndKeys:[[self routeCaptionAttributes] objectForKey:NSFontAttributeName], NSFontAttributeName,
	                                                  [NSColor colorWithCalibratedWhite:0.0 alpha:1.0], NSForegroundColorAttributeName, nil];
}

- (id)routeCaptionAttributes
{
	float size = _scale * 10.0f;
	if (size < 1.0f)
		size = 1.0f;
	return [NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:size], NSFontAttributeName,
	                                                  [NSColor colorWithCalibratedWhite:0.8 alpha:1.0], NSForegroundColorAttributeName, nil];
}

- (CGFloat)routeMarkerRadius
{
	float scale = (float)[Preferences markersScale];
	return (scale + scale + 1.0f) * _scale;
}

- (id)cityColor
{
	return [NSColor yellowColor];
}

- (CGFloat)cityRadius
{
	return 1.0;
}

- (void)setDrawsAppleStores:(BOOL)aStores
{
	_dvFlags.drawsAppleStores = aStores;
}

- (BOOL)drawsAppleStores
{
	return _dvFlags.drawsAppleStores;
}

- (void)setDrawsCityBorder:(BOOL)aBorder
{
	_dvFlags.drawsCityBorder = aBorder;
}

- (BOOL)drawsCityBorder
{
	return _dvFlags.drawsCityBorder;
}

- (void)setDrawsRouteNames:(BOOL)aNames
{
	_dvFlags.drawsRouteNames = aNames;
}

- (BOOL)drawsRouteNames
{
	return _dvFlags.drawsRouteNames;
}

- (void)setDrawsRouteLines:(BOOL)aLines
{
	_dvFlags.drawsRouteLines = aLines;
}

- (BOOL)drawsRouteLines
{
	return _dvFlags.drawsRouteLines;
}

- (void)setDrawsRouteMarkers:(BOOL)aMarkers
{
	_dvFlags.drawsRouteMarkers = aMarkers;
}

- (BOOL)drawsRouteMarkers
{
	return _dvFlags.drawsRouteMarkers;
}

- (void)setDrawsAllCities:(BOOL)aCities
{
	_dvFlags.drawsAllCities = aCities;
}

- (BOOL)drawsAllCities
{
	return _dvFlags.drawsAllCities;
}

- (void)setDrawsStateNames:(BOOL)aNames
{
	_dvFlags.drawsStateNames = aNames;
}

- (BOOL)drawsStateNames
{
	return _dvFlags.drawsStateNames;
}

- (void)setDrawsStateBorders:(BOOL)aBorders
{
	_dvFlags.drawsStateBorders = aBorders;
}

- (BOOL)drawsStateBorders
{
	return _dvFlags.drawsStateBorders;
}

- (void)setDrawsCountryNames:(BOOL)aNames
{
	_dvFlags.drawsCountryNames = aNames;
}

- (BOOL)drawsCountryNames
{
	return _dvFlags.drawsCountryNames;
}

- (void)setDrawsCountryBorders:(BOOL)aBorders
{
	_dvFlags.drawsCountryBorders = aBorders;
}

- (BOOL)drawsCountryBorders
{
	return _dvFlags.drawsCountryBorders;
}

- (void)setDrawsGrid:(BOOL)aGrid
{
	_dvFlags.drawsGrid = aGrid;
}

- (BOOL)drawsGrid
{
	return _dvFlags.drawsGrid;
}

- (void)setDrawsDayNight:(BOOL)aNight
{
	_dvFlags.drawsDayNight = aNight;
}

- (BOOL)drawsDayNight
{
	return _dvFlags.drawsDayNight;
}

- (void)setDrawsClouds:(BOOL)aClouds
{
	_dvFlags.drawsClouds = aClouds;
}

- (BOOL)drawsClouds
{
	return _dvFlags.drawsClouds;
}

- (void)setDrawsMap:(BOOL)aMap
{
	_dvFlags.drawsMap = aMap;
}

- (BOOL)drawsMap
{
	return _dvFlags.drawsMap;
}

- (void)setScale:(CGFloat)aScale
{
	_scale = (float)aScale;
}

- (void)setAtlasPanelController:(id)aController
{
	_panelController = aController;
}

- (id)atlasPanelController
{
	return _panelController;
}

- (BOOL)isOpaque
{
	return YES;
}

- (void)dealloc
{
	_panelController = nil;
	[_captionsLayouter release];
	[super dealloc];
}

- (id)initWithFrame:(NSRect)aFrame
{
	self = [super initWithFrame:aFrame];
	if (self != nil)
		_transfRect = NSMakeRect(0.0, 0.0, 1.0, 1.0);
	return self;
}

@end

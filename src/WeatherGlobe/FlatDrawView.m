#import "FlatDrawView.h"


// map tiles per degree LOD: 1, 3, 9 and 18 tiles per half of the map
static int _tilesForLOD(NSInteger aLOD)
{
	if (aLOD < 1)
		return 1;
	if (aLOD == 1)
		return 3;
	return aLOD != 2 ? 18 : 9;
}

@implementation FlatDrawView

- (void)drawRect:(NSRect)aRect
{
	[super drawRect:aRect];
}

// route lines; a line jumping over the map's side is split at the edges
- (void)drawRoutes
{
	NSRect destination = [self destinationRect];
	SMK_GL_Mesh *mesh = [[_panelController scene] routePathsMesh];
	SMK_GL_VertexBuffer *vertexBuffer = [mesh vertexBuffer];
	const char *vertices = [vertexBuffer lock:1];
	SMK_GL_IndexBuffer *indexBuffer = [mesh indexBuffer];
	NSBezierPath *path = [NSBezierPath bezierPath];
	NSInteger lines = [mesh primitivesCount];
	BOOL is32Bit = [indexBuffer are32BitIndices];
	const char *indices = [indexBuffer lock:1];
	float left = (float)destination.origin.x;
	float width = (float)destination.size.width;
	float maxJump = width * 0.98f;
	float right = width + left;
	NSPoint points[2];
	BOOL visible[2];
	for (NSInteger i = 0; i < lines * 2; i++) {
		int end = (int)(i % 2);
		unsigned index = is32Bit ? *(const uint32_t *)indices : *(const uint16_t *)indices;
		indices += is32Bit ? 4 : 2;
		const float *vertex = (const float *)(vertices + index * 16);
		struct WeatherGlobe_anon2 position = { vertex[0], vertex[1], vertex[2] };
		points[end] = [self convertVertexPoint:position isVisible:&visible[end]];
		if (end == 0)
			continue;
		float x0 = (float)points[0].x, y0 = (float)points[0].y;
		float x1 = (float)points[1].x, y1 = (float)points[1].y;
		NSPoint start = points[0];
		if ((float)[self geoRect].size.width + 0.001f > 360.0f && fabsf(x1 - x0) > maxJump) {
			float y, restart;
			if (x0 - x1 <= maxJump) {
				y = y0 + ((y1 - y0) / (x0 - (x1 - width))) * (x0 - left);
				[path moveToPoint:points[0]];
				[path lineToPoint:NSMakePoint(left, y)];
				restart = right;
			} else {
				y = y0 + ((y1 - y0) / (x1 - (x0 - width))) * (right - x0);
				[path moveToPoint:points[0]];
				[path lineToPoint:NSMakePoint(right, y)];
				restart = right - width;
			}
			start = NSMakePoint(restart, y);
		}
		[path moveToPoint:start];
		[path lineToPoint:points[1]];
	}
	[indexBuffer unlock];
	[vertexBuffer unlock];
	[(NSColor *)[self lineColor] set];
	[NSGraphicsContext saveGraphicsState];
	[NSBezierPath clipRect:destination];
	[path stroke];
	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawGridInRect:(NSRect)aRect
{
	NSRect destination = [self destinationRect];
	NSRect geo = [self geoRect];
	NSBezierPath *path = [NSBezierPath bezierPath];
	NSInteger step = [_panelController degreesGridStep];
	float mapWidth = (float)_transfRect.size.width * 360.0f;
	NSDictionary *attributes = [self gridMarkerAttributes];
	float fStep = (float)step;
	float left = (float)destination.origin.x;
	float right = (float)destination.size.width + left;
	float gx = (float)geo.origin.x, gy = (float)geo.origin.y, gw = (float)geo.size.width, gh = (float)geo.size.height;

	for (float longitude = (float)((int)ceilf(gx / fStep) * step); longitude < gx + gw; longitude += fStep) {
		float l = longitude >= 180.0f ? longitude - 360.0f : longitude;
		NSPoint p = [self _convertGeoPoint:NSMakePoint(l, gy)];
		if ((float)p.x + 0.001f < left && !(right <= mapWidth + (float)p.x - 0.001f))
			p.x = mapWidth + (float)p.x;
		[path moveToPoint:p];
		NSPoint q = [self _convertGeoPoint:NSMakePoint(l, gh + gy)];
		if ((float)q.x + 0.001f < left && mapWidth + (float)q.x - 0.001f < right)
			q.x = mapWidth + (float)q.x;
		[path lineToPoint:q];
		NSString *label = [NSString stringWithFormat:@"%d", (int)l];
		NSSize size = [label sizeWithAttributes:attributes];
		[label drawAtPoint:NSMakePoint(q.x, (float)q.y - ((float)size.height + 10.0f)) withAttributes:attributes];
	}
	for (float latitude = (float)((int)ceilf(gy / fStep) * step); latitude < gh + gy; latitude += fStep) {
		[path moveToPoint:[self _convertGeoPoint:NSMakePoint(gx, latitude)]];
		NSPoint q = [self _convertGeoPoint:NSMakePoint(gx + gw, latitude)];
		if (!(right <= mapWidth + (float)q.x - 0.001f))
			q.x = mapWidth + (float)q.x;
		[path lineToPoint:q];
		NSString *label = [NSString stringWithFormat:@"%d", (int)latitude];
		NSSize size = [label sizeWithAttributes:attributes];
		float x = (float)q.x - ((float)size.width + 10.0f);
		if (x + 0.001f < left && !(right <= mapWidth + x - 0.001f))
			x = mapWidth + x;
		[label drawAtPoint:NSMakePoint(x, q.y) withAttributes:attributes];
	}
	[(NSColor *)[self gridColor] set];
	[path setLineWidth:0.5];
	[path stroke];
}

- (void)drawMapInRect:(NSRect)aRect enableClouds:(BOOL)aClouds enableDayNight:(BOOL)aNight
{
	float pixels = ((float)[(FlatMapController *)_panelController mapScaleValue] * 2.0f) * (float)aRect.size.height;
	int lod;
	if (pixels < 2048.0f)
		lod = 0;
	else if (pixels < 6144.0f)
		lod = 1;
	else
		lod = (pixels >= 12288.0f) + 2;
	MapPartsLoader *loader = [[_panelController windowController] mapPartsLoader];
	int tiles = _tilesForLOD(lod);
	NSRect mapRect = _mapRectFromGeoRect([self geoRect]);
	float tileWidth = 0.5f / (float)tiles;
	float tileHeight = 1.0f / (float)tiles;
	int firstX = (int)(((float)mapRect.origin.x + 1e-05f) / tileWidth);
	int lastX = (int)((((float)mapRect.origin.x + (float)mapRect.size.width) - 1e-05f) / tileWidth);
	int firstY = (int)(((float)mapRect.origin.y + 1e-05f) / tileHeight);
	int lastY = (int)((((float)mapRect.origin.y + (float)mapRect.size.height) - 1e-05f) / tileHeight);

	NSBitmapImageRep *clouds1 = nil, *clouds0 = nil;
	if (_cashedImageReps == nil) {
		_cashedImageReps = [NSMutableArray new];
		if (aClouds) {
			NSArray *cloudReps = [[CWManager cloudsManager] currentCloudsBitmapReps];
			if (cloudReps != nil && (firstX < tiles || lastX >= tiles * 2))
				clouds1 = [[cloudReps objectAtIndex:1] retain];
			if (cloudReps != nil && lastX >= tiles)
				clouds0 = [[cloudReps objectAtIndex:0] retain];
		}
	}

	int cacheIndex = 0;
	for (int x = firstX; x <= lastX; x++) {
		for (int y = firstY; y <= lastY; y++) {
			int row = tiles - 1 - y;
			NSBitmapImageRep *rep;
			NSBitmapImageRep *clouds = nil;
			if (!_isImageRepsCashed) {
				NSString *path = [MapPartsLoader pathForMapTextureForLOD:lod xPos:x yPos:row];
				rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:1024 pixelsHigh:1024 bitsPerSample:8
				                                         samplesPerPixel:4 hasAlpha:YES isPlanar:NO
				                                          colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:4096 bitsPerPixel:32];
				[loader fillBitmapRep:rep withContentsOfFile:path];
				if (aClouds) {
					clouds = clouds1;
					if (tiles <= x && tiles <= x % (tiles * 2))
						clouds = clouds0;
				}
			} else {
				rep = [_cashedImageReps objectAtIndex:cacheIndex];
			}
			NSRect geoTile = _geoRectFromMapRect(NSMakeRect(tileWidth * (float)x, (float)y * tileHeight, tileWidth, tileHeight));
			NSArray *rects = [self _rectsToDrawImageFromGeoRect:geoTile];
			NSInteger count = [rects count];
			for (NSInteger i = 0; i < count; i++) {
				NSRect rect = [[rects objectAtIndex:i] rectValue];
				NSRect target = NSIntersectionRect(rect, aRect);
				if (NSIsEmptyRect(target))
					continue;
				float scale = 1024.0f / (float)rect.size.height;
				NSRect source = NSMakeRect(((float)target.origin.x - (float)rect.origin.x) * scale,
				                           ((float)target.origin.y - (float)rect.origin.y) * scale,
				                           ((float)target.size.width / (float)rect.size.width) * 1024.0f,
				                           ((float)target.size.height / (float)rect.size.height) * 1024.0f);
				if (!_isImageRepsCashed)
					[self _convertImageRep:rep withXIndex:x YIndex:row forLOD:lod cloudsImageRep:clouds inRect:source
					          enableClouds:aClouds enableDayNight:aNight];
				NSImage *image = [[NSImage alloc] initWithSize:[rep size]];
				[image addRepresentation:rep];
				[image drawInRect:target fromRect:source operation:NSCompositingOperationCopy fraction:1.0];
				[image release];
			}
			if (!_isImageRepsCashed) {
				[_cashedImageReps addObject:rep];
				[rep release];
			}
			cacheIndex++;
		}
	}
	[clouds1 release];
	[clouds0 release];
	_isImageRepsCashed = YES;
}

- (void)invalidateCashes
{
	[_cashedImageReps release];
	_cashedImageReps = nil;
	_isImageRepsCashed = NO;
}

// darkens the night side of a 1024x1024 map tile and blends the clouds in
- (void)_convertImageRep:(id)aRep withXIndex:(NSInteger)aIndex YIndex:(NSInteger)aIndex2 forLOD:(NSInteger)aLOD cloudsImageRep:(id)aRep2 inRect:(NSRect)aRect enableClouds:(BOOL)aClouds enableDayNight:(BOOL)aNight
{
	if (aRep == nil || (!aClouds && !aNight))
		return;
	NSBitmapImageRep *rep = aRep;
	NSBitmapImageRep *cloudsRep = aRep2;
	int tiles = _tilesForLOD(aLOD);
	int bytesPerPixel = (int)[rep bitsPerPixel] >> 3;
	int width = (int)(float)[rep size].width;
	int height = (int)(float)[rep size].height;
	int cloudsHeight = (int)(float)[cloudsRep size].height;
	int cloudsWidth = (int)(float)[cloudsRep size].width;
	int cloudsRowBytes = ((int)[cloudsRep bitsPerPixel] >> 3) * cloudsWidth;
	float fTiles = (float)tiles;
	float cloudsStep = ((float)cloudsHeight * 0.0009765625f) / fTiles;
	float cloudsPerTile = (float)cloudsHeight / fTiles;
	float tileFraction = 1.0f / fTiles;
	float mapScale = (float)[(FlatMapController *)_panelController mapScaleValue];
	struct WeatherGlobe_anon2 light = [(AtlasController *)[[_panelController windowController] atlasController] lightDirection];
	unsigned char *data = [rep bitmapData];
	const unsigned char *cloudsData = (aClouds && cloudsRep != nil) ? [cloudsRep bitmapData] : NULL;

	int lastRow = (int)((float)aRect.size.height + (float)aRect.origin.y + 1.0f);
	if (height <= lastRow)
		lastRow = height - 1;
	int lastColumn = (int)((float)aRect.origin.x + (float)aRect.size.width + 1.0f);
	if (lastColumn >= width)
		lastColumn = width - 1;
	float cachedLatitude = -10.0f, cosLatitude = 0.0f, sinLatitude = 0.0f;

	for (int row = 1023 - lastRow; row <= 1023 - (int)aRect.origin.y; row++) {
		float cloudsY = cloudsPerTile * (float)aIndex2 + cloudsStep * (float)row;
		int cloudsRow0 = cloudsRowBytes * (int)cloudsY;
		int cloudsNextY = (int)cloudsY + 1;
		int cloudsRow1 = cloudsRowBytes * cloudsNextY;
		float latitude = (((float)aIndex2 * tileFraction + (float)row * tileFraction * 0.0009765625f) - 0.5f) * 3.1415927f;
		for (int column = (int)aRect.origin.x; column <= lastColumn; column++) {
			int offset = row * bytesPerPixel * width + column * bytesPerPixel;
			unsigned char *pixel = data + offset;
			float cloudsFactor;
			if (!aNight) {
				cloudsFactor = 1.0f;
			} else {
				if (cachedLatitude != latitude) {
					cosLatitude = cosf(latitude);
					sinLatitude = sinf(latitude);
					cachedLatitude = latitude;
				}
				double longitude = (double)(((float)column * tileFraction * 0.0009765625f * 0.5f +
				                             (float)aIndex * tileFraction * 0.5f) * 6.2831855f);
				float light2 = 0.25f - ((float)cos(longitude) * cosLatitude * -light.f0 + cosLatitude * (float)sin(longitude) * -light.f1 +
				                        sinLatitude * -light.f2) * (mapScale * 0.5f + 3.0f);
				if (light2 > 1.0f) {
					light2 = 1.0f;
					cloudsFactor = 0.5f;
				} else if (light2 >= 0.25f) {
					cloudsFactor = light2 * 0.5f;
				} else {
					light2 = 0.25f;
					cloudsFactor = 0.125f;
				}
				cloudsFactor += 0.5f;
				for (int c = 0; c < 3; c++)
					pixel[c] = (unsigned char)(int)((float)pixel[c] * light2);
			}
			if (!aClouds || cloudsData == NULL)
				continue;
			if (cloudsStep >= 0.99f) {
				for (int c = 0; c < 3; c++) {
					int value = (int)((float)pixel[c] + (float)cloudsData[offset + c] * cloudsFactor);
					pixel[c] = value < 256 ? (unsigned char)value : 0xff;
				}
			} else {
				// bilinear sample of the clouds map
				float cloudsX = (float)column * cloudsStep + cloudsPerTile * (float)(aIndex % tiles);
				float fracX = cloudsX - floorf(cloudsX);
				float fracY = cloudsY - floorf(cloudsY);
				int cloudsColumn0 = bytesPerPixel * (int)cloudsX;
				int cloudsNextX = (int)cloudsX + 1;
				int cloudsColumn1 = cloudsNextX < cloudsWidth ? bytesPerPixel * cloudsNextX : cloudsColumn0;
				int row1 = cloudsNextY < cloudsHeight ? cloudsRow1 : cloudsRow0;
				for (int c = 0; c < 3; c++) {
					float topLeft = cloudsData[c + cloudsRow0 + cloudsColumn0];
					float topRight = cloudsData[c + cloudsRow0 + cloudsColumn1];
					float bottomLeft = cloudsData[c + row1 + cloudsColumn0];
					float bottomRight = cloudsData[c + row1 + cloudsColumn1];
					float top = topLeft + (float)(int)(topRight - topLeft) * fracX;
					float bottom = bottomLeft + (float)(int)(bottomRight - bottomLeft) * fracX;
					int value = (int)((top + (bottom - top) * fracY) * cloudsFactor) + pixel[c];
					pixel[c] = value < 256 ? (unsigned char)value : 0xff;
				}
			}
		}
	}
}

// the largest visible part of the country's outline
- (NSRect)captionRectForCountryInfo:(id)aInfo
{
	NSRect geo = [self geoRect];
	NSRect best = NSZeroRect;
	NSArray *paths = [aInfo borderPaths];
	NSInteger count = [paths count];
	NSRect shiftedGeo = geo;
	shiftedGeo.origin.x = (float)geo.origin.x - 360.0f;
	NSPoint previous = NSZeroPoint;
	for (NSInteger i = 0; i < count; i++) {
		NSBezierPath *path = [paths objectAtIndex:i];
		NSInteger elements = [path elementCount];
		NSRect rect = NSZeroRect;
		BOOL started = NO;
		for (NSInteger e = 0; e < elements; e++) {
			NSPoint points[3];
			NSBezierPathElement element = [path elementAtIndex:e associatedPoints:points];
			NSPoint point = points[0];
			NSRect test = geo.origin.x <= point.x ? geo : shiftedGeo;
			if (element == NSMoveToBezierPathElement) {
				if (NSPointInRect(point, test) && !started) {
					rect = [self _initialRectForPoint:point Path:path];
					started = YES;
				}
			} else if (element == NSLineToBezierPathElement) {
				if (NSPointInRect(point, test) || NSPointInRect(previous, test)) {
					BOOL use = YES;
					if (!started) {
						if (NSPointInRect(point, test)) {
							rect = [self _initialRectForPoint:point Path:path];
							started = YES;
						} else {
							use = NO;
						}
					}
					if (use)
						rect = NSUnionRect(rect, NSMakeRect(MIN(point.x, previous.x), MIN(point.y, previous.y),
						                                    fabs(point.x - previous.x), fabs(point.y - previous.y)));
				}
			}
			previous = point;
		}
		if (!NSIsEmptyRect(rect)) {
			NSRect shifted = NSIntersectionRect(rect, shiftedGeo);
			rect = NSIntersectionRect(rect, geo);
			if (rect.size.height * rect.size.width < shifted.size.height * shifted.size.width)
				rect = shifted;
		}
		if (best.size.width * best.size.height < rect.size.height * rect.size.width)
			best = rect;
	}
	return best;
}

// grows a point inside the path to the view edges the path reaches
- (NSRect)_initialRectForPoint:(NSPoint)aPoint Path:(id)aPath
{
	NSRect geo = [self geoRect];
	NSSize size = NSZeroSize;
	NSPoint origin = aPoint;
	if ([aPath containsPoint:NSMakePoint(aPoint.x, geo.origin.y)]) {
		size.height += aPoint.y - geo.origin.y;
		origin.y = geo.origin.y;
	}
	float top = (float)geo.origin.y + (float)geo.size.height;
	if ([aPath containsPoint:NSMakePoint(aPoint.x, top)])
		size.height += top - aPoint.y;
	if ([aPath containsPoint:NSMakePoint(geo.origin.x, aPoint.y)]) {
		size.width += aPoint.x - geo.origin.x;
		origin.x = geo.origin.x;
	}
	float right = (float)geo.origin.x + (float)geo.size.width;
	if ([aPath containsPoint:NSMakePoint(right, aPoint.y)])
		size.width += right - aPoint.x;
	return NSMakeRect(origin.x, origin.y, size.width, size.height);
}

- (BOOL)isGeoPathVisible:(id)aVisible
{
	NSRect bounds = [aVisible bounds];
	if (bounds.size.width + bounds.origin.x < _geoRect.origin.x)
		bounds.origin.x += 360.0;
	return NSIntersectsRect(_geoRect, bounds);
}

- (BOOL)isCountryVisible:(id)aVisible
{
	NSRect bounds = [aVisible enclosingRect];
	if (bounds.size.width + bounds.origin.x < _geoRect.origin.x)
		bounds.origin.x += 360.0;
	return NSIntersectsRect(_geoRect, bounds);
}

- (NSRect)destinationRect
{
	[self _calcGeoRect];
	[self _calcTransform];
	return [self _convertGeoRect:[self geoRect]];
}

- (CGFloat)cityRadius
{
	float radius = (float)[super cityRadius];
	return (float)((log2((double)(float)[(FlatMapController *)_panelController mapScaleValue]) * 0.4000000059604645 + 1.0) * (double)radius);
}

- (id)transformGeoPath:(id)aPath
{
	NSRect destination = [self destinationRect];
	float mapWidth = (float)_transfRect.size.width * 360.0f;
	NSBezierPath *result = [NSBezierPath bezierPath];
	NSInteger count = [aPath elementCount];
	float left = (float)destination.origin.x;
	float right = left + (float)destination.size.width;
	NSPoint previous = NSZeroPoint;
	for (NSInteger i = 0; i < count; i++) {
		NSPoint points[3];
		NSBezierPathElement element = [aPath elementAtIndex:i associatedPoints:points];
		BOOL visible;
		NSPoint point = [self convertGeoPoint:points[0] isVisible:&visible];
		if (element == NSMoveToBezierPathElement) {
			[result moveToPoint:point];
		} else if (element == NSLineToBezierPathElement) {
			if ((float)point.x + 0.001f < left) {
				float wrapped = mapWidth + (float)point.x;
				if (!(right <= wrapped - 0.001f))
					point.x = wrapped;
			}
			if ((float)destination.size.width * 0.98f < fabsf((float)point.x - (float)previous.x))
				[result moveToPoint:point];
			else
				[result lineToPoint:point];
		}
		previous = point;
	}
	return result;
}

- (NSSize)convertSizeToGeoSize:(NSSize)aSize
{
	return NSMakeSize((float)aSize.width / (float)_transfRect.size.width, (float)aSize.height / (float)_transfRect.size.height);
}

- (NSPoint)convertVertexPoint:(struct WeatherGlobe_anon2)aPoint isVisible:(BOOL *)aVisible
{
	NSPoint geoPoint = _geoPointFromMapPoint(NSMakePoint(aPoint.f0, aPoint.f1));
	if (aVisible != NULL) {
		NSPoint test = geoPoint;
		if (test.x < _geoRect.origin.x)
			test.x += 360.0;
		*aVisible = NSPointInRect(test, _geoRect);
	}
	return [self _convertGeoPoint:geoPoint];
}

- (NSPoint)_convertVertexPoint:(struct WeatherGlobe_anon2)aPoint
{
	return [self _convertGeoPoint:_geoPointFromMapPoint(NSMakePoint(aPoint.f0, aPoint.f1))];
}

// the view rects of a geo rect and of its copies one map width to each side
- (id)_rectsToDrawImageFromGeoRect:(NSRect)aRect
{
	NSMutableArray *rects = [NSMutableArray array];
	NSRect rect = [self _convertGeoRect:aRect];
	if (NSIntersectsRect(rect, [self bounds]))
		[rects addObject:[NSValue valueWithRect:rect]];
	rect.origin.x = (float)_transfRect.size.width * -360.0f + (float)rect.origin.x;
	if (NSIntersectsRect(rect, [self bounds]))
		[rects addObject:[NSValue valueWithRect:rect]];
	rect.origin.x = (float)_transfRect.size.width * 720.0f + (float)rect.origin.x;
	if (NSIntersectsRect(rect, [self bounds]))
		[rects addObject:[NSValue valueWithRect:rect]];
	return rects;
}

- (NSRect)_convertGeoRect:(NSRect)aRect
{
	NSPoint origin = [self _convertGeoPoint:aRect.origin];
	return NSMakeRect(origin.x, origin.y, (float)aRect.size.width * (float)_transfRect.size.width,
	                  (float)aRect.size.height * (float)_transfRect.size.height);
}

- (NSPoint)convertGeoPoint:(NSPoint)aPoint isVisible:(BOOL *)aVisible
{
	if (aVisible != NULL) {
		NSPoint test = aPoint;
		if (test.x < _geoRect.origin.x)
			test.x += 360.0;
		*aVisible = NSPointInRect(test, _geoRect);
	}
	return [self _convertGeoPoint:aPoint];
}

// picks the map copy (shifted by a map width) nearest to the view
- (NSPoint)_convertGeoPoint:(NSPoint)aPoint
{
	float scale = (float)_transfRect.size.width;
	float x = (float)aPoint.x * scale + (float)_transfRect.origin.x;
	float mapWidth = scale * 360.0f;
	NSRect bounds = [self bounds];
	float left = (float)bounds.origin.x;
	float right = left + (float)bounds.size.width;
	if (x < left || right < x) {
		float minus = x - mapWidth;
		float plus = mapWidth + x;
		float distanceMinus = MIN(fabsf(left - minus), fabsf(right - minus));
		float distancePlus = MIN(fabsf(left - plus), fabsf(right - plus));
		float distance = MIN(fabsf(left - x), fabsf(right - x));
		if (distancePlus <= distanceMinus) {
			if (!(distance <= distancePlus))
				x = plus;
		} else if (distanceMinus < distance) {
			x = minus;
		}
	}
	return NSMakePoint(x, (float)aPoint.y * (float)_transfRect.size.height + (float)_transfRect.origin.y);
}

- (void)_calcTransform
{
	NSRect geo = [self geoRect];
	NSRect frame = [self frame];
	float scale = (float)frame.size.width / (float)geo.size.width;
	if ((float)frame.size.height / (float)geo.size.height <= scale)
		scale = (float)frame.size.height / (float)geo.size.height;
	_transfRect.size.width = scale;
	_transfRect.size.height = scale;
	_transfRect.origin.x = ((float)frame.size.width - (float)geo.size.width * scale) * 0.5f - scale * (float)geo.origin.x;
	_transfRect.origin.y = ((float)frame.size.height - (float)geo.size.height * scale) * 0.5f - scale * (float)geo.origin.y;
}

- (void)_calcGeoRect
{
	NSRect geo = NSZeroRect;
	if (_panelController != nil) {
		NSPoint point;
		if ([_panelController canConvertNormalizedViewPoint:NSMakePoint(0.0, 0.0) toGeoPoint:&point])
			geo.origin = point;
		if ([_panelController canConvertNormalizedViewPoint:NSMakePoint(1.0, 1.0) toGeoPoint:&point]) {
			geo.size.width = (float)point.x - (float)geo.origin.x;
			if (geo.size.width <= 0.0)
				geo.size.width = ((float)point.x + 180.0f + 180.0f) - (float)geo.origin.x;
			geo.size.height = (float)point.y - (float)geo.origin.y;
		}
		if (360.0f < (float)[_panelController viewAspect] * (float)geo.size.height) {
			geo.origin.x = (float)geo.size.width * 0.5f + (float)geo.origin.x;
			if (180.0 < geo.origin.x)
				geo.origin.x = (float)geo.origin.x - 360.0f;
			geo.size.width = 360.0;
		}
	}
	_geoRect = geo;
}

- (NSRect)geoRect
{
	return _geoRect;
}

- (void)dealloc
{
	[_cashedImageReps release];
	[super dealloc];
}

- (id)initWithFrame:(NSRect)aFrame
{
	self = [super initWithFrame:aFrame];
	if (self != nil) {
		[self setDrawsRouteNames:YES];
		[self setDrawsCityBorder:YES];
	}
	return self;
}

@end

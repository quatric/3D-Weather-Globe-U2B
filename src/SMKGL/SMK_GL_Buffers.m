// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Buffers.m
#import "SMK_GL_Buffers.h"

// A buffer keeps its contents in _bufferData until a context is attached;
// then a _SMK_GL_BufferImp subclass holds them in a VBO, in vertex array
// range memory or in plain memory.

@implementation SMK_GL_GenericBuffer

- (BOOL)isDirty
{
	return [_bufferImp isDirty];
}

- (void)stopDrawing
{
	[_bufferImp stopDrawing];
}

- (void)startDrawing
{
	[_bufferImp startDrawing];
}

- (void)unbind
{
	if (_vertexArrayObject == 0) {
		[self _unbindPointers];
	}
	else {
		glBindVertexArrayAPPLE(0);
	}
	[_bufferImp unbind];
}

- (void)rebind
{
	if (_vertexArrayObject == 0) {
		void *p = [_bufferImp rebind];
		if (p != NULL) {
			[self _bindPointers:p];
		}
	}
	else {
		glBindVertexArrayAPPLE(_vertexArrayObject);
	}
}

- (void)bind
{
	if (_vertexArrayObject == 0) {
		if (_requiresVAO) {
			glGenVertexArraysAPPLE(1, &_vertexArrayObject);
			glBindVertexArrayAPPLE(_vertexArrayObject);
		}
		[self _bindPointers:[_bufferImp bind]];
	}
	else {
		glBindVertexArrayAPPLE(_vertexArrayObject);
	}
}

- (void)unlock
{
	NSUInteger length = _updateOnUnlock ? _elementSize * _count : 0;
	if (_autoUpdateBounds && _updateOnUnlock) {
		[self _updateBufferBounds];
	}
	[_bufferImp unlock:NSMakeRange(0, length)];
	if (_vertexArrayObject != 0) {
		glDeleteVertexArraysAPPLE(1, &_vertexArrayObject);
		_vertexArrayObject = 0;
	}
	_lockedPointer = NULL;
}

- (void *)lock:(NSInteger)aLock
{
	_updateOnUnlock = aLock == kSMK_GL_LockWriteOnly || aLock == kSMK_GL_LockReadWrite;
	_lockedPointer = [_bufferImp lock:aLock];
	if (_lockedPointer == NULL) {
		if (_bufferData == nil) {
			_bufferData = [[NSMutableData alloc] initWithLength:_elementSize * _count];
		}
		_lockedPointer = [_bufferData mutableBytes];
	}
	return _lockedPointer;
}

- (void)contextWillBeDetached
{
	if (_vertexArrayObject != 0) {
		glDeleteVertexArraysAPPLE(1, &_vertexArrayObject);
	}
	_vertexArrayObject = 0;
	[super contextWillBeDetached];
}

- (NSUInteger)length
{
	return _count * _elementSize;
}

- (NSInteger)usage
{
	return _usage & 0xfff;
}

- (NSUInteger)elementSize
{
	return _elementSize;
}

- (NSUInteger)count
{
	return _count;
}

- (void)dealloc
{
	[_context _bufferWillDie:self];
	[_bufferData release];
	[super dealloc];
}

- (id)initWithContainer:(id)aContainer count:(NSUInteger)aCount elementSize:(NSUInteger)aSize usage:(NSInteger)aUsage
{
	self = [super initWithContainer:aContainer];
	if (self != nil) {
		_count = (unsigned int)aCount;
		_elementSize = (unsigned int)aSize;
		_usage = (int)aUsage;
		_requiresVAO = NO;
	}
	return self;
}

@end

@implementation SMK_GL_IndexBuffer

- (void)drawInMode:(NSUInteger)aMode first:(NSUInteger)aFirst count:(NSUInteger)aCount
{
	if (_elementArrayAPPLE) {
		glDrawRangeElementArrayAPPLE((GLenum)aMode, _minIndex, _maxIndex, (GLint)aFirst, (GLsizei)aCount);
	}
	else if (_drawRangeElements) {
		glDrawRangeElements((GLenum)aMode, _minIndex, _maxIndex, (GLsizei)aCount, _indexType,
			(char *)_boundPointer + aFirst * _elementSize);
	}
	else {
		glDrawElements((GLenum)aMode, (GLsizei)aCount, _indexType,
			(char *)_boundPointer + aFirst * _elementSize);
	}
}

- (void)contextWillBeDetached
{
	[_bufferImp release];
	_bufferImp = nil;
	_elementArrayAPPLE = NO;
	[super contextWillBeDetached];
}

// indices always stay in client memory
- (void)contextWasAttached:(id)aAttached
{
	[super contextWasAttached:aAttached];
	_drawRangeElements = [aAttached drawRangeElementsEXT];
	_bufferImp = [[_SMK_GL_BufferImpGeneric alloc] initWithData:_bufferData
		capacity:_elementSize * _count];
}

- (void)unbind
{
}

- (void)bind
{
	if (_boundPointer == NULL) {
		_boundPointer = [_bufferImp bind];
	}
}

#define MIN_MAX_INDEX(type) do { \
		const type *p = _lockedPointer, *end = (const type *)((const char *)_lockedPointer + _elementSize * _count); \
		type lo = *p, hi = *p; \
		for (p++; p < end; p++) { \
			if (*p < lo) { \
				lo = *p; \
			} \
			else if (*p > hi) { \
				hi = *p; \
			} \
		} \
		_minIndex = lo; \
		_maxIndex = hi; \
	} while (0)

- (void)_updateBufferBounds
{
	switch (_indexType) {
		case GL_UNSIGNED_SHORT:
			MIN_MAX_INDEX(GLushort);
			break;
		case GL_UNSIGNED_INT:
			MIN_MAX_INDEX(GLuint);
			break;
		case GL_UNSIGNED_BYTE:
			MIN_MAX_INDEX(GLubyte);
			break;
	}
}

- (NSUInteger)indicesCount
{
	return _count;
}

- (NSUInteger)maxIndex
{
	return _maxIndex;
}

- (NSUInteger)minIndex
{
	return _minIndex;
}

- (BOOL)are32BitIndices
{
	return _elementSize == 4;
}

- (NSUInteger)indexType
{
	return _indexType;
}

// Any other index type means "the smallest one that fits".
- (id)initWithContainer:(id)aContainer count:(NSUInteger)aCount usage:(NSInteger)aUsage indexType:(NSUInteger)aType
{
	GLenum type;
	NSUInteger size;
	if (aType == GL_UNSIGNED_BYTE) {
		type = GL_UNSIGNED_BYTE;
		size = 1;
	}
	else if (aType == GL_UNSIGNED_SHORT || (aType != GL_UNSIGNED_INT && aCount < 0x10000)) {
		type = GL_UNSIGNED_SHORT;
		size = 2;
	}
	else {
		type = GL_UNSIGNED_INT;
		size = 4;
	}
	self = [super initWithContainer:aContainer count:aCount elementSize:size usage:aUsage];
	if (self != nil) {
		_indexType = type;
		_autoUpdateBounds = YES;
	}
	return self;
}

- (id)initWithContainer:(id)aContainer count:(NSUInteger)aCount usage:(NSInteger)aUsage
{
	BOOL small = aCount < 0x10000;
	self = [super initWithContainer:aContainer count:aCount elementSize:small ? 2 : 4 usage:aUsage];
	if (self != nil) {
		_indexType = small ? GL_UNSIGNED_SHORT : GL_UNSIGNED_INT;
		_autoUpdateBounds = YES;
	}
	return self;
}

@end

@implementation SMK_GL_VertexBuffer

+ (NSUInteger)vertexSizeForFVF:(NSUInteger)aFVF
{
	NSUInteger size = 0;
	if (aFVF & kSMK_GL_FVF_Position) {
		size += 12;
	}
	if (aFVF & kSMK_GL_FVF_Normal) {
		size += 12;
	}
	if (aFVF & kSMK_GL_FVF_Diffuse) {
		size += 4;
	}
	if (aFVF & kSMK_GL_FVF_Specular) {
		size += 4;
	}
	size += ((aFVF & kSMK_GL_FVF_TexCoordMask) >> kSMK_GL_FVF_TexCoordShift) * 8;
	return size;
}

- (void)_unbindPointers
{
	if (_fvf & kSMK_GL_FVF_Position) {
		glDisableClientState(GL_VERTEX_ARRAY);
	}
	if (_fvf & kSMK_GL_FVF_Normal) {
		glDisableClientState(GL_NORMAL_ARRAY);
	}
	if (_fvf & kSMK_GL_FVF_Diffuse) {
		glDisableClientState(GL_COLOR_ARRAY);
	}
	if (_fvf & kSMK_GL_FVF_Specular) {
		glDisableClientState(GL_SECONDARY_COLOR_ARRAY);
	}
	int sets = (_fvf & kSMK_GL_FVF_TexCoordMask) >> kSMK_GL_FVF_TexCoordShift;
	if (sets != 0) {
		for (int i = 0; i < sets; i++) {
			glClientActiveTextureARB(GL_TEXTURE0_ARB + i);
			glDisableClientState(GL_TEXTURE_COORD_ARRAY);
		}
		glClientActiveTextureARB(GL_TEXTURE0_ARB);
	}
}

- (void)_bindPointers:(char *)aPointers
{
	if (_fvf & kSMK_GL_FVF_Position) {
		glEnableClientState(GL_VERTEX_ARRAY);
		glVertexPointer(3, GL_FLOAT, _elementSize, aPointers);
		aPointers += 12;
	}
	if (_fvf & kSMK_GL_FVF_Normal) {
		glEnableClientState(GL_NORMAL_ARRAY);
		glNormalPointer(GL_FLOAT, _elementSize, aPointers);
		aPointers += 12;
	}
	if (_fvf & kSMK_GL_FVF_Diffuse) {
		glEnableClientState(GL_COLOR_ARRAY);
		glColorPointer(4, GL_UNSIGNED_BYTE, _elementSize, aPointers);
		aPointers += 4;
	}
	if (_fvf & kSMK_GL_FVF_Specular) {
		glEnableClientState(GL_SECONDARY_COLOR_ARRAY);
		glSecondaryColorPointer(4, GL_UNSIGNED_BYTE, _elementSize, aPointers);
		aPointers += 4;
	}
	int sets = (_fvf & kSMK_GL_FVF_TexCoordMask) >> kSMK_GL_FVF_TexCoordShift;
	for (int i = 0; i < sets; i++) {
		glClientActiveTextureARB(GL_TEXTURE0_ARB + i);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);
		glTexCoordPointer(2, GL_FLOAT, _elementSize, aPointers);
		aPointers += 8;
	}
}

// bounding box of the vertex positions (the first three floats of each vertex)
- (void)_updateBufferBounds
{
	const char *p = _lockedPointer;
	const char *end = p + _count * _elementSize;
	const float *v = (const float *)p;
	_minCorner = _maxCorner = (SMK_GL_Vec3){ v[0], v[1], v[2] };
	for (p += _elementSize; p < end; p += _elementSize) {
		v = (const float *)p;
		_minCorner.x = MIN(_minCorner.x, v[0]);
		_maxCorner.x = MAX(_maxCorner.x, v[0]);
		_minCorner.y = MIN(_minCorner.y, v[1]);
		_maxCorner.y = MAX(_maxCorner.y, v[1]);
		_minCorner.z = MIN(_minCorner.z, v[2]);
		_maxCorner.z = MAX(_maxCorner.z, v[2]);
	}
}

- (SMK_GL_Vec3 *)maxCorner
{
	return &_maxCorner;
}

- (SMK_GL_Vec3 *)minCorner
{
	return &_minCorner;
}

- (void)setAutoUpdateBounds:(BOOL)aBounds
{
	_autoUpdateBounds = aBounds;
}

- (void)drawNonIndexedInMode:(NSUInteger)aMode first:(NSUInteger)aFirst count:(NSUInteger)aCount
{
	glDrawArrays((GLenum)aMode, (GLint)aFirst, (GLsizei)aCount);
}

- (void)contextWillBeDetached
{
	[_bufferImp release];
	_bufferImp = nil;
	[super contextWillBeDetached];
}

- (void)contextWasAttached:(id)aAttached
{
	[super contextWasAttached:aAttached];
	if (!(_usage & kSMK_GL_UsageSystemMemory)) {
		if ([aAttached vertexBufferObjectARB]) {
			_bufferImp = [[_SMK_GL_BufferImpVBO alloc] initWithData:_bufferData
				capacity:_elementSize * _count target:GL_ARRAY_BUFFER_ARB usage:_usage context:_context];
			return;
		}
		if ([aAttached vertexArrayRangeAPPLE]) {
			_bufferImp = [[_SMK_GL_BufferImpVAR alloc] initWithData:_bufferData
				capacity:_elementSize * _count target:GL_VERTEX_ARRAY_RANGE_APPLE usage:_usage
				context:_context];
			return;
		}
	}
	_bufferImp = [[_SMK_GL_BufferImpGeneric alloc] initWithData:_bufferData
		capacity:_elementSize * _count];
}

- (NSUInteger)vertexSize
{
	return _elementSize;
}

- (NSUInteger)fvf
{
	return _fvf;
}

- (id)initWithContainer:(id)aContainer count:(NSUInteger)aCount usage:(NSInteger)aUsage fvf:(NSUInteger)aFvf
{
	NSUInteger size = [[self class] vertexSizeForFVF:aFvf];
	NSAssert(size != 0, @"Vertex format is invalid.");
	self = [super initWithContainer:aContainer count:aCount elementSize:size usage:aUsage];
	if (self != nil) {
		_fvf = (unsigned int)aFvf;
	}
	return self;
}

@end

@implementation _SMK_GL_BufferImp

- (void)unlock:(NSRange)aUnlock
{
}

- (void *)lock:(NSUInteger)aLock
{
	return NULL;
}

- (void)unbind
{
}

- (void *)rebind
{
	return NULL;
}

- (void *)bind
{
	return NULL;
}

- (BOOL)isDirty
{
	return NO;
}

- (void)stopDrawing
{
}

- (void)startDrawing
{
}

@end

// plain memory
@implementation _SMK_GL_BufferImpGeneric

- (void)unlock:(NSRange)aUnlock
{
}

- (void *)lock:(NSInteger)aLock
{
	return [_data mutableBytes];
}

- (void)unbind
{
}

- (void *)bind
{
	return [_data mutableBytes];
}

- (void)dealloc
{
	[_data release];
	[super dealloc];
}

- (id)initWithData:(id)aData capacity:(NSUInteger)aCapacity
{
	self = [super init];
	if (self != nil) {
		_data = aData != nil ? [aData retain] : [[NSMutableData alloc] initWithLength:aCapacity];
	}
	return self;
}

@end

// Vertex array range memory. Dynamic buffers rotate through four copies,
// each guarded by a fence, so writing one doesn't stall on drawing another.
@implementation _SMK_GL_BufferImpVAR

- (void)unlock:(NSRange)aUnlock
{
	NSRange current = _bufferRanges[_currentBufferIndex];
	if (aUnlock.length >= current.length) {
		aUnlock.length = current.length;
	}
	[_context _accumulateFlushVAR:NSMakeRange(current.location + aUnlock.location, aUnlock.length)];
}

- (void *)lock:(NSInteger)aLock
{
	int next;
	if (aLock == kSMK_GL_LockReadOnly || (_currentBufferIndex >= 0 && (_usage & 0xfff) == 0)) {
		next = _currentBufferIndex;
	}
	else {
		next = (_currentBufferIndex + 1) & 3;
	}
	_isDirty = _currentBufferIndex != next;
	if (aLock != kSMK_GL_LockReadOnly && _bufferFences[next] != 0) {
		glFinishFenceAPPLE(_bufferFences[next]);
	}
	char *base = [_context _currentPointerVAR];
	if (aLock == kSMK_GL_LockReadWrite && _currentBufferIndex >= 0 && _isDirty) {
		// carry the previous copy's contents over
		memmove(base + _bufferRanges[next].location, base + _bufferRanges[_currentBufferIndex].location,
			MIN(_bufferRanges[next].length, _bufferRanges[_currentBufferIndex].length));
	}
	_currentBufferIndex = next;
	return base + _bufferRanges[next].location;
}

- (void)unbind
{
	glDisableClientState(_target);
}

- (void *)rebind
{
	if (!_isDirty) {
		return NULL;
	}
	_isDirty = NO;
	return (char *)[_context _currentPointerVAR] + _bufferRanges[_currentBufferIndex].location;
}

- (void *)bind
{
	glEnableClientState(_target);
	_isDirty = NO;
	return (char *)[_context _currentPointerVAR] + _bufferRanges[_currentBufferIndex].location;
}

- (BOOL)isDirty
{
	return _isDirty;
}

- (void)stopDrawing
{
	if (_bufferFences[_currentBufferIndex] != 0) {
		glSetFenceAPPLE(_bufferFences[_currentBufferIndex]);
	}
}

- (void)startDrawing
{
	[_context _flushVAR:_bufferRanges[_currentBufferIndex]];
}

- (void)dealloc
{
	if (_bufferFences[0] != 0) {
		glDeleteFencesAPPLE(4, _bufferFences);
	}
	for (int i = 0; i < 4; i++) {
		[_context _deallocateVAR:_bufferRanges[i]];
	}
	[super dealloc];
}

- (id)initWithData:(id)aData capacity:(NSUInteger)aCapacity target:(NSUInteger)aTarget usage:(NSInteger)aUsage context:(id)aContext
{
	self = [super init];
	if (self == nil) {
		return nil;
	}
	_context = aContext;
	_usage = (int)aUsage;
	_target = (unsigned int)aTarget;
	if ((aUsage & 0xfff) == kSMK_GL_UsageStatic) {
		_bufferRanges[0] = [aContext _allocateVAR:aCapacity];
	}
	else {
		glGenFencesAPPLE(4, _bufferFences);
		for (int i = 0; i < 4; i++) {
			_bufferRanges[i] = [_context _allocateVAR:aCapacity];
			glSetFenceAPPLE(_bufferFences[i]);
		}
	}
	if (aData == nil) {
		_currentBufferIndex = -1;
	}
	else {
		_currentBufferIndex = 0;
		memmove((char *)[_context _currentPointerVAR] + _bufferRanges[0].location, [aData bytes], aCapacity);
	}
	return self;
}

@end

@implementation _SMK_GL_BufferImpVBO

- (void)unlock:(NSRange)aUnlock
{
	glBindBufferARB(_target, _object);
	glUnmapBufferARB(_target);
	glBindBufferARB(_target, 0);
	[_ctx _resetAllBondBuffers];
}

- (void *)lock:(NSInteger)aLock
{
	GLenum access = 0;
	switch (aLock) {
		case kSMK_GL_LockReadOnly:
			access = GL_READ_ONLY_ARB;
			break;
		case kSMK_GL_LockReadWrite:
			access = GL_READ_WRITE_ARB;
			break;
		case kSMK_GL_LockWriteOnly:
			access = GL_WRITE_ONLY_ARB;
			break;
		default:
			NSAssert(NO, @"Invalid lock type");
	}
	glBindBufferARB(_target, _object);
	void *p = glMapBufferARB(_target, access);
	glBindBufferARB(_target, 0);
	[_ctx _resetAllBondBuffers];
	return p;
}

- (void)unbind
{
	glBindBufferARB(_target, 0);
}

// with a VBO bound, vertex pointers are offsets into it
- (void *)bind
{
	glBindBufferARB(_target, _object);
	return NULL;
}

- (void)dealloc
{
	glDeleteBuffersARB(1, &_object);
	[super dealloc];
}

- (id)initWithData:(id)aData capacity:(NSUInteger)aCapacity target:(NSUInteger)aTarget usage:(NSInteger)aUsage context:(id)aContext
{
	self = [super init];
	if (self == nil) {
		return nil;
	}
	_ctx = aContext;
	GLenum usage = GL_STATIC_DRAW_ARB;
	switch (aUsage & 0xfff) {
		case kSMK_GL_UsageDynamic:
			usage = GL_DYNAMIC_DRAW_ARB;
			break;
		case kSMK_GL_UsageStatic:
			usage = GL_STATIC_DRAW_ARB;
			break;
		case kSMK_GL_UsageStream:
			usage = GL_STREAM_DRAW_ARB;
			break;
	}
	_target = (unsigned int)aTarget;
	glGenBuffersARB(1, &_object);
	glBindBufferARB(_target, _object);
	if (aData == nil) {
		aData = [NSMutableData dataWithLength:aCapacity];
	}
	glBufferDataARB(_target, aCapacity, [aData bytes], usage);
	glBindBufferARB(_target, 0);
	[_ctx _resetAllBondBuffers];
	return self;
}

@end

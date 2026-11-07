// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_object.m
#import "SMK_GL_object.h"

NSString *kSMK_GL_ObjectsContainerWillDieNotification = @"kSMK_GL_ObjectsContainerWillDieNotification";

@implementation SMK_GL_Object

- (void)contextWillBeDetached
{
	_context = nil;
}

- (void)contextWasAttached:(id)aAttached
{
	_context = aAttached;
}

- (id)context
{
	return _context;
}

- (id)currentContext
{
	return _context;
}

- (void)_markContainerAsDead
{
	_container = nil;
}

- (void)dealloc
{
	[_container removeObject:self];
	[super dealloc];
}

- (id)initWithContainer:(id)aContainer
{
	self = [super init];
	if (self != nil) {
		_container = aContainer;
		// the container keeps a non-retaining reference
		[aContainer addObject:self];
	}
	return self;
}

@end

// The container holds its objects without retaining them: adding an object
// releases the reference the set took, and removing one retains it first to
// balance the set's release.
@implementation SMK_GL_ObjectsContainer

- (id)context
{
	return _context;
}

- (id)currentContext
{
	return _context;
}

- (void)adjustFrameDependedObjects:(double)aObjects
{
	_currentTime = aObjects;
	[_particleSystems makeObjectsPerformSelector:@selector(adjustToNewFrameTime)];
}

- (double)currentFrameTime
{
	return _currentTime;
}

- (void)contextWillBeDetached
{
	[[_context systemContext] makeCurrentContext];
	[_objects makeObjectsPerformSelector:@selector(contextWillBeDetached)];
	[_accumObjects removeAllObjects];
	_context = nil;
}

- (void)contextWasAttached:(id)aAttached
{
	_context = aAttached;
	[[aAttached systemContext] makeCurrentContext];
	[_objects makeObjectsPerformSelector:@selector(contextWasAttached:) withObject:aAttached];
	NSMutableSet *pending = [NSMutableSet setWithSet:_accumObjects];
	[pending intersectSet:_objects];
	[pending makeObjectsPerformSelector:@selector(retain)];
	[_accumObjects minusSet:_objects];
}

- (void)endAccumulationBlock
{
	if (_context != nil) {
		[_context makeCurrent];
		[_accumObjects makeObjectsPerformSelector:@selector(contextWasAttached:) withObject:_context];
	}
	[_accumObjects makeObjectsPerformSelector:@selector(retain)];
	[_accumObjects removeAllObjects];
}

- (void)beginAccumulationBlock
{
}

- (void)removeParticlesSystem:(id)aSystem
{
	if ([_particleSystems containsObject:aSystem]) {
		[aSystem retain];
		[_particleSystems removeObject:aSystem];
	}
}

- (void)addParticlesSystem:(id)aSystem
{
	if (![_particleSystems containsObject:aSystem]) {
		[_particleSystems addObject:aSystem];
		[aSystem release];
	}
}

- (void)removeObject:(id)aObject
{
	BOOL wasMember = [_objects containsObject:aObject];
	if (wasMember) {
		[aObject retain];
		[_objects removeObject:aObject];
	}
	if ([_accumObjects containsObject:aObject]) {
		[aObject retain];
		[_accumObjects removeObject:aObject];
	}
	else if (!wasMember) {
		return;
	}
	if ([aObject context] != nil) {
		[aObject contextWillBeDetached];
	}
}

- (void)addObject:(id)aObject
{
	if (![_objects containsObject:aObject]) {
		[_objects addObject:aObject];
		[aObject release];
	}
	if (![_accumObjects containsObject:aObject]) {
		[_accumObjects addObject:aObject];
		[aObject release];
	}
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter]
		postNotificationName:kSMK_GL_ObjectsContainerWillDieNotification object:self];
	[_objects makeObjectsPerformSelector:@selector(retain)];
	[_objects makeObjectsPerformSelector:@selector(_markContainerAsDead)];
	[_objects release];
	[_particleSystems makeObjectsPerformSelector:@selector(retain)];
	[_particleSystems release];
	[_accumObjects makeObjectsPerformSelector:@selector(retain)];
	[_accumObjects release];
	[super dealloc];
}

- (id)init
{
	self = [super init];
	if (self != nil) {
		_objects = [NSMutableSet new];
		_particleSystems = [NSMutableSet new];
		_accumObjects = [NSMutableSet new];
	}
	return self;
}

@end

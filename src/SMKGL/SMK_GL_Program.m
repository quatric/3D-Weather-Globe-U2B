// Original module: /Users/maxx/Projects/WB2005/SMKGL_all/SMKGL_sources/Sources/SMK_GL_Program.m
#import "SMK_GL_Program.h"

// An ARB assembly program. Its data source supplies the local parameters,
// each a run of vec4 constants, every time it is bound.
@implementation SMK_GL_Program

- (void)unbind
{
	glDisable((GLenum)[self _programTarget]);
}

- (void)bind
{
	GLenum target = (GLenum)[self _programTarget];
	glBindProgramARB(target, _program);
	glEnable(target);
	if (_constSizes == nil) {
		_numConstants = (unsigned int)[_dataSource numberOfParametersForProgram:self];
		_constSizes = [[NSMutableData alloc] initWithLength:_numConstants * sizeof(unsigned int)];
		_constSizesArray = [_constSizes mutableBytes];
		NSUInteger total = 0;
		for (unsigned int i = 0; i < _numConstants; i++) {
			_constSizesArray[i] = (unsigned int)[_dataSource program:self sizeOfParameterAtIndex:i];
			total += _constSizesArray[i];
		}
		_constsBuffer = [[NSMutableData alloc] initWithLength:total * 16];
	}
	char *consts = [_constsBuffer mutableBytes];
	unsigned int index = 0;
	for (unsigned int i = 0; i < _numConstants; i++) {
		unsigned int size = _constSizesArray[i];
		if ([_dataSource program:self fillParameter:consts atIndex:i]) {
			for (unsigned int k = 0; k < size; k++) {
				glProgramLocalParameter4fvARB(target, index + k, (const GLfloat *)(consts + k * 16));
			}
		}
		consts += size * 16;
		index += size;
	}
}

- (void)contextWillBeDetached
{
	if (_program != 0) {
		glDeleteProgramsARB(1, &_program);
		_program = 0;
	}
	[_constSizes release];
	[_constsBuffer release];
	_constSizes = nil;
	_constsBuffer = nil;
	_numConstants = 0;
	_constSizesArray = NULL;
	[super contextWillBeDetached];
}

- (void)contextWasAttached:(id)aAttached
{
	[super contextWasAttached:aAttached];
	GLenum target = (GLenum)[self _programTarget];
	if (target != 0) {
		glGenProgramsARB(1, &_program);
		glBindProgramARB(target, _program);
		const char *code = [_code UTF8String];
		glProgramStringARB(target, GL_PROGRAM_FORMAT_ASCII_ARB, (GLsizei)strlen(code), code);
	}
}

- (NSUInteger)_programTarget
{
	return 0;
}

- (void)dealloc
{
	[_code release];
	[super dealloc];
}

- (id)initWithContainer:(id)aContainer string:(id)aString dataSource:(id)aSource
{
	self = [super initWithContainer:aContainer];
	if (self != nil) {
		_code = [aString copy];
		_dataSource = aSource;
	}
	return self;
}

@end

@implementation SMK_GL_FragmentProgram

- (NSUInteger)_programTarget
{
	return [_context fragmentProgramARB] ? GL_FRAGMENT_PROGRAM_ARB : 0;
}

@end

@implementation SMK_GL_VertexProgram

- (NSUInteger)_programTarget
{
	return [_context vertexProgramARB] ? GL_VERTEX_PROGRAM_ARB : 0;
}

@end

#import "DynamicEnvironment.h"

// entry points of the URLCreator plugin
typedef id (*GetURLForCloudsDownloadProc)(char aWest, id aDate, int aSize);
typedef id (*GetURLForReportDownloadProc)(float aX, float aY, int aReport);
typedef id (*GetURLForReportDownloadByIDProc)(int aID, int aReport);
typedef int (*GetVersionProc)(void);
typedef id (*GetXMLForReportDataProc)(id aData, int aReport);
typedef id (*GetJPGForCloudsDataProc)(id aData);
typedef id (*GetReportProc)(void);

static DynamicEnvironment *_sCocoaDynaEnv = nil;
static int _sDLLVErsion = 0;

@implementation DynamicEnvironment

+ (void)replaceDYLIBWithNew:(id)aNew
{
    [[self singleton] replaceDYLIBWithNew:aNew];
}

+ (id)jpegDataForCloudsData:(id)aData
{
    return [[self singleton] jpegDataForCloudsData:aData];
}

+ (id)xmlDataForReport:(NSInteger)aReport fromData:(id)aData
{
    return [[self singleton] xmlDataForReport:aReport fromData:aData];
}

+ (id)reportP
{
    return [[self singleton] reportP];
}

+ (id)reportUN
{
    return [[self singleton] reportUN];
}

+ (id)URLForReportDownload:(NSInteger)aDownload cw_id:(NSInteger)aId
{
    return [[self singleton] URLForReportDownload:aDownload cw_id:aId];
}

+ (id)URLForReportDownload:(NSInteger)aDownload geoPoint:(NSPoint)aPoint
{
    return [[self singleton] URLForReportDownload:aDownload geoPoint:aPoint];
}

+ (id)URLForCloudsWest:(BOOL)aWest date:(id)aDate size:(NSInteger)aSize
{
    return [[self singleton] URLForCloudsWest:aWest date:aDate size:aSize];
}

+ (NSInteger)currentVersion
{
    return [[self singleton] currentVersion];
}

+ (id)singleton
{
    if (_sCocoaDynaEnv == nil)
        _sCocoaDynaEnv = [DynamicEnvironment new];
    return _sCocoaDynaEnv;
}

- (id)jpegDataForCloudsData:(id)aData
{
    [self _loadBundleIfNeeded];
    if (_jpegParserFuncPtr != NULL)
        return ((GetJPGForCloudsDataProc)_jpegParserFuncPtr)(aData);
    return aData;
}

- (id)xmlDataForReport:(NSInteger)aReport fromData:(id)aData
{
    [self _loadBundleIfNeeded];
    if (_xmlParserFuncPtr != NULL)
        return ((GetXMLForReportDataProc)_xmlParserFuncPtr)(aData, (int)aReport);
    return aData;
}

- (id)reportP
{
    [self _loadBundleIfNeeded];
    if (_getReportPFuncPtr != NULL)
        return ((GetReportProc)_getReportPFuncPtr)();
    return nil;
}

- (id)reportUN
{
    [self _loadBundleIfNeeded];
    if (_getReportUNFuncPtr != NULL)
        return ((GetReportProc)_getReportUNFuncPtr)();
    return nil;
}

- (id)URLForReportDownload:(NSInteger)aDownload cw_id:(NSInteger)aId
{
    [self _loadBundleIfNeeded];
    if (_reportsByIDFuncPtr != NULL)
        return ((GetURLForReportDownloadByIDProc)_reportsByIDFuncPtr)((int)aId, (int)aDownload);
    return nil;
}

- (id)URLForReportDownload:(NSInteger)aDownload geoPoint:(NSPoint)aPoint
{
    [self _loadBundleIfNeeded];
    if (_reportsFuncPtr != NULL)
        return ((GetURLForReportDownloadProc)_reportsFuncPtr)((float)aPoint.x, (float)aPoint.y, (int)aDownload);
    return nil;
}

- (id)URLForCloudsWest:(BOOL)aWest date:(id)aDate size:(NSInteger)aSize
{
    [self _loadBundleIfNeeded];
    if (_cloudsFuncPtr != NULL)
        return ((GetURLForCloudsDownloadProc)_cloudsFuncPtr)((char)aWest, aDate, (int)aSize);
    return nil;
}

- (NSInteger)currentVersion
{
    [self _loadBundleIfNeeded];
    if (_getVerFuncPtr != NULL)
        return ((GetVersionProc)_getVerFuncPtr)();
    return 0;
}

- (void)dealloc
{
    [self _unloadBundle];
    [super dealloc];
}

- (id)init
{
    self = [super init];
    if (self != nil) {
        NSFileManager *manager = [NSFileManager defaultManager];
        NSString *tempPath = [self _tempURLLibRootPath];
        if ([manager isReadableFileAtPath:tempPath]) {
            NSString *path = [self _URLLibRootPath];
            [manager removeItemAtPath:path error:NULL];
            [manager moveItemAtPath:tempPath toPath:path error:NULL];
        }
    }
    return self;
}

- (void)replaceDYLIBWithNew:(id)aNew
{
    [self _unloadBundle];
    [_dylibRootPath release];
    _dylibRootPath = [[self _tempURLLibRootPath] retain];
    [self _createPluginBundleWithDYLIBBody:aNew atPath:_dylibRootPath];
}

- (void)_unloadBundle
{
    if (_loadedBundle == NULL)
        return;
    CFBundleUnloadExecutable(_loadedBundle);
    CFRelease(_loadedBundle);
    _loadedBundle = NULL;
    _cloudsFuncPtr = NULL;
    _reportsFuncPtr = NULL;
    _reportsByIDFuncPtr = NULL;
    _getVerFuncPtr = NULL;
    _xmlParserFuncPtr = NULL;
    _jpegParserFuncPtr = NULL;
}

- (void)_loadBundleIfNeeded
{
    if (_loadedBundle != NULL)
        return;
    if (_dylibRootPath == nil)
        _dylibRootPath = [[self _URLLibRootPath] retain];
    NSString *libPath = [self _URLLibFullPath];
    NSString *defaultPath = [[NSBundle mainBundle] pathForResource:@"URLCreator.dylib" ofType:@""];
    NSFileManager *manager = [NSFileManager defaultManager];
    NSTimeInterval installed = [[[manager attributesOfItemAtPath:libPath error:NULL] fileModificationDate] timeIntervalSinceReferenceDate];
    NSTimeInterval shipped = [[[manager attributesOfItemAtPath:defaultPath error:NULL] fileModificationDate] timeIntervalSinceReferenceDate];
    if (![manager isReadableFileAtPath:libPath] || installed < shipped) {
        NSData *body = [NSData dataWithContentsOfFile:defaultPath];
        NSAssert(body != nil, @"Unable to get default URL Creator Bundle");
        [self _createPluginBundleWithDYLIBBody:body atPath:_dylibRootPath];
    }
    _loadedBundle = CFBundleCreate(kCFAllocatorDefault, (CFURLRef)[NSURL fileURLWithPath:_dylibRootPath]);
    if (_loadedBundle == NULL)
        return;
    if (!CFBundleLoadExecutable(_loadedBundle)) {
        CFRelease(_loadedBundle);
        _loadedBundle = NULL;
        return;
    }
    _cloudsFuncPtr = CFBundleGetFunctionPointerForName(_loadedBundle, CFSTR("GetURLForCloudsDownload"));
    _reportsFuncPtr = CFBundleGetFunctionPointerForName(_loadedBundle, CFSTR("GetURLForReportDownload"));
    _reportsByIDFuncPtr = CFBundleGetFunctionPointerForName(_loadedBundle, CFSTR("GetURLForReportDownloadByID"));
    _getVerFuncPtr = CFBundleGetFunctionPointerForName(_loadedBundle, CFSTR("GetVersion"));
    _xmlParserFuncPtr = CFBundleGetFunctionPointerForName(_loadedBundle, CFSTR("GetXMLForReportData"));
    _jpegParserFuncPtr = CFBundleGetFunctionPointerForName(_loadedBundle, CFSTR("GetJPGForCloudsData"));
    _getReportUNFuncPtr = CFBundleGetFunctionPointerForName(_loadedBundle, CFSTR("GetReportUN"));
    _getReportPFuncPtr = CFBundleGetFunctionPointerForName(_loadedBundle, CFSTR("GetReportP"));
    if (_getVerFuncPtr != NULL)
        _sDLLVErsion = ((GetVersionProc)_getVerFuncPtr)();
}

- (id)_URLLibFullPath
{
    return [_dylibRootPath stringByAppendingPathComponent:[NSString stringWithFormat:@"Contents/MacOS/%@", @"URLs"]];
}

- (id)_tempURLLibRootPath
{
    return [[[[NSFileManager defaultManager] atlasSharedFolder] stringByAppendingPathComponent:@"URLs"] stringByAppendingPathExtension:@"tmp"];
}

- (id)_URLLibRootPath
{
    return [[[NSFileManager defaultManager] atlasSharedFolder] stringByAppendingPathComponent:@"URLs"];
}

- (void)_createPluginBundleWithDYLIBBody:(id)aBody atPath:(id)aPath
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSDictionary *attributes = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0777] forKey:NSFilePosixPermissions];
    [manager createDirectoryAtPath:aPath withIntermediateDirectories:NO attributes:attributes error:NULL];
    NSString *contents = [aPath stringByAppendingPathComponent:@"Contents"];
    [manager createDirectoryAtPath:contents withIntermediateDirectories:NO attributes:attributes error:NULL];
    _sDLLVErsion++;
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"6.0", @"CFBundleInfoDictionaryVersion",
                          @"BNDL", @"CFBundlePackageType",
                          @"URLs", @"CFBundleExecutable",
                          [NSString stringWithFormat:@"com.mackiev.3DAtlasDYLib_%d", _sDLLVErsion], @"CFBundleIdentifier",
                          nil];
    [info writeToFile:[contents stringByAppendingPathComponent:@"Info.plist"] atomically:YES];
    NSString *macOS = [contents stringByAppendingPathComponent:@"MacOS"];
    [manager createDirectoryAtPath:macOS withIntermediateDirectories:NO attributes:attributes error:NULL];
    NSString *executable = [macOS stringByAppendingPathComponent:@"URLs"];
    if ([aBody writeToFile:executable atomically:YES])
        [manager setAttributes:attributes ofItemAtPath:executable error:NULL];
    else
        NSLog(@"Unable to replace DLL at path %@", executable);
}

@end

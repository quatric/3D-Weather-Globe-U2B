#import "NSFileManager+WBAtlasFileManager.h"

static NSString *_sRoutesSupportFolder;
static NSString *_sAppSupportFolder;

// Translates a localized folder name from the PathComponents table.
static NSString *_pathComponent(NSString *aKey)
{
	return [[NSBundle mainBundle] localizedStringForKey:aKey value:@"" table:kPathCompTable];
}

static NSDictionary *_openPermissions(void)
{
	return [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0777] forKey:NSFilePosixPermissions];
}

static NSString *_localized(NSString *aKey)
{
	return [[NSBundle mainBundle] localizedStringForKey:aKey value:@"" table:@"Localizable"];
}

// The atlas's files: the shared folder (database, caches, downloads) in
// Application Support and the routes folder in Documents.
@implementation NSFileManager (WBAtlasFileManager)

- (id)securityFilePath
{
	return [[self _appSupportFolder] stringByAppendingPathComponent:kSecurityFile];
}

- (id)serialNumberPath
{
	return [[self atlasSharedFolder] stringByAppendingPathComponent:kSerialNumberFile];
}

// the routes folder in the user's Documents, created if needed
- (id)routesFolder
{
	if (_sRoutesSupportFolder != nil && [self fileExistsAtPath:_sRoutesSupportFolder]) {
		return _sRoutesSupportFolder;
	}
	[_sRoutesSupportFolder release];
	_sRoutesSupportFolder = nil;
	NSString *documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
	if (documents == nil) {
		return nil;
	}
	NSString *folder = [documents stringByAppendingPathComponent:_pathComponent(kRoutesFolder)];
	if (![self fileExistsAtPath:folder] &&
	    ![self createDirectoryAtPath:folder withIntermediateDirectories:NO attributes:_openPermissions() error:NULL]) {
		return nil;
	}
	_sRoutesSupportFolder = [folder retain];
	return _sRoutesSupportFolder;
}

- (double)lastUpdateTimeForFile:(id)aFile
{
	if (![self fileExistsAtPath:aFile]) {
		return 0.0;
	}
	return [[[self attributesOfItemAtPath:[aFile stringByResolvingSymlinksInPath] error:NULL] fileModificationDate]
	           timeIntervalSinceReferenceDate];
}

- (id)filePathForExpiredReport:(NSInteger)aReport entryID:(id)aID
{
	return [[self rootFolderForReport:aReport]
	           stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_expired.plist", aID]];
}

- (id)filePathForReport:(NSInteger)aReport entryID:(id)aID
{
	return [[self rootFolderForReport:aReport] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", aID]];
}

- (id)rootFolderForReport:(NSInteger)aReport
{
	return [self _folderWithName:[NSString stringWithFormat:@"%d", (int)aReport] inFolder:[self reportsDownloadFolder]];
}

- (id)reportsDownloadFolder
{
	return [self _folderWithName:_pathComponent(kReportsFolder) inFolder:[self atlasSharedFolder]];
}

- (id)updatesDownloadFolder
{
	return [self _folderWithName:_pathComponent(kUpdatesFolder) inFolder:[self atlasSharedFolder]];
}

- (id)cloudsDownloadFolder
{
	return [self _folderWithName:_pathComponent(kCloudsFolder) inFolder:[self atlasSharedFolder]];
}

- (id)sortedEntriesCachePath
{
	return [[self atlasSharedFolder] stringByAppendingPathComponent:kSortedEntriesCacheFile];
}

- (id)entriesCachePath
{
	return [[self atlasSharedFolder] stringByAppendingPathComponent:kEntriesCacheFile];
}

// The atlas folder in Application Support, created world-writable. When it
// can't be created or written, the user may repair it with administrator
// rights (mkdir and chmod 777) or quit.
- (id)atlasSharedFolder
{
	NSString *support = [self _appSupportFolder];
	NSString *folder = [support stringByAppendingPathComponent:_pathComponent(kAtlasAppSuppFolder)];
	if (![self fileExistsAtPath:folder]) {
		if ([self isWritableFileAtPath:support]) {
			if (![self createDirectoryAtPath:folder withIntermediateDirectories:NO attributes:_openPermissions() error:NULL]) {
				return nil;
			}
		} else {
			NSInteger answer = NSRunAlertPanel(_localized(@"BadAppSuppPermissionsTitle"), @"%@", _localized(@"RepairButt"),
			                                   _localized(@"QuitButt"), nil, _localized(@"BadAppSuppPermissionsBody"));
			NSArray *chmod = [NSArray arrayWithObjects:@"/bin/chmod", @"777", folder, nil];
			NSArray *mkdir = [NSArray arrayWithObjects:@"/bin/mkdir", folder, nil];
			if (answer != NSAlertDefaultReturn || ![self _runAuthorizedTasks:[NSArray arrayWithObjects:mkdir, chmod, nil]]) {
				[NSApp terminate:nil];
				return nil;
			}
		}
	}
	if ([self isWritableFileAtPath:folder] && [self isReadableFileAtPath:folder]) {
		return folder;
	}
	if ([self setAttributes:_openPermissions() ofItemAtPath:folder error:NULL]) {
		return folder;
	}
	NSInteger answer = NSRunAlertPanel(_localized(@"BadAtlasSuppPermissionsTitle"), @"%@", _localized(@"RepairButt"),
	                                   _localized(@"QuitButt"), nil, _localized(@"BadAtlasSuppPermissionsBody"));
	if (answer == NSAlertDefaultReturn) {
		NSArray *chmod = [NSArray arrayWithObjects:@"/bin/chmod", @"777", folder, nil];
		if ([self _runAuthorizedTasks:[NSArray arrayWithObjects:chmod, nil]]) {
			return folder;
		}
	}
	[NSApp terminate:nil];
	return nil;
}

// The original used the local domain's Application Support (shared by all
// users), which current systems only let administrators write; this uses
// the user's own instead.
- (id)_appSupportFolder
{
	if (_sAppSupportFolder == nil || ![self fileExistsAtPath:_sAppSupportFolder]) {
		[_sAppSupportFolder release];
		_sAppSupportFolder = nil;
		NSString *support = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
		if (support == nil) {
			return nil;
		}
		[self createDirectoryAtPath:support withIntermediateDirectories:YES attributes:nil error:NULL];
		_sAppSupportFolder = [[NSString stringWithString:support] retain];
	}
	for (;;) {
		if ([self isReadableFileAtPath:_sAppSupportFolder]) {
			return _sAppSupportFolder;
		}
		NSInteger answer = NSRunAlertPanel(_localized(@"BadAppSuppReadPermissionsTitle"), @"%@", _localized(@"RetryButt"),
		                                   _localized(@"QuitButt"), nil, _localized(@"BadAppSuppReadPermissionsBody"));
		if (answer == 0) {
			break;
		}
	}
	[NSApp terminate:nil];
	return nil;
}

- (id)_folderWithName:(id)aName inFolder:(id)aFolder
{
	NSString *folder = [aFolder stringByAppendingPathComponent:aName];
	if (![self fileExistsAtPath:folder] &&
	    ![self createDirectoryAtPath:folder withIntermediateDirectories:NO attributes:_openPermissions() error:NULL]) {
		return nil;
	}
	return folder;
}

// Runs each task (an array of the tool's path and up to 98 arguments) as
// root, after asking for an administrator's password.
- (BOOL)_runAuthorizedTasks:(id)aTasks
{
	AuthorizationRef authorization = NULL;
	if (AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorization) != errAuthorizationSuccess) {
		return NO;
	}
	AuthorizationItem right = { "system.privilege.admin", 0, NULL, 0 };
	AuthorizationRights rights = { 1, &right };
	AuthorizationFlags flags = kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
	if (AuthorizationCopyRights(authorization, &rights, NULL, flags, NULL) != errAuthorizationSuccess) {
		return NO;
	}
	int count = (int)[aTasks count];
	for (int i = 0; i < count; i++) {
		NSArray *task = [aTasks objectAtIndex:i];
		NSString *tool = [task objectAtIndex:0];
		int argumentCount = (int)[task count];
		if (argumentCount > 99) {
			[[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self
			    file:@"/Users/3dwgbuilder/Projects/3DWGBuildFolder/WBAll/WBAtlas/Sources/Extensions/FileManager.m"
			    lineNumber:51 description:@"Unsupported arguments count."];
		}
		char *arguments[100];
		int j;
		for (j = 1; j < argumentCount; j++) {
			arguments[j] = (char *)[[task objectAtIndex:j] fileSystemRepresentation];
		}
		arguments[j] = NULL;
		OSStatus (*execute)(AuthorizationRef, const char *, AuthorizationFlags, char *const *, FILE **) =
		    (OSStatus (*)(AuthorizationRef, const char *, AuthorizationFlags, char *const *, FILE **))
		        dlsym(RTLD_DEFAULT, "AuthorizationExecuteWithPrivileges");
		if (execute == NULL || execute(authorization, [tool fileSystemRepresentation], kAuthorizationFlagDefaults, arguments + 1, NULL) != 0) {
			return NO;
		}
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceReferenceDate:[NSDate timeIntervalSinceReferenceDate] + 0.4]];
	}
	return YES;
}

@end

#import "YAConnection.h"

static void _ReadStreamClientCallBack(CFReadStreamRef aStream, CFStreamEventType aEvent, void *aInfo)
{
    [(YAConnection *)aInfo handleNetworkEvent:aEvent];
}

@implementation YAConnection

- (void)handleNetworkEvent:(NSInteger)aEvent
{
    [_timeoutTimer invalidate];
    _timeoutTimer = nil;
    switch (aEvent) {
    case kCFStreamEventOpenCompleted:
        [self _handleStreamOpenCompleted];
        break;
    case kCFStreamEventHasBytesAvailable:
        [self _handleBytesAvailable];
        break;
    case kCFStreamEventErrorOccurred:
        [self _handleStreamError];
        break;
    case kCFStreamEventEndEncountered:
        [self _handleStreamComplete];
        break;
    }
}

- (void)_streamTimeout:(id)aTimeout
{
    _timeoutTimer = nil;
    [self _handleStreamError];
}

- (void)_handleStreamOpenCompleted
{
    _timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:90.0 target:self selector:@selector(_streamTimeout:) userInfo:nil repeats:NO];
}

- (void)_handleStreamComplete
{
    CFHTTPMessageRef response = (CFHTTPMessageRef)CFReadStreamCopyProperty(_stream, kCFStreamPropertyHTTPResponseHeader);
    CFIndex status = response != NULL ? CFHTTPMessageGetResponseStatusCode(response) : 0;
    BOOL retry = NO;
    if (status == 407 && !_proxyAuthFromKeyChainDone)
        retry = [self _setProxyUserNameAndPasswdFromKeyChain];
    if (response != NULL)
        CFRelease(response);
    [self _closeStream];
    if (retry) {
        [_responce release];
        _responce = nil;
        _fetchIsActive = NO;
        [self fetch];
    } else {
        NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:(unsigned int)status], kConnectionLastErrorKey, _responce, kConnectionDataKey, nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:kConnectionClosedNotification object:self userInfo:info];
    }
    [self release];
}

- (BOOL)_setProxyUserNameAndPasswdFromKeyChain
{
    SCDynamicStoreRef store = SCDynamicStoreCreate(NULL, CFSTR("SIMPLE_GET_"), NULL, NULL);
    CFDictionaryRef proxies = SCDynamicStoreCopyProxies(store);
    if (store != NULL)
        CFRelease(store);
    if (proxies == NULL)
        return NO;
    NSString *host = (NSString *)CFDictionaryGetValue(proxies, kSCPropNetProxiesHTTPProxy);
    NSNumber *port = (NSNumber *)CFDictionaryGetValue(proxies, kSCPropNetProxiesHTTPPort);
    if (host == nil || port == nil) {
        CFRelease(proxies);
        return NO;
    }
    // the proxy password lives in an internet password item for the proxy host
    NSMutableDictionary *query = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                  (id)kSecClassInternetPassword, (id)kSecClass,
                                  host, (id)kSecAttrServer,
                                  (id)kCFBooleanTrue, (id)kSecReturnData,
                                  (id)kCFBooleanTrue, (id)kSecReturnAttributes,
                                  (id)kSecMatchLimitOne, (id)kSecMatchLimit,
                                  nil];
    if ([port isKindOfClass:[NSNumber class]] && [port intValue] != 0)
        [query setObject:[NSNumber numberWithUnsignedShort:(unsigned short)[port intValue]] forKey:(id)kSecAttrPort];
    CFRelease(proxies);
    CFTypeRef result = NULL;
    if (SecItemCopyMatching((CFDictionaryRef)query, &result) != errSecSuccess || result == NULL)
        return NO;
    NSDictionary *item = [(id)result autorelease];
    NSString *account = [item objectForKey:(id)kSecAttrAccount];
    NSData *passwordData = [item objectForKey:(id)kSecValueData];
    NSString *password = nil;
    if (passwordData != nil) {
        password = [[[NSString alloc] initWithData:passwordData encoding:NSUTF8StringEncoding] autorelease];
        if (password == nil)
            password = [[[NSString alloc] initWithData:passwordData encoding:NSMacOSRomanStringEncoding] autorelease];
    }
    if (account == nil || password == nil)
        return NO;
    BOOL added = CFHTTPMessageAddAuthentication(_request, NULL, (CFStringRef)account, (CFStringRef)password, kCFHTTPAuthenticationSchemeBasic, TRUE);
    _proxyAuthFromKeyChainDone = YES;
    return added;
}

- (void)_handleBytesAvailable
{
    UInt8 buffer[2048];
    CFIndex length = CFReadStreamRead(_stream, buffer, sizeof(buffer));
    if (length < 0) {
        [self _handleStreamError];
        return;
    }
    if (length == 0)
        return;
    if (_responce == nil)
        _responce = [[NSMutableData alloc] initWithBytes:buffer length:length];
    else
        [_responce appendBytes:buffer length:length];
}

- (void)_handleStreamError
{
    [self _closeStream];
    NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:-50], kConnectionLastErrorKey, nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kConnectionClosedNotification object:self userInfo:info];
    [self release];
}

- (void)terminate
{
    [_timeoutTimer invalidate];
    _timeoutTimer = nil;
    if (_fetchIsActive) {
        [self _closeStream];
        [self release];
        _fetchIsActive = NO;
    }
}

- (void)fetch
{
    if (_fetchIsActive)
        return;
    _stream = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, _request);
    NSAssert(_stream != NULL, @"Unable to create a stream for HTTP  request");
    SCDynamicStoreRef store = SCDynamicStoreCreate(NULL, CFSTR("SIMPLE_GET_"), NULL, NULL);
    NSDictionary *proxies = [(NSDictionary *)SCDynamicStoreCopyProxies(store) autorelease];
    if (store != NULL)
        CFRelease(store);
    CFReadStreamSetProperty(_stream, kCFStreamPropertyHTTPProxy, (CFDictionaryRef)proxies);
    CFStreamClientContext context = {0, self, NULL, NULL, NULL};
    CFOptionFlags events = kCFStreamEventOpenCompleted | kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered;
    if (!CFReadStreamSetClient(_stream, events, _ReadStreamClientCallBack, &context)) {
        CFRelease(_stream);
        _stream = NULL;
        NSAssert(NO, @"Unable to set stream client");
        return;
    }
    CFReadStreamScheduleWithRunLoop(_stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    if (CFReadStreamOpen(_stream)) {
        _fetchIsActive = YES;
        [self retain];
    } else {
        NSLog(@"Unable to open an HTTP stream");
        [self _closeStream];
    }
}

- (void)setUserName:(id)aName password:(id)aPassword
{
    CFHTTPMessageAddAuthentication(_request, NULL, (CFStringRef)aName, (CFStringRef)aPassword, kCFHTTPAuthenticationSchemeBasic, FALSE);
}

- (void)appendHeaderDict:(id)aDict
{
    NSArray *keys = [aDict allKeys];
    NSInteger count = [keys count];
    for (NSInteger i = 0; i < count; i++) {
        id key = [keys objectAtIndex:i];
        CFHTTPMessageSetHeaderFieldValue(_request, (CFStringRef)key, (CFStringRef)[aDict objectForKey:key]);
    }
}

- (void)setBody:(id)aBody
{
    CFHTTPMessageSetBody(_request, (CFDataRef)aBody);
}

- (void)setUserInfo:(id)aInfo
{
    [aInfo retain];
    [_userInfo release];
    _userInfo = aInfo;
}

- (id)userInfo
{
    return _userInfo;
}

- (void)dealloc
{
    [_timeoutTimer invalidate];
    [self _closeStream];
    [_responce release];
    [_userInfo release];
    if (_request != NULL)
        CFRelease(_request);
    [super dealloc];
}

- (void)_closeStream
{
    if (_stream == NULL)
        return;
    CFReadStreamSetClient(_stream, kCFStreamEventNone, NULL, NULL);
    CFReadStreamUnscheduleFromRunLoop(_stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    CFReadStreamClose(_stream);
    CFRelease(_stream);
    _stream = NULL;
}

- (id)initWithURLString:(id)aString method:(id)aMethod userInfo:(id)aInfo
{
    self = [super init];
    if (self != nil) {
        _userInfo = [aInfo retain];
        NSURL *url = [NSURL URLWithString:aString];
        _request = url != nil ? CFHTTPMessageCreateRequest(kCFAllocatorDefault, (CFStringRef)(aMethod != nil ? aMethod : @"GET"), (CFURLRef)url, kCFHTTPVersion1_1) : NULL;
        if (_request == NULL) {
            [self release];
            self = nil;
        }
    }
    return self;
}

@end

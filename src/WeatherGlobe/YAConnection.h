#import "WeatherGlobePrefix.h"


@interface YAConnection : NSObject
{
    id _userInfo;
    struct __CFHTTPMessage *_request;
    struct __CFReadStream *_stream;
    BOOL _fetchIsActive;
    BOOL _proxyAuthFromKeyChainDone;
    NSMutableData *_responce;
    NSTimer *_timeoutTimer;
}
- (void)handleNetworkEvent:(NSInteger)aEvent;
- (void)_streamTimeout:(id)aTimeout;
- (void)_handleStreamOpenCompleted;
- (void)_handleStreamComplete;
- (BOOL)_setProxyUserNameAndPasswdFromKeyChain;
- (void)_handleBytesAvailable;
- (void)_handleStreamError;
- (void)terminate;
- (void)fetch;
- (void)setUserName:(id)aName password:(id)aPassword;
- (void)appendHeaderDict:(id)aDict;
- (void)setBody:(id)aBody;
- (void)setUserInfo:(id)aInfo;
- (id)userInfo;
- (void)dealloc;
- (void)_closeStream;
- (id)initWithURLString:(id)aString method:(id)aMethod userInfo:(id)aInfo;
@end


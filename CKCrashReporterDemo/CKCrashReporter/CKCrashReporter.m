//
//  CKCrashReporter.m
//
///////////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2012 Giulio Petek
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
///////////////////////////////////////////////////////////////////////////////////

#import "CKCrashReporter.h"

#define kCrashReporterDidCatchExceptionNotification @"CKCrashReporterDidCatchExceptionNotification"
#define kExceptionUserInfoKey @"Exception"

NSString *const CKLowMemoryWarningReceivedExceptionName = @"CKLowMemoryWarningReceived";
NSString *const CKSignalReceivedExceptionName = @"CKSignalReceived";
NSString *const CKCrashInfoReasonKey = @"Reason";
NSString *const CKCrashInfoNameKey = @"Name";
NSString *const CKCrashInfoCallStackKey = @"CallStack";
NSString *const CKCrashReporterErrorDomain = @"de.Giulio_Petek.CKCrashReporter";

static void _exceptionCought(NSException *exception);
static int _CSignalFromCKSignal[] = {
    [CKCrashReporterSIGSEGVSignal] = SIGSEGV,
    [CKCrashReporterSIGPIPESignal] = SIGPIPE,
    [CKCrashReporterSIGILLSignal] = SIGILL,
    [CKCrashReporterSIGFPESignal] = SIGFPE,
    [CKCrashReporterSIGBUSSignal] = SIGBUS,
    [CKCrashReporterSIGABRTSignal] = SIGABRT
};

///////////////////////////////////////////////////////////////////////////////////
/// CKCrashReporter ()
///////////////////////////////////////////////////////////////////////////////////

@interface CKCrashReporter () {
    struct _CKCrashReporter_flags_t {
        unsigned int catching:1;
        unsigned int catchingLowMemoryWarnings:1;
        unsigned int catchingSignals:1;
        unsigned int catchingUncaughtExceptions:1;
        unsigned int registeredObserverForSignalsAndUncaughtExcceptions:1;
    } _flags;
    
    dispatch_source_t _SIGSEGVSource;
    dispatch_source_t _SIGABRTSource;
    dispatch_source_t _SIGBUSSource;
    dispatch_source_t _SIGFPESource;
    dispatch_source_t _SIGILLSource;
    dispatch_source_t _SIGPIPESource;
}

- (NSArray *)_callStackForException:(NSException *)exception;
- (NSString *)_crashFilePath;
- (void)_persistCrash:(NSDictionary *)crash;
- (void)_handleException:(NSException *)exception;
- (void)_didCatchLowMemoryWarning:(NSNotification *)notification;
- (void)_didCatchUncaughtException:(NSNotification *)notification;
- (void)_updateCatching;
- (void)_updateSignals;
- (void)_updateLowMemoryCatching;
- (void)_updateUncaughtExceptionsCatching;

@end

///////////////////////////////////////////////////////////////////////////////////
/// CKCrashReporter
///////////////////////////////////////////////////////////////////////////////////

@implementation CKCrashReporter
@synthesize catchOptions = _catchOptions;
@synthesize catchedSignals = _catchedSignals;
@synthesize onSaveCrash = _onSaveCrash;

#pragma mark Init

static BOOL _initializedSharedReporter;
static BOOL _passInit;

+ (CKCrashReporter *)sharedReporter {
    static dispatch_once_t __sharedToken = 0;
    static CKCrashReporter * __sharedInstance = nil;
    dispatch_once(&__sharedToken, ^{
        _passInit = YES; 
        __sharedInstance = [[self alloc] init];
    });
    return __sharedInstance;
}

- (id)init {
    if (!_passInit) {
        NSLog(@"Do not initialize an own CKCrashReporter. Use the singleton instead.");
        return nil;
    }
    
    if (_initializedSharedReporter) {
        NSLog(@"Only one CKCrashReporter can exist throughout this application.");
        return nil;
    } else 
        _initializedSharedReporter = YES;

    
    if ((self = [super init])) {       
        _flags.catching = NO;
        _flags.catchingLowMemoryWarnings = NO;
        _flags.catchingSignals = NO;
        _flags.catchingUncaughtExceptions = NO;
        _flags.registeredObserverForSignalsAndUncaughtExcceptions = NO;
        
        self.catchOptions = CKCrashReporterCatchOptionAll;
        self.catchedSignals = CKCrashReporterAllSignals;
    }
    
    return self;
}

#pragma mark Subclass

- (void)saveCrash:(NSMutableDictionary *)crash {
    if (self.onSaveCrash)
        self.onSaveCrash(crash);
    
    [self _persistCrash:crash];
}

#pragma mark Catch

- (NSString *)_crashFilePath {
    NSString *caches_dir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    return [caches_dir stringByAppendingFormat:@"%@_crash.plist", NSStringFromClass([self class])];
}

#pragma mark Helper

- (NSArray *)_callStackForException:(NSException *)exception {
    NSArray *callStack = exception.callStackSymbols;    
    if (!callStack || [callStack count] <= 0)
        callStack = [NSThread callStackSymbols];
    
    if (!callStack || [callStack count] <= 0)
        return [NSArray array];
    
    NSMutableArray *callStackMutableCopy = [callStack mutableCopy];
    while ([callStackMutableCopy count] > 20)
        [callStackMutableCopy removeObjectAtIndex:0];
    return [callStackMutableCopy copy];
}

#pragma mark Manage catching

- (void)beginCatching {
    if (_flags.catching)
        return;
    
    _flags.catching = YES;
    [self _updateCatching];
}

- (void)endCatching {
    if (!_flags.catching)
        return;

    _flags.catching = NO;
    [self _updateCatching];
}

- (BOOL)isCatching {
    return _flags.catching;
}

#pragma mark Private - Handle catches

- (void)_didCatchLowMemoryWarning:(NSNotification *)notification {
    NSException *exception = [NSException exceptionWithName:CKLowMemoryWarningReceivedExceptionName 
                                                     reason:@"Received low memory warning." 
                                                   userInfo:nil];
    [self _handleException:exception];
}

- (void)_didCatchUncaughtException:(NSNotification *)notification {
    NSException *exception = [[notification userInfo] objectForKey:kExceptionUserInfoKey];
    [self _handleException:exception];
}

- (void)_handleException:(NSException *)exception {   
    NSMutableDictionary *crash = [[NSMutableDictionary alloc] initWithCapacity:3];
    [crash setObject:exception.reason ? exception.reason : @"Unknown reason"
              forKey:CKCrashInfoReasonKey];
    [crash setObject:exception.name ? exception.name : @"Unknown name"
              forKey:CKCrashInfoNameKey];
    NSArray *callstack = [self _callStackForException:exception];
    [crash setObject:callstack ? callstack : @"Unknown callstack" 
              forKey:CKCrashInfoCallStackKey];
    [self saveCrash:crash];
    
    if (![exception.name isEqualToString:CKLowMemoryWarningReceivedExceptionName])
        [exception raise];
}

#pragma mark Private - Update catching 

- (void)_updateCatching {
    [self _updateSignals];
    [self _updateLowMemoryCatching];
    [self _updateUncaughtExceptionsCatching];
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    if (_flags.catching && (_flags.catchingSignals || _flags.catchingUncaughtExceptions)) {
        [center addObserver:self
                   selector:@selector(_didCatchUncaughtException:)
                       name:kCrashReporterDidCatchExceptionNotification
                     object:nil];
        _flags.registeredObserverForSignalsAndUncaughtExcceptions = YES;
    } else {
        [center removeObserver:self 
                          name:kCrashReporterDidCatchExceptionNotification 
                        object:nil];
        _flags.registeredObserverForSignalsAndUncaughtExcceptions = NO;
    }
}

- (void)_updateSignal:(CKCrashReporterSignal)_CKSignal {
    dispatch_source_t signalSource = nil;
    NSString *reason = nil;
    int _CSignal = _CSignalFromCKSignal[_CKSignal];
    
    switch (_CKSignal) {
        case CKCrashReporterSIGSEGVSignal: {
            signalSource = _SIGSEGVSource; 
            reason = @"Received a SIGSEGV signal. See here http://en.wikipedia.org/wiki/SIGSEGV for more information.";
        } break;
        case CKCrashReporterSIGBUSSignal: {
            signalSource = _SIGBUSSource;
            reason = @"Received a SIGBUS signal. See here http://en.wikipedia.org/wiki/SIGBUS for more information.";
        } break;
        case CKCrashReporterSIGFPESignal: {
            signalSource = _SIGFPESource;
            reason = @"Received a SIGFPE signal. See here http://en.wikipedia.org/wiki/SIGFPE for more information.";
        } break;
        case CKCrashReporterSIGABRTSignal: {
            signalSource = _SIGABRTSource;
            reason = @"Received a SIGABRT signal. See here http://en.wikipedia.org/wiki/SIGABRT for more information.";
        } break;
        case CKCrashReporterSIGILLSignal: {
            signalSource = _SIGILLSource;
            reason = @"Received a SIGILL signal. See here http://en.wikipedia.org/wiki/SIGILL for more information.";
        } break;
        case CKCrashReporterSIGPIPESignal: {
            signalSource = _SIGPIPESource;
            reason = @"Received a SIGPIPE signal. See here http://en.wikipedia.org/wiki/SIGPIPE for more information.";
        } break;
        default:break;
    }
    
    if (_flags.catching && _flags.catchingSignals && (self.catchedSignals & _CKSignal)) {
        signal(_CSignal, SIG_IGN);

        if (!signalSource)
            signalSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, _CSignal, 0, dispatch_get_main_queue());
        
        __weak CKCrashReporter *weak = self;
        dispatch_source_set_event_handler(signalSource, ^{
            NSException *exception = [NSException exceptionWithName:CKSignalReceivedExceptionName 
                                                             reason:reason
                                                           userInfo:nil];
            [weak _handleException:exception];
        });
        dispatch_resume(signalSource);
    } else {
        if (signalSource) {
            signal(_CSignal, SIG_DFL);
            
            dispatch_release(signalSource);
            signalSource = nil;
        }
    }
}

- (void)_updateSignals {
    [self _updateSignal:CKCrashReporterSIGSEGVSignal];
    [self _updateSignal:CKCrashReporterSIGABRTSignal];
    [self _updateSignal:CKCrashReporterSIGILLSignal];
    [self _updateSignal:CKCrashReporterSIGFPESignal];
    [self _updateSignal:CKCrashReporterSIGBUSSignal];
    [self _updateSignal:CKCrashReporterSIGPIPESignal];
}

- (void)_updateLowMemoryCatching {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    if (_flags.catchingLowMemoryWarnings && _flags.catching) 
        [center addObserver:self 
                   selector:@selector(_didCatchLowMemoryWarning:)
                       name:UIApplicationDidReceiveMemoryWarningNotification 
                     object:[UIApplication sharedApplication]]; 
    else
        [center removeObserver:self
                          name:UIApplicationDidReceiveMemoryWarningNotification 
                        object:[UIApplication sharedApplication]];
}

- (void)_updateUncaughtExceptionsCatching {
    if (_flags.catchingUncaughtExceptions && _flags.catching)
        NSSetUncaughtExceptionHandler(&_exceptionCought);
    else
        NSSetUncaughtExceptionHandler(nil);
}

#pragma mark UncaughtExceptionsHandler

static void _exceptionCought(NSException *exception) {
    [[NSNotificationCenter defaultCenter] postNotificationName:kCrashReporterDidCatchExceptionNotification 
                                                        object:nil
                                                      userInfo:[NSDictionary dictionaryWithObject:exception forKey:kExceptionUserInfoKey]];
}

#pragma mark Setter

- (void)setCatchOptions:(CKCrashReporterCatchOption)catchOptions {
    _catchOptions = catchOptions;
    
    _flags.catchingLowMemoryWarnings = (_catchOptions & CKCrashReporterCatchOptionLowMemoryWarnings) ? YES : NO;
    _flags.catchingUncaughtExceptions = (_catchOptions & CKCrashReporterCatchOptionUncaughtException) ? YES : NO;
    _flags.catchingSignals = (_catchOptions & CKCrashReporterCatchOptionSignals) ? YES : NO;
        
    if (_flags.catching) 
        [self _updateCatching];
}

- (void)setCatchedSignals:(CKCrashReporterSignal)catchedSignals {
    _catchedSignals = catchedSignals;
    [self _updateSignals];
}

#pragma mark Manage crash

- (BOOL)hasCrashAvailable {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self _crashFilePath]];
}

- (void)_persistCrash:(NSDictionary *)crash {
    [crash writeToFile:[self _crashFilePath] atomically:YES];
}

- (NSDictionary *)latestCrash {
    if (![self hasCrashAvailable])
        return nil;
    return [NSDictionary dictionaryWithContentsOfFile:[self _crashFilePath]];
}

- (void)removeLatestCrash {
    [[NSFileManager defaultManager] removeItemAtPath:[self _crashFilePath] error:nil];
}

#pragma mark Mailing

- (MFMailComposeViewController *)mailComposeViewControllerWithLatestCrashAsAttachmentAndError:(NSError *__autoreleasing *)error {
    if (![self hasCrashAvailable])
        *error = [NSError errorWithDomain:CKCrashReporterErrorDomain code:001 userInfo:[NSDictionary dictionaryWithObject:@"No crash available." forKey:NSLocalizedDescriptionKey]];
    
    if (![MFMailComposeViewController canSendMail])
        *error = [NSError errorWithDomain:CKCrashReporterErrorDomain code:002 userInfo:[NSDictionary dictionaryWithObject:@"No eMail account available." forKey:NSLocalizedDescriptionKey]];
    
    if (*error)
        return nil;
    
    NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:[self latestCrash]
                                                                 format:NSPropertyListXMLFormat_v1_0
                                                                options:0
                                                                  error:&*error];
    if (*error)
        return nil;
    
    MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
    [mailViewController addAttachmentData:xmlData
                                 mimeType:@"plist"
                                 fileName:[NSString stringWithFormat:@"%@_crash.plist", NSStringFromClass([self class])]];
    
    if (mailViewController)
        return mailViewController;
    
    *error = [NSError errorWithDomain:CKCrashReporterErrorDomain code:003 userInfo:[NSDictionary dictionaryWithObject:@"Not able to create MFMailComposeViewController." forKey:NSLocalizedDescriptionKey]];
    
    return nil;
}

#pragma mark Memory

- (void)dealloc {
    [self endCatching];
}

@end

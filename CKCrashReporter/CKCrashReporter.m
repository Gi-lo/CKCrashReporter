/* ----------------------------------------------------------------------
 CKCrashReporter.m
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 ---------------------------------------------------------------------- */

#import "CKCrashReporter.h"

/* ----------------------------------------------------------------------
 @defines CKCrashReporter
 ---------------------------------------------------------------------- */

#define kCrashReporterDidCatchExceptionNotification @"CKCrashReporterDidCatchExceptionNotification"
#define kExceptionUserInfoKey @"NSException"

/* ----------------------------------------------------------------------
 @constants CKCrashReporter
 ---------------------------------------------------------------------- */

NSString *const CKSignalReceivedExceptionName = @"CKSignalReceived";
NSString *const CKCrashInfoReasonKey = @"Reason";
NSString *const CKCrashInfoNameKey = @"Name";
NSString *const CKCrashInfoExceptionBacktraceKey = @"Exception backtrace";
NSString *const CKCrashInfoMainThreadBacktraceKey = @"Main thread backtrace";

/* ----------------------------------------------------------------------
 @c-methods CKCrashReporter
 ---------------------------------------------------------------------- */

static void _exceptionCaught(NSException *exception);

/* ----------------------------------------------------------------------
 @interface CKCrashReporter ()
 ---------------------------------------------------------------------- */

@interface CKCrashReporter ()

- (void)_didCatchUncaughtException:(NSNotification *)notification;
- (void)_handleException:(NSException *)exception;

- (NSString *)_reasonOfException:(NSException *)exception;
- (NSString *)_nameOfException:(NSException *)exception;

- (NSArray *)_backtraceOfException:(NSException *)exception;
- (NSArray *)_mainThreadBacktrace;

@end

/* ----------------------------------------------------------------------
 @implementation CKCrashReporter
 ---------------------------------------------------------------------- */

@implementation CKCrashReporter
@synthesize catchExceptions = _catchExceptions;

#pragma mark Subclassing

- (id)initSharedReporter {
    if ((self = [super init]))
        _catchExceptions = NO;
    
    return self;
}

- (NSString *)crashPath {
    NSString *caches_dir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    return [caches_dir stringByAppendingFormat:@"%@_crash.plist", NSStringFromClass([self class])];
}

- (void)saveCrash:(NSMutableDictionary *)crash {
    [crash writeToFile:[self crashPath] atomically:YES];
}

#pragma mark Init

+ (CKCrashReporter *)sharedReporter {
    static dispatch_once_t __sharedToken = 0;
    static CKCrashReporter * __sharedReporter = nil;
    dispatch_once(&__sharedToken, ^{
        __sharedReporter = [[self alloc] initSharedReporter];
    });
    return __sharedReporter;
}

- (id)init {
    NSAssert(0, @"Do not initialize your own CKCrashReporter. Use the singleton instead.");
    return nil;
}

#pragma mark Helper

- (NSArray *)_mainThreadBacktrace {
    if (![NSThread isMainThread])
        return [self performSelector:@selector(_mainThreadBacktrace)];
        
    return [[NSThread callStackSymbols] count] ? [NSThread callStackSymbols] : [NSArray array];
}

#pragma mark NSExceptionHelper

- (NSString *)_reasonOfException:(NSException *)exception {
    return exception.reason ? exception.reason : @"Unknown";
}

- (NSArray *)_backtraceOfException:(NSException *)exception {
    return exception.callStackSymbols.count ? exception.callStackSymbols : [NSArray array];
}

- (NSString *)_nameOfException:(NSException *)exception {
    return exception.name ? exception.name : @"Unknown";
}

#pragma mark Manage catching

- (void)setCatchExceptions:(BOOL)catchExceptions {
    if (catchExceptions == _catchExceptions)
        return;
    
    _catchExceptions = catchExceptions;
    
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    if (_catchExceptions) {
        NSSetUncaughtExceptionHandler(&_exceptionCaught);
        
        [defaultCenter addObserver:self
                          selector:@selector(_didCatchUncaughtException:)
                              name:kCrashReporterDidCatchExceptionNotification
                            object:nil];
    } else {
        NSSetUncaughtExceptionHandler(nil);
        
        [defaultCenter removeObserver:self
                                 name:kCrashReporterDidCatchExceptionNotification
                               object:nil];
    }
}

#pragma mark Private - Handle catches

- (void)_didCatchUncaughtException:(NSNotification *)notification {
    [self _handleException:[[notification userInfo] objectForKey:kExceptionUserInfoKey]];
}

- (void)_handleException:(NSException *)exception {   
    NSMutableDictionary *crash = [[NSMutableDictionary alloc] initWithCapacity:3];
    [crash setObject:[self _reasonOfException:exception] forKey:CKCrashInfoReasonKey];
    [crash setObject:[self _nameOfException:exception] forKey:CKCrashInfoNameKey];
    [crash setObject:[self _backtraceOfException:exception] forKey:CKCrashInfoExceptionBacktraceKey];
    [crash setObject:[self _mainThreadBacktrace] forKey:CKCrashInfoMainThreadBacktraceKey];

    [self saveCrash:crash];
    
    [exception raise];
}

#pragma mark UncaughtExceptionsHandler

static void _exceptionCaught(NSException *exception) {
    [[NSNotificationCenter defaultCenter] postNotificationName:kCrashReporterDidCatchExceptionNotification 
                                                        object:nil
                                                      userInfo:[NSDictionary dictionaryWithObject:exception forKey:kExceptionUserInfoKey]];
}

#pragma mark Manage crash

- (BOOL)hasCrashAvailable {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self crashPath]];
}

- (NSDictionary *)savedCrash {
    if (![self hasCrashAvailable])
        return nil;
    return [NSDictionary dictionaryWithContentsOfFile:[self crashPath]];
}

- (void)removeSavedCrash {
    [[NSFileManager defaultManager] removeItemAtPath:[self crashPath] error:nil];
}

#pragma mark Memory

- (void)dealloc {
    self.catchExceptions = NO;
}

@end
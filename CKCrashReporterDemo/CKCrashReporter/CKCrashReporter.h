//
//  CKCrashReporter.h
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

#import <MessageUI/MFMailComposeViewController.h>

extern NSString *const CKLowMemoryWarningReceivedExceptionName;
extern NSString *const CKSignalReceivedExceptionName;

extern NSString *const CKCrashInfoNameKey;
extern NSString *const CKCrashInfoExceptionReasonKey;
extern NSString *const CKCrashInfoCallStackKey;

extern NSString *const CKCrashReporterErrorDomain;

typedef void (^CKMutableDictionaryBlock)(NSMutableDictionary *dictionary);

enum {
    CKCrashReporterSIGSEGVSignal = 1 << 0,
    CKCrashReporterSIGFPESignal = 1 << 1,
    CKCrashReporterSIGABRTSignal = 1 << 2,
    CKCrashReporterSIGILLSignal = 1 << 3,
    CKCrashReporterSIGBUSSignal = 1 << 4,
    CKCrashReporterSIGPIPESignal = 1 << 5,
    CKCrashReporterAllSignals = 63,
};
typedef NSUInteger CKCrashReporterSignal;

enum {
    CKCrashReporterCatchOptionLowMemoryWarnings = 1 << 0,
    CKCrashReporterCatchOptionSignals = 1 << 1,
    CKCrashReporterCatchOptionUncaughtException = 1 << 2,
    CKCrashReporterCatchOptionAll = 7,
};
typedef NSUInteger CKCrashReporterCatchOption;

@interface CKCrashReporter : NSObject

@property (nonatomic, unsafe_unretained, readonly, getter = hasCrashAvailable) BOOL crashAvailable;
@property (nonatomic, unsafe_unretained, readonly) BOOL isCatching;

@property (nonatomic, unsafe_unretained, readwrite) CKCrashReporterCatchOption catchOptions;
@property (nonatomic, unsafe_unretained, readwrite) CKCrashReporterSignal catchedSignals;

@property (nonatomic, copy, readwrite) CKMutableDictionaryBlock onSaveCrash;

+ (CKCrashReporter *)sharedReporter;

- (void)beginCatching;
- (void)endCatching;

- (void)removeLatestCrash;
- (NSDictionary *)latestCrash;

- (MFMailComposeViewController *)mailComposeViewControllerWithLatestCrashAsAttachmentAndError:(NSError *__autoreleasing *)error;

@end
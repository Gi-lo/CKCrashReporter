/* ----------------------------------------------------------------------
 CKCrashReporter+Mailing.m
 Copyright 2012 Giulio Petek. All rights reserved.

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

#import "CKCrashReporter+Mailing.h"

/* ----------------------------------------------------------------------
 @constants CKCrashReporter (Mailing)
 ---------------------------------------------------------------------- */

NSString *const CKCrashReporterErrorDomain = @"de.Giulio_Petek.CKCrashReporter";

/* ----------------------------------------------------------------------
 @implementation CKCrashReporter (Mailing)
 ---------------------------------------------------------------------- */

@implementation CKCrashReporter (Mailing)

#pragma mark Mailing

- (MFMailComposeViewController *)mailComposeViewControllerWithLatestCrashAsAttachmentAndError:(NSError *__autoreleasing *)error {
    if (![self hasCrashAvailable])
        *error = [NSError errorWithDomain:CKCrashReporterErrorDomain code:001 userInfo:[NSDictionary dictionaryWithObject:@"No crash available." forKey:NSLocalizedDescriptionKey]];
    
    if (![MFMailComposeViewController canSendMail])
        *error = [NSError errorWithDomain:CKCrashReporterErrorDomain code:002 userInfo:[NSDictionary dictionaryWithObject:@"No eMail account available." forKey:NSLocalizedDescriptionKey]];
    
    if (*error)
        return nil;
    
    NSData *xmlData = [NSPropertyListSerialization dataWithPropertyList:[self savedCrash]
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

@end

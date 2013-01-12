/* ----------------------------------------------------------------------
 AppDelegate.m
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

#import "AppDelegate.h"

#import "CKCrashReporter+Mailing.h"
#import "CustomCrashReporter.h"

@implementation AppDelegate
@synthesize window = _window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    
    CustomCrashReporter *reporter = [CustomCrashReporter sharedReporter];
    reporter.catchExceptions = YES;

    if ([reporter hasCrashAvailable]) {
        NSLog(@"Crashreporter did found crash: %@", [reporter savedCrash]);
        
        NSError *error = nil;
        MFMailComposeViewController *mailComposer = [reporter mailComposeViewControllerWithLatestCrashAsAttachmentAndError:&error];
        if (error) {
            NSLog(@"Error creation mail composer: %@", error);
        }
        else {
            [self.window.rootViewController presentModalViewController:mailComposer animated:YES];
        }
        
        [reporter removeSavedCrash];
    }
    else {
        [self performSelector:@selector(fakeCrash)];
    }
    
    return YES;
}

@end

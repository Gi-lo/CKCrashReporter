//
//  AppDelegate.m
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

#import "AppDelegate.h"
#import "CKCrashReporter.h"

@implementation AppDelegate
@synthesize window = _window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    
    
    
    // Get the shared instance
    CKCrashReporter *reporter = [CKCrashReporter sharedReporter];
  
    // Modify the crash report for your own needs
    reporter.onSaveCrash  = ^(NSMutableDictionary *rawCrash) {
        [rawCrash setObject:[UIDevice currentDevice].model forKey:@"Model"];
    };
    
    // Specify the catch options
    reporter.catchOptions = CKCrashReporterCatchOptionAll;
    
    // Start catching
    [reporter beginCatching];
    
    // Check if there is a crash available
    if ([reporter hasCrashAvailable]) {
        
        // Create a mail composer based on the crash and show it if there was no error
        NSError *error = nil;
        MFMailComposeViewController *composer = [reporter mailComposeViewControllerWithLatestCrashAsAttachmentAndError:&error];
        if (error)
            NSLog(@"Could not create mail composer -> %@", error);
        else
            [self.window.rootViewController presentModalViewController:composer animated:YES];
       
        // Remove the crash file
        [reporter removeLatestCrash];
    }
    else
        
        // Fake crash for testing
        [self performSelector:@selector(notThere)];
    
    
    
    
    return YES;
}

@end

#CKCrashReporter

##1. What is it?
`CKCrashReporter` is a very easy to use crash reporter class for your `iOS` and `OSx` application. It was designed to be easily extendable. _(More information on this can be found under #3)_. `CKCrashReporter` will catch any uncaught `NSException` and save useful information about it on disk. The next time the user starts the application you can read out that information and e.g. send it via `MFMailComposeViewController`.

##2. How to use it?

###2.1 Basic implementation
It is very simple to adopt `CKCrashReporter` in your application.
**You have to add the `MessageUI.framework` to your target/project.**

```objective-c

 #import "CKCrashReporter

	// Get the shared instance
 	CustomCrashReporter *reporter = [CustomCrashReporter sharedReporter];  	
 	
 	// Begin catching NSExceptions
    reporter.catchExceptions = YES;
    
    // Check if there was a crash on previously app run
    if ([reporter hasCrashAvailable]) {
    	
    	// Crash available do something with it
    	NSDictionary *savedCrash = [reporter savedCrash];
    	
    	// Remove the saved crash as we already handled it
    	[reporter removeSavedCrash];
    }

```

You may want to do this in `- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions;`.

###2.1 Reading out crash information
If you want to access information of the crash you can simple use the predefined constants:

* CKCrashInfoNameKey: The `NSException`'s name.
* CKCrashInfoExceptionReasonKey: The `NSException`'s reason.
* CKCrashInfoNameKey: The `NSException`'s backtrace.
* CKCrashInfoNameKey: The main thread's backtrace when the exception was thrown.

##3. How to extend it?

There are 2 main reason you may consider extending `CKCrashReporter`.

**You always need to subclass `CKCrashReporter` if you wish to extend it.**
 
###3.1 Adding additional information to crashes
If you want to have additional information in your crashes like e.g. the device name or such, you need to override the method `- (void)saveCrash:(NSMutableDictionary *)crash;`. +
**Be sure to call `[super saveCrash:crash]` at the end. Else your crash may not be persisted.**

###3.2 Overriding the crash location
If you want a custom crash location you have to return it in `- (NSString *)crashPath;`.

##4. How does it work?
Basically `CKCrashReporter` takes advantage of `NSSetUncaughtExceptionHandler()`. This allows you to do additional stuff when an uncaught `NSException` is about to be thrown. To get a better understanding of why this works you need to know that the exception is not crashing your applicaion. Furthermore it starts a "kill chain" on `[NSException raise]` which then terminates your application. With `NSSetUncaughtExceptionHandler()` we can avoid that "kill chain" and perform our code instead. When we are done with our additional code we still call `[NSException raise]` as the application state may be corrupted.

##5. License
CKCrashReporter is available under the MIT license. See the LICENSE file for more info.
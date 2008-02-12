//
//  KTApplication.m
//  Marvel
//
//  Created by Terrence Talbot on 10/2/04.
//  Copyright 2004 Biophony, LLC. All rights reserved.
//

/*
PURPOSE OF THIS CLASS/CATEGORY:
	Override methods to clean up when we exit

TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	Subclass NSApplication

IMPLEMENTATION NOTES & CAUTIONS:
	x

TO DO:
	Catch exceptions and report them better

 */

#import "KTApplication.h"

#import "KT.h"
#import "KTAppDelegate.h"
#import "KTDocument.h"
#import "KTExceptionReporter.h"
#import "NSException+Karelia.h"
#import <ExceptionHandling/NSExceptionHandler.h>
#import "KTComponents.h"
#import "KTQuickStartController.h"
#import "Registration.h"

#if 0

// From Wolf ... http://rentzsch.com/cocoa/debuggingViaPosers

@interface NSNotificationCenter_DebuggingPoser : NSNotificationCenter {
	
}

@end

@interface NSNotificationCenter_DebuggingObserverRecord : NSObject {
    @public
    id          observer;
    SEL         selector;
    NSString    *notificationName;
    id          object;
}
@end
@implementation NSNotificationCenter_DebuggingObserverRecord
- (id)initWithObserver:(id)observer_ selector:(SEL)selector_ name:(NSString *)notificationName_ object:(id)object_ {
    self = [super init];
    if( self ) {
        observer = observer_; // Not retained.
        selector = selector_;
        notificationName = [notificationName_ retain];
        object = object_; // Not retained.
    }
    return self;
}
+ (id)observerRecordWithObserver:(id)observer_ selector:(SEL)selector_ name:(NSString *)notificationName_ object:(id)object_ {
    return [[[NSNotificationCenter_DebuggingObserverRecord alloc] initWithObserver:observer_
                                                                          selector:selector_
                                                                              name:notificationName_
                                                                            object:object_] autorelease];
}
- (void)dealloc {
    [notificationName release];
    [super dealloc];
}
@end

@interface NSNotificationCenter_DebuggingProxy : NSNotificationCenter {
    @public
    id  target;
}
@end
@implementation NSNotificationCenter_DebuggingProxy

static NSMutableArray* observers() {
    static NSMutableArray *observers = nil;
    if( !observers )
        observers = [[NSMutableArray alloc] init];
    return observers;
}

- (void)addObserver:(id)observer_ selector:(SEL)selector_ name:(NSString*)notificationName_ object:(id)object_ {
    NSParameterAssert( observer_ );
    NSParameterAssert( notificationName_ );
    
    [observers() addObject:[NSNotificationCenter_DebuggingObserverRecord observerRecordWithObserver:observer_
                                                                                           selector:selector_
                                                                                               name:notificationName_
                                                                                             object:object_]];
    [super addObserver:observer_ selector:selector_ name:notificationName_ object:object_];
}

- (void)removeObserver:(id)observer_ {
    NSParameterAssert( observer_ );
    
    unsigned recordIndex = [observers() count];
    while( recordIndex-- ) {
        NSNotificationCenter_DebuggingObserverRecord *record = [observers() objectAtIndex:recordIndex];
        if( record->observer == observer_ )
            [observers() removeObjectAtIndex:recordIndex];
    }
    
    [super removeObserver:observer_];
}

- (void)removeObserver:(id)observer_ name:(NSString*)notificationName_ object:(id)object_ {
 //   NSParameterAssert( observer_ );
    
    unsigned recordIndex = [observers() count];
    while( recordIndex-- ) {
        NSNotificationCenter_DebuggingObserverRecord *record = [observers() objectAtIndex:recordIndex];
        if( record->observer == observer_ ) {
            BOOL nameMatch = YES, objectMatch = YES;
            if( notificationName_ )
                nameMatch = [record->notificationName isEqualToString:notificationName_];
            if( object_ )
                objectMatch = record->object == object_;
            
            if( nameMatch && objectMatch )
                [observers() removeObjectAtIndex:recordIndex];
        }
    }
    
    [super removeObserver:observer_ name:notificationName_ object:object_];
}

- (void)postNotification:(NSNotification*)notification_ {
    unsigned recordIndex = 0, recordCount = [observers() count];
    for( ; recordIndex < recordCount; ++recordIndex ) {
        NSNotificationCenter_DebuggingObserverRecord *record = [observers() objectAtIndex:recordIndex];
        if( [record->notificationName isEqualToString:[notification_ name]] ) {
            BOOL objectMatch = YES;
            if( record->object )
                objectMatch = record->object == [notification_ object];
            if( objectMatch ) {
                NSLog( @"NOTIFICATION %@ to -[<%@ %p> %@]",
                       [notification_ name],
                       [record->observer className],
                       record->observer,
                       NSStringFromSelector(record->selector) );
            }
        }
    }
    
    [super postNotification:notification_];
}

- (void)postNotificationName:(NSString*)notificationName_ object:(id)object_ {
    unsigned recordIndex = 0, recordCount = [observers() count];
    for( ; recordIndex < recordCount; ++recordIndex ) {
        NSNotificationCenter_DebuggingObserverRecord *record = [observers() objectAtIndex:recordIndex];
        if( [record->notificationName isEqualToString:notificationName_] ) {
            BOOL objectMatch = YES;
            if( record->object )
                objectMatch = record->object == object_;
            if( objectMatch ) {
                NSLog( @"NOTIFICATION %@ to -[<%@ %p> %@]",
                       notificationName_,
                       [record->observer className],
                       record->observer,
                       NSStringFromSelector(record->selector) );
            }
        }
    }
    
    [super postNotificationName:notificationName_ object:object_];
}

- (void)postNotificationName:(NSString*)notificationName_ object:(id)object_ userInfo:(NSDictionary*)userInfo {
    unsigned recordIndex = 0, recordCount = [observers() count];
    for( ; recordIndex < recordCount; ++recordIndex ) {
        NSNotificationCenter_DebuggingObserverRecord *record = [observers() objectAtIndex:recordIndex];
        if( [record->notificationName isEqualToString:notificationName_] ) {
            BOOL objectMatch = YES;
            if( record->object )
                objectMatch = record->object == object_;
            if( objectMatch ) {
                NSLog( @"NOTIFICATION %@ to -[<%@ %p> %@]",
                       notificationName_,
                       [record->observer className],
                       record->observer,
                       NSStringFromSelector(record->selector) );
            }
        }
    }
	
    [super postNotificationName:notificationName_ object:object_ userInfo:userInfo];
}
@end

@implementation NSNotificationCenter_DebuggingPoser

+ (void)load {
    printf( "NSNotificationCenter_DebuggingPoser loaded\n" );
    [NSNotificationCenter_DebuggingPoser poseAsClass:[NSNotificationCenter class]];
}

+ (id)defaultCenter {
    static id defaultCenter = nil;
    if( !defaultCenter ) {
//#if 1
        defaultCenter = [[NSNotificationCenter_DebuggingProxy alloc] init];
//#else   
//        defaultCenter = [super defaultCenter];
//        NSNotificationCenter_DebuggingProxy *proxy = [[NSNotificationCenter_DebuggingProxy alloc] init];
//        proxy->target = defaultCenter;
//        defaultCenter = proxy;
//#endif
    }
    //NSLog( @"-[NSNotificationCenter_DebuggingPoser defaultCenter] => %@", defaultCenter );
    return defaultCenter;
}

#endif


#if 0

// COPY THIS TO OTHER METHODS TO WATCH THEIR RETAIN - RELEASE

- (id)retain
{
	NSLog(@"retain:%@", self);
	return [super retain];
}

- (oneway void)release
{
	NSLog(@"release:%@", self);
	[super release];
}

- (id)autorelease
{
	NSLog(@"autorelease:%@", self);
	return [super autorelease];
}

#endif


#if 0

#import </usr/include/objc/objc-class.h>
void MethodSwizzle(Class aClass, SEL orig_sel, SEL alt_sel)
{
    Method orig_method = nil, alt_method = nil;
	
    // First, look for the methods
    orig_method = class_getInstanceMethod(aClass, orig_sel);
    alt_method = class_getInstanceMethod(aClass, alt_sel);
	
    // If both are found, swizzle them
    if ((orig_method != nil) && (alt_method != nil))
	{
        char *temp1;
        IMP temp2;
		
        temp1 = orig_method->method_types;
        orig_method->method_types = alt_method->method_types;
        alt_method->method_types = temp1;
		
        temp2 = orig_method->method_imp;
        orig_method->method_imp = alt_method->method_imp;
        alt_method->method_imp = temp2;
	}
}

#endif


#if 0

@interface MyThread : NSThread

@end

@implementation MyThread


+ (void)detachNewThreadSelector:(SEL)selector
					   toTarget:(id)target
					 withObject:(id)argument;
{
	NSString *targetDesc = [NSString stringWithFormat:@"<%@ %p>", [target class], target];
	NSString *argDesc = [NSString stringWithFormat:@"<%@ %p>", [argument class], argument];
	if (nil == argument)
	{
		argDesc= [targetDesc hasSuffix:@":"] ? @"nil" : @"";
	}
	if ([argument isKindOfClass:[NSString class]]) argDesc = [NSString stringWithFormat:@"@\"%@\"", argument];
	if ([argument isKindOfClass:[NSInvocation class]])
	{
		argDesc = [NSString stringWithFormat:@"<%@ %p %@>", [argument class], argument, NSStringFromSelector([argument selector])];
	}
	LOG((@"------------- detach -[%@ %@%@]", targetDesc, NSStringFromSelector(selector), argDesc));
	[super detachNewThreadSelector:selector
						  toTarget:target
						withObject:argument];
}

+ (void) load
{
	[self poseAsClass:[NSThread class]];
}

@end


@interface MyEntityDescription : NSEntityDescription

@end

@implementation MyEntityDescription

+ (NSManagedObject *)insertNewObjectForEntityForName:(NSString *)entityName
							  inManagedObjectContext:(NSManagedObjectContext *)context

{
	if ( [NSThread isMainThread] )
	{
		TJT((@"creating %@ in main thread with context %X", entityName, context));
	}
	else
	{
		TJT((@"creating %@ in thread %X with context %X", entityName, [NSThread currentThread], context));
	}
	
	return [super insertNewObjectForEntityForName:entityName
						   inManagedObjectContext:context];
}

//+ (void) load
//{
//	[self poseAsClass:[NSEntityDescription class]];
//}
	
@end



#endif









#if 0

@interface MyLoggingBindingObject : NSObject

@end

@implementation MyLoggingBindingObject


- (void)bind:(NSString *)binding toObject:(id)observable withKeyPath:(NSString *)keyPath options:(NSDictionary *)options;    // placeholders and value transformers are specified in options dictionary
{
	LOG((@"<%@ 0x%x> bind:%@ toObject: <%@ 0x%x> withKeyPath:%@ options:...", [self class], self, binding, [observable class], observable, keyPath));
	[super bind:binding toObject:observable withKeyPath:keyPath options:options];
}

- (void)unbind:(NSString *)binding;
{
	LOG((@"<%@ 0x%x> unbind:%@", self, self, binding));
	[super unbind:binding];
}

+ (void) load
{
	[self poseAsClass:[NSObject class]];
}

#endif

#if 0

@interface NSKeyValueObservationForwarder : NSObject
{
    NSObject *_observer;
    NSString *_relationshipKey;
    NSString *_keyPathFromRelatedObject;
    unsigned int _options;
    void *_context;
}

- (id)initWithObserver:(id)fp8 relationshipKey:(id)fp12 keyPathFromRelatedObject:(id)fp16 options:(unsigned int)fp20 context:(void *)fp24;
- (void)dealloc;
- (void)finalize;
- (void)stopObservingRelatedObject:(id)fp8;
- (void)observeValueForKeyPath:(id)fp8 ofObject:(id)fp12 change:(id)fp16 context:(void *)fp20;

@end

@interface MyKeyValueObservationForwarder : NSKeyValueObservationForwarder

@end

@implementation MyKeyValueObservationForwarder

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	NSLog(@"- - - - - - - - - %@ %@", keyPath, [object class]);
	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

+ (void) load
{
	[self poseAsClass:[NSKeyValueObservationForwarder class]];
}

@end


@interface MyObject : NSObject

@end

@implementation MyObject

- (void)_removeObserver:(id)obs forProperty:(id)prop
{
	NSLog(@"- - - - - - - - - - - - - %@ %@", obs, prop);
	[super _removeObserver:obs forProperty:prop];
}

+ (void) load
{
	[self poseAsClass:[NSObject class]];
}

@end

#endif


#if 0

@interface MyQTMovie : QTMovie

@end

@implementation MyQTMovie

- (id)init
{
	NSAssert([NSThread currentThread] == gMainThread, @"Not initializing Movie from the Main Thread");
	NSLog(@"QTMovie %@", NSStringFromSelector(_cmd));
	if (self = [super init])
	{
	}
	return self;
}

- (id)initWithFile:(NSString *)fileName error:(NSError **)errorPtr
{
	NSAssert([NSThread currentThread] == gMainThread, @"Not initializing Movie from the Main Thread");
	NSLog(@"QTMovie %@", NSStringFromSelector(_cmd));
	return [super initWithFile:fileName error:errorPtr];
}

- (id)initWithURL:(NSURL *)url error:(NSError **)errorPtr
{
	NSAssert([NSThread currentThread] == gMainThread, @"Not initializing Movie from the Main Thread");
	NSLog(@"QTMovie %@", NSStringFromSelector(_cmd));
	return [super initWithURL:url error:errorPtr];
}

- (id)initWithDataReference:(QTDataReference *)dataReference error:(NSError **)errorPtr
{
	NSAssert([NSThread currentThread] == gMainThread, @"Not initializing Movie from the Main Thread");
	NSLog(@"QTMovie %@", NSStringFromSelector(_cmd));
	return [super initWithDataReference:dataReference error:errorPtr];
}

- (id)initWithPasteboard:(NSPasteboard *)pasteboard error:(NSError **)errorPtr
{
	NSAssert([NSThread currentThread] == gMainThread, @"Not initializing Movie from the Main Thread");
	NSLog(@"QTMovie %@", NSStringFromSelector(_cmd));
	return [super initWithPasteboard:pasteboard error:errorPtr];
}

- (id)initWithData:(NSData *)data error:(NSError **)errorPtr
{
	NSAssert([NSThread currentThread] == gMainThread, @"Not initializing Movie from the Main Thread");
	NSLog(@"QTMovie %@", NSStringFromSelector(_cmd));
	return [super initWithData:data error:errorPtr];
}

- (id)initWithMovie:(QTMovie *)movie timeRange:(QTTimeRange)range error:(NSError **)errorPtr
{
	NSAssert([NSThread currentThread] == gMainThread, @"Not initializing Movie from the Main Thread");
	NSLog(@"QTMovie %@", NSStringFromSelector(_cmd));
	return [super initWithMovie:movie timeRange:range error:errorPtr];
}

- (id)initWithQuickTimeMovie:(Movie)movie disposeWhenDone:(BOOL)dispose error:(NSError **)errorPtr
{
	NSAssert([NSThread currentThread] == gMainThread, @"Not initializing Movie from the Main Thread");
	NSLog(@"QTMovie %@", NSStringFromSelector(_cmd));
	return [super initWithQuickTimeMovie:movie disposeWhenDone:dispose error:errorPtr];
}

- (id)initWithAttributes:(NSDictionary *)attributes error:(NSError **)errorPtr
{
	NSAssert([NSThread currentThread] == gMainThread, @"Not initializing Movie from the Main Thread");
	NSLog(@"QTMovie %@", NSStringFromSelector(_cmd));
	return [super initWithAttributes:attributes error:errorPtr];
}



+ (void) load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];	
	[self poseAsClass:[QTMovie class]];
	[pool release];
}

#endif






#ifdef DEBUG

// from http://www.macdevcenter.com/pub/a/mac/2002/05/31/runtime_parttwo.html?page=2

#import <objc/objc-runtime.h>

void showMethodGroups(Class klass, char mType);

void showMethodGroups(Class klass, char mType) {
	void *iterator = 0;     // Method list (category) iterator
	struct objc_method_list* mlist;
	Method currMethod;
	int  j;
	while ( 0 != (mlist = class_nextMethodList( klass, &iterator )) ) {
		printf ("  Methods:\n");
		for ( j = 0; j < mlist->method_count; ++j ) {
			currMethod = (mlist->method_list + j);
			printf ("    method: '%c%s'  encodedReturnTypeAndArguments: '%s'\n", mType,
					(const char *)currMethod->method_name, currMethod->method_types);
		}
	}
}

#endif


#if 0

@interface MyObject : NSObject

@end

@implementation MyObject

- (void)performSelector:(SEL)aSelector withObject:(id)anArgument afterDelay:(NSTimeInterval)delay;
{
	LOG((@"NSObject performSelector:%@ withObject:%p afterDelay:%.f", NSStringFromSelector(aSelector), anArgument, delay ));

	if ( ![NSThread isMainThread] )
	{
		LOG((@"NSObject %@ not from main thread", NSStringFromSelector(_cmd) ));
	}
	
	[super performSelector:aSelector withObject:anArgument afterDelay:delay];
}

- (void)performSelector:(SEL)aSelector withObject:(id)anArgument afterDelay:(NSTimeInterval)delay inModes:(NSArray *)modes;
{
	LOG((@"NSObject performSelector:%@ withObject:%p afterDelay:%.f inModes:%@", NSStringFromSelector(aSelector), anArgument, delay, modes ));
	if ( ![NSThread isMainThread] )
	{
		LOG((@"NSObject %@ not from main thread", NSStringFromSelector(_cmd) ));
	}
	
	[super performSelector:aSelector withObject:anArgument afterDelay:delay inModes:modes];
}

+ (void) load
{
	[self poseAsClass:[NSObject class]];
}





@interface MyRunLoop : NSRunLoop

@end

@implementation MyRunLoop

- (void)performSelector:(SEL)aSelector target:(id)target argument:(id)arg order:(unsigned)order modes:(NSArray *)modes;
{
	LOG((@"NSRunLoop performSelector:%@ target:%p argument:%p order:%d inModes:%@", NSStringFromSelector(aSelector), target, arg, order, modes ));
	if ( ![NSThread isMainThread] )
	{
		LOG((@"NSRunLoop %@ not from main thread", NSStringFromSelector(_cmd) ));
	}
	
	[super performSelector:aSelector target:target argument:arg order:order modes:modes];
}

+ (void) load
{
	[self poseAsClass:[NSRunLoop class]];
}

@end

@interface MyTimer : NSTimer

@end

@implementation MyTimer

+ (NSTimer *)timerWithTimeInterval:(NSTimeInterval)ti invocation:(NSInvocation *)invocation repeats:(BOOL)yesOrNo;
{
	LOG((@"NSTimer timerWithTimeInterval:%f invocation:%@ repeats:%d", ti, invocation, yesOrNo));
	return [super timerWithTimeInterval:ti invocation:invocation repeats:yesOrNo];
}

+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)ti invocation:(NSInvocation *)invocation repeats:(BOOL)yesOrNo;
{
	LOG((@"NSTimer scheduledTimerWithTimeInterval:%f invocation:%@ repeats:%d", ti, invocation, yesOrNo));
	return [super scheduledTimerWithTimeInterval:ti invocation:invocation repeats:yesOrNo];
}


+ (NSTimer *)timerWithTimeInterval:(NSTimeInterval)ti target:(id)aTarget selector:(SEL)aSelector userInfo:(id)userInfo repeats:(BOOL)yesOrNo;
{
	LOG((@"NSTimer timerWithTimeInterval:%f target:%p selector:%@ userInfo:%@ repeats:%d", ti, aTarget, NSStringFromSelector(aSelector), userInfo, yesOrNo));
	return [super timerWithTimeInterval:ti target:aTarget selector:aSelector userInfo:userInfo repeats:yesOrNo];
}

+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)ti target:(id)aTarget selector:(SEL)aSelector userInfo:(id)userInfo repeats:(BOOL)yesOrNo;
{
	LOG((@"NSTimer scheduledTimerWithTimeInterval:%f target:%p selector:%@ userInfo:%@ repeats:%d", ti, aTarget, NSStringFromSelector(aSelector), userInfo, yesOrNo));
	return [super scheduledTimerWithTimeInterval:ti target:aTarget selector:aSelector userInfo:userInfo repeats:yesOrNo];
}




- (void)fire;
{
	LOG((@"NSTimer fire %@", [self userInfo] ));
	
	[super fire];
}

+ (void) load
{
	[self poseAsClass:[NSTimer class]];
}


@end

#endif



// REGISTRATION GLOBALS
int gRegistrationFailureCode;
NSString *gRegistrationString;
int gLicenseIsBlacklisted;
int gLicenseViolation;
int gRegistrationWasChecked;
NSString *gLicensee = nil;
NSDate *gLicenseDate = nil;
NSString *gRegistrationHash = nil;
int gLicenseType = 0;
int gIsPro = 0;
int gLicenseVersion = 0;
unsigned int gSeats = 0;

@implementation KTApplication

- (void)run
{
#ifdef DEBUG
//	showMethodGroups(NSClassFromString(@"_NSControllerObjectProxy"), '-');
#endif
	
	/* Needed?
	FSRef bundleRef; 
	OSStatus err = noErr; 
	CFBundleRef applicationBundle = CFBundleGetMainBundle(); 
	CFURLRef bundleURL = CFBundleCopyBundleURL(applicationBundle); 
	if (!CFURLGetFSRef(bundleURL, &bundleRef)) err = fnfErr; 

	if (err == noErr) err = AHRegisterHelpBook(&bundleRef); 
	*/
	
	
	[super run];
}


// iMedia Browser Requirement

+ (NSString *)applicationIdentifier
{
	return @"com.karelia.Sandvox";
}

// Do something other than log the exception

// Handler calls this, I think.

- (void)reportException:(NSException *)anException
{
	// This is still called even when exceptionHandler:shouldHandleException:mask: returns NO!
	// So ... call it again to determine if I should report it....e
	if (![[self delegate] exceptionHandler:nil shouldHandleException:anException mask:0])
	{
		
		return;
	}
	
	// No need to log, it already was by our exception handler.  But this gives us or the user an alert.
    
    NSString *alertTitle = NSLocalizedString(@"Sandvox encountered a problem.",
                                             "Unexpected Exception Alert Title"); 
    NSString *errorMessage = nil;

	// Show us user info only if there's something there besides stack trace
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:[anException userInfo]];
	[userInfo removeObjectForKey:NSStackTraceKey];
	NSString *userInfoDescription = [userInfo count] ? [NSString stringWithFormat:@"UserInfo: %@\n\n", [userInfo description]] : @"";
	
#ifdef DEBUG
	
	errorMessage = [NSString stringWithFormat:@"DEBUG ALERT:\n\nName: %@\n\nReason: %@\n\n%@\n%@", [anException name], [anException reason], userInfoDescription, [anException printStackTrace]];
    NSRunCriticalAlertPanel(alertTitle, errorMessage, nil, nil, nil);
    
	NSString *traceName = [anException traceName];
	NSLog(@"tracename = %@", traceName);

#else
    
	// Log it for posterity and in case the exception isn't reported
		NSLog(@"%@", [[NSString stringWithFormat:@"EXCEPTION:\n\nName: %@\n\nReason: %@\n\n%@\n%@", [anException name], [anException reason], userInfoDescription, [[anException userInfo] objectForKey:NSStackTraceKey]] condenseWhiteSpace]);


    // have we seen this exception/trace before?
	BOOL stackTraceIsKnown = NO;
    NSString *buildNumber = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];        
	NSString *traceName = [anException traceName];
    
	// key = ExceptionReports, value = dictionary of all traceNames by buildNumber
	// ExceptionReports, key = buildNumber value = array of recorded traceName
	NSDictionary *exceptionReports = [[NSUserDefaults standardUserDefaults] objectForKey:@"ExceptionReports"];
	if ( nil != exceptionReports )
	{
		NSArray *recordedNames = [exceptionReports valueForKey:buildNumber];
		if ( nil != recordedNames )
		{
			NSEnumerator *e = [recordedNames objectEnumerator];
			NSString *recordedName = nil;
			while ( recordedName = [e nextObject] )
			{
				if ( [recordedName isEqualToString:traceName] )
				{
					stackTraceIsKnown = YES;
				}
			}
		}
	}
    
	// if we've already seen it, just put up a normal panel
	if ( stackTraceIsKnown )
	{
        errorMessage = [NSString stringWithFormat:NSLocalizedString(@"%@\n\n(You have already reported this problem to Karelia. Thank you.)", "Exception Already Reported Alert Text"), [anException name]];
        NSRunCriticalAlertPanel(alertTitle, errorMessage, nil, nil, nil);
	}
	else
	{
		// we have a new trace, encourage the user to send in a report
		int alertResult = [[KTExceptionReporter sharedInstance] runAlertWithException:anException
                                                                          messageText:alertTitle
                                                                      informativeText:[anException name]];
        
        // if user submitted, record traceName against buildNumber in defaults
        if ( NSOKButton == alertResult )
        {
            // user submitted, so make note of summary in defaults
            if ( nil == exceptionReports )
            {
                exceptionReports = [NSDictionary dictionary];
            }
            NSMutableDictionary *mutableExceptionReports = [exceptionReports mutableCopy];
            NSMutableArray *mutableSummaries = [[mutableExceptionReports valueForKey:buildNumber] mutableCopy];
            if ( nil == mutableSummaries )
            {
                mutableSummaries = [[NSArray array] mutableCopy];
            }
            [mutableSummaries addObject:traceName];
            [mutableExceptionReports setObject:mutableSummaries forKey:buildNumber];
            [mutableSummaries release];
            
            [[NSUserDefaults standardUserDefaults] setObject:mutableExceptionReports
                                                      forKey:@"ExceptionReports"];
            // synch now, just in case we can't recover normally
            [[NSUserDefaults standardUserDefaults] synchronize];
            [mutableExceptionReports release];
        }
	}
    
#endif
    
}


- (void)terminate:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	// remember our open documents
	[(KTAppDelegate *)[self delegate] updateLastOpened];
	
	[pool release];	// let the above really clean up before we pop that last pool.
	
    // terminate
    [super terminate:sender];
}



/*!	Machine name.  May be helpful to look up here:
	http://developer.apple.com/documentation/Hardware/hardware2.html
*/

+(NSString * )machineName
{
	StringPtr *gestaltValue = nil;
    // Fetch machine name as pointer to PStr255 (Pascal String:  Byte0=length, Byte1..255=Characters)
	if (!Gestalt((OSType)gestaltUserVisibleMachineName,  (long *)&gestaltValue))
	{
		return [(NSString*)CFStringCreateWithPascalString(NULL, 
			(ConstStr255Param) gestaltValue, kCFStringEncodingMacRoman) autorelease];
	} else {
		return @"Unknown";
	}
}


- (void)showHelpPage:(NSString *)inHelpString;
{
	BOOL OK = [NSHelpManager gotoHelpAnchor:inHelpString];
	if (!OK)
	{
		NSBeep();
		NSLog(@"error: could not find help named %@", inHelpString);
	}
}


@end

#ifdef DEBUG

/*!	Override debugDescription so it's easier to use the debugger.  Not compiled for non-debug versions.
*/
@implementation NSDictionary ( OverrideDebug )

- (NSString *)debugDescription
{
	return [self description];
}

@end

@implementation NSArray ( OverrideDebug )

- (NSString *)debugDescription
{
	if ([self count] > 20)
	{
		NSArray *subArray = [self subarrayWithRange:NSMakeRange(0,20)];
		return [NSString stringWithFormat:@"%@ [... %d items]", [subArray description], [self count]];
	}
	else
	{
		return [self description];
	}
}

@end

@implementation NSSet ( OverrideDebug )

- (NSString *)debugDescription
{
	return [self description];
}

@end

@implementation NSData ( description )

- (NSString *)description
{
	unsigned int width = [[NSUserDefaults standardUserDefaults] integerForKey:@"NSDataDescriptionWidth"];
	unsigned int maxBytes = [[NSUserDefaults standardUserDefaults] integerForKey:@"NSDataDescriptionBytes"];
	if (!width) width = 32;
	if (!maxBytes) maxBytes = 1024;
	
	unsigned char *bytes = (unsigned char *)[self bytes];
	unsigned length = [self length];
	NSMutableString *buf = [NSMutableString string];
	if (length > width)	// don't do header if we're only showing a few bytes
	{
		[buf appendFormat:@"NSData %d bytes:\n", length];
	}
	unsigned int i, j;

	for ( i = 0 ; i < length ; i += width )
	{
		if (i > maxBytes)		// don't print too much!
		{
			[buf appendString:@"\n...\n"];
			break;
		}
		for ( j = 0 ; j < width ; j++ )
		{
			unsigned int offset = i+j;
			if (offset < length)
			{
				[buf appendFormat:@"%02X ",bytes[offset]];
			}
			else
			{
				[buf appendFormat:@"   "];
			}
		}
		[buf appendString:@"| "];
		for ( j = 0 ; j < width ; j++ )
		{
			unsigned int offset = i+j;
			if (offset < length)
			{
				unsigned char theChar = bytes[offset];
				if (theChar < 32 || theChar > 127)
				{
					theChar ='.';
				}
				[buf appendFormat:@"%c", theChar];
			}
		}
		[buf appendString:@"\n"];
	}
	if ([buf length] > 1)
	{
	[buf deleteCharactersInRange:NSMakeRange([buf length]-1, 1)];
	}
	return buf;
}

@end

#endif

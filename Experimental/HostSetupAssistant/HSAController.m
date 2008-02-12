//
//  HSAController.m
//  HostSetupAssistant
//
//  Created by Greg Hulands on 9/01/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "HSAController.h"

// Defined Keys to Use.
NSString *HSALocalHostingProperty = @"localHosting";
NSString *HSALocalHostnameProperty = @"localHostName";
NSString *HSALocalSubFolderProperty = @"localSubFolder";
NSString *HSARemoteHostingProperty = @"remoteHosting";
NSString *HSAProviderProperty = @"provider";
NSString *HSAProviderRegionProperty = @"regions";
NSString *HSAProviderNotesProperty = @"notes";
NSString *HSAProviderStorageLimitProperty = @"storageLimitMB";
NSString *HSAHostnameProperty = @"host";
NSString *HSADocumentRootProperty = @"docRoot";
NSString *HSABaseURLProperty = @"stemURL";
NSString *HSAUsernameProperty = @"userName";
NSString *HSAProtocolProperty = @"protocol";
NSString *HSAPortProperty = @"port";

@interface HSAController (Private)

- (NSArray *)initialStep; // it is possible that someone could have registered another initial step so we need to throw an exception if that is the case.

@end

static NSMutableDictionary *gRegisteredSteps = nil;

@implementation HSAController

+ (void)load
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	gRegisteredSteps = [[NSMutableDictionary dictionary] retain];
	[pool release];
}

+ (void)registerStep:(NSString *)name withClass:(Class)aClass
{
	[gRegisteredSteps setObject:NSStringFromClass(aClass) forKey:name];
}

+ (void)unregisterStep:(NSString *)name
{
	[gRegisteredSteps removeObjectForKey:name];
}

+ (NSArray *)registeredSteps
{
	return [gRegisteredSteps allKeys];
}

- (id)initWithProperties:(NSDictionary *)properties
{
	if (self = [super initWithWindowNibName:@"Assistant"])
	{
		[self setProperties:properties];
		mySteps = [[NSMutableArray alloc] initWithCapacity:[[gRegisteredSteps allKeys] count]];
		
		NSEnumerator *stepEnum = [gRegisteredSteps keyEnumerator];
		NSString *step;
		
		while (step = [stepEnum nextObject])
		{
			NSString *clsString = [gRegisteredSteps objectForKey:step];
			Class aClass = NSClassFromString(clsString);
			if (![aClass conformsToProtocol:@protocol(HSAStep)])
			{
				NSLog(@"%@ does not implement the HSAStep protocol", clsString);
				continue;
			}
			id <HSAStep>stepController = [[aClass alloc] init];
			[mySteps setObject:stepController forKey:step];
			[stepController release];
		}
	}
	return self;
}

- (void)dealloc
{
	[myOriginalProperties release];
	[myCurrentProperties release];
	[mySteps release];
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (void)setBackgrounImage:(NSImage *)image
{
	[oBackgroundImage setImage:image];
}

- (NSImage *)backgroundImage
{
	return [oBackgroundImage image];
}

- (void)setProperties:(NSDictionary *)properties
{
	[myOriginalProperties autorelease];
	myOriginalProperties = [properties copy];
	myCurrentProperties = [properties mutableCopy];
}

- (void)setProperty:(id)property forKey:(NSString *)key
{
	[myCurrentProperties setObject:property forKey:key];
}

- (id)propertyForKey:(NSString *)key
{
	return [myCurrentProperties objectForKey:key];
}

- (id)originalPropertyForKey:(NSString *)key
{
	return [myOriginalProperties objectForKey:key];
}

- (NSDictionary *)properties
{
	return [NSDictionary dictionaryWithDictionary:myCurrentProperties];
}

- (void)resetPropeties
{
	[myCurrentProperties autorelease];
	myCurrentProperties = [myOriginalProperties mutableCopy];
}

- (void)setIsBusy:(BOOL)flag
{
	if (flag)
	{
		[oBusy startAnimation:self];
	}
	else
	{
		[oBusy stopAnimation:self];
	}
}

- (void)addStep:(NSString *)name with:(id <HSAStep>)step
{
	[mySteps setObject:step forKey:name];
}

- (void)removeStep:(NSString *)name
{
	[mySteps removeObjectForKey:name];
}

- (NSArray *)steps
{
	return [mySteps allKeys];
}

- (void)setCanGoForward:(BOOL)flag
{
	[oForward setEnabled:flag];
}

- (void)setCanGoBack:(BOOL)flag
{
	[oBack setEnabled:flag];
}

- (void)appendToSummary:(NSAttributedString *)str
{
	
}

#pragma mark -
#pragma mark Interface Actions

- (void)awakeFromNib
{
	[oBusy setUsesThreadedAnimation:YES];
}

- (void)beginSheetModalForWindow:(NSWindow *)window modalDelegate:(id)delegate didEndSelector:(SEL)callback userInfo:(id)userInfo
{
	myDelegate = [delegate retain];
	myCallback = callback;
	myUserInfo = [userInfo retain];
	
	[[NSApplication sharedApplication] beginSheet:[self window]
								   modalForWindow:window
									modalDelegate:nil
								   didEndSelector:nil
									  contextInfo:nil];
}

- (void)closeOurselfWithReturnCode:(int)rc
{
	[[NSApplication sharedApplication] endSheet:[self window] returnCode:rc];
	[[self window] orderOut:self];
	
	if (myDelegate)
	{
		// - (void)hostSetupAssistantDidEnd:(HSAController *)hsa returnCode:(int)returnCode userInfo:(id)userInfo;
		NSMethodSignature *ms = [myDelegate methodSignatureForSelector:myCallback];
		NSInvocation *inv = [NSInvocation invocationWithMethodSignature:ms];
		
		[inv setSelector:myCallback];
		[inv setArgument:&self atIndex:2];
		[inv setArgument:&rc atIndex:3];
		if (myUserInfo)
		{
			[inv setArgument:myUserInfo atIndex:4];
		}
		[inv invokeWithTarget:myDelegate];
		[myDelegate release];
		[myUserInfo release];
		myDelegate = nil;
		myUserInfo = nil;
	}
}

- (IBAction)cancel:(id)sender
{
	[self closeOurselfWithReturnCode:NSCancelButton];
}

- (IBAction)goBack:(id)sender
{
	
}

- (IBAction)goForward:(id)sender
{
	[self closeOurselfWithReturnCode:NSOKButton];
}

@end

//
//  HSAController.h
//  HostSetupAssistant
//
//  Created by Greg Hulands on 9/01/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "HSAStep.h"

@class HSAView;

@interface HSAController : NSWindowController <HostSetupAssistant>
{
	NSDictionary					*myOriginalProperties;
	NSMutableDictionary				*myCurrentProperties;
	NSMutableDictionary				*mySteps;
	
	id <HSAStep>					myCurrentStep;
	
	NSURL							*myPreconfiguredHostsURL;
	NSURL							*mySubmitConfiguredHostURL;
	
	id								myDelegate;
	SEL								myCallback;
	id								myUserInfo;
	
	// Interface Outlets
	IBOutlet NSTextField			*oStepName;
	IBOutlet NSImageView			*oBackgroundImage;
	IBOutlet NSProgressIndicator	*oBusy;
	IBOutlet NSButton				*oCancel;
	IBOutlet NSButton				*oBack;
	IBOutlet NSButton				*oForward;
	IBOutlet HSAView				*oView;
}

- (id)initWithProperties:(NSDictionary *)properties;

//default step loading
+ (void)registerStep:(NSString *)name withClass:(Class)aClass;
+ (NSArray *)registeredSteps;

//runtime step loading
- (void)addStep:(NSString *)name with:(id <HSAStep>)step;
- (void)removeStep:(NSString *)name;
- (NSArray *)steps;

- (void)setBackgrounImage:(NSImage *)image;
- (NSImage *)backgroundImage;

/*
		didEndSelector should be of the form 
		- (void)hostSetupAssistantDidEnd:(HSAController *)hsa returnCode:(int)returnCode userInfo:(id)userInfo;
		returnCode == NSOKButton if the process was completed, otherwise it was cancelled.
 */
- (void)beginSheetModalForWindow:(NSWindow *)window modalDelegate:(id)delegate didEndSelector:(SEL)callback userInfo:(id)userInfo;

// Preconfigured Host Management
- (void)setPreconfiguredHostsURL:(NSURL *)url;
- (void)setSubmitConfiguredHostURL:(NSURL *)url;

// Property Management
- (void)setProperties:(NSDictionary *)properties;
- (void)setProperty:(id)property forKey:(NSString *)key;
- (id)propertyForKey:(NSString *)key;
- (id)originalPropertyForKey:(NSString *)key;
- (NSDictionary *)properties;
- (void)resetPropeties;

// IBActions
- (IBAction)cancel:(id)sender;
- (IBAction)goBack:(id)sender;
- (IBAction)goForward:(id)sender;

@end

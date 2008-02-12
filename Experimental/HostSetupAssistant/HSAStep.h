/*
 *  HSAStep.h
 *  HostSetupAssistant
 *
 *  Created by Greg Hulands on 9/01/06.
 *  Copyright 2006 __MyCompanyName__. All rights reserved.
 *
 */

#include <Cocoa/Cocoa.h>

@protocol HostSetupAssistant

- (void)setProperty:(id)property forKey:(NSString *)key;
- (id)propertyForKey:(NSString *)key;
- (void)resetPropeties;

// Set the progress indicator to spin and control whether they can proceed or go back.
- (void)setIsBusy:(BOOL)flag;
- (void)setCanGoForward:(BOOL)flag;
- (void)setCanGoBack:(BOOL)flag;

- (void)appendToSummary:(NSAttributedString *)str;

@end

typedef enum {
	HSARemotePath = 0,
	HSALocalPath,
	HSAMultiPath
} HSAStepType;

@protocol HSAStep <NSObject>

// The internal step name - used as a key in determining the path of steps to take
- (NSString *)name;
// The steps visual display name
- (NSString *)displayName;

- (HSAStepType)type;
- (NSString *)displayAfterStep:(NSString *)name;

// The view that will appear in the panel, the size must be { } and it is the onous of the panel to be this size.
- (NSView *)panel;
// When the panel becomes active, you can have a text field or whatever become the first responder
- (NSResponder *)firstResponder;

// We can change the appearance of the box we are displayed in
- (BOOL)drawBackground;
- (BOOL)drawBorder;

// if either return nil, then they are hidden. Should only be nil if the first or last step in the path
- (NSString *)forwardButtonTitle;
- (NSString *)backButtonTitle;

// Called before the panel is dislayed, flag is used to determine if we were activated from someone pressing the forward or back buttons
- (void)willActivateInAssistant:(id <HostSetupAssistant>)controller fromStep:(NSString *)step isMovingForward:(BOOL)flag;
/* 
	Called before the panel is removed from display
	It has the opportunity to return the next panel name. If it returns nil, then it is assumed that this path in the process is complete.
*/
- (NSString *)willDeactivateInAssistant:(id <HostSetupAssistant>)controller toStep:(NSString *)step isMovingForward:(BOOL)flag;

@end

// Defined Keys to Use.
extern NSString *HSALocalHostingProperty;	// @"localHosting"
extern NSString *HSALocalHostnameProperty;	// @"localHostName"
extern NSString *HSALocalSubFolderProperty; // @"localSubFolder"
extern NSString *HSARemoteHostingProperty;	// @"remoteHosting"
extern NSString *HSAProviderProperty;		// @"provider"
extern NSString *HSAProviderRegionProperty;	// @"regions"
extern NSString *HSAProviderNotesProperty;	// @"notes"
extern NSString *HSAProviderStorageLimitProperty; // @"storageLimitMB"
extern NSString *HSAHostnameProperty;		// @"host"
extern NSString *HSADocumentRootProperty;	// @"docRoot"
extern NSString *HSABaseURLProperty;		// @"stemURL"
extern NSString *HSAUsernameProperty;		// @"userName"
extern NSString *HSAProtocolProperty;		// @"protocol"
extern NSString *HSAPortProperty;			// @"port"


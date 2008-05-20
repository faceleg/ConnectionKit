//
//  KTDocument+Alert.m
//  Marvel
//
//  Created by Terrence Talbot on 9/26/06.
//  Copyright 2006 Karelia Software. All rights reserved.
//

#import "KTDocument.h"

#import "NSObject+Karelia.h"


// this file exists to consolidate the alertDidEnd::: selector for KTDocument
// beginSheetModalForWindow::: is messages from several KTDocument categories
// it should be easier to track here, rather than end up with multiple
// implementations in the same class!

@implementation KTDocument ( Alert )

- (void)delayedAlertSheetWithInfo:(NSDictionary *)anInfoDictionary
{
	NSWindow *window = [[self windowController] window];
	
	NSString *messageText = [anInfoDictionary valueForKey:@"messageText"];
	NSString *informativeText = [anInfoDictionary valueForKey:@"informativeText"];
	
	if ( nil == window )
	{
		// somehow we got called before the window finished loading
		// at least log the error to the console
		NSLog(@"Unable to display alert: %@ : %@", messageText, informativeText);
	}
	
	NSAlert *alert = [NSAlert alertWithMessageText:messageText
									 defaultButton:NSLocalizedString(@"OK", "OK Button")
								   alternateButton:nil 
									   otherButton:nil 
						 informativeTextWithFormat:informativeText];
	
	[alert beginSheetModalForWindow:window
					  modalDelegate:self
					 didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
						contextInfo:[[NSDictionary dictionaryWithObject:@"delayedAlertSheetWithInfo:" forKey:@"context"] retain]];
}

// NB: it is assumed contextInfo is always a retained NSDictionary containing 
// at least the key @"context" that usually specifies the selector (as a string)
// from which the alert was called.

// NB: each context handler must be careful to autorelease contextInfo to balance the retain 
// required in beginSheetModalForWindow:::: We can't do it automatically as at least one
// handler requires it to be released in a different order 
// Perhaps Objective-C 2.0 will obviate this?

- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(id)contextInfo
{
	// close the alert
	[[alert window] orderOut:nil];
	
	NSString *context = [(id)contextInfo valueForKey:@"context"];
    
	// handle delayedAlertSheetWithInfo: above
	if ( [context isEqualToString:@"delayedAlertSheetWithInfo:"] )
	{	
		; // nothing to do but orderOut: the alert
	}
	
	// handle canCloseDocumentWithDelegate from KTDocument.m
	else if ( [context isEqualToString:@"canCloseDocumentWithDelegate:"] )
	{
		BOOL shouldClose = NO;
        
        switch ( returnCode )
        {
		case NSAlertOtherReturn:
			// cancel
			shouldClose = NO;
			break;
		case NSAlertAlternateReturn:
			// don't save
			shouldClose = YES;
			break;
		case NSAlertDefaultReturn:
		default:
			// save as
			shouldClose = NO;
			[self performSelector:@selector(saveDocumentAs:)
			withObject:self
			afterDelay:0.0];
        }
		
		// finish out the delegate callback to the document controller to close the window
		id delegate = [(id)contextInfo valueForKey:@"delegate"];
		SEL shouldCloseSelector = NSSelectorFromString([contextInfo valueForKey:@"selector"]);
		if ( [delegate respondsToSelector:shouldCloseSelector] )
		{
			objc_msgSend(delegate, shouldCloseSelector, self, shouldClose, contextInfo);
		}
	}
	
	// handle revertDocumentToSnapshot: from KTDocument.m
	else if ( [context isEqualToString:@"revertDocumentToSnapshot:"] )
	{	
		if ( NSOKButton == returnCode )
		{
			[self performSelector:@selector(revertPersistentStoreToSnapshot:) withObject:nil afterDelay:0.0];
		}
	}
	
	// handle inability to move old snapshot to Trash
	else if ( [context isEqualToString:@"!didMoveOldSnapshotToTrash"] )
	{	
		; // nothing to do, just an OK button
	}
	
	// handle inability to snapshot document
	else if ( [context isEqualToString:@"!didSnapshot"] )
	{	
		; // nothing to do, just an OK button
	}	

	// clean up
	[contextInfo autorelease];
}

@end

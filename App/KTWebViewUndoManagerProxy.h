//
//  KTWebViewUndoManagerProxy.h
//  Marvel
//
//  Created by Mike on 20/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


extern NSString *KTWebViewDidEditChunkNotification;


@class KTDocWebViewController;


@interface KTWebViewUndoManagerProxy : NSProxy
{
	NSUndoManager			*myUndoManager;
	
	int				myRegisteredUndosCount;
	NSMutableArray	*myWebViewActionTargets;	// NSSet might not be safe
}

- (id)initWithUndoManager:(NSUndoManager *)undoManager;

- (void)removeAllWebViewTargettedActions;

@end

//
//  KTWebViewUndoManagerProxy.m
//  Marvel
//
//  Created by Mike on 20/12/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTWebViewUndoManagerProxy.h"

#import "Debug.h"
#import "NSArray+Karelia.h"

NSString *KTWebViewDidEditChunkNotification = @"WebViewDidEditTextChunk";


@implementation KTWebViewUndoManagerProxy

- (id)initWithUndoManager:(NSUndoManager *)undoManager
{
	myUndoManager = [undoManager retain];
	
	myWebViewActionTargets = [[NSMutableArray alloc] init];
	
	return self;
}

- (NSUndoManager *)undoManager { return myUndoManager; }

- (void)dealloc
{
	[myUndoManager release];
	[myWebViewActionTargets release];
	
	[super dealloc];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	NSMethodSignature *result = [[self undoManager] methodSignatureForSelector:aSelector];
	return result;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
	[anInvocation setTarget:[self undoManager]];
	
	OFF((@"Invoking method -%@ on undo manager", NSStringFromSelector([anInvocation selector])));
	
	[anInvocation invoke];
}

- (void)willRegisterUndoWithTarget:(id)target
{
	// Post a notification that the WebView has been edited.
	// We DON'T do this for the first registration or if undoing/redoing
	if (myRegisteredUndosCount > 0 && ![[self undoManager] isUndoing] && ![[self undoManager] isRedoing])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:KTWebViewDidEditChunkNotification
															object:self];
	}
	
	
	// Increment or decrement our registered undo count as appropriate
	if ([[self undoManager] isUndoing]) {
		myRegisteredUndosCount--;
	}
	else {
		myRegisteredUndosCount++;
	}
	NSAssert1(myRegisteredUndosCount >= 0,
			  @"KTWebViewUndoManagerProxy undo count slipped to %i", myRegisteredUndosCount);
	
	
	// Maintain a list of undo targets
	if (![myWebViewActionTargets containsObjectIdenticalTo:target]) {
		[myWebViewActionTargets addObject:target];
	}
}

- (void)registerUndoWithTarget:(id)target selector:(SEL)aSelector object:(id)anObject
{
	[self willRegisterUndoWithTarget:target];
	
	[[self undoManager] registerUndoWithTarget:target selector:aSelector object:anObject];
}

- (id)prepareWithInvocationTarget:(id)target
{
	[self willRegisterUndoWithTarget:target];
	
	id result = [[self undoManager] prepareWithInvocationTarget:target];
	return result;
}

/*	We record every undo action target. This method then calls -removeAllActionsWithTarget: for them.
 *	The main purpose behind this is so that the WebViewController can remove the actions sooner
 *	than the WebView normally would.
 */
- (void)removeAllWebViewTargettedActions
{
	// Remove undo actions from the real undo manager
	NSEnumerator *actionTargetsEnumerator = [myWebViewActionTargets objectEnumerator];
	id aTarget;
	while (aTarget = [actionTargetsEnumerator nextObject])
	{
		[[self undoManager] removeAllActionsWithTarget:aTarget];
	}
	
	[myWebViewActionTargets removeAllObjects];
	
	
	// Reset the registered undo count
	myRegisteredUndosCount = 0;
}

@end

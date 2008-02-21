//
//  KTUndoManager.m
//  Marvel
//
//  Created by Terrence Talbot on 5/1/06.
//  Copyright 2006 Karelia Software. All rights reserved.
//

#import "KTUndoManager.h"

#import "KTDocument.h"



@implementation KTUndoManager

- (id)init
{
	if ( ![super init] )
	{
		return nil;
	}
	
	TJT((@"init KTUndoManager"));
	
	return self;
}

- (void)dealloc
{
	TJT((@"dealloc KTUndoManager"));
	[self setDocument:nil];
	[super dealloc];
}

- (KTDocument *)document
{
	return myDocument;
}

- (void)setDocument:(KTDocument *)aDocument
{
	[aDocument retain];
	[myDocument release];
	myDocument = aDocument;
}

- (void)removeAllActions
{
	TJT((@"undo: removing all actions"));
	[super removeAllActions];
}

- (void)removeAllActionsWithTarget:(id)target
{
	if ( [target isManagedObject] )
	{
		TJT((@"undo: removing all actions with target: %@", [target managedObjectDescription]));
	}
	else
	{
		TJT((@"undo: removing all actions with target: %@", target));
	}
	[super removeAllActionsWithTarget:target];
}

- (void)setActionName:(NSString *)actionName
{
	TJT((@"undo: setting action name to %@", actionName));
	[super setActionName:actionName];
}

- (void)setLevelsOfUndo:(unsigned)anInt
{
	TJT((@"undo: setting levels of undo to %i", anInt));
	[super setLevelsOfUndo:anInt];
}

- (void)disableUndoRegistration
{
	TJT((@"undo: disabling undo registration"));
	[super disableUndoRegistration];
}

- (void)enableUndoRegistration
{
	TJT((@"undo: enabling undo registration"));
	[super enableUndoRegistration];
}

- (void)beginUndoGrouping
{
	TJT((@"undo: begin undo group"));
	[super beginUndoGrouping];
}

- (void)endUndoGrouping
{
	TJT((@"undo: end undo group"));
	[super endUndoGrouping];
}

- (void)registerUndoWithTarget:(id)target selector:(SEL)aSelector object:(id)anObject
{
	if ( [target isManagedObject] )
	{
		TJT((@"undo: registering undo (%@) with target %@", NSStringFromSelector(aSelector), [target managedObjectDescription]));
	}
	else
	{
		TJT((@"undo: registering undo (%@) with target %@", NSStringFromSelector(aSelector), target));
	}
	
	[super registerUndoWithTarget:target selector:aSelector object:anObject];
}

- (id)prepareWithInvocationTarget:(id)target
{
	if ( [target isManagedObject] )
	{
		TJT((@"undo: prepareWithInvocationTarget: %@", [target managedObjectDescription]));
	}
	else
	{
		TJT((@"undo: prepareWithInvocationTarget: %@", target));
	}
	
	return [super prepareWithInvocationTarget:target];
}

- (void)undoNestedGroup
{
	TJT((@"======================= UNDO ======================="));
	//TJT((@"cancelling autosave timers..."));
	//[[self document] cancelAndInvalidateAutosaveTimers];
	[super undoNestedGroup];
}

- (void)redo
{
	TJT((@"======================= REDO ======================="));
	//TJT((@"cancelling autosave timers..."));
	//[[self document] cancelAndInvalidateAutosaveTimers];
	[super redo];
}


@end


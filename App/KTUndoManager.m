//
//  KTUndoManager.m
//  Marvel
//
//  Created by Terrence Talbot on 5/1/06.
//  Copyright 2006-2009 Karelia Software. All rights reserved.
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
	
	OFF((@"init KTUndoManager"));
	
	return self;
}

- (void)dealloc
{
	OFF((@"dealloc KTUndoManager"));
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
	OFF((@"undo: removing all actions"));
	[super removeAllActions];
}

- (void)removeAllActionsWithTarget:(id)target
{
	if ( [target isManagedObject] )
	{
		OFF((@"undo: removing all actions with target: %@", [target managedObjectDescription]));
	}
	else
	{
		OFF((@"undo: removing all actions with target: %@", target));
	}
	[super removeAllActionsWithTarget:target];
}

- (void)setActionName:(NSString *)actionName
{
	OFF((@"undo: setting action name to %@", actionName));
	[super setActionName:actionName];
}

- (void)setLevelsOfUndo:(unsigned)anInt
{
	OFF((@"undo: setting levels of undo to %i", anInt));
	[super setLevelsOfUndo:anInt];
}

- (void)disableUndoRegistration
{
	OFF((@"undo: disabling undo registration"));
	[super disableUndoRegistration];
}

- (void)enableUndoRegistration
{
	OFF((@"undo: enabling undo registration"));
	[super enableUndoRegistration];
}

- (void)beginUndoGrouping
{
	OFF((@"undo: begin undo group"));
	[super beginUndoGrouping];
}

- (void)endUndoGrouping
{
	OFF((@"undo: end undo group"));
	[super endUndoGrouping];
}

- (void)registerUndoWithTarget:(id)target selector:(SEL)aSelector object:(id)anObject
{
	if ( [target isManagedObject] )
	{
		OFF((@"undo: registering undo (%@) with target %@", NSStringFromSelector(aSelector), [target managedObjectDescription]));
	}
	else
	{
		OFF((@"undo: registering undo (%@) with target %@", NSStringFromSelector(aSelector), target));
	}
	
	[super registerUndoWithTarget:target selector:aSelector object:anObject];
}

- (id)prepareWithInvocationTarget:(id)target
{
	if ( [target isManagedObject] )
	{
		OFF((@"undo: prepareWithInvocationTarget: %@", [target managedObjectDescription]));
	}
	else
	{
		OFF((@"undo: prepareWithInvocationTarget: %@", target));
	}
	
	return [super prepareWithInvocationTarget:target];
}

- (void)undoNestedGroup
{
	OFF((@"======================= UNDO ======================="));
	//OFF((@"cancelling autosave timers..."));
	//[[self document] cancelAndInvalidateAutosaveTimers];
	[super undoNestedGroup];
}

- (void)redo
{
	OFF((@"======================= REDO ======================="));
	//OFF((@"cancelling autosave timers..."));
	//[[self document] cancelAndInvalidateAutosaveTimers];
	[super redo];
}


@end


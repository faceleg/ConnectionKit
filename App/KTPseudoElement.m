//
//  KTPseudoElement.m
//  KTComponents
//
//  Created by Terrence Talbot on 8/14/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTPseudoElement.h"

#import "Debug.h"
#import "KTAbstractPluginDelegate.h"
#import "KTDocument.h"
#import "NSBundle+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSString+Karelia.h"


static NSString *kKTPseudoElementException = @"KTPseudoElementException";


@interface KTPseudoElement ()
@end


#pragma mark -


@implementation KTPseudoElement

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key { return NO; }

#pragma mark -
#pragma mark Init & Dealloc

- (void)awakeFromFetch
{
	[NSException raise:kKTPseudoElementException format:@"PseudoElements have no context!"];
}

- (void)awakeFromInsert
{
	[NSException raise:kKTPseudoElementException format:@"PseudoElements have no context!"];
}

- (id)initWithDOMNode:(DOMNode *)node container:(KTAbstractElement *)container;
{
	if (![super init]) {
		return nil;
	}
	
	myPrimitiveValues = [[NSMutableDictionary alloc] init];
	myDOMNode = [node retain];
	myContainer = [container retain];
	
	return self;
}

- (void)dealloc
{
	if ([self automaticUndoIsEnabled])
	{
		[[[[self container] managedObjectContext] undoManager] removeAllActionsWithTarget:self];
	}
	
	[myDOMNode release];
	[myContainer release];
	[myPrimitiveValues release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark NSManagedObject / Undo

- (id)primitiveValueForKey:(NSString *)key { return [myPrimitiveValues valueForKey:key]; }

- (void)undoSetValue:(id)value forKey:(NSString *)key
{
	[self willChangeValueForKey:key];
	[self setPrimitiveValue:value forKey:key];
	[self didChangeValueForKey:key];
}

- (void)setPrimitiveValue:(id)value forKey:(NSString *)key
{
	// Register an undo operation
	if ([self automaticUndoIsEnabled])
	{
		NSUndoManager *undoManager = [[[self container] managedObjectContext] undoManager];
		[[undoManager prepareWithInvocationTarget:self] undoSetValue:[self primitiveValueForKey:key] forKey:key];
	}
	
	[myPrimitiveValues setValue:value forKey:key];
}

- (BOOL)automaticUndoIsEnabled { return myAutomaticUndoIsEnabled; }

- (void)setAutomaticUndoIsEnabled:(BOOL)flag { myAutomaticUndoIsEnabled = flag; }

#pragma mark -
#pragma mark KTPluginInspector Protocol

- (NSString *)uniqueID
{
	SUBCLASSMUSTIMPLEMENT;
	return nil;
}

- (id)inspectorObject { return self; }

- (NSBundle *)inspectorNibBundle
{
	return [NSBundle bundleForClass:[self class]];
}

- (NSString *)inspectorNibName
{
	SUBCLASSMUSTIMPLEMENT;
	return nil;
}

- (id)inspectorNibOwner { return self; }

#pragma mark -
#pragma mark Accessors

- (DOMNode *)DOMNode { return myDOMNode; }

- (void)setDOMNode:(DOMNode *)aDOMNode
{
	[aDOMNode retain];
	[myDOMNode release];
	myDOMNode = aDOMNode;
}

- (KTAbstractElement *)container { return myContainer; }

@end

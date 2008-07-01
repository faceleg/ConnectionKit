//
//  KTAbstractPluginDelegate.m
//  KTComponents
//
//  Created by Terrence Talbot on 6/25/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTAbstractPluginDelegate.h"

#import "Debug.h"
#import "KTDocument.h"
#import "KTPage.h"
#import "KTPagelet.h"
#import "NSManagedObject+KTExtensions.h"

@implementation KTAbstractPluginDelegate

#pragma mark awake

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject
{
	;
}

- (void)awakeFromDragWithDictionary:(NSDictionary *)aDictionary
{
	;
}

#pragma mark -
#pragma mark dealloc

- (void)dealloc
{
	[self setDelegateOwner:nil];
	[super dealloc];
}

#pragma mark -
#pragma mark Validation

/*	Called by our delegateOwner whenever it is asked to validate something. By default we
 *	always accept the value; it is subclasses repsonsibility to override it.
 */
- (BOOL)validatePluginValue:(id *)ioValue forKeyPath:(NSString *)inKeyPath error:(NSError **)outError
{
	return YES;
}

#pragma mark -
#pragma mark accessors/mutators

- (NSBundle *)bundle
{
	return [[[self delegateOwner] plugin] bundle];
}

- (KTDocument *)document
{
	return [[self page] document];
}

- (KTManagedObjectContext *)managedObjectContext
{
	return (KTManagedObjectContext *)[myDelegateOwner managedObjectContext];
}

- (KTMediaManager *)mediaManager { return [[self delegateOwner] mediaManager]; }

//- (KTOldMediaManager *)oldMediaManager
//{
//	return [myDelegateOwner oldMediaManager];
//}

- (NSMutableDictionary *)pluginProperties {	return [[self delegateOwner] pluginProperties]; }

- (NSUndoManager *)undoManager { return [[self delegateOwner] undoManager]; }

- (BOOL)lockContextIfNeeded
{
	LOG((@"lockContextIfNeeded is deprecated -- who's calling me?"));
	return [myDelegateOwner lockContextIfNeeded];
}

- (void)unlockContextIfNeeded:(BOOL)didLock
{
	LOG((@"unlockContextIfNeeded is deprecated -- who's calling me?"));
	[myDelegateOwner unlockContextIfNeeded:didLock];
}

- (KTPage *)page;
{
	// Get owner of this delegate
	id container = [self delegateOwner];
	
	// Try to get out of pagelet to page
	if ([container isKindOfClass:[KTPagelet class]])
	{
		container = [container page];
	}
	
	// At this point we should have a page
	OBASSERTSTRING([container isKindOfClass:[KTPage class]], @"unable to get page from a KTAbstractPluginDelegate");
	return container;
}

// We return "id" since it's easier to bind methods to an "id"
- (id)delegateOwner
{
	return myDelegateOwner;
}

- (void)setDelegateOwner:(id)anObject
{
	[anObject retain];
	[myDelegateOwner release];
	myDelegateOwner = anObject;
}

#pragma mark content change propagation

/*! when a page receives a notification that its content has changed we ask the
page's delegate which properties propagate up and down the heirachy of pages */
- (NSArray *)propertiesPropagatingToParent
{
	return [NSArray array];
}

- (NSArray *)propertiesPropagatingToChildren
{
	return [NSArray array];
}

#pragma mark media ref management

- (NSArray *)reservedMediaRefNames
{
	return [NSArray array];
}

@end

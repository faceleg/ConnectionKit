//
//  KTAbstractPluginDelegate.m
//  KTComponents
//
//  Created by Terrence Talbot on 6/25/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTAbstractPluginDelegate.h"

#import "KTAbstractElement+Internal.h"
#import "KTDocument.h"
#import "KTDocWindowController.h"
#import "KTPage.h"
#import "SVHTMLTemplateParser.h"

#import "NSManagedObject+KTExtensions.h"

#import "Debug.h"


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

- (NSManagedObjectContext *)managedObjectContext
{
	return [myDelegateOwner managedObjectContext];
}

- (KTMediaManager *)mediaManager { return [[self delegateOwner] mediaManager]; }

- (NSUndoManager *)undoManager
{
    return [[[self delegateOwner] managedObjectContext] undoManager];
}

- (KTPage *)page;
{
	// Get owner of this delegate
	id container = [self delegateOwner];
	
    if ([container isKindOfClass:NSClassFromString(@"SVContentObject")])
    {
        container = [container valueForKeyPath:@"container.pagelet.sidebar.page"];
    }
    
	// At this point we should have a page
	if (container)
    {
        OBPOSTCONDITION([container isKindOfClass:[KTPage class]]);
    }
    
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

@end

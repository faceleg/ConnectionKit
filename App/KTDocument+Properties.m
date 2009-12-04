//
//  KTDocument+Properties.m
//  Marvel
//
//  Created by Terrence Talbot on 4/6/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTDocument.h"

#import "Debug.h"

#import "KTDocWindowController.h"
#import "KTSite.h"
#import "KTHTMLInspectorController.h"
#import "KTStalenessManager.h"

#import "NSArray+Karelia.h"
#import "NSIndexSet+Karelia.h"
#import "NSObject+Karelia.h"


@interface KTDocument (PropertiesPrivate)
- (void)updateDefaultDocumentProperty:(NSString *)key;
@end


#pragma mark -


@implementation KTDocument (Properties)

#pragma mark -

/*  We store the thread the document was intialised on so that threading-critical operation
 *  like saves can assert that they're being run on the right thread. You can change this thread
 *  using -setThread, but this shouldn't generally be needed.
 *
 *  Normal documents are on the main thread, but data migration docs work in the background.
 */

- (NSThread *)thread { return _thread; }

- (void)setThread:(NSThread *)thread
{
    [thread retain];
    [_thread release];
    _thread = thread;
}

#pragma mark -
#pragma mark Managers

- (KTMediaManager *)mediaManager
{
	return myMediaManager;
}

#pragma mark -
#pragma mark Other

- (KTSite *)site { return _site; }

- (void)setSite:(KTSite *)site
{
    [_site setDocument:nil];    // Disassociate ourself from the site
    
    [site retain];
    [_site release];
    _site = site;
    
    [_site setDocument:self];
}

#pragma mark -
#pragma mark Publishing

- (void)setHTMLInspectorController:(KTHTMLInspectorController *)anHTMLInspectorController
{
    [anHTMLInspectorController retain];
    [myHTMLInspectorController release];
    myHTMLInspectorController = anHTMLInspectorController;
}

- (KTHTMLInspectorController *)HTMLInspectorControllerWithoutLoading	// lazily instantiate
{
	return myHTMLInspectorController;
}

- (KTHTMLInspectorController *)HTMLInspectorController	// lazily instantiate
{
	if ( nil == myHTMLInspectorController )
	{
		KTHTMLInspectorController *controller = [[[KTHTMLInspectorController alloc] init] autorelease];
		[self setHTMLInspectorController:controller];
		[self addWindowController:controller];
	}
	return myHTMLInspectorController;
}

#pragma mark -
#pragma mark Document Display Properties

- (BOOL)showDesigns
{
	return myShowDesigns;
}

- (void)setShowDesigns:(BOOL)value
{
	myShowDesigns = value;
}

- (BOOL)displaySiteOutline { return myDisplaySiteOutline; }

- (void)setDisplaySiteOutline:(BOOL)value
{
	myDisplaySiteOutline = value;
	[self updateDefaultDocumentProperty:@"displaySiteOutline"];
}

- (BOOL)displayStatusBar { return myDisplayStatusBar; }

- (void)setDisplayStatusBar:(BOOL)value
{
	myDisplayStatusBar = value;
	[self updateDefaultDocumentProperty:@"displayStatusBar"];
}

- (BOOL)displayEditingControls { return myDisplayEditingControls; }

- (void)setDisplayEditingControls:(BOOL)value
{
	myDisplayEditingControls = value;
	[self updateDefaultDocumentProperty:@"displayEditingControls"];
}

- (BOOL)displaySmallPageIcons { return myDisplaySmallPageIcons; }

- (void)setDisplaySmallPageIcons:(BOOL)aSmall
{
	myDisplaySmallPageIcons = aSmall;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KTDisplaySmallPageIconsDidChange"
														object:self];
														
	[self updateDefaultDocumentProperty:@"displaySmallPageIcons"];
}

- (BOOL)displayCodeInjectionWarnings { return myDisplayCodeInjectionWarnings; }

- (void)setDisplayCodeInjectionWarnings:(BOOL)flag
{
	myDisplayCodeInjectionWarnings = flag;
	[self updateDefaultDocumentProperty:@"displayCodeInjectionWarnings"];
}

#pragma mark support

/*	Support method for whenever the user changes a view property of the document.
 *	We write a copy of the last used properties out to the defaults so that new documents can use them.
 */
- (void)updateDefaultDocumentProperty:(NSString *)key
{
	NSDictionary *existingProperties =
		[[NSUserDefaults standardUserDefaults] objectForKey:@"defaultDocumentProperties"];
	
	NSMutableDictionary *updatedProperties;
	if (existingProperties)
	{
		updatedProperties = [NSMutableDictionary dictionaryWithDictionary:existingProperties];
		[updatedProperties setObject:[self valueForKey:key] forKey:key];
	}
	else
	{
		updatedProperties = [NSDictionary dictionaryWithObject:[self valueForKey:key] forKey:key];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:updatedProperties forKey:@"defaultDocumentProperties"];
}

/*	Generally this method is used when saving the document.
 *	We don't want manage these view properties in the model normally since they would be affected by undo/redo.
 *	Instead, they are kept within KTDocument and then only written out at save-time. If the user
 *  happens to hit undo and change the property, it is ignored.
 */
- (void)copyDocumentDisplayPropertiesToModel
{
	// Source Outline width
	float width = 99;	// TODO: Get the split view position
	[[self site] setInteger:width forKey:@"sourceOutlineSize"];
	
	
	// Icon size
	[[self site] setBool:[self displaySmallPageIcons] forKey:@"displaySmallPageIcons"];
	
	
	// Window size
	NSWindow *window = [[[self windowControllers] firstObjectKS] window];
	if (window)
	{
		[[self site] setDocWindowContentRect:[window contentRectForFrameRect:[window frame]]];
	}
}

#pragma mark -
#pragma mark *valueForKey: support

- (id)wrappedInheritedValueForKey:(NSString *)aKey
{
	OFF((@"WARNING: wrappedInheritedValueForKey: %@ is being called on KTDocument -- is this a property stored in defaults?", aKey));
    id result = [[self site] valueForKey:aKey];
	if ( nil == result )
	{
		result = [[NSUserDefaults standardUserDefaults] objectForKey:aKey];
		if ( nil != result )
		{
			// for now, we're going to specialize support for known entities
			// in the model that we want to be inheritied.
			KTSite *site = [self site];
//				[site lockPSCAndMOC];
			[site setPrimitiveValue:result forKey:aKey];
//				[self refreshObjectInAllOtherContexts:(KTManagedObject *)site];
//				[site unlockPSCAndMOC];
		}
	}
	return result;
}

- (void)setWrappedInheritedValue:(id)aValue forKey:(NSString *)aKey
{
	OFF((@"WARNING: setWrappedInheritedValue:forKey: %@ is being called on KTDocument -- is this a property stored in defaults?", aKey));

	[[self site] setValue:aValue forKey:aKey];
	
	// we only want to be storing property values in defaults
	// for now, we're going to specialize support for known entities
	// in the model that we want to be inheritied.
	id value = aValue;
	if ( [aKey isEqualToString:@"hostProperties"] )
	{
		value = [value dictionary]; // convert KTStoredSet to NSDictionary
	}
	[[NSUserDefaults standardUserDefaults] setObject:value forKey:aKey];
}

@end

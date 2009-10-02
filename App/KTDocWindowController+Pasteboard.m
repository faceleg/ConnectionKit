//
//  KTDocWindowController+Pasteboard.m
//  Marvel
//
//  Created by Terrence Talbot on 1/1/06.
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//

#import "KTDocWindowController.h"

#import "Debug.h"
#import "KT.h"
#import "KTAppDelegate.h"
#import "KTDocSiteOutlineController.h"
#import "KTDocument.h"
#import "KTPage.h"
#import "Elements+Pasteboard.h"
#import "KTPasteboardArchiving.h"
#import "KSSilencingConfirmSheet.h"

#import "NSArray+Karelia.h"
#import "NSArray+KTExtensions.h"
#import "NSIndexSet+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSOutlineView+KTExtensions.h"
#import "NSThread+Karelia.h"


@interface KTDocWindowController ( Pasteboard_Private )
- (void)copyPagelets:(NSArray *)thePages toPasteboard:(NSPasteboard *)aPboard;

- (NSArray *)pastePagesFromPasteboard:(NSPasteboard *)aPboard toParent:(KTPage *)aParent keepingUniqueID:(BOOL)aFlag;
- (NSArray *)pastePagesFromArchive:(NSArray *)archive toParent:(KTPage *)aParent;
- (NSArray *)pastePageletsFromPasteboard:(NSPasteboard *)aPboard toPage:(KTPage *)aPage keepingUniqueID:(BOOL)aFlag;

- (void)removePages:(NSArray *)anArray fromContext:(NSManagedObjectContext *)aContext;
- (void)removePagelets:(NSArray *)anArray fromContext:(NSManagedObjectContext *)aContext;
- (void)actuallyDeletePages:(NSDictionary *)aContext;
@end


#pragma mark -


// NB: a lot of this code follows the same pattern for both pages and pagelets but
// is currently separated into different methods for easier debugging/understandability

@implementation KTDocWindowController ( Pasteboard )

// these pasteboards are used for cut/copy/paste of pagelets
NSString *kKTCopyPageletsPasteboard = @"KTCopyPageletsPasteboard";

#pragma mark -
#pragma mark Copy

- (IBAction)copy:(id)sender
{
    if ( nil != [self selectedPagelet] )
	{
		[self copyPagelets:sender];
	}
	else if ([[[[self siteOutlineViewController] pagesController] selectionIndexes] count] > 0)
	{
		[self copyPages:sender];
	}
}

- (IBAction)copyViaContextualMenu:(id)sender
{
	NSString *selectionClassName = [[sender representedObject] valueForKey:kKTSelectedObjectsClassNameKey];
	if ( nil != selectionClassName )
	{
		if ( [selectionClassName isEqualToString:[KTPagelet className]] )
		{
			[self copyPagelets:sender];
		}
		else if ( [selectionClassName isEqual:[KTPage className]] )
		{
			[self copyPages:sender];
		}
		else
		{
			LOG((@"copyViaContextualMenu: don't know how to copy contextual selection!"));
		}		
	}
	else
	{
		LOG((@"copyViaContextualMenu: no selectionClassName!"));
	}
}

// copy selected pages
- (IBAction)copyPages:(id)sender
{
    NSArray *selectedPages = [[[self siteOutlineViewController] pagesController] selectedObjects];
	if ([sender isKindOfClass:[NSMenuItem class]] && (nil != [sender representedObject]))
    {
        // copy was sent from a contextual menuitem, get the selection from the context
        id context = [sender representedObject];
        selectedPages = [context valueForKey:kKTSelectedObjectsKey];
    }
    
    OBASSERTSTRING((nil != selectedPages), @"selectedPages cannot be nil.");
    OBASSERTSTRING([selectedPages isKindOfClass:[NSArray class]], @"selectedPages must be an array.");
        
	if ([selectedPages count] > 0)
    {
        // Package up the selected page(s) (children included)
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
		[pboard declareTypes:[NSArray arrayWithObjects:kKTPagesPboardType, nil] owner:self];
        
        NSArray *topLevelPages = [selectedPages parentObjects];
		NSArray *pasteboardReps = [topLevelPages valueForKey:@"pasteboardRepresentation"];
		[pboard setData:[NSKeyedArchiver archivedDataWithRootObject:pasteboardReps] forType:kKTPagesPboardType];
    }
}

- (void)copyPagelets:(id)sender
{
	NSArray *selectedPagelets = nil;
    
    if ( [sender isKindOfClass:[NSMenuItem class]] && (nil != [sender representedObject]) )
    {
        // cut was sent from a contextual menuitem, get the selection from the context
        id selection = [[sender representedObject] valueForKey:kKTSelectedObjectsKey];
		if ( [selection isKindOfClass:[NSArray class]] )
		{
			selectedPagelets = [[selection mutableCopy] autorelease];
		}
    }
    else
    {
        selectedPagelets = [NSArray arrayWithObject:[self selectedPagelet]];
    }
    
	if ( [selectedPagelets count] > 0 )
	{
        // we declare numerous types so that plugin delegates can copy arbitrary data to pboard
		NSPasteboard *pboard = [NSPasteboard pasteboardWithName:kKTCopyPageletsPasteboard];
		[pboard declareTypes:[NSArray arrayWithObjects:kKTPagesPboardType, NSFileContentsPboardType, NSHTMLPboardType, NSPostScriptPboardType, NSRTFPboardType, NSRTFDPboardType, NSStringPboardType, NSTIFFPboardType, nil] owner:self];
        
		// copy to pboard
		[self copyPagelets:selectedPagelets toPasteboard:pboard];
	}
}

- (void)copyPagelets:(NSArray *)thePagelets toPasteboard:(NSPasteboard *)aPboard
{
    // package up the selected pagelet(s)
    NSArray *pasteboardReps = [thePagelets valueForKey:@"pasteboardRepresentation"];
    [aPboard setData:[NSKeyedArchiver archivedDataWithRootObject:pasteboardReps] forType:kKTPageletsPboardType];
}

#pragma mark -
#pragma mark Cut

// for now, we only cut/copy/paste/delete/duplicate a single selectedPagelet at a time

- (IBAction)cut:(id)sender
{
	if ( nil != [self selectedPagelet] )
	{
		[self cutPagelets:sender];
	}
	else if ([[[[self siteOutlineViewController] pagesController] selectionIndexes] count] > 0)
	{
		[self cutPages:sender];
	}
}

- (IBAction)cutViaContextualMenu:(id)sender
{
	NSString *selectionClassName = [[sender representedObject] valueForKey:kKTSelectedObjectsClassNameKey];
	if ( nil != selectionClassName )
	{
		if ( [selectionClassName isEqualToString:[KTPagelet className]] )
		{
			[self cutPagelets:sender];
		}
		else if ( [selectionClassName isEqualToString:[KTPage className]] )
		{
			[self cutPages:sender];
		}
		else
		{
			LOG((@"cutViaContextualMenu: don't know how to cut contextual selection!"));
		}		
	}
	else
	{
		LOG((@"cutViaContextualMenu: no selectionClassName!"));
	}
}

// cut selected pages (copy and then remove from parents)
- (IBAction)cutPages:(id)sender
{
	// Figure out the selection
	NSArray *selectedPages = [[[self siteOutlineViewController] pagesController] selectedObjects];
	if ( [sender isKindOfClass:[NSMenuItem class]] && (nil != [sender representedObject]) )
    {
        // cut was sent from a contextual menuitem, get the selection from the context
        selectedPages = [[sender representedObject] valueForKey:kKTSelectedObjectsKey];
    }
    
	
	// We should never get here if the root page is in the selection
    OBASSERTSTRING((nil != selectedPages), @"selectedPages cannot be nil.");
    OBASSERTSTRING([selectedPages isKindOfClass:[NSArray class]], @"selectedPages must be an array.");
    OBASSERTSTRING(![selectedPages containsObject:[[[self document] site] root]], @"Cannot cut the home page");
	
	
	// Copy to the clipboard
	[self copy:sender];
	
	
	// Delete the selection
	[self actuallyDeletePages:nil];
}

- (void)removePages:(NSArray *)anArray fromContext:(NSManagedObjectContext *)aContext
{
	// we break this out into a separate method, currently, because during cutPages:
	// we have to mark stale and then copy to the pboard before we delete the pages
	// so we can't do it inside one enumeration like -actuallyDeletePages:
	NSEnumerator *e = [anArray objectEnumerator];
	KTPage *page = nil;
	while ( page = [e nextObject] )
	{
		KTPage *parent = [page parent];
		[parent removePage:page];
		[aContext deleteObject:page];
	}
	
	[aContext processPendingChanges];
	LOG((@"removed a save here, is it still needed?"));
//	[[self document] saveContext:aContext onlyIfNecessary:NO];
}

- (IBAction)cutPagelets:(id)sender
{
	// currently only one pagelet at a time is selectable
	
	// determine selected pagelets, either selected in document or via sender
	NSArray *selectedPagelets = nil;
    
    if ( [sender isKindOfClass:[NSMenuItem class]] && (nil != [sender representedObject]) )
    {
        // cut was sent from a contextual menuitem, get the selection from the context
        id selection = [[sender representedObject] valueForKey:kKTSelectedObjectsKey];
		if ( [selection isKindOfClass:[NSArray class]] )
		{
			selectedPagelets = [[selection mutableCopy] autorelease];
		}
    }
    else
    {
        selectedPagelets = [NSArray arrayWithObject:[self selectedPagelet]];
    }
    
	if ( [selectedPagelets count] > 0 )
	{
        // we declare numerous types so that plugin delegates can copy arbitrary data to pboard
		NSPasteboard *pboard = [NSPasteboard pasteboardWithName:kKTCopyPageletsPasteboard];
		[pboard declareTypes:[NSArray arrayWithObjects:kKTPagesPboardType, NSFileContentsPboardType, NSHTMLPboardType, NSPostScriptPboardType, NSRTFPboardType, NSRTFDPboardType, NSStringPboardType, NSTIFFPboardType, nil] owner:self];
        
		// copy to pboard
		[self copyPagelets:selectedPagelets toPasteboard:pboard];
		
		//stale the page they belong to
		NSEnumerator *e = [selectedPagelets objectEnumerator];
		KTPagelet *cur;
		
		while (cur = [e nextObject])
		{
			if ([cur boolForKey:@"shouldPropagate"])
			{
				////LOG((@"~~~~~~~~~ %@ calls markStale:kStaleFamily on '%@' because pagelet's page is marked as shouldPropagate", NSStringFromSelector(_cmd), [[cur page] titleText]));
				//[[cur page] markStale:kStaleFamily];
				break; // only need to propagate the once.
			}
			else
			{
				////LOG((@"~~~~~~~~~ %@ ....", NSStringFromSelector(_cmd)));
				//[[cur page] markStale:kStalePage];
			}
		}
		
		// remove from page/context
		[self removePagelets:selectedPagelets fromContext:[[self document] managedObjectContext]];
		LOG((@"removed a save here, is it still needed?"));
//		[[self document] saveContext:[[self document] managedObjectContext]];
	}
}

- (void)removePagelets:(NSArray *)pagelets fromContext:(NSManagedObjectContext *)aContext
{
	//[aContext lockPSCAndSelf];
	
	NSEnumerator *e = [pagelets objectEnumerator];
	KTPagelet *pagelet = nil;
	while ( pagelet = [e nextObject] )
	{
		[aContext deleteObject:pagelet];    // THIS IS A BAD IDEA. INSTEAD, ASK THE PARENT TO DELETE THE PAGELET
	}
	
	[aContext processPendingChanges];
	LOG((@"removed a save here, is it still needed?"));
//	[[self document] saveContext:aContext onlyIfNecessary:NO];
	
	//[aContext unlockPSCAndSelf];
}

#pragma mark -
#pragma mark Paste

- (IBAction)paste:(id)sender
{
    // looks at what's on pboard before deciding what to paste
    if ( [self canPastePagelets] )
    {
		[self pastePagelets:sender];
    }
    else if ( [self canPastePages] )
    {
		[self pastePages:sender];
    }
}

- (IBAction)pasteViaContextualMenu:(id)sender
{
	NSString *selectionClassName = [[sender representedObject] valueForKey:kKTSelectedObjectsClassNameKey];
	if ( nil != selectionClassName )
	{
		if ( [selectionClassName isEqual:[KTPagelet className]] )
		{
			[self pastePagelets:sender];
		}
		else if ( [selectionClassName isEqual:[KTPage className]] )
		{
			[self pastePages:sender];
		}
		else
		{
			LOG((@"pasteViaContextualMenu: don't know how to paste contextual selection!"));
		}		
	}
	else
	{
		LOG((@"pasteViaContextualMenu: no selectionClassName!"));
	}
}

// creates pages from data on pboard and add as children of selected parent
// paste should validate only if there is one selectedPage and it is a collection
- (IBAction)pastePages:(id)sender
{
    KTPage *selectedPage = nil;
    
    if ( [sender isKindOfClass:[NSMenuItem class]] && (nil != [sender representedObject]) )
    {
        // paste was sent from a contextual menuitem, get the selection from the context
        id context = [sender representedObject];
        id selection = [context valueForKey:kKTSelectedObjectsKey];
        OBASSERTSTRING([selection isKindOfClass:[NSArray class]], @"selection should be an array.");
        selectedPage = [selection objectAtIndex:0];
    }
    else
    {
        selectedPage = [[[[self siteOutlineViewController] pagesController] selectedObjects] objectAtIndex:0];
    }
    
    // if we haven't selected a collection, use its parent
	if ( ![selectedPage isCollection] )
	{
		selectedPage = [selectedPage parent];
	}
        
    if ( nil != selectedPage )
    {
        // paste pages
        NSArray *pastedPages = [self pastePagesFromPasteboard:[NSPasteboard generalPasteboard] toParent:selectedPage keepingUniqueID:NO];
        
        // Update the undo menu title
        if ([pastedPages count] == 1)
        {
			[[[self document] undoManager] setActionName:NSLocalizedString(@"Paste Page", "Paste Page MenuItem")];
		}
		else if ([pastedPages count] > 1)
		{
			[[[self document] undoManager] setActionName:NSLocalizedString(@"Paste Pages", "Paste Pages MenuItem")];
		}
    }
    else
    {
        LOG((@"would like to paste pages, but there's no selectedPage to paste to!"));
    }
}

/* returns array of newly pasted pages */
- (NSArray *)pastePagesFromPasteboard:(NSPasteboard *)aPboard toParent:(KTPage *)aParent keepingUniqueID:(BOOL)aFlag
{
	NSMutableArray *result = [NSMutableArray array];
	
    NSString *type = nil;
    type = [aPboard availableTypeFromArray:[NSArray arrayWithObject:kKTPagesPboardType]];
    
    if ( [type length] > 0 )
    {
        @try	// Just in case there's any reall screwy data on the pasteboard
        {
            NSData *data = [aPboard dataForType:kKTPagesPboardType];
            if ([data length] > 0)
            {
				NSArray *archivedPages = [NSKeyedUnarchiver unarchiveObjectWithData:data];
				[self pastePagesFromArchive:archivedPages toParent:aParent];
            }
            else
            {
                LOG((@"would like to paste pages, but there's nothing on the pasteboard!"));
            }
        }
        @catch (NSException *exception)
        {
            [NSApp reportException:exception];
        }
    }
    else
    {
        LOG((@"expecting to paste pages, but KTPagesPboardType is not on the pboard!"));
    }
	

	return [NSArray arrayWithArray:result];
}

- (NSArray *)pastePagesFromArchive:(NSArray *)archive toParent:(KTPage *)aParent
{
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:[archive count]];
	
    NSEnumerator *archivedPagesEnumerator = [archive objectEnumerator];
	NSDictionary *anArchivedPage;
	while (anArchivedPage = [archivedPagesEnumerator nextObject])
	{
		KTPage *page = [KTPage pageWithPasteboardRepresentation:anArchivedPage parent:aParent];
		if (page)
		{
			[result addObject:page];
		}
	}
	
	return [NSArray arrayWithArray:result];
}

- (BOOL)canPastePages
{
	// check the general pasteboard to see if there are any pages on it
	BOOL result = [[[NSPasteboard generalPasteboard] types] containsObject:kKTPagesPboardType];
	return result;
}

- (IBAction)pastePagelets:(id)sender
{
    KTPage *selectedPage = nil;
    
    if ( [sender isKindOfClass:[NSMenuItem class]] && (nil != [sender representedObject]) )
    {
        // paste was sent from a contextual menuitem, get the selection from the context
        id context = [sender representedObject];
        id selection = [context valueForKey:kKTSelectedObjectsKey];
        OBASSERTSTRING([selection isKindOfClass:[NSArray class]], @"selection should be an array.");
        selectedPage = [selection objectAtIndex:0];
    }
    else
    {
        selectedPage = [[[[self siteOutlineViewController] pagesController] selectedObjects] objectAtIndex:0];
    }
    
    if ( [selectedPage isKindOfClass:[KTPage class]] )
    {
        BOOL canPaste = ([selectedPage includeSidebar] || [selectedPage includeCallout]);
        if ( canPaste )
        {
            // paste
            NSArray *pastedPagelets = [self pastePageletsFromPasteboard:[NSPasteboard pasteboardWithName:kKTCopyPageletsPasteboard] toPage:selectedPage keepingUniqueID:NO];
            
            // (re)label undo
            if ( [pastedPagelets count] > 0 )
            {
                if ( [pastedPagelets count] > 1 )
                {
                    [[[self document] undoManager] setActionName:NSLocalizedString(@"Paste Pagelets", "Paste Pagelets MenuItem")];
                }
                else
                {
                    [[[self document] undoManager] setActionName:NSLocalizedString(@"Paste Pagelet", "Paste Pagelet MenuItem")];
                }
				//stale the page they belong to
				NSEnumerator *e = [pastedPagelets objectEnumerator];
				KTPagelet *cur;
				
				while (cur = [e nextObject])
				{
					if ([cur boolForKey:@"shouldPropagate"])
					{
						////LOG((@"~~~~~~~~~ %@ calls markStale:kStaleFamily on '%@' because pagelet is marked as shouldPropagate", NSStringFromSelector(_cmd), [[cur page] titleText]));
						//[[cur page] markStale:kStaleFamily];
						break; // only need to propagate the once.
					}
					else
					{
						////LOG((@"~~~~~~~~~ %@ ....", NSStringFromSelector(_cmd)));
						//[[cur page] markStale:kStalePage];
					}
				}
            }
            
        }
    }
    else
    {
        LOG((@"would like to paste pagelets, but there's no selectedPage to paste to!"));
    }    
}

- (NSArray *)pastePageletsFromPasteboard:(NSPasteboard *)aPboard toPage:(KTPage *)aPage keepingUniqueID:(BOOL)aFlag
{

	NSMutableArray *result = [NSMutableArray array];
    
    NSString *type = nil;
    type = [aPboard availableTypeFromArray:[NSArray arrayWithObject:kKTPageletsPboardType]];
    
    if ([type length] > 0)
    {
        @try	// Just in case there's any reall screwy data on the pasteboard
        {
			NSData *data = [aPboard dataForType:kKTPageletsPboardType];
			NSArray *pasteboardReps = [NSKeyedUnarchiver unarchiveObjectWithData:data];
			
			if (pasteboardReps && [pasteboardReps count] > 0)
			{
                NSEnumerator *e = [pasteboardReps objectEnumerator];
                NSDictionary *anArchivedPagelet;
                while (anArchivedPagelet = [e nextObject])
                {
                    KTPagelet *pagelet = [KTPagelet pageletWithPasteboardRepresentation:anArchivedPagelet page:aPage];
                    
                    if ( nil != pagelet )
                    {
                        [result addObject:pagelet];
                    }
                    else
                    {
                        LOG((@"would like to paste pagelets, but unable to create pagelet in this context!"));
                    }
                }
            }
            else
            {
                LOG((@"would like to paste pagelets, but there's nothing on the pasteboard!"));
            }
        }
        @catch (NSException *exception)
        {
            [NSApp reportException:exception];
        }
    }
    else
    {
        LOG((@"expecting to paste pagelets, but KTPageletsPboardType is not on the pboard!"));
    }
	

	return [NSArray arrayWithArray:result];
}

- (BOOL)canPastePagelets
{
	// check the pagelets pasteboard to see if there are any pagelets on it
	NSPasteboard *pboard = [NSPasteboard pasteboardWithName:kKTCopyPageletsPasteboard];
	BOOL hasPagelets = [kKTPageletsPboardType isEqualToString:[pboard availableTypeFromArray:[NSArray arrayWithObject:kKTPageletsPboardType]]];
	if ( hasPagelets )
	{
		return YES;
	}
    else
    {
        return NO;
    }
}

#pragma mark delete

- (IBAction)deleteViaContextualMenu:(id)sender
{
    id selectionClassName = [[sender representedObject] valueForKey:kKTSelectedObjectsClassNameKey];
    if ( [selectionClassName isEqualToString:[KTPage className]] )
    {
        [self deletePages:sender];
    }
    else if ( [selectionClassName isEqualToString:[KTPagelet className]] )
    {
        [self deletePagelets:sender];
    } 
}

- (IBAction)deletePages:(id)sender
{
	// FIXME: figure out something global for leftDoubleQuote and rightDoubleQuote
	// the compiler won't allow these to be static, unfortunately
	// it would be a lot nicer if we could have one global declaration
	// for these unichars
	NSString *leftDoubleQuote = NSLocalizedString(@"\\U201C", "left double quote");
	NSString *rightDoubleQuote = NSLocalizedString(@"\\U201D", "right double quote");
	
	[[[self document] managedObjectContext] processPendingChanges];

	// this method carries through the idea that if there are multiple
    // selected pages, then selectedPage will be nil and selectedPages
    // will be an array of two or more pages
    KTPage *selectedPage = nil;
	NSMutableArray *selectedPages = nil;
    
    if ( [sender isKindOfClass:[NSMenuItem class]] && (nil != [sender representedObject]) )
    {
        // delete was sent from a contextual menuitem, get the selection from the context
        id context = [sender representedObject];
        id selection = [context valueForKey:kKTSelectedObjectsKey];
        OBASSERTSTRING([selection isKindOfClass:[NSArray class]], @"selection should be an array.");
        if ( [selection count] > 1 )
        {
            selectedPages = [[selection mutableCopy] autorelease];
        }
        else
        {
            selectedPage = [selection objectAtIndex:0];
        }        
    }
	else if ( [sender isKindOfClass:[NSPasteboard class]] )
	{
		NSDictionary *pboardData = [sender propertyListForType:kKTOutlineDraggingPboardType];
		if ( nil != pboardData )
		{
			NSArray *parentRows = [pboardData objectForKey:@"parentRows"];
			NSOutlineView *siteOutline = [[[self siteOutlineViewController] pagesController] siteOutline];
			selectedPages = [NSMutableArray arrayWithArray:[siteOutline itemsAtRows:[NSIndexSet indexSetWithArray:parentRows]]];
			
			switch ( [selectedPages count] )
			{
				case 0:
					selectedPage = nil;
					selectedPages = nil;
					break;
				case 1:
					selectedPage = [selectedPages objectAtIndex:0];
					selectedPages = nil;
					break;
				default:
					break;
			}
		}
	}
    else
    {
        selectedPages = [[[[[self siteOutlineViewController] pagesController] selectedObjects] mutableCopy] autorelease];
        selectedPage = [[[self siteOutlineViewController] pagesController] selectedPage];
    }
	
	if ( [selectedPages count] >= 1 )
	{
		NSMutableArray *deletedPages = [NSMutableArray array];
		
		unsigned int i;
		for ( i=0; i < [selectedPages count]; i++ )
		{
			KTPage *page = [selectedPages objectAtIndex:i];
			if ( [page isDeleted] )
			{
				[deletedPages addObject:page];
			}
		}
		
		[selectedPages removeObjectsInArray:deletedPages];
	}
	
	NSString *title = nil;
	NSString *message = nil;
	NSDictionary *context = nil;
	if ( (nil != selectedPage) && ![selectedPage isDeleted] )
	{
		if ( [selectedPage isCollection] )
		{
			if ( [selectedPage hasChildren] )
			{
				title = NSLocalizedString(@"Delete Collection", "Delete Collection Alert Title");
				message = [NSString stringWithFormat:NSLocalizedString(@"Do you really want to delete the collection named \\U201C%@\\U201D and all the pages it contains?",
																	   "Delete Collection with Pages Alert Message"), [selectedPage titleText]];
				context = [NSDictionary dictionaryWithObject:selectedPage forKey:@"selectedPage"];
			}
			else
			{
				title = NSLocalizedString(@"Delete Collection", "Delete Collection Alert Title");
				message = [NSString stringWithFormat:NSLocalizedString(@"Do you really want to delete the collection named \\U201C%@\\U201D ?",
																	   "Delete Collection without Pages Alert Message"), [selectedPage titleText]];
				context = [NSDictionary dictionaryWithObject:selectedPage forKey:@"selectedPage"];
			}
		}
		else
		{
			title = NSLocalizedString(@"Delete Page", "Delete Page Alert Title");
			message = [NSString stringWithFormat:NSLocalizedString(@"Do you really want to delete the page named \\U201C%@\\U201D ?",
																   "Delete Page Alert Message"), [selectedPage titleText]];
			context = [NSDictionary dictionaryWithObject:selectedPage forKey:@"selectedPage"];
		}
	}
	else if ( [selectedPages count] > 1 )
	{
		NSString *comma = NSLocalizedString(@",", "list separator: , in English");
		NSString *and = NSLocalizedString(@"and", "join conjunction: and in English");
		
		NSString *pageTitles = @"";
		if ( [selectedPages count] == 2 )
		{
			pageTitles = [pageTitles stringByAppendingFormat:@"%@%@%@ %@ %@%@%@", leftDoubleQuote, [[selectedPages objectAtIndex:0] titleText], rightDoubleQuote, and, leftDoubleQuote, [[selectedPages objectAtIndex:1] titleText], rightDoubleQuote];
		}
		else
		{
			unsigned int i;
			for ( i = 0; i < [selectedPages count]-1 ; ++i )
			{
				NSString *pageTitle = [[selectedPages objectAtIndex:i] titleText];
				pageTitles = [pageTitles stringByAppendingFormat:@"%@%@%@%@ ", leftDoubleQuote, pageTitle, rightDoubleQuote, comma];
			}
			NSString *lastPageTitle = [[selectedPages objectAtIndex:([selectedPages count]-1)] titleText];
			pageTitles = [pageTitles stringByAppendingFormat:@"%@ %@%@%@", and, leftDoubleQuote, lastPageTitle, rightDoubleQuote];
		}
		
		
		title = NSLocalizedString(@"Delete Pages", "Delete Pages Alert Title");
		message = [NSString stringWithFormat:NSLocalizedString(@"Do you really want to delete the pages named %@, and any pages they contain?",
															   "Delete Pages Alert Message"), pageTitles];
		context = [NSDictionary dictionaryWithObject:selectedPages forKey:@"selectedPages"];
	}
	else
	{
        LOG((@"-deletePages: no useful object(s) selected!"));
		return;
	}	
	
	[[self confirmWithWindow:[self window] 
				silencingKey:@"DeletePagesSilencingKey" 
				   canCancel:YES
					OKButton:NSLocalizedString(@"Delete", "Delete Button") 
					 silence:nil 
					   title:title 
					  format:message] actuallyDeletePages:[context retain]]; // we retain so dictionary survives event loop
// FIXME: what if if the message is cancelled, we have a leaking context, right? ("context" here is not a moc, but a dictionary)
}

- (void)actuallyDeletePages:(NSDictionary *)aContext
{	
	[aContext release]; // balancing retain in deletePages:
    
    
	// FIXME: we could do away with the context dictionay, since we're going off of selected pages,
	// but first test whether this is OK for deleting from a contextual menu
	
    NSSet *selectedPages = [NSSet setWithArray:[[[self siteOutlineViewController] pagesController] selectedObjects]];
	
    
    // The user shouldn't be able to try to delete root, but if so, beep and fail
    if ([selectedPages containsObject:[[[self document] site] root]])
    {
        NSBeep();
        return;
    }
    
	
	if ([selectedPages count] > 0)
	{		
        // Find the parents of all the pages to delete. This also has the effect of eliminating root
		// since it has no parent.
		NSSet *pageParents = [selectedPages valueForKey:@"parent"];
		
		// Remove the pages from their parents
		NSEnumerator *pagesEnumerator = [pageParents objectEnumerator];
		KTPage *aPageParent;
		while (aPageParent = [pagesEnumerator nextObject])
		{
			[aPageParent removePages:selectedPages];	// Far more efficient than calling -removePage: repetitively
		}
		
		// Delete the pages
		[[[self document] managedObjectContext] deleteObjectsInCollection:selectedPages];
		
		
		// label undo last
		if ([selectedPages count] == 1)
		{
			if ([[selectedPages anyObject] isCollection])
			{
				[[[self document] undoManager] setActionName:NSLocalizedString(@"Delete Collection", "Delete Collection MenuItem")];
			}
			else
			{
				[[[self document] undoManager] setActionName:NSLocalizedString(@"Delete Page", "Delete Page MenuItem")];
			}
		}
		else
		{
			[[[self document] undoManager] setActionName:NSLocalizedString(@"Delete Pages", "Delete Pages MenuItem")];
		}
	}

}

- (IBAction)deletePagelets:(id)sender
{
	OBASSERTSTRING([NSThread isMainThread], @"should be main thread");

	[[[self document] managedObjectContext] lock];

    // currently assumes there is only one pagelet to be deleted
    KTPagelet *selectedPagelet = nil;
    
    if ( [sender isKindOfClass:[NSMenuItem class]] && (nil != [sender representedObject]) )
    {
        // paste was sent from a contextual menuitem, get the selection from the context
        id context = [sender representedObject];
        id selection = [context valueForKey:kKTSelectedObjectsKey];
        OBASSERTSTRING([selection isKindOfClass:[NSArray class]], @"selection should be an array.");
        // we're only going to delete the first selected pagelet
        selectedPagelet = [selection objectAtIndex:0];
    }
    else
    {
        selectedPagelet = [self selectedPagelet];
    }
    
    if ( [selectedPagelet isKindOfClass:[KTPagelet class]] )
    {
        KTPage *selectedPage = [[[self siteOutlineViewController] pagesController] selectedPage];
        if ( [[selectedPagelet page] isEqual:selectedPage] )
        {		
            NSManagedObjectContext *context = [selectedPage managedObjectContext];
            
            // remove pagelet from the page
			[[selectedPagelet page] removePagelet:selectedPagelet];
			
            // delete it from the context
            LOG((@"deleting pagelet “%@” from context", [selectedPagelet valueForKey:@"pluginIdentifier"]));
            [context deleteObject:selectedPagelet];
            
            // close undo group
            [context processPendingChanges];
			
			// save
			LOG((@"removed a save here, is it still needed?"));
//			[[self document] saveContext:context onlyIfNecessary:NO];
            
            // change the selection to be the page
            [self setSelectedPagelet:nil];
            
            // update the inspector and reload the page
            [self postSelectionAndUpdateNotificationsForItem:selectedPage];
            
            // label undo
            [[[self document] undoManager] setActionName:NSLocalizedString(@"Delete Pagelet", "Delete Pagelet MenuItem")];
        }
    }
	
	[[[self document] managedObjectContext] unlock];
}

#pragma mark -
#pragma mark Duplicate

// duplicate does a copy/paste at once, within the same document, using a private pboard
// the trick here is that we need to use new uniqueIDs, new titles, etc.

- (IBAction)duplicate:(id)sender
{
	if ([self selectedPagelet])
	{
		[self duplicatePagelets:sender];
	}
	else if ([[[[self siteOutlineViewController] pagesController] selectionIndexes] count] > 0)
	{
		[self duplicateSelectedPages:sender];
	}
 }

- (IBAction)duplicateViaContextualMenu:(id)sender
{
	id selectionClassName = [[sender representedObject] valueForKey:kKTSelectedObjectsClassNameKey];
    if ( [selectionClassName isEqualToString:[KTPage className]] )
    {
        [self duplicateSelectedPages:sender];
    }
    else if ( [selectionClassName isEqualToString:[KTPagelet className]] )
    {
        [self duplicatePagelets:sender];
    } 
}

/*  Duplicates the selected pages in the Site Outline
 */
- (IBAction)duplicateSelectedPages:(id)sender
{
	// Figure out our selection
	NSArray *selectedPages = [[[self siteOutlineViewController] pagesController] selectedObjects];
    if ([sender isKindOfClass:[NSMenuItem class]] && (nil != [sender representedObject]) )
    {
        // Duplicate was sent from a contextual menuitem, get the selection from the context
        id context = [sender representedObject];
        id selection = [context valueForKey:kKTSelectedObjectsKey];
        OBASSERTSTRING([selection isKindOfClass:[NSArray class]], @"selection should be an array.");
        selectedPages = [[selection mutableCopy] autorelease];
    }
	
	
	// Don't allow duplicating root - Why not? Mike.
	if ([selectedPages count] == 0 || [selectedPages containsRoot])
    {
        NSBeep();
        return;
    }
    
    
    // Duplicate each page
    NSEnumerator *pagesEnumerator = [selectedPages objectEnumerator];
    KTPage *aPage;
    NSMutableArray *newPages = [[NSMutableArray alloc] initWithCapacity:[selectedPages count]];
    while (aPage = [pagesEnumerator nextObject])
    {
        [newPages addObject:[self duplicatePage:aPage]];
    }
    
    
    // Select the new pages
    [[[self siteOutlineViewController] pagesController] setSelectedObjects:newPages];
    [newPages release];
    
    
    // Label the Undo menu item
    if ([selectedPages count] > 1)
    {
        [[[self document] undoManager] setActionName:NSLocalizedString(@"Duplicate Pages", "Duplicate Pages MenuItem")];
    }
    else
    {
        [[[self document] undoManager] setActionName:NSLocalizedString(@"Duplicate Page", "Duplicate Page MenuItem")];
    }
}

- (IBAction)duplicatePagelets:(id)sender
{
    // currently assumes there is only one pagelet to be deleted
/*    
    KTPagelet *selectedPagelet = nil;
    
    if ( [sender isKindOfClass:[NSMenuItem class]] && (nil != [sender representedObject]) )
    {
        // paste was sent from a contextual menuitem, get the selection from the context
        id context = [sender representedObject];
        id selection = [context valueForKey:kKTSelectedObjectsKey];
        OBASSERTSTRING([selection isKindOfClass:[NSArray class]], @"selection should be an array.");
        // we're only going to duplicate the first selected pagelet
        selectedPagelet = [selection objectAtIndex:0];
    }
    else
    {
        selectedPagelet = [self selectedPagelet];
    }
    
    if ( [selectedPagelet isKindOfClass:[KTPagelet class]] )
    {
        KTPage *selectedPage = [[[self siteOutlineViewController] pagesController] selectedPage];
        if ( [[selectedPagelet page] isEqual:selectedPage] )
        {		
            // create a special pasteboard just for this document/operation
            NSPasteboard *duplicatePboard = [NSPasteboard pasteboardWithName:kKTDuplicatePageletsPasteboard];
            [duplicatePboard declareTypes:[NSArray arrayWithObject:kKTPageletsPboardType] owner:self];
            
            // copy pagelets
            [self copyPagelets:[NSArray arrayWithObject:selectedPagelet] toPasteboard:duplicatePboard];
            
            // paste back not keeping uniqueID
            NSArray *newPagelets = [self pastePageletsFromPasteboard:duplicatePboard toPage:selectedPage keepingUniqueID:NO];
            
            // we're done, clear the pasteboard
            [duplicatePboard releaseGlobally];
            
            if ( [newPagelets count] > 0 )
            {
                // reload the page, selected the newly added pagelet, and update the inspector 
                [self postSelectionAndUpdateNotificationsForItem:[newPagelets objectAtIndex:0]];
                
                // label undo
                [[[self document] undoManager] setActionName:NSLocalizedString(@"Duplicate Pagelet", "Duplicate Pagelet MenuItem")];              
            }
        }
    }
	else
	{
		LOG((@"-deletePagelets: no recognizable object selected!"));
	}*/
}

/*  Duplicates the specified page. Does NOT manage selection in the site outline. Returns the duplicate copy
 */
- (KTPage *)duplicatePage:(KTPage *)page
{
    OBPRECONDITION(page);
    OBPRECONDITION(![page isRoot]);
    
    
    id archive = [page pasteboardRepresentation];
    
    KTPage *parent = [page parent];
    KTPage *result = [KTPage pageWithPasteboardRepresentation:archive parent:parent];
    
    // For unordered collections, the duplicate should appear just after the original
    if ([parent collectionSortOrder] == KTCollectionUnsorted)
    {
        unsigned index = [[parent sortedChildren] indexOfObjectIdenticalTo:page] + 1;
        [result moveToIndex:index];
    }
    
    return result;
}

@end

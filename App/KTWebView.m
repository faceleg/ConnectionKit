//
//  KTWebView.m
//  Marvel
//
//  Created by Dan Wood on 8/11/04.
//  Copyright 2004 Biophony, LLC. All rights reserved.
//

/*
PURPOSE OF THIS CLASS/CATEGORY:
	Specialized WebView that Handle clicks and drag/drops

TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	Inherits WebView.
	Works with bundle manager to find drag sources.
	Works with WebView's delegates.
	Gets its click messages from KTDocWindow.

IMPLEMENTATION NOTES & CAUTIONS:
	We forward the click messages the WebView UIDelegate, so it's getting additional messages beyond the standard messages.

TO DO:
	Drag & Drop is mostly just test code at this point.

 */

#import <Sandvox.h>

#import "KTWebView.h"
#import "KTBundleManager.h"
#import "KTAppDelegate.h"
#import "KTDocWindowController.h"
#import "KTDocSiteOutlineController.h"


@class ImageSource;

/*
@interface NSArray(desc)
- (NSString *)PBDescription;
@end

@implementation NSArray(desc)
- (NSString *)PBDescription
{
	NSMutableString *b = [NSMutableString string];
	NSEnumerator *enumerator = [self objectEnumerator];
	NSString * anObject;

	while (anObject = [enumerator nextObject]) {
		if ([anObject hasPrefix:@"CorePasteboardFlavorType"])
			[b appendFormat:@"%@ %@ ",[anObject description], [anObject class]];
	}
	//
	return b;
}

@end
*/

@interface NSView ( WebHTMLViewHack )
-(BOOL) _canProcessDragWithDraggingInfo:(id)something;
@end


@implementation KTWebView

- (id)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	[self setMaintainsBackForwardList:NO];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(windowDidBecomeMain:)
												 name:NSWindowDidBecomeMainNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(windowDidResignMain:)
												 name:NSWindowDidResignMainNotification
											   object:nil];
	return self;
}

// window is not known yet so we can't observer on a particular window.
- (id)initWithCoder:(NSCoder *)aDecoder;
{
	self = [super initWithCoder:aDecoder];
	[self setMaintainsBackForwardList:NO];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(windowDidBecomeMain:)
												 name:NSWindowDidBecomeMainNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(windowDidResignMain:)
												 name:NSWindowDidResignMainNotification
											   object:nil];
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

// per Graham
- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)item
{
	SEL action = [item action];
	if ( action == @selector(toggleContinuousSpellChecking:) )
	{
		if ( [(NSObject *)item isKindOfClass:[NSMenuItem class]] )
		{
            NSMenuItem *menuItem = (NSMenuItem *)item;
            [menuItem setState:([self isContinuousSpellCheckingEnabled] ? NSOnState : NSOffState)];
        }
		
		// under what circumstances should this be NO? If the current selection isn't editable?
		// But continuous spell checking applies to the entire web view and not to the
		// current editable element. Perhaps this should be NO if the current document is an
		// external page or something that isn't a 'normal' page? But how can the WebView figure that out?
		return YES; 
	}
	
	return [super validateUserInterfaceItem:item];
}

- (IBAction)toggleContinuousSpellChecking:(id)sender
{
	[self setContinuousSpellCheckingEnabled:![self isContinuousSpellCheckingEnabled]];
}

- (void)windowDidBecomeMain:(NSNotification *)notification;
{
	if ([notification object] == [self window])
	{
		myWindowIsMain = YES;
	}
}

- (void)windowDidResignMain:(NSNotification *)notification;
{
	if ([notification object] == [self window])
	{
		myWindowIsMain = NO;
	}
}


- (void)registerForDraggedTypes:(NSArray *)newTypes
{

	NSMutableSet *collected = [NSMutableSet setWithSet:[[[NSApp delegate] bundleManager] setOfAllDragSourceAcceptedDragTypesForPagelets:YES]];
	[collected addObjectsFromArray:newTypes];

	[super registerForDraggedTypes:[collected allObjects]];
}

- (void)unregisterDraggedTypes
{
	NSLog(@"YIKES -- unregisterDraggedTypes");
	[super unregisterDraggedTypes];
}


- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	if ([[self window] attachedSheet]) return NSDragOperationNone;		// disallow drop when there's a sheet
   
	NSPasteboard *pboard;
    NSDragOperation sourceDragMask;
    sourceDragMask = [sender draggingSourceOperationMask];
    pboard = [sender draggingPasteboard];
	
	NSDragOperation result = [super draggingEntered:sender];

	// seems to return None no matter what?
	/*
	if (result == NSDragOperationNone)
	{
		NSLog(@"KTWebView draggingEntered NSDragOperationNone pboard types = %@",
			  [[pboard types] description]);
		
		// Override -- do a "copy" drag; we're copying something else in.
		result = NSDragOperationCopy;
		NSLog(@"KTWebView I'm handling draggingEntered --> %d", result);
	}
	else
	{
		NSLog(@"WebView it's handling draggingEntered --> %d", result);
		myHandlingDrag = NO;
	}
	 */
	return result;
}

/*
 if ( [[pboard types] containsObject:NSColorPboardType] ) {
	 if (sourceDragMask & NSDragOperationGeneric) {
		 return NSDragOperationGeneric;
	 }
 }
 if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
	 if (sourceDragMask & NSDragOperationLink) {
		 return NSDragOperationLink;
	 } else if (sourceDragMask & NSDragOperationCopy) {
		 return NSDragOperationCopy;
	 }
 }
 return NSDragOperationNone;
 */

// We do the drop ourselves; don't let WebView do it.
// Really what we'll do is dispatch to the page type and let it handle it.

/*
 
 
 OK, so now I can accept pretty much anything.  The only trick is knowing where *exactly* things dropped.
 I think I can also paste graphics and stuff OK.
 
 I just need an architecture for all of this and the plugins.
 
 How about clicking to select something?  Do I need to?
 
 I definitely need to show some indication of where the drop will take place.
 
 
 */



/*!	How to override intelligently? I don't know who's going to handle the drop...
*/
- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
	if ([[self window] attachedSheet]) return NSDragOperationNone;		// disallow drop when there's a sheet

	NSDragOperation result;
	

	result = [super draggingUpdated:sender];

	// NSLog(@"KTWebView draggingUpdated --> %d", result);	// LOTS OF LOGGING -- CAUTION!
	return result;
}

// - (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender // WebKit does nothing, returns YES

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	if ([[self window] attachedSheet]) return NSDragOperationNone;		// disallow drop when there's a sheet

	// Am I dragging into an editable block?  If so, call super
	BOOL draggingIntoEditableBlock = NO;
	
	WebFrameView *frameView = [[self mainFrame] frameView];
	NSView <WebDocumentView> *documentView = [frameView documentView];
	if ([documentView respondsToSelector:@selector(_canProcessDragWithDraggingInfo:)])
	{
		draggingIntoEditableBlock = [(id)documentView _canProcessDragWithDraggingInfo:sender];
	}
	else	// do the logic myself, though I don't quite have all the pieces.
	{
		// copied from -[WebHTMLView _canProcessDragWithDraggingInfo:]
		NSPoint point = [self convertPoint:[sender draggingLocation] fromView:nil];
		NSDictionary *element = [self elementAtPoint:point];
		if ([self isEditable] || [[element objectForKey:WebElementDOMNodeKey] isContentEditable])
		{
			if (/* _private->initiatedDrag && */ [[element objectForKey:WebElementIsSelectedKey] boolValue]) {
				// Can't drag onto the selection being dragged.
				draggingIntoEditableBlock = NO;
			}
			draggingIntoEditableBlock = YES;
		}
	}
	if (draggingIntoEditableBlock)
	{
        // ok, we're in an editable area
		
        NSPasteboard *pboard = [sender draggingPasteboard];

        // we're going to special case WebURLsWithTitlesPboardType
        // and, if present, handle it ourselves, otherwise pass to WebView
        if ( [[pboard types] containsObject:@"WebURLsWithTitlesPboardType"] 
             || [[pboard types] containsObject:NSURLPboardType] )
        {
            LOG((@"Dragged into editable block; DocWindowController is doing performDragOperation"));
            KTDocWindowController *controller = ((KTDocWindowController *)[self UIDelegate]);
            BOOL hyperlinked = [controller acceptDropOfURLsFromDraggingInfo:sender];
			// if it didn't work, let the super try to insert a picture.

			if (hyperlinked)
			{
				return YES;
			}

			// Now, see if it's an image file dragged in -- if so, allow webkit to handle it.
			// Otherwise we will ignore other URL types; we don't want allow dragging in other junk.
			
			NSURL *url = [NSURL URLFromPasteboard:pboard];
		
			if ( [[url scheme] isEqualToString:@"file"] )
			{
				NSString *UTI = [NSString UTIForFileAtPath:[url path]];
				if (![NSString UTI:UTI conformsToUTI:(NSString *)kUTTypeImage])
				{
					return NO;	// short-circuit -- don't allow drags of file non-image URLs!
				}
			}
        }
		
		// Fallback; let webkit take care of non-URL types like color
		return [super performDragOperation:sender];
	}
	//
	//
	//
	// Not dragging into editable text; try to perform drag otherwise.

	// Just handle first item for pagelet
    KTAbstractDataSource *bestSource = [KTAbstractDataSource highestPriorityDataSourceForDrag:sender index:0 isCreatingPagelet:YES];
    if ( nil == bestSource )
	{
		return NO;
	}
	
	NSMutableDictionary *dragDataDictionary = [NSMutableDictionary dictionary];
	[dragDataDictionary setValue:[sender draggingPasteboard] forKey:kKTDataSourcePasteboard];	// always include this!
	BOOL didPerformDrag = [bestSource populateDictionary:dragDataDictionary forPagelet:YES fromDraggingInfo:sender index:0];
	
	if ( !didPerformDrag )
	{
		return NO;
	}
	
	// Done with the drag
	[KTAbstractDataSource doneProcessingDrag];
	
	// If dragging into an image element, process it
	KTDocWindowController *controller = ((KTDocWindowController *)[self UIDelegate]);
	KTPage *selectedPage = [[controller siteOutlineController] selectedPage];
	KTDocument *theDocument = [selectedPage document];
	NSPoint location = [self convertPoint:[sender draggingLocation] fromView:nil];
	NSString *theID = nil;
	NSString *property = nil;
	KTAbstractPlugin *draggedItem = [controller selectableItemAtPoint:location itemID:&theID];
    if ( nil != [draggedItem delegate] )
    {
        LOG((@"KTWebView performDragOperation dest = %@", [[draggedItem delegate] class]));
    }
    else
    {
        LOG((@"KTWebView performDragOperation dest = %@", [draggedItem class]));
    }

	if (nil != theID)
	{
		NSArray *dashComponents = [theID componentsSeparatedByString:@"-"];
		if ([dashComponents count] > 2)
		{
			property = [dashComponents objectAtIndex:2];
		}
	}

	// Handle drag onto an image element
	
	if ([[bestSource className] isEqualToString:@"ImageSource"]		// Hack ... a better way of verify it's an image source?
		&& [[[draggedItem plugin] bundleIdentifier] isEqualToString:@"sandvox.ImageElement"])
	{
		LOG((@"Dragging into an image element"));
        [draggedItem willChangeValueForKey:@"media"];
		[draggedItem awakeFromDragWithDictionary:dragDataDictionary];
        [draggedItem didChangeValueForKey:@"media"];
		return YES;
	}
	
// TODO: handle drag of video onto a quicktime thing, too!  Somehow we have to intercept the drag from the QT view.
	
	// Handle drag onto a thumbnail (which summarizes a page)
	if ([[bestSource className] isEqualToString:@"ImageSource"]		// Hack ... a better way of verify it's an image source?
		&& [draggedItem isKindOfClass:[KTPage class]] 
		&& [property isEqualToString:@"image"])
	{
		LOG((@"Dragging into an a page thumbnail"));
		
		// see if this page has a thumbnail mediaRef
		KTMediaContainer *thumbRef = [(KTPage *)draggedItem thumbnail];
		if ( nil != thumbRef )
		{
			// if it's a placeholder, don't accept the drop

			{
				LOG((@"sorry, can't drop on a placeholder"));
				return NO;
			}
			
			// don't change the thumbref, just change the 
			// thumbnailData of the underlying media object
			//KTMediaFile *media = [thumbRef file];
            [selectedPage willChangeValueForKey:@"thumbnail"];
			//[media setThumbnailWithDataSourceDictionary:dragDataDictionary];
            [selectedPage didChangeValueForKey:@"thumbnail"];

			// Note: we are ignoring possible alt text clues in the dict.  Alt text of a thumbnail
			// comes from the page title it represents.  We may want to rethink that at some point.
		}
		else
		{
			// if we don't already have a mediaRef, don't allow dropping on the placeholder to create one
			return NO;
			
			// this page has no thumbnail as yet
			// we need to create a media object with thumbnail
			// and retain a mediaRef to it
			//KTMedia *thumbMedia = [KTMedia mediaWithDataSourceDictionary:dragDataDictionary
			//							insertIntoManagedObjectContext:[theDocument managedObjectContext]];
			//[thumbMedia setThumbnailFromMedia];
			//KTMediaRef *newThumbRef = [KTMediaRef retainMedia:thumbMedia name:@"thumbnail" owner:draggedItem];
			//[draggedItem setThumbnail:newThumbRef];
		}
				
//		id refetchedThumbnail = [draggedItem thumbnail];
//	LOG((@"refetchedThumbnail   = %@", refetchedThumbnail));
	
	
		return YES;
	}
	
	

	// If dragging into the site title, process it specially.   NOT VERY ENCAPSULATED CODE ... YUCK.
	NSDictionary *item = [self elementAtPoint:location];
	DOMNode *aNode = [item objectForKey:WebElementDOMNodeKey];
	
	if ([aNode respondsToSelector:@selector(idName)]
		&& [[((DOMHTMLElement *)aNode) idName] isEqualToString:@"logo"]
		&& [[bestSource className] isEqualToString:@"ImageSource"] )	// Hack ... a better way of verify it's an image source?
	{
		// Drag into site title ... this affects the document root
		/*
		KTPage *root = [theDocument root];
		
		KTMedia *headerImageMedia = [KTMedia mediaWithDataSourceDictionary:dragDataDictionary
									insertIntoManagedObjectContext:(KTManagedObjectContext *)[theDocument managedObjectContext]];
			
		KTMediaRef *headerImageRef = [KTMediaRef retainMedia:headerImageMedia 
														name:@"headerImage"
													   owner:root];
		//[[root master] setBannerImage:headerImageRef];
		*/
		NSString *altText = [dragDataDictionary objectForKey:kKTDataSourceTitle];
		if ( nil == altText )
		{
			NSFileManager *fm = [NSFileManager defaultManager];
			altText = [[fm displayNameAtPath:[dragDataDictionary valueForKey:kKTDataSourceFileName]] stringByDeletingPathExtension];
		}
		if (nil != altText )
		{
			[[[theDocument root] valueForKey:@"master"] setValue:altText forKey:@"headerImageDescription"];
		}
		
		[[self undoManager] setActionName:NSLocalizedString(@"Set Banner",@"action name for setting banner image")];

		return YES;
	}
	
	
	
	if (![selectedPage includeSidebar] && ![selectedPage includeCallout])
	{
		return NO;		// sorry, can't drag a onto a page without a sidebar or callout
	}
	
	NSString *theBundleIdentifier = [bestSource pageletBundleIdentifier];
	if (nil == theBundleIdentifier)
	{
		return NO;
	}

	NSBundle *theBundle = [[[[NSApp delegate] bundleManager] pluginWithIdentifier:theBundleIdentifier] bundle];
	if ( nil != theBundle )
	{
		[dragDataDictionary setObject:theBundle forKey:kKTDataSourceBundle];
	}
	else
	{
		LOG((@"error: datasource returned unknown bundle identifier: %@", theBundleIdentifier));
		return NO;
	}
	
	KTPagelet *pagelet = [KTPagelet pageletWithPage:selectedPage
							   dataSourceDictionary:dragDataDictionary];
	
	if ( nil != pagelet )
	{
		[controller insertPagelet:pagelet toSelectedItem:selectedPage];
	}
	return ( nil != pagelet );
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	[super concludeDragOperation:sender];
	LOG((@"KTWebView concludeDragOperation"));
}


/*!	Deal with mouse down.  Dispatched by KTDocWindow.
*/

- (void)singleClickAtCoordinates:(NSPoint)aPoint modifierFlags:(unsigned int)modifierFlags;
{
	if (myWindowWasMainBeforeClick
		&& [[self UIDelegate] respondsToSelector:@selector(webView:singleClickAtCoordinates:modifierFlags:)])
	{
		[([self UIDelegate]) webView:self singleClickAtCoordinates:aPoint modifierFlags:modifierFlags];
	}
}

- (void)doubleClickAtCoordinates:(NSPoint)aPoint modifierFlags:(unsigned int)modifierFlags;
{
	if (myWindowWasMainBeforeClick
		&& [[self UIDelegate] respondsToSelector:@selector(webView:doubleClickAtCoordinates:modifierFlags:)])
	{
		[([self UIDelegate]) webView:self doubleClickAtCoordinates:aPoint modifierFlags:modifierFlags];
	}
}

- (BOOL)earlySingleClickAtCoordinates:(NSPoint)aPoint modifierFlags:(unsigned int)modifierFlags;
{
	myWindowWasMainBeforeClick = myWindowIsMain;		// save this for later, so we'll know after activation if it was main
	BOOL result = YES;		// assume we can continue
	if (myWindowIsMain
		&& [[self UIDelegate] respondsToSelector:@selector(webView:earlySingleClickAtCoordinates:modifierFlags:)])
	{
		result = [([self UIDelegate]) webView:self earlySingleClickAtCoordinates:aPoint modifierFlags:modifierFlags];
	}
	return result;
}

- (BOOL)earlyDoubleClickAtCoordinates:(NSPoint)aPoint modifierFlags:(unsigned int)modifierFlags;
{
	BOOL result = YES;		// assume we can continue
	if (myWindowIsMain
		&& [[self UIDelegate] respondsToSelector:@selector(webView:earlyDoubleClickAtCoordinates:modifierFlags:)])
	{
		result = [([self UIDelegate]) webView:self earlyDoubleClickAtCoordinates:aPoint modifierFlags:modifierFlags];
	}
	return result;
}

- (void)paste:(id)sender
{
	DJW((@"paste: %@", [[NSPasteboard generalPasteboard] types]));
	[super paste:sender];
}

@end

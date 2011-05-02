//
//  iMediaAmazon.m
//  iMediaAmazon
//
//  Created by Dan Wood on 1/1/07.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

/* CACHING

http://www.amazon.com/AWS-License-home-page-Money/b/ref=sc_fe_c_0_12738641_5/105-3584771-5594807?ie=UTF8&node=3440661&no=12738641&me=A36L942TSJ2AJA

It looks like I can cache top sellers for 24 hours.  Browse nodes are not mentioned here ... should
I assume 1 month?

*/

#import "iMediaAmazon.h"
#import <AmazonSupport/AmazonSupport.h>

@interface iMediaAmazon ( Private )
- (NSString *)browseNodeCachePath;
@end

@implementation iMediaAmazon

+ (void)initialize
{
	[AmazonOperation setAccessKeyID: @"198Z9G3EA70GMSBA6XR2"];
	[iMediaBrowser registerParser:[self class] forMediaType:@"amazon"];
	[iMediaBrowser registerBrowser:self];
	//	[iMBMoviesController setKeys:[NSArray arrayWithObject:@"images"] triggerChangeNotificationsForDependentKey:@"imageCount"];
	
	[[[NSUserDefaultsController sharedUserDefaultsController] defaults] registerDefaults:
		[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt:comboView], @"AmazonListType",
			[NSNumber numberWithInt:newReleases], @"AmazonViewType",
			[NSNumber numberWithInt:AmazonStoreUS], @"AmazonListLastStore",
			nil]];
}

// designated initializer
- (id)initWithPlaylistController:(NSTreeController *)ctrl;
{
	if (self = [super initWithPlaylistController:ctrl])
	{
		[NSBundle loadNibNamed:@"amazon" owner:self];
	}
	return self;
}

- (void)dealloc
{
	NSUserDefaultsController *controller = [NSUserDefaultsController sharedUserDefaultsController];
	
	[controller removeObserver:self forKeyPath:@"values.AmazonViewType"];
	[controller removeObserver:self forKeyPath:@"values.AmazonListType"];
	[controller removeObserver:self forKeyPath:@"values.AmazonListLastStore"];

	[myAmazonQueryData release];
	[myCachedLibrary release];
	[myPlaceholderChild release];

	[mySelection release];
	[myCache release];
	[myCacheLock release];
	[myImages release];
	[mySearchString release];
	[mySelectedIndexPath release];
	[myProcessingImages release];
	
	[super dealloc];
}

- (void) setListTypeBinding
{
	int whichView = [[[NSUserDefaultsController sharedUserDefaultsController] defaults] integerForKey:@"AmazonListType"];
	NSString *path = whichView ? @"controller.selection.topSellers" : @"controller.selection.newReleases";
	[oArrayController bind:@"contentArray" toObject:self withKeyPath:path options:nil];
}	

- (void)awakeFromNib
{
	NSUserDefaultsController *controller = [NSUserDefaultsController sharedUserDefaultsController];
	
	[controller addObserver:self forKeyPath:@"values.AmazonViewType" options:(NSKeyValueObservingOptionNew) context:nil];
	[controller addObserver:self forKeyPath:@"values.AmazonListType" options:(NSKeyValueObservingOptionNew) context:nil];
	[controller addObserver:self forKeyPath:@"values.AmazonListLastStore" options:(NSKeyValueObservingOptionNew) context:nil];

	[self setListTypeBinding];
	
	[oPhotoView setDelegate:self];
	[oPhotoView setUseOutlineBorder:NO];
	[oPhotoView setUseHighQualityResize:NO];
	[oPhotoView setBackgroundColor:[NSColor whiteColor]];

	[oSlider setFloatValue:[oPhotoView photoSize]];	// initialize.  Changes are put into defaults.
	[oPhotoView setPhotoHorizontalSpacing:15];
	[oPhotoView setPhotoVerticalSpacing:15];
	
	[[[oComboTableView tableColumnWithIdentifier:@"title"] dataCell] setWraps:YES];
	
	// Set up store icons
	NSMenu *menu = [oStoreSelectionPopup menu];
	NSBundle *bundle = [NSBundle bundleForClass: [AmazonOperation class]];
	
	[[menu itemWithTag: AmazonStoreUS]		setImage:[[[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"us_flag"]] autorelease]];
	[[menu itemWithTag: AmazonStoreCanada]	setImage:[[[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"canada_flag"]] autorelease]];
	[[menu itemWithTag: AmazonStoreUK]		setImage:[[[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"uk_flag"]] autorelease]];
	[[menu itemWithTag: AmazonStoreGermany] setImage:[[[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"german_flag"]] autorelease]];
	[[menu itemWithTag: AmazonStoreFrance]	setImage:[[[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"france_flag"]] autorelease]];
	[[menu itemWithTag: AmazonStoreJapan]	setImage:[[[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"japan_flag"]] autorelease]];

	menu = [oViewTypePopup menu];
	
	[[menu itemWithTag: photoView]	setImage:[[[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"photoview"]] autorelease]];
	[[menu itemWithTag: comboView]	setImage:[[[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"comboview"]] autorelease]];
	[[menu itemWithTag: textView]	setImage:[[[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"textview"]] autorelease]];
}

// -----------------------------------------------------------------------------
// PARSING PROTOCOL
// -----------------------------------------------------------------------------

- (iMBLibraryNode *)library:(BOOL)reuseCachedData;
{
	if (!myCachedLibrary || !reuseCachedData)
	{
		myPlaceholderChild = [[iMBLibraryNode alloc] init];
		[myPlaceholderChild setName:LocalizedStringInThisBundle(@"loading…", @"placeholder name while loading")];

		myCachedLibrary = [[iMBLibraryNode alloc] init];
		[myCachedLibrary setName:LocalizedStringInThisBundle(@"Amazon", @"Amazon name")];
		[myCachedLibrary setParser:self];

		NSArray *topLevelNodes = [NSArray arrayWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"topLevelNodes" ofType:@"plist"]];

		NSEnumerator *enumerator = [topLevelNodes objectEnumerator];
		NSDictionary *nameAndID;

		while ((nameAndID = [enumerator nextObject]) != nil)
		{
			iMBLibraryNode *topLevel = [[iMBLibraryNode alloc] init];
			[topLevel setName:[nameAndID objectForKey:@"name"]];
			[topLevel setAttribute:[nameAndID objectForKey:@"id"] forKey:@"BrowseNodeID"];
			[topLevel setIconName:@"folder"];
			[topLevel addItem:[[myPlaceholderChild copy] autorelease]];
			[topLevel setParser:self];
			[myCachedLibrary addItem:topLevel];
		}
	}
	return myCachedLibrary;
}

// Node selected.  Load information if not already loaded.
- (void)iMediaBrowser:(iMediaBrowser *)browser didSelectNode:(iMBLibraryNode *)node
{
	NSString *browseNodeID = [node attributeForKey:@"BrowseNodeID"];
	BOOL alreadyLoaded = [[node attributeForKey:@"loaded"] boolValue];
	if (nil != browseNodeID && !alreadyLoaded)
	{
		NSDictionary *treeInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			node, @"node",
			nil];
		AmazonBrowseNodeLookup *request = [[[AmazonBrowseNodeLookup alloc]
			initWithBrowseNodeID:browseNodeID
						treeInfo:treeInfo] autorelease];
		[request loadWithDelegate:self];
	}
}

// Node selected.  Load information if not already loaded.  When loaded, tree will be updated.
- (void)iMediaBrowser:(iMediaBrowser *)browser willExpandOutline:(NSOutlineView *)outline row:(id)row node:(iMBLibraryNode *)node
{
	NSString *browseNodeID = [node attributeForKey:@"BrowseNodeID"];
	BOOL alreadyLoaded = [[node attributeForKey:@"loaded"] boolValue];
	if (nil != browseNodeID && !alreadyLoaded)
	{
		NSDictionary *treeInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			outline, @"outline",
			row, @"row",
			node, @"node",
			nil];
		AmazonBrowseNodeLookup *request = [[[AmazonBrowseNodeLookup alloc]
			initWithBrowseNodeID:browseNodeID
						treeInfo:treeInfo] autorelease];
		[request loadWithDelegate:self];
	}
}

- (void)setBrowser:(id <iMediaBrowser>)browser
{
	// Not needed, since we're both the same?
}

// -----------------------------------------------------------------------------
// BROWSER PROTOCOL
// -----------------------------------------------------------------------------

	// used for the parser register to load the correct parsers
- (NSString *)mediaType;
{
	return @"amazon";
}

- (IBAction)search:(id)sender
{
//	[mySearchString autorelease];
//	mySearchString = [[sender stringValue] copy];
//
//	[oPhotoView setNeedsDisplay:YES];
}

static NSImage *_toolbarIcon = nil;

- (NSImage*)toolbarIcon
{
	if(_toolbarIcon == nil)
	{
		NSString *p = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"icon"];
		_toolbarIcon = [[NSImage alloc] initWithContentsOfFile:p];
	}
	return _toolbarIcon;
}

	// localized name for the browser
- (NSString *)name;
{
    //return [[NSBundle bundleForClass:[self class]] localizedStringForKey:@"Amazon" value:@"" table:nil];
	return @"Amazon";	// no need to localize
}

	// Drag and Drop support for the playlist/album
- (void)writePlaylist:(iMBLibraryNode *)playlist toPasteboard:(NSPasteboard *)pboard;
{

}

- (BOOL)allowPlaylistFolderDrop:(NSString*)path;
{
	return NO;
}



// -----------------------------------------------------------------------------
// Loading Data
// -----------------------------------------------------------------------------


- (void)asyncObject:(id)request
	 didFailWithError:(NSError *)error;
{
	NSDictionary *treeInfo = [request treeInfo];
	NSOutlineView *outline = [treeInfo objectForKey:@"outline"];
	id row = [treeInfo objectForKey:@"row"];
	iMBLibraryNode *node = [treeInfo objectForKey:@"node"];
	// inform the user that the download could not be made
	if (0 == [[node items] count])
	{
		// add a single child item if it's not there yet
		[node addItem:[[myPlaceholderChild copy] autorelease]];
	}
	[((iMBLibraryNode *)[[node items] objectAtIndex:0]) setName:[error localizedDescription]];

	[outline reloadItem:row];
}

- (void)asyncObjectDidFinishLoading:(id)request;
{
	NSDictionary *treeInfo = [((AmazonBrowseNodeLookup *)request) treeInfo];
	NSOutlineView *outline = [treeInfo objectForKey:@"outline"];
	iMBLibraryNode *node = [treeInfo objectForKey:@"node"];
	// inform the user that the download could not be made
	if (0 != [[node items] count])
	{
		[node removeAllItems];
	}
	NSEnumerator *enumerator = [[request children] objectEnumerator];
	NSDictionary *childDict;

	while ((childDict = [enumerator nextObject]) != nil)
	{
		iMBLibraryNode *newChild = [[iMBLibraryNode alloc] init];
		[newChild setName:[childDict objectForKey:@"Name"]];
		[newChild setAttribute:[childDict objectForKey:@"BrowseNodeId"] forKey:@"BrowseNodeID"];
		[newChild setIconName:@"folder"];
		[newChild addItem:[[myPlaceholderChild copy] autorelease]];	// assume you can expand
		[newChild setParser:self];
		[node addItem:newChild];
	}
	
	// Now we have top-sellers, new releases - for each, it's ASIN and Title.
	
	[node setAttribute:[request topSellers] forKey:@"topSellers"];
	[node setAttribute:[request newReleases] forKey:@"newReleases"];
	[node setAttribute:[NSNumber numberWithBool:YES] forKey:@"loaded"];
	
	if (nil != outline)
	{
		[outline reloadData];
	}
}


- (NSString *)browseNodeCachePath
{
	static NSString *sBrowseNodeCachePath = nil;
    if ( nil == sBrowseNodeCachePath )
	{
		// construct path
		NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES);
		if ( [libraryPaths count] == 1 )
        {
			sBrowseNodeCachePath = [libraryPaths objectAtIndex:0];
			sBrowseNodeCachePath = [sBrowseNodeCachePath stringByAppendingPathComponent:@"iMedia"];
			sBrowseNodeCachePath = [sBrowseNodeCachePath stringByAppendingPathComponent:@"Amazon"];
			sBrowseNodeCachePath = [sBrowseNodeCachePath stringByAppendingPathExtension:@"noindex"];
		}
    }
    return sBrowseNodeCachePath;
}



- (void)observeValueForKeyPath:(NSString *)aKeyPath
                      ofObject:(id)anObject
                        change:(NSDictionary *)aChange
                       context:(void *)aContext
{
//	NSLog(@"observeValueForKeyPath: %@", aKeyPath);
//	NSLog(@"                object: %@", anObject);
//	NSLog(@"                change: %@", [aChange description]);
	
	if ([aKeyPath isEqualToString:@"values.AmazonViewType"])
	{
		NSLog(@"User switched view type");
	}
	else if ([aKeyPath isEqualToString:@"values.AmazonListType"])
	{
		NSLog(@"User switched list type");
		[self setListTypeBinding];
	}
	else if ([aKeyPath isEqualToString:@"values.AmazonListLastStore"])
	{
		NSLog(@"Switched store -- need to reload tables");
		/*
		 
		 // Reload the manual and automatic lists
		 [self loadAutomaticList];
		 
		 NSEnumerator *enumerator = [[self products] objectEnumerator];
		 APManualListProduct *product;
		 while (product = [enumerator nextObject]) {
			 [product setStore: country];
		 }
		 
		 [self loadAllManualListProducts];
		 */
	}
}

- (NSArray *)selectedRecords
{
	NSMutableArray *records = [NSMutableArray array];
	int i, c = [myImages count];
	
	for (i = 0; i < c; i++)
	{
		if ([mySelection containsIndex:i])
		{
			[records addObject:[myImages objectAtIndex:i]];
		}
	}
	
	return records;
}


#pragma mark -
#pragma mark MUPhotoView Delegate Methods

- (void)setImages:(NSArray *)images
{
	[myImages autorelease];
	myImages = [images retain];
	NSIndexPath *selectionIndex = [[self controller] selectionIndexPath];
	// only clear the cache if we go to another parser
	if (!([selectionIndex isSubPathOf:mySelectedIndexPath] || 
		  [mySelectedIndexPath isSubPathOf:selectionIndex] || 
		  [mySelectedIndexPath isPeerPathOf:selectionIndex]))
	{
		[myCache removeAllObjects];
	}
	[mySelectedIndexPath autorelease];
	mySelectedIndexPath = [selectionIndex retain];
	
	//reset the scroll position
	[oPhotoView scrollRectToVisible:NSMakeRect(0,0,1,1)];
	[oPhotoView setNeedsDisplay:YES];
}

- (NSArray *)images
{
	return myImages;
}

- (unsigned)photoCountForPhotoView:(MUPhotoView *)view
{
	return [myImages count];
}

- (NSString *)photoView:(MUPhotoView *)view captionForPhotoAtIndex:(unsigned)index
{
	NSDictionary *rec = [myImages objectAtIndex:index];
	
	return [rec objectForKey:@"title"];
}
- (NSString *)photoView:(MUPhotoView *)view titleForPhotoAtIndex:(unsigned)index
{
	if ([[self browser] showsFilenamesInPhotoBasedBrowsers])
        return [self photoView:view captionForPhotoAtIndex:index];
    
	return nil;
}


- (NSImage *)photoView:(MUPhotoView *)view photoAtIndex:(unsigned)index
{
	NSDictionary *rec;
	rec = [myImages objectAtIndex:index];

	//try the caches
	[myCacheLock lock];
	NSString *imagePath = [rec objectForKey:@"ImagePath"];
	NSImage *img = [myCache objectForKey:imagePath];
	[myCacheLock unlock];
	
	if (!img) img = [rec objectForKey:@"CachedThumb"];
	
	if (!img)
	{
		// background load the image
		img = nil; //return nil so the image view draws a bezierpath
	}
	return img;
}

- (void)photoView:(MUPhotoView *)view didSetSelectionIndexes:(NSIndexSet *)indexes
{
	[mySelection removeAllIndexes];
	[mySelection addIndexes:indexes];
	
	NSArray *selection = [self selectedRecords];
	NSEvent *evt = [NSApp currentEvent];
	NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:selection, @"records", evt, @"event", nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:iMediaBrowserSelectionDidChangeNotification
														object:self
													  userInfo:d];
}

- (void)photoView:(MUPhotoView *)view doubleClickOnPhotoAtIndex:(unsigned)index withFrame:(NSRect)frame
{
	NSArray *selection = [self selectedRecords];
	NSEvent *evt = [NSApp currentEvent];
	NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:selection, @"records", evt, @"event", nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:iMediaBrowserSelectionDidChangeNotification
														object:self
													  userInfo:d];
}

- (NSIndexSet *)selectionIndexesForPhotoView:(MUPhotoView *)view
{
	return mySelection;
}

- (unsigned int)photoView:(MUPhotoView *)view draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	return NSDragOperationCopy;
}

// MUPHOTOVIEW STYLE

- (NSArray *)pasteboardDragTypesForPhotoView:(MUPhotoView *)view
{
    return [[[NSArray alloc] init] autorelease];
}

- (NSData *)photoView:(MUPhotoView *)view pasteboardDataForPhotoAtIndex:(unsigned)index dataType:(NSString *)type
{
    return nil;
}

// OUR STYLE

- (void)photoView:(MUPhotoView *)view fillPasteboardForDrag:(NSPasteboard *)pboard
{
	NSMutableArray *items = [NSMutableArray array];
	NSDictionary *cur;
	int i;
	
	for(i = 0; i < [myImages count]; i++) 
	{
		if ([mySelection containsIndex:i]) 
		{
			cur = [myImages objectAtIndex:i];
			[items addObject:cur];
		}
	}
//	[self writeItems:items fromAlbum:[[NSBundle bundleForClass:[self class]] localizedStringForKey:@"Selection" value:@"" table:nil] toPasteboard:pboard];
}



@end

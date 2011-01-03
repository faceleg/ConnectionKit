//
//  iMediaAmazon.h
//  iMediaAmazon
//
//  Created by Dan Wood on 1/1/07.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <iMediaBrowser/iMedia.h>
//#import "AmazonOperation.h"

@class MUPhotoView;

typedef enum { comboView = 0, photoView, textView  } viewType;
typedef enum { newReleases = 0, topSellers } listType;

@interface iMediaAmazon : iMBAbstractController <iMBParser>
{
	iMBLibraryNode		*myCachedLibrary;
	iMBLibraryNode		*myPlaceholderChild;

	IBOutlet NSPopUpButton	*oStoreSelectionPopup;
	IBOutlet NSPopUpButton	*oViewTypePopup;
	IBOutlet NSArrayController	*oArrayController;	// hopefully this doesn't cause a retain cycle
	IBOutlet NSTableView	*oComboTableView;
	IBOutlet NSTableView	*oTextTableView;
	
	// photo view stuff, not sure what I'll need
	IBOutlet MUPhotoView	*oPhotoView;
	IBOutlet NSSlider		*oSlider;
	NSMutableDictionary		*myCache;
	NSMutableIndexSet		*mySelection;
	NSArray					*myImages;
	NSString				*mySearchString;
	NSLock					*myCacheLock;
	NSMutableSet			*myProcessingImages;
	int						myThreadCount;
	NSIndexPath				*mySelectedIndexPath;
	
	NSMutableData *myAmazonQueryData;
	iMBLibraryNode	*myLoadingNode;
}


@end

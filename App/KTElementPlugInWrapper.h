//
//  KTElementPlugInWrapper.h
//  Marvel
//
//  Created by Mike on 26/01/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KSPlugInWrapper.h"


typedef enum {
	KTPluginCategoryUnknown = 0,
	KTPluginCategoryTopLevel = 1,		// In case we have any plug-ins that we don't want to show up in a category
	KTPluginCategoryIndex = 2,
	KTPluginCategoryBadge,
	KTPluginCategoryEmbedded,
	KTPluginCategorySocial,				// Should Social and Embedded be folded together?
	KTPluginCategoryOther
} KTPluginCategory;


@class SVPlugInGraphicFactory;


@interface KTElementPlugInWrapper : KSPlugInWrapper
{
@private
    SVPlugInGraphicFactory    *_factory;
}

+ (NSSet *)pageletPlugins;
+ (NSSet *)pagePlugins;

// Inserts one item per known collection preset into aMenu at the specified index.
+ (NSSet *)collectionPresets;

- (SVPlugInGraphicFactory *)graphicFactory;

- (KTPluginCategory)category;

@end

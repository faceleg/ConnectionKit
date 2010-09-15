//
//  KTHTMLPlugInWrapper.h
//  Marvel
//
//  Created by Mike on 26/01/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KSPlugInWrapper.h"
#import "SVGraphicFactory.h"

typedef enum {
	KTPluginCategoryUnknown = 0,
	KTPluginCategoryTopLevel = 1,		// In case we have any plug-ins that we don't want to show up in a category
	KTPluginCategoryIndex = 2,
	KTPluginCategoryBadge,
	KTPluginCategoryEmbedded,
	KTPluginCategorySocial,				// Should Social and Embedded be folded together?
	KTPluginCategoryOther
} KTPluginCategory;


@interface KTHTMLPlugInWrapper : KSPlugInWrapper
{
  @private
    SVGraphicFactory    *_factory;
    
	NSString    *_templateHTML;
}

- (SVGraphicFactory *)graphicFactory;

- (NSUInteger)priority;
- (KTPluginCategory)category;

- (NSString *)CSSClassName;

@end

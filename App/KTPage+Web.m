//
//  KTPage+Web.m
//  KTComponents
//
//  Created by Dan Wood on 8/9/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTPage+Internal.h"

#import "KT.h"
#import "KTSite.h"
#import "SVApplicationController.h"
#import "KTDesign.h"
#import "KTDocument.h"
#import "KTElementPlugInWrapper.h"
#import "SVHTMLContext.h"
#import "SVHTMLTextBlock.h"
#import "SVHTMLTemplateParser.h"
#import "KTMaster.h"
#import "KTPublishingEngine.h"
#import "SVTitleBox.h"

#import "NSBundle+KTExtensions.h"
#import "NSBundle+QuickLook.h"

#import "NSBundle+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"
#import "NSObject+Karelia.h"

#import <WebKit/WebKit.h>

#import "Registration.h"


@interface KSSiteMenuItem : NSObject
{
	KTPage *_page;
	NSMutableArray *_childPages;
}
@property (retain) KTPage *page;
@property (retain) NSMutableArray *childPages;

@end

@implementation KSSiteMenuItem

@synthesize page = _page;
@synthesize childPages = _childPages;

- (id)initWithPage:(KTPage *)aPage
{
	if ((self = [super init]) != nil)
	{
		self.page = aPage;
		self.childPages = [NSMutableArray array];
	}
	return self;
}

- (NSUInteger)hash
{
	return [[[[self page] objectID] description] hash];
}
@end



@implementation KTPage (Web)

/*	Generates the path to the specified file with the current page's design.
 *	Takes into account the HTML Generation Purpose to handle Quick Look etc.
 */
- (NSString *)pathToDesignFile:(NSString *)filename inContext:(SVHTMLContext *)context;
{
	NSString *result = nil;
	
	// Return nil if the file doesn't actually exist
	
	KTDesign *design = [[self master] design];
	NSString *localPath = [[[design bundle] bundlePath] stringByAppendingPathComponent:filename];
	if ([[NSFileManager defaultManager] fileExistsAtPath:localPath])
	{
		if ([context isForQuickLookPreview])
        {
            result = [[design bundle] quicklookDataForFile:filename];
        }
        else if ([context isEditable] && ![context baseURL])
        {
            result = [[NSURL fileURLWithPath:localPath] absoluteString];
        }
        else
        {
            KTMaster *master = [(KTPage *)[context page] master];
            NSURL *designFileURL = [NSURL URLWithString:filename relativeToURL:[master designDirectoryURL]];
            result = [designFileURL stringRelativeToURL:[context baseURL]];
        }
	}
	
	return result;
}

#pragma mark Class Methods

- (NSString *)markupString;   // creates a temporary HTML context and calls -writeHTML
{
    NSMutableString *result = [NSMutableString string];
    
    SVHTMLContext *context = [[SVHTMLContext alloc] initWithStringWriter:result];
    [context setPage:self];
	
	[self writeHTML:context];
    
    [context release];
    return result;
}

- (void)writeHTML:(SVHTMLContext *)context;
{
	// Build the HTML    
    [context addDependencyOnObject:[NSUserDefaultsController sharedUserDefaultsController]
                           keyPath:[@"values." stringByAppendingString:kSVLiveDataFeedsKey]];
     
    [context setXHTML:[self isXHTML]];
    [context setEncoding:[[[self master] valueForKey:@"charset"] encodingFromCharset]];
    [context setLanguage:[[self master] language]];
    
    NSString *cssPath = [self pathToDesignFile:@"main.css" inContext:context];
    [context setMainCSSURL:[NSURL URLWithString:cssPath
                                  relativeToURL:[context baseURL]]];
     
    
	SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc] initWithPage:self];
    [parser parseIntoHTMLContext:context];
    [parser release];
}

- (void)publish:(id <SVPublishingContext>)publishingEngine recursively:(BOOL)recursive;
{
    NSString *path = [self uploadPath];
    SVHTMLContext *context = [publishingEngine beginPublishingHTMLToPath:path];
    [context setPage:self];
	
    [self writeHTML:context];
    [context close];
    
    
	// Generate and publish RSS feed if needed
	if ([[self collectionSyndicate] boolValue])
	{
		NSString *RSSString = [self RSSFeedWithParserDelegate:publishingEngine];
		if (RSSString)
		{			
			// Now that we have page contents in unicode, clean up to the desired character encoding.
			NSData *RSSData = [RSSString dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
			OBASSERT(RSSData);
			
			NSString *RSSFilename = [self RSSFileName];
			NSString *RSSUploadPath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:RSSFilename];
			[publishingEngine publishData:RSSData toPath:RSSUploadPath];
		}
	}
    
    
    // Continue onto the next page if the app is licensed
    if (recursive && !gLicenseIsBlacklisted && gRegistrationString)
    {
        for (SVSiteItem *anItem in [self sortedChildren])
        {
            if (![[anItem isDraft] boolValue])
            {
                [anItem publish:publishingEngine recursively:recursive];
            }
        }
    }
}

+ (NSString *)pageTemplate
{
	static NSString *sPageTemplateString = nil;
	
	if (!sPageTemplateString)
	{
		NSString *path = [[NSBundle bundleForClass:[self class]] overridingPathForResource:@"KTPageTemplate" ofType:@"html"];
		NSData *data = [NSData dataWithContentsOfFile:path];
		sPageTemplateString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	}
	
	return sPageTemplateString;
}

+ (NSString *)pageMainContentTemplate;
{
	static NSString *sPageTemplateString = nil;
	
	if (!sPageTemplateString)
	{
		NSString *path = [[NSBundle bundleForClass:[self class]] overridingPathForResource:@"KTPageMainContentTemplate" ofType:@"html"];
		NSData *data = [NSData dataWithContentsOfFile:path];
		sPageTemplateString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	}
	
	return sPageTemplateString;
}

- (void)writeMainContent
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    
    SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc] initWithTemplate:[[self class] pageMainContentTemplate]
                                                                        component:[context page]];
    
    [context setCurrentHeaderLevel:3];
    [parser parse];
    [parser release];
}

#pragma mark CSS

- (NSString *)cssClassName { return @"text-page"; }

/*  Used by KTPageTemplate.html to generate links to the stylesheets needed by this page. Used to be a dedicated [[stylesheet]] parser function
 */
- (void)writeStylesheetLinks
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    
    
    // Write link to main.CSS file -- the most specific
    NSURL *mainCSSURL = [context mainCSSURL];
    if (mainCSSURL)
    {
        [context writeLinkToStylesheet:[context relativeURLStringOfURL:mainCSSURL]
                                 title:[[[self master] design] title]
                                 media:nil];
    }
	
	
	// design's print.css but not for Quick Look
    if (![context isForQuickLookPreview])
	{
		NSString *printCSS = [self pathToDesignFile:@"print.css" inContext:context];
		if (printCSS)
        {
            [context writeLinkToStylesheet:printCSS title:nil media:@"print"];
        }
	}
	
	
	// Always include the global sandvox CSS.
	NSString *globalCSSFile = [[NSBundle mainBundle] overridingPathForResource:@"sandvox" ofType:@"css"];
    NSString *globalCSS = [NSString stringWithContentsOfFile:globalCSSFile encoding:NSUTF8StringEncoding error:NULL];
    if (globalCSS) [[context mainCSS] appendString:globalCSS];
    
    
    // Load up main.css
    NSString *mainCSS = [NSString stringWithData:[[[self master] design] mainCSSData]
                                        encoding:NSUTF8StringEncoding];
    if (mainCSS) [[context mainCSS] appendString:mainCSS];
    
    
	// If we're for editing, include additional editing CSS
	if ([context isEditable])
	{
		NSString *editingCSSPath = [[NSBundle mainBundle] overridingPathForResource:@"design-time"
																			 ofType:@"css"];
        NSString *editingCSS = [NSString stringWithContentsOfFile:editingCSSPath
                                                         encoding:NSUTF8StringEncoding
                                                            error:NULL];
		if (editingCSS) [[context mainCSS] appendString:editingCSS];
	}
	
    
	// For preview/quicklook mode, the banner CSS
    [[self master] writeBannerCSS];
}

#pragma mark Other

/*!	Generate path to javascript.  Nil if not there */
- (NSString *)javascriptURLPath
{
	NSString *result = nil;
	
	NSBundle *designBundle = [[[self master] design] bundle];
	BOOL scriptExists = ([designBundle pathForResource:@"javascript" ofType:@"js"] != nil);
	if (scriptExists)
	{
		NSURL *javascriptURL = [NSURL URLWithString:@"javascript.js" relativeToURL:[[self master] designDirectoryURL]];
		result = [javascriptURL stringRelativeToURL:[self URL]];
	}
	
	return result;
}


/*!	Return the string that makes up the title.  Page Title | Site Title | Author ... this is the DEFAULT if not set by windowTitle property.
*/
- (NSString *)comboTitleText
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *titleSeparator = [defaults objectForKey:@"TitleSeparator"];
	
	if ( [self isDeleted] || (nil == [[self site] rootPage]) )
	{
		return @"Bad Page!";
	}
	
	NSMutableString *buf = [NSMutableString string];
	
	BOOL needsSeparator = NO;
	NSString *title = [[self titleBox] text];
	if ( nil != title && ![title isEqualToString:@""])
	{
		[buf appendString:title];
		needsSeparator = YES;
	}
	
	
	NSString *siteTitleText = [[[[self master] siteTitle] textHTMLString] stringByConvertingHTMLToPlainText];
	if ( (nil != siteTitleText) && ![siteTitleText isEqualToString:@""] && ![siteTitleText isEqualToString:title] )
	{
		if (needsSeparator)
		{
			[buf appendString:titleSeparator];
		}
		[buf appendString:siteTitleText];
		needsSeparator = YES;
	}
	
	NSString *author = [[self master] valueForKey:@"author"];
	if (nil != author
		&& ![author isEqualToString:@""]
		&& ![author isEqualToString:siteTitleText]
		)
	{
		if (needsSeparator)
		{
			[buf appendString:titleSeparator];
		}
		[buf appendString:author];
	}
	
	if ([buf isEqualToString:@""])
	{
		buf = [NSMutableString stringWithString:NSLocalizedString(@"Untitled Page","fallback page title if no title is otherwise found")];
	}
	
	return buf;
}

#pragma mark -
#pragma mark DTD

- (KTDocType)docType
{
	KTDocType result = [[NSUserDefaults standardUserDefaults] integerForKey:@"DocType"];
	
	
    // if wantsJSKit comments, use transitional doc type (or worse, if already known)
	if ( result > KTXHTMLTransitionalDocType )
	{
		if ([[self allowComments] boolValue] && [[self master] wantsJSKit] )
		{
			result = KTXHTMLTransitionalDocType; // if this changes to KTHTML401DocType, also change isXHTML
		}
	}
    
    
    // Do any plug-ins want to lower the tone?
    NSManagedObjectContext *context = [self managedObjectContext];
    NSArray *graphics = [context fetchAllObjectsForEntityForName:@"Graphic" error:NULL];
    
    for (NSManagedObject *aGraphic in graphics)
    {
        result = MIN(result, [[aGraphic valueForKey:@"docType"] integerValue]);
        if (result == KTHTML401DocType) break;
    }
    
    
	return result;
}

- (NSString *)docTypeName
{
	KTDocType docType = [self docType];
	NSString *result = nil;
	switch (docType)
	{
		case KTHTML401DocType:
			result = @"HTML 4.01 Transitional";
			break;
		case KTXHTMLTransitionalDocType:
			result = @"XHTML 1.0 Transitional";
			break;
		case KTXHTMLStrictDocType:
			result = @"XHTML 1.0 Strict";
			break;
		case KTXHTML11DocType:
			result = @"XHTML 1.1";
			break;
	}
	return result;
}


- (BOOL)isXHTML	// returns true if our page is XHTML of some type, false if old HTML
{
	KTDocType docType = [self docType];
	BOOL result = (KTHTML401DocType != docType);
	return result;
}

- (NSString *)DTD
{
	KTDocType docType = [self docType];
	NSString *result = nil;
	switch (docType)
	{
		case KTHTML401DocType:
			result = @"<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">";
			break;
		case KTXHTMLTransitionalDocType:
			result = @"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">";
			break;
		case KTXHTMLStrictDocType:
			result = @"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">";
			break;
		case KTXHTML11DocType:
			result = @"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\" \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">";
			break;
	}
	return result;
}

- (void)outputMenuForSiteMenuItems:(NSArray *)anArray treeLevel:(int)aTreeLevel
{
	SVHTMLContext *context = [SVHTMLContext currentContext];
	KTPage *currentParserPage = [[SVHTMLContext currentContext] page];
	
	NSString *className = [NSString stringWithFormat:@"sf%d", aTreeLevel];;
	if (0 == aTreeLevel)
	{
		className = [className stringByAppendingString:@" sf-menu"];
		int hierMenuType = [[[self master] design] hierMenuType];
		if (HIER_MENU_NAVBAR == hierMenuType)
		{
			className = [className stringByAppendingString:@" sf-navbar"];
		}
		else if (HIER_MENU_VERTICAL == hierMenuType)
		{
			className = [className stringByAppendingString:@" sf-vertical"];
		}
	}
	[context startElement:@"ul" idName:nil className:className];

	int i=1;	// 1-based iteration
	int last = [anArray count];

	for (KSSiteMenuItem *item in anArray)
	{
		KTPage *page = item.page;
		NSArray *children = item.childPages;

		if (page == currentParserPage)
		{
			[context startElement:@"li" idName:nil className:
			 [NSString stringWithFormat:@"sf%d i%d %@%@ currentPage", aTreeLevel, i, (i%2)?@"o":@"e", (i==last)? @" last" : @""]];
		}
		else
		{
			BOOL isCurrentParent = NO;
			if (!currentParserPage.includeInSiteMenu && page == currentParserPage.parentPage && currentParserPage.parentPage.index)
			{
				isCurrentParent = YES;
			}
			
			[context startElement:@"li" idName:nil className:
			 [NSString stringWithFormat:@"sf%d i%d %@%@%@%@",
			  aTreeLevel,
			  i,
			  (i%2)?@"o":@"e",
			  (i==last)? @" last" : @"",
			  isCurrentParent ? @" currentParent" : @"",
			  aTreeLevel ? @" sfPop" : @""				// any popup one gets 'sfPop' to distinguish from non-popups
			  ]];
			
			NSString *urlString = [context relativeURLStringOfSiteItem:page];
			
			[context startAnchorElementWithHref:urlString title:[page title] target:nil rel:nil];
			// TODO: targetStringForPage:targetPage
		}
		
		// Build a text block
		SVHTMLTextBlock *textBlock = [[[SVHTMLTextBlock alloc] init] autorelease];
		
		[textBlock setEditable:NO];
		[textBlock setFieldEditor:NO];
		[textBlock setRichText:NO];
		[textBlock setImportsGraphics:NO];
		[textBlock setTagName:@"span"];
		[textBlock setGraphicalTextCode:@"m"];		// Actually we are probably throwing away graphical text menus
		
		[textBlock setHTMLSourceObject:page];
		[textBlock setHTMLSourceKeyPath:@"menuTitle"];
		
		[textBlock writeHTML:context];
		
		if (page != currentParserPage)
		{
			[context endElement];	// a
		}
		
		if ([children count])
		{
			[self outputMenuForSiteMenuItems:children treeLevel:aTreeLevel+1];
			[context endElement];	// li
        }
		else
		{
			[context endElement];	// li
		}
		i++;
	}
	[context endElement];	// ul
}

- (NSString *)sitemenu
{
	if (self.site.pagesInSiteMenu)	// Are there any pages in the site menu?
	{
		SVHTMLContext *context = [SVHTMLContext currentContext];
		[context startElement:@"div" idName:@"sitemenu" className:nil];			// <div id="sitemenu">
		[context startElement:@"h2" idName:nil className:@"hidden"];				// hidden skip navigation menu
		[context writeString:
		 NSLocalizedStringWithDefaultValue(@"skipNavigationTitleHTML", nil, [NSBundle mainBundle], @"Site Navigation", @"Site navigation title on web pages (can be empty if link is understandable)")];

		[context startAnchorElementWithHref:@"#page-content" title:nil target:nil rel:@"nofollow"];
		[context writeString:NSLocalizedStringWithDefaultValue(@"skipNavigationLinkHTML", nil, [NSBundle mainBundle], @"[Skip]", @"Skip navigation LINK on web pages")];
		
		[context endElement];	// a
		[context endElement];	// h2
		
		
		[context startElement:@"div" idName:@"sitemenu-content" className:nil];		// <div id="sitemenu-content">
	
		KTSite *site = self.site;
		NSArray *pagesInSiteMenu = site.pagesInSiteMenu;
		
		int hierMenuType = [[[self master] design] hierMenuType];
		NSMutableArray *forest = [NSMutableArray array];
		if (HIER_MENU_NONE == hierMenuType || [[NSUserDefaults standardUserDefaults] boolForKey:@"disableHierMenus"])
		{
			// Flat menu, either by design's preference or user default
			for (KTPage *siteMenuPage in pagesInSiteMenu)
			{
				KSSiteMenuItem *item = [[[KSSiteMenuItem alloc] initWithPage:siteMenuPage] autorelease];
				[forest addObject:item];
			}
			[self outputMenuForSiteMenuItems:forest treeLevel:0];
		}
		else	// hierarchical menu
		{
			// now to build up the hiearchical site menu.
			// Array of dictionaries keyed with "page" and "children" array
			NSMutableArray *childrenLookup = [NSMutableArray array];
			// Assume we are traversing tree in sorted order, so children will always be found after parent, which makes it easy to build this tree.
			for (KTPage *siteMenuPage in pagesInSiteMenu)
			{
				BOOL wasSubPage = NO;
				KTPage *parent = siteMenuPage;
				KSSiteMenuItem *item = nil;
				do // loop through, looking to see if this (or parent) page is a sub-page of an already-found page in the site menu.
				{
					KSSiteMenuItem *itemToAddTo = nil;
					// See if this is already known about
					for (KSSiteMenuItem *checkItem in childrenLookup)
					{
						if (checkItem.page == parent)
						{
							itemToAddTo = checkItem;
							break;
						}
					}					
					if (itemToAddTo)	// Was there a parent menu item?
					{
						// If so, create a new entry for this page, with an empty array of children; add to list of children
						item = [[[KSSiteMenuItem alloc] initWithPage:siteMenuPage] autorelease];
						[itemToAddTo.childPages addObject:item];
						parent = nil;	// stop looking
						wasSubPage = YES;
					}
					else // No, this page (or its parent) was not in the menu list so go up one level to keep looking.
					{
						parent = [parent parentPage];
					}
				}
				while (nil != parent && ![parent isRoot]);	// Stop when we reach root. Note that we don't put items under root.

				if (!item)
				{
					item = [[[KSSiteMenuItem alloc] initWithPage:siteMenuPage] autorelease];
				}
				[childrenLookup addObject:item];		// quick lookup from page to children

				if (!wasSubPage)	// Not a sub-page, so it's a top-level menu item.
				{
					[forest addObject:item];		// Add to our list of top-level menus
				}
			}	// end for
			[self outputMenuForSiteMenuItems:forest treeLevel:0];
		}
		
		
		[context writeEndTagWithComment:@"/sitemenu-content"];
		[context writeEndTagWithComment:@"/sitemenu"];
	}
	return nil;
}
/*
 Based on this template markup:
 [[if site.pagesInSiteMenu]]
	 <div id='sitemenu'>
		 <h2 class='hidden'>[[`skipNavigationTitleHTML]]<a rel='nofollow' href='#page-content'>[[`skipNavigationLinkHTML]]</a></h2>
		 <div id='sitemenu-content'>
			 <ul>
				 [[forEach site.pagesInSiteMenu toplink]]
					 [[if toplink==parser.currentPage]]
						 <li class='[[i]] [[eo]][[last]] currentPage'>
							[[textblock property:toplink.menuTitle graphicalTextCode:mc tag:span]]
						 </li>
					 [[else2]]
						 <li class='[[i]] [[eo]][[last]][[if !parser.currentPage.includeInSiteMenu]][[if toplink==parser.currentPage.parentPage]][[if parser.currentPage.parentPage.index]] currentParent[[endif5]][[endif4]][[endif3]]'>
							 <a [[target toplink]]href='[[path toplink]]' title='[[=&toplink.titleText]]'>
							 [[textblock property:toplink.menuTitle graphicalTextCode:m tag:span]]</a>
						 </li>
					 [[endif2]]
				 [[endForEach]]
			 </ul>
		 </div> <!-- sitemenu-content -->
	 </div> <!-- sitemenu -->
 [[endif]]
*/ 

@end

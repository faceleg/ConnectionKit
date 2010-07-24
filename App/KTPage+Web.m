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
#import "SVPublisher.h"
#import "SVTitleBox.h"
#import "SVWebEditorHTMLContext.h"

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
- (NSString *)pathToDesignFile:(NSString *)whichFileName inContext:(SVHTMLContext *)context;
{
	NSString *result = nil;
	
	// Return nil if the file doesn't actually exist
	
	KTDesign *design = [[self master] design];
	NSString *localPath = [[[design bundle] bundlePath] stringByAppendingPathComponent:whichFileName];
	if ([[NSFileManager defaultManager] fileExistsAtPath:localPath])
	{
		if ([context isForQuickLookPreview])
        {
            result = [[design bundle] quicklookDataForFile:whichFileName];		// Hmm, this isn't going to pick up the variation or any other CSS
        }
        else if ([context isForEditing] && ![context baseURL])
        {
            result = [[NSURL fileURLWithPath:localPath] absoluteString];
			
			// Append variation index as fragment, so that we can switch among variations and see a different URL
			if (NSNotFound != design.variationIndex)
			{
				result = [result stringByAppendingFormat:@"#var%d", design.variationIndex];
			}
        }
        else
        {
            KTMaster *master = [[context page] master];
            NSURL *designFileURL = [NSURL URLWithString:whichFileName relativeToURL:[master designDirectoryURL]];
            result = [designFileURL stringRelativeToURL:[context baseURL]];
        }
	}
	
	return result;
}

#pragma mark HTML

- (NSString *)markupString;   // creates a temporary HTML context and calls -writeHTML
{
    NSMutableString *result = [NSMutableString string];
    
    SVHTMLContext *context = [[SVHTMLContext alloc] initWithMutableString:result];	
	[context writeDocumentWithPage:self];
    
    [context release];
    return result;
}

- (NSString *)markupStringForEditing;   // for viewing source for debugging purposes.
{
    NSMutableString *result = [NSMutableString string];
    
	SVWebEditorHTMLContext *context = [[SVWebEditorHTMLContext alloc] initWithMutableString:result];
	[context writeDocumentWithPage:self];
    [context release];
    
    return result;
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
    [parser parseIntoHTMLContext:context];
    [parser release];
}

#pragma mark Code injection

- (BOOL)canWriteCodeInjection:(SVHTMLContext *)aContext;
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	return ([aContext isForPublishingProOnly]
		
		// Show the code injection in the webview as well, as long as this default is set.
		|| ([defaults boolForKey:@"ShowCodeInjectionInPreview"]) && [aContext isForEditing]
		
			);
}

- (void)writeCodeInjectionSection:(NSString *)aKey masterFirst:(BOOL)aMasterFirst;
{
	SVHTMLContext *context = [SVHTMLContext currentContext];
    if ([self canWriteCodeInjection:context])
	{
        NSString *masterCode = [[[self master] codeInjection] valueForKey:aKey];
		NSString *pageCode = [[self codeInjection] valueForKey:aKey];

		if (masterCode && aMasterFirst)		{	[context startNewline]; [context writeString:masterCode];	}
        if (pageCode)						{	[context startNewline]; [context writeString:pageCode];		}
		if (masterCode && !aMasterFirst)	{	[context startNewline]; [context writeString:masterCode];	}
    }
}

// Note: For the paired code injection points -- the start and end of the head, and the body -- we flip around
// the ordering so we can do thing like nesting output buffers in PHP. Page is more "local" than master.

- (void)writeCodeInjectionEarlyHead		{	[self writeCodeInjectionSection:@"earlyHead"	masterFirst:YES];	}
- (void)writeCodeInjectionHeadArea		{	[self writeCodeInjectionSection:@"headArea"		masterFirst:NO];	}
- (void)writeCodeInjectionBodyTagStart	{	[self writeCodeInjectionSection:@"bodyTagStart"	masterFirst:YES];	}
- (void)writeCodeInjectionBodyTagEnd	{	[self writeCodeInjectionSection:@"bodyTagEnd"	masterFirst:NO];	}
- (void)writeCodeInjectionBeforeHTML	{	[self writeCodeInjectionSection:@"beforeHTML"	masterFirst:NO];	}

// Special case: Show a space in between the two; no newlines.
- (void)writeCodeInjectionBodyTag
{
	SVHTMLContext *context = [SVHTMLContext currentContext];
    if ([self canWriteCodeInjection:context])
    {
        NSString *masterCode = [[[self master] codeInjection] valueForKey:@"bodyTag"];
		NSString *pageCode = [[self codeInjection] valueForKey:@"bodyTag"];
		
		if (masterCode)				[context writeString:masterCode];
		if (masterCode && pageCode)	[context writeText:@" "];	// space in between, only if we have both
		if (pageCode)				[context writeString:pageCode];
    }
}

#pragma mark CSS

- (NSString *)cssClassName { return @"text-page"; }

/*  Used by KTPageTemplate.html to generate links to the stylesheets needed by this page. Used to be a dedicated [[stylesheet]] parser function
 */
- (void)writeStylesheetLinks
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    NSString *path = nil;
    
    // Write link to main.CSS file -- the most specific
    NSURL *mainCSSURL = [context mainCSSURL];
    if (mainCSSURL)
    {
        [context writeLinkToStylesheet:[context relativeURLStringOfURL:mainCSSURL]
                                 title:[[[self master] design] title]
                                 media:nil];
    }
	
	
	// design's print.css but not for Quick Look
    if ([context isForPublishing])
	{
		path = [self pathToDesignFile:@"print.css" inContext:context];
		if (path)
        {
            [context writeLinkToStylesheet:path title:nil media:@"print"];
        }
	}
}

#pragma mark Publishing

- (void)publish:(id <SVPublisher>)publishingEngine recursively:(BOOL)recursive;
{
    NSString *path = [self uploadPath];
    SVHTMLContext *context = [publishingEngine beginPublishingHTMLToPath:path];
	
    [context writeDocumentWithPage:self];
    
    
	// Generate and publish RSS feed if needed
	if ([[self collectionSyndicate] boolValue])
	{
		NSString *RSSFilename = [self RSSFileName];
        NSString *RSSUploadPath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:RSSFilename];
        
        SVHTMLContext *context = [publishingEngine beginPublishingHTMLToPath:RSSUploadPath];
        [self writeRSSFeed:context];
        [context close];
	}
    
    
    // Want the page itself to be placed on the queue after RSS feed, so if publishing fails between the two, both will be republished next time round
    [context close];
    
    
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

#pragma mark Other

/*!	Generate path to javascript.  Nil if not there */
- (NSString *)javascriptURLPath	// loaded after jquery so this can contain jquery in it.
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

#pragma mark DTD

// For code review:  Where can this utility class go?
+ (NSString *)stringFromDocType:(KTDocType)docType local:(BOOL)isLocal;
{
	NSString *result = nil;
	if (isLocal)
	{
		NSURL *dtd = nil;
		switch (docType)
		{
			case KTHTML401DocType:
				dtd = nil;	// don't load a local DTD for HTML 4.01
				result = [NSString stringWithFormat:@"<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"%@\">", [dtd absoluteString]];
				break;
			case KTXHTMLTransitionalDocType:
				dtd = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"xhtml1-transitional" ofType:@"dtd" inDirectory:@"DTD"]];
				result = [NSString stringWithFormat:@"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"%@\">", [dtd absoluteString]];
				break;
			case KTXHTMLStrictDocType:
				dtd = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"xhtml1-strict" ofType:@"dtd" inDirectory:@"DTD"]];
				result = [NSString stringWithFormat:@"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"%@\">", [dtd absoluteString]];
				break;
			case KTHTML5DocType:
				result = [NSString stringWithFormat:@"<!DOCTYPE html>"];	// Do we do something special to deal with DTDs?
				break;
			default:
				break;
		}
		
	}
	else
	{
		result = [SVHTMLContext stringFromDocType:docType];
	}
	return result;
}

#pragma mark Site Menu

- (void)outputMenuForSiteMenuItems:(NSArray *)anArray treeLevel:(int)aTreeLevel
{
	SVHTMLContext *context = [SVHTMLContext currentContext];
	KTPage *currentParserPage = [[SVHTMLContext currentContext] page];
	
	NSString *className = nil;
	className = [NSString stringWithFormat:@"dd%d", aTreeLevel];
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
			 [NSString stringWithFormat:@"i%d %@%@ currentPage", i, (i%2)?@"o":@"e", (i==last)? @" last" : @""]];
		}
		else
		{
			BOOL isCurrentParent = NO;
			if (!currentParserPage.includeInSiteMenu && page == currentParserPage.parentPage && currentParserPage.parentPage.index)
			{
				isCurrentParent = YES;
			}
			
			[context startElement:@"li" idName:nil className:
			 [NSString stringWithFormat:@"i%d %@%@%@",
			  i,
			  (i%2)?@"o":@"e",
			  (i==last)? @" last" : @"",
			  isCurrentParent ? @" currentParent" : @""
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

- (void)writeHierMenuLoader
{
	HierMenuType hierMenuType = [[[self master] design] hierMenuType];
	if (HIER_MENU_NONE != hierMenuType)
	{
		SVHTMLContext *context = [SVHTMLContext currentContext];
		
		NSURL *ddsmoothmenu = [NSURL fileURLWithPath:[[NSBundle mainBundle]
														pathForResource:@"ddsmoothmenu"
														ofType:@"js"]];
		NSURL *src = [context addResourceWithURL:ddsmoothmenu];
		
		
		NSString *prelude = [NSString stringWithFormat:@"\n%@\n%@\n%@\n%@\n%@", 
 @"/***********************************************",
 @"* Smooth Navigational Menu- (c) Dynamic Drive DHTML code library (www.dynamicdrive.com)",
 @"* This notice MUST stay intact for legal use",
 @"* Visit Dynamic Drive at http://www.dynamicdrive.com/ for full source code",
 @"***********************************************/"];

		[context startJavascriptElementWithSrc:[src absoluteString]];
        [context stopWritingInline];
        [context writeString:prelude];
        [context endElement];

/*
		 These are ddsmoothmenu's options we could set here, or maybe I could modify the JS file that gets uploaded....
		 
		 //Specify full URL to down and right arrow images (23 is padding-right added to top level LIs with drop downs):
		 arrowimages: {down:['downarrowclass', 'down.gif', 23], right:['rightarrowclass', 'right.gif']},
		 transition: {overtime:300, outtime:300}, //duration of slide in/ out animation, in milliseconds
		 shadow: {enable:true, offsetx:5, offsety:5}, //enable shadow?
		 showhidedelay: {showdelay: 100, hidedelay: 200}, //set delay in milliseconds before sub menus appear and disappear, respectively
*/
		
		NSURL *arrowDown = [NSURL fileURLWithPath:[[NSBundle mainBundle]
													  pathForResource:@"down"
													  ofType:@"gif"]];
		NSURL *arrowDownSrc = [context addResourceWithURL:arrowDown];
		NSURL *arrowRight = [NSURL fileURLWithPath:[[NSBundle mainBundle]
												   pathForResource:@"right"
												   ofType:@"gif"]];
		NSURL *arrowRightSrc = [context addResourceWithURL:arrowRight];
		
		[context startJavascriptElementWithSrc:nil];
		
		// [context startJavascriptCDATA];		// probably not needed
		[context writeString:[NSString stringWithFormat:
							  @"ddsmoothmenu.arrowimages = {down:['downarrowclass', '%@', 23], right:['rightarrowclass', '%@']}",
							  [arrowDownSrc absoluteString], [arrowRightSrc absoluteString]]];
		[context writeString:@"\n"];
		[context writeString:[NSString stringWithFormat:
							  @"ddsmoothmenu.init({ mainmenuid: 'sitemenu-content',orientation:'%@', classname:'%@',contentsource:'markup'})",					  
							  (hierMenuType == HIER_MENU_VERTICAL ? @"v" : @"h"),
							  (hierMenuType == HIER_MENU_VERTICAL ? @"ddsmoothmenu-v" : @"ddsmoothmenu")]];
		// [context endJavascriptCDATA];
		[context endElement];
	}
}

- (void)writeSiteMenu
{
	if (self.site.pagesInSiteMenu.count)	// Are there any pages in the site menu?
	{
		SVHTMLContext *context = [SVHTMLContext currentContext];
		[context startNewline];
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
		
		HierMenuType hierMenuType = [[[self master] design] hierMenuType];
		NSMutableArray *forest = [NSMutableArray array];
		if (HIER_MENU_NONE == hierMenuType)
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
			NSString *path = nil;

			// Append appropriate CSS for the site menus.
			HierMenuType hierMenuType = [[[self master] design] hierMenuType];
			// First get the base CSS
			if (HIER_MENU_NONE != hierMenuType)
			{
				path = [[NSBundle mainBundle] overridingPathForResource:@"ddsmoothmenu-base" ofType:@"css"];
                if (path) [context addCSSWithURL:[NSURL fileURLWithPath:path]];
				
			}
			if (HIER_MENU_HORIZONTAL == hierMenuType)
			{
				path = [[NSBundle mainBundle] overridingPathForResource:@"ddsmoothmenu" ofType:@"css"];
                if (path) [context addCSSWithURL:[NSURL fileURLWithPath:path]];
			}
			if (HIER_MENU_VERTICAL == hierMenuType)
			{
				path = [[NSBundle mainBundle] overridingPathForResource:@"ddsmoothmenu-v" ofType:@"css"];
                if (path) [context addCSSWithURL:[NSURL fileURLWithPath:path]];
			}

			
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

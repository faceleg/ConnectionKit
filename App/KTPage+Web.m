//
//  KTPage+Web.m
//  KTComponents
//
//  Created by Dan Wood on 8/9/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import "KTPage+Paths.h"

#import "KT.h"
#import "KTSite.h"
#import "SVApplicationController.h"
#import "SVArchivePage.h"
#import "KTDesign.h"
#import "KTDocument.h"
#import "KTElementPlugInWrapper.h"
#import "SVHTMLTextBlock.h"
#import "SVHTMLTemplateParser.h"
#import "KTMaster.h"
#import "SVPublisher.h"
#import "SVTitleBox.h"
#import "SVWebEditorHTMLContext.h"
#import "SVTemplate.h"

#import "NSBundle+KTExtensions.h"

#import "NSBundle+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+Karelia.h"
#import "KSURLUtilities.h"
#import "NSObject+Karelia.h"
#import "KSStringHTMLEntityUnescaping.h"

#import <WebKit/WebKit.h>

#import "Registration.h"


@interface SVSiteMenuItem : NSObject
{
	SVSiteItem *_siteItem;
	NSMutableArray *_childItems;
}
@property (retain) SVSiteItem *siteItem;
@property (retain) NSMutableArray *childItems;
- (BOOL)containsSiteItem:(SVSiteItem *)aSiteItem;

@end

@implementation SVSiteMenuItem

@synthesize siteItem = _siteItem;
@synthesize childItems = _childItems;

- (id)initWithSiteItem:(SVSiteItem *)aSiteItem
{
	if ((self = [super init]) != nil)
	{
		self.siteItem = aSiteItem;
		self.childItems = [NSMutableArray array];
	}
	return self;
}

- (void)dealloc
{
    [_siteItem release];
    [_childItems release];
    
    [super dealloc];
}

- (BOOL)containsSiteItem:(SVSiteItem *)aSiteItem;
{
	if (self.siteItem == aSiteItem)
	{
		return YES;
	}
	for (SVSiteMenuItem *childMenuItem in self.childItems)
	{
		if ([childMenuItem containsSiteItem:aSiteItem])
		{
			return YES;	// recurse
		}
	}
	return NO;
}

- (NSUInteger)hash
{
	return [[[[self siteItem] objectID] description] hash];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@: %@, children: %@", [self class], self.siteItem, self.childItems];
}

@end



@implementation KTPage (Web)

#pragma mark HTML

- (NSString *)markupString;   // creates a temporary HTML context and calls -writeHTML
{
    SVHTMLContext *context = [[SVHTMLContext alloc] init];	
	[context writeDocumentWithPage:self];
    
    NSString *result = [[context outputStringWriter] string];
    [context release];
    return result;
}

- (NSString *)markupStringForEditing;   // for viewing source for debugging purposes.
{
    SVWebEditorHTMLContext *context = [[SVWebEditorHTMLContext alloc] init];
	[context writeDocumentWithPage:self];
    
	NSString *result = [[context outputStringWriter] string];
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
    SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
    
    SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc] initWithTemplate:[[self class] pageMainContentTemplate]
                                                                        component:[context page]];
    
    [context setCurrentHeaderLevel:2];		// this will let elements increment level so H3 is seen in main body
    [parser parseIntoHTMLContext:context];
    [parser release];
}

#pragma mark Code injection

- (void)write:(SVHTMLContext *)context codeInjectionSection:(NSString *)aKey masterFirst:(BOOL)aMasterFirst;
{
    OBPRECONDITION(context);
    
    if ([context canWriteCodeInjection])
	{
        NSString *masterCode = [[[self master] codeInjection] valueForKey:aKey];
		NSString *pageCode = [[self codeInjection] valueForKey:aKey];
        
        NSString *first, *second;
        if (aMasterFirst)
        {
            first = masterCode; second = pageCode;
        }
        else
        {
            first = pageCode; second = masterCode;
        }
        
        // Use a template parser so that it will weed out any double newlines for us
        SVTemplateParser *templateParser = [SVHTMLTemplateParser currentTemplateParser];
        if (!templateParser)
        {
            templateParser = [[[SVTemplateParser alloc] initWithOutputWriter:context] autorelease];
        }
        
		if (first)
        {
            [templateParser writeString:first];
            [templateParser writeString:@"\n"];
        }
        if (second) [templateParser writeString:second];
    }
}

- (void)writeCodeInjectionSection:(NSString *)aKey masterFirst:(BOOL)aMasterFirst;
{
	SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
    [self write:context codeInjectionSection:aKey masterFirst:aMasterFirst];
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
	SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
    if ([context canWriteCodeInjection])
    {
        NSString *masterCode = [[[self master] codeInjection] valueForKey:@"bodyTag"];
		NSString *pageCode = [[self codeInjection] valueForKey:@"bodyTag"];
		
		if (masterCode)				[context writeString:masterCode];
		if (masterCode && pageCode)	[context writeCharacters:@" "];	// space in between, only if we have both
		if (pageCode)				[context writeString:pageCode];
    }
}

#pragma mark Comments

- (NSString *)commentsTemplate	// instance method too for key paths to work in tiger
{
	static NSString *result;
	
	if (!result)
	{
		NSString *templatePath = [[NSBundle mainBundle] overridingPathForResource:@"KTCommentsTemplate" ofType:@"html"];
		result = [[NSString alloc] initWithContentsOfFile:templatePath];
	}
	
	return result;
}

#pragma mark thumbnail

- (void)writeThumbnailRel	// For facebook, digg, Yahoo, MySpace, etc.
{
    SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
	NSURL *URL = [context URLForImageRepresentationOfPage:self
													width:90 height:90	// This seems to be largest size used by facebook. Yahoo is 98x54?
												  options:0];
	if (URL)
	{
		NSString *href = [URL absoluteString];	// leave it an absolute URL for Facebook's benefit
		
		NSString *pathExtension = [[URL path] pathExtension];
		NSString *UTI = [KSWORKSPACE ks_typeForFilenameExtension:pathExtension];
		NSString *mimeType = [KSWORKSPACE ks_MIMETypeForType:UTI];
		
		[context pushAttribute:@"rel" value:@"image_src"];
		[context pushAttribute:@"href" value:href];
		[context pushAttribute:@"type" value:mimeType];
		[context startElement:@"link"];
		[context endElement];
	}
}

#pragma mark CSS

/*  Used by KTPageTemplate.html to generate links to the stylesheets needed by this page. Used to be a dedicated [[stylesheet]] parser function
 */
- (void)writeStylesheetLinks
{
    SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
    NSString *path = nil;
	
	// Bring in any import" statements that the design wants
	KTDesign *design = [[self master] design];
	NSArray *imports = [design imports];
	for (NSString *urlString in imports)
	{
        [context writeLinkToStylesheet:urlString
                                 title:nil
                                 media:nil];
	}
	
	// Bring in any IE conditional comment stylesheets that the design wants.
	// Since the @import statements we used to use were generally at
	// the start of the file, it's best to load these *before* the main style sheet.
	NSDictionary *conditionalCommentsForIE = [design conditionalCommentsForIE];
	for (NSString *predicate in conditionalCommentsForIE)
	{
		NSString *ieFile = [conditionalCommentsForIE objectForKey:predicate];
		NSURL *ieURL = [context URLOfDesignFile:ieFile];
		
		[context openComment];
		[context writeString:[NSString stringWithFormat:@"[if %@]>", predicate]];		// Do not escape XML
		[context writeLinkToStylesheet:[context relativeStringFromURL:ieURL]
								 title:nil
								 media:nil];
		[context writeString:@"<![endif]"];		// Do not escape XML
		[context closeComment];
	}
	
    // Write link to main.CSS file -- the most specific
    NSURL *mainCSSURL = [context mainCSSURL];
    if (mainCSSURL)
    {
        [context writeLinkToStylesheet:[context relativeStringFromURL:mainCSSURL]
                                 title:[[[self master] design] title]
                                 media:nil];
    }
	
	
	// design's print.css but not for Quick Look
    if ([context isForPublishing])
	{
        NSURL *printCSSURL = [context URLOfDesignFile:@"print.css"];
        if ( printCSSURL )
        {
            path = [context relativeStringFromURL:printCSSURL];
            if (path)
            {
                [context writeLinkToStylesheet:path title:nil media:@"print"];
            }
        }
	}
    
    if (![context isForPublishing])    // during publishing, pub engine will take care of design CSS
    {
        // Load up DESIGN CSS, which might override the generic stuff
        KTDesign *design = [[self master] design];
        [design writeCSS:context];
        
        
        // For preview/quicklook mode, the banner CSS (after the design's main.css)
        [[self master] writeBannerCSS:context];
        
		// Finally, the stuff that is code-injected.
		[[self master] writeCodeInjectionCSS:context];
    }
}

#pragma mark Publishing

- (void)publish:(id <SVPublisher>)publishingEngine recursively:(BOOL)recursive;
{
    if ([publishingEngine isCancelled]) return;
    
    
	NSUInteger itemIndex = [publishingEngine incrementingCountOfPublishedItems];
    BOOL canBePublished = ((nil != gRegistrationString) && !gLicenseIsBlacklisted);	// OK if licensed, and not blacklisted...
	
    if (!canBePublished)
	{
		// Check and see if it's in the first few
		DJW((@"itemIndex:%d   %@", itemIndex, [[self URL] path]));
		if (itemIndex < kMaxNumberOfFreePublishedPages)
		{
			canBePublished = YES;
		}
	}
	// If not canBePublished, put up a placeholder page instead.
	
    
    /*  HTML writing tends to create a lot of temporary objects, so wrap in pools
     */
    
    
    NSAutoreleasePool *pool1 = [[NSAutoreleasePool alloc] init];
    
    NSString *path = [self uploadPath]; // needs to be in the outer pool
    SVHTMLContext *context = [publishingEngine beginPublishingHTMLToPath:path];
	
    NSAutoreleasePool *pool2 = [[NSAutoreleasePool alloc] init];
	
	if (canBePublished)
	{
		[context writeDocumentWithPage:self];
		OFF((@"publishing  %@", [[self URL] path]));
	}
	else	// publish a placeholder instead
	{
		
		// is this the right way to do it?
		
		static SVTemplate *sUnpublishedTemplate = nil;
		if (!sUnpublishedTemplate)
		{
			sUnpublishedTemplate = [[SVTemplate templateNamed:@"UnpublishedTemplate.html"] retain];
			
			// For template:
			// NSLocalizedString(@"This page has not been published, because the webmaster is using a demo of Sandvox.", @"Note as to why a page wasn't published");
		}

		SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc]
                                        initWithTemplate:[sUnpublishedTemplate templateString]
                                        component:self];
        
        [parser parseIntoHTMLContext:context];
        [parser release];
		DJW((@"PLACEHOLDER %@", [[self URL] path]));
	}
    [pool2 release];
    
    
	// Generate and publish RSS feed if needed
	if (canBePublished && [[self collectionSyndicationType] boolValue])
	{
        pool2 = [[NSAutoreleasePool alloc] init];
        
		NSString *RSSFilename = [self RSSFileName];
        NSString *RSSUploadPath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:RSSFilename];
        
        SVHTMLContext *context2 = [publishingEngine beginPublishingHTMLToPath:RSSUploadPath];
        [context2 setBaseURL:nil]; // #103807
        [self writeRSSFeed:context2];
        [context2 close];
        
        [pool2 release];
	}
    
    if (canBePublished)
	{
		// Publish archives
		for (SVArchivePage *anArchivePage in [self archivePages])
		{
			pool2 = [[NSAutoreleasePool alloc] init];
			
			SVHTMLContext *context3 = [publishingEngine beginPublishingHTMLToPath:
									   [anArchivePage uploadPath]];
			[context setBaseURL:[anArchivePage URL]]; // have to set manually. #98791
			
			[context3 writeDocumentWithArchivePage:anArchivePage];
			[context3 close];
			
			[pool2 release];
		}
	}
    
    
    // Publish the page
    [context close];
    [pool1 release];
    
	if (recursive)
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
- (void)writeDesignJavascript	// loaded after jquery so this can contain jquery in it.
{
	NSBundle *designBundle = [[[self master] design] bundle];
	NSString *scriptPath = [designBundle pathForResource:@"javascript" ofType:@"js"];
    
	if (scriptPath)
	{
        SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
        
        NSURL *url = [context addResourceAtURL:[NSURL fileURLWithPath:scriptPath]
                                   destination:SVDestinationDesignDirectory
                                       options:0];
        
		[context writeJavascriptWithSrc:[context relativeStringFromURL:url] encoding:NSUTF8StringEncoding];
	}
}

#pragma mark Window Title

/*!	Return the string that makes up the title.  Page Title | Site Title | Author ... this is the DEFAULT if not set by windowTitle property.
*/
- (NSString *)comboTitleText
{
	if (self.windowTitle && ![self.windowTitle isEqualToString:@""])
	{
		return self.windowTitle;
	}
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

- (void)setComboTitleText:(NSString *)aTitle
{
	[self setWindowTitle:aTitle];
}

+ (NSSet *)keyPathsForValuesAffectingComboTitleText;
{
    return [NSSet setWithObjects:@"titleBox.text", @"master.siteTitle.textHTMLString", @"master.author", nil];
}

#pragma mark DTD

// For code review:  Where can this utility class go?
+ (NSString *)stringFromDocType:(NSString *)docType local:(BOOL)isLocal;		// UTILITY
{
    OBPRECONDITION(docType);
    
	NSMutableString *result = [NSMutableString string];
    KSHTMLWriter *writer = [[KSHTMLWriter alloc] initWithOutputWriter:result];
    
	if (isLocal)
	{
		NSURL *dtd = nil;
        
		if ([docType isEqualToString:KSHTMLWriterDocTypeHTML_4_01_Strict] ||
            [docType isEqualToString:KSHTMLWriterDocTypeHTML_4_01_Transitional] ||
            [docType isEqualToString:KSHTMLWriterDocTypeHTML_4_01_Frameset])
        {
    		dtd = nil;	// don't load a local DTD for HTML 4.01
            result = [NSString stringWithFormat:@"<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"%@\">", [dtd absoluteString]];
        }
        else if ([docType isEqualToString:KSHTMLWriterDocTypeXHTML_1_0_Transitional] ||
                 [docType isEqualToString:KSHTMLWriterDocTypeXHTML_1_0_Frameset])
        {
            dtd = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"xhtml1-transitional" ofType:@"dtd" inDirectory:@"DTD"]];
            result = [NSString stringWithFormat:@"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"%@\">", [dtd absoluteString]];
        }
        else if	([docType isEqualToString:KSHTMLWriterDocTypeXHTML_1_0_Strict])
        {
            dtd = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"xhtml1-strict" ofType:@"dtd" inDirectory:@"DTD"]];
            result = [NSString stringWithFormat:@"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"%@\">", [dtd absoluteString]];
        }
        else if ([docType isEqualToString:KSHTMLWriterDocTypeHTML_5])
        {
            result = [NSString stringWithFormat:@"<!DOCTYPE html>"];	// Do we do something special to deal with DTDs?
		}
		
	}
	else
	{
		[writer startDocumentWithDocType:docType encoding:NSUTF8StringEncoding];
	}
    
    [writer release];
	return result;
}

#pragma mark Site Menu

- (void)writeMenu:(SVHTMLContext *)context
 forSiteMenuItems:(NSArray *)anArray
        treeLevel:(int)aTreeLevel
{
	KTPage *currentParserPage = [context page];
    
	if (0 == aTreeLevel)
	{
		[context startElement:@"ul"];
	}
	else
	{
		[context startElement:@"ul" writeInline:YES];		// for Webkit bug, don't have white space in here 
	}
    
	int i=1;	// 1-based iteration
	int last = [anArray count];
    
	for (SVSiteMenuItem *item in anArray)
	{
		SVSiteItem *siteItem = item.siteItem;
		NSArray *children = item.childItems;

		[context pushClassName:[NSString stringWithFormat:@"i%d", i]];
		[context pushClassName:(i%2)?@"o":@"e"];
		if (i == last)
		{
			[context pushClassName:@"last"];
		}
		if ([children count])
		{
			[context pushClassName:@"hasSubmenu"];
		}
		
		if (siteItem == currentParserPage)
		{
			[context pushClassName:@"currentPage"];
		}
		else
		{
			BOOL isCurrentParent = (currentParserPage != siteItem
									&& [currentParserPage isDescendantOfItem:siteItem]
									&& ![siteItem isRoot]		// Don't include currentParent for Root since it owns it all!
									// NOT USEFUL FOR NON-H-MENU ?  && [item containsSiteItem:currentParserPage]
									);
			OFF((@"%d .... current = %@ siteItem = %@", isCurrentParent, currentParserPage, siteItem));
			if (isCurrentParent)
			{
				[context pushClassName:@"currentParent"];
			}
		}
		[context startElement:@"li" writeInline:YES];

		// start the anchor
		if (siteItem != currentParserPage)
		{
			[context startAnchorElementWithPage:siteItem];
		}
		
		// Build a text block
		SVHTMLTextBlock *textBlock = [[[SVHTMLTextBlock alloc] init] autorelease];
		
		[textBlock setEditable:NO];
		[textBlock setFieldEditor:NO];
		[textBlock setRichText:NO];
		[textBlock setImportsGraphics:NO];
		[textBlock setTagName:@"span"];
		
		[textBlock setHTMLSourceObject:siteItem];
		[textBlock setHTMLSourceKeyPath:@"menuTitleHTMLString"];
		
		[textBlock writeHTML:context];
		
		if (siteItem != currentParserPage)
		{
			[context endElement];	// a
		}
		
		if ([children count])
		{
			[self writeMenu:context forSiteMenuItems:children treeLevel:aTreeLevel+1];
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


// Create the site menu forest.  Needed in both writeHierMenuScript and writeHierMenuCSS and writeSiteMenu.  Maybe cache value later?

- (NSArray *)createSiteMenuForestIsHierarchical:(BOOL *)outHierarchical;
{
	BOOL isHierarchical = NO;
	KTSite *site = self.site;
	NSArray *pagesInSiteMenu = site.pagesInSiteMenu;

	HierMenuType hierMenuType = [[[self master] design] hierMenuType];
	NSMutableArray *forest = [NSMutableArray array];
	if (HIER_MENU_NONE == hierMenuType)
	{
		// Flat menu, either by design's preference or user default
		for (SVSiteItem *siteMenuItem in pagesInSiteMenu)
		{
			if ([siteMenuItem shouldIncludeInSiteMenu])
			{
				SVSiteMenuItem *item = [[[SVSiteMenuItem alloc] initWithSiteItem:siteMenuItem] autorelease];
				[forest addObject:item];
			}
		}
	}
	else	// hierarchical menu
	{
		// build up the hierarchical site menu.
		// Array of dictionaries keyed with "page" and "children" array
		NSMutableArray *childrenLookup = [NSMutableArray array];
		// Assume we are traversing tree in sorted order, so children will always be found after parent, which makes it easy to build this tree.
		for (SVSiteItem *siteMenuItem in pagesInSiteMenu)
		{
			if ([siteMenuItem shouldIncludeInSiteMenu])
			{
				BOOL wasSubPage = NO;
				KTPage *parent = (KTPage *)siteMenuItem;		// Parent will *always* be a KTPage once we calculate it
				SVSiteMenuItem *item = nil;
				do // loop through, looking to see if this (or parent) page is a sub-page of an already-found page in the site menu.
				{
					SVSiteMenuItem *itemToAddTo = nil;
					// See if this is already known about
					for (SVSiteMenuItem *checkItem in childrenLookup)
					{
						if (checkItem.siteItem == parent)
						{
							itemToAddTo = checkItem;
							break;
						}
					}					
					if (itemToAddTo)	// Was there a parent menu item?
					{
						// If so, create a new entry for this page, with an empty array of children; add to list of children
						item = [[[SVSiteMenuItem alloc] initWithSiteItem:siteMenuItem] autorelease];
						[itemToAddTo.childItems addObject:item];
						parent = nil;	// stop looking
						wasSubPage = YES;
						isHierarchical = YES;		// there is a hierarchical menu here
					}
					else // No, this page (or its parent) was not in the menu list so go up one level to keep looking.
					{
						parent = [parent parentPage];
					}
				}
				while (nil != parent && ![parent isRoot]);	// Stop when we reach root. Note that we don't put items under root.
				
				if (!item)
				{
					item = [[[SVSiteMenuItem alloc] initWithSiteItem:siteMenuItem] autorelease];
				}
				[childrenLookup addObject:item];		// quick lookup from page to children
				
				if (!wasSubPage)	// Not a sub-page, so it's a top-level menu item.
				{
					[forest addObject:item];		// Add to our list of top-level menus
				}
			}
		}	// end for
	}
	if (outHierarchical)
	{
		*outHierarchical = isHierarchical;
	}
	return forest;
}

- (void)writeHierMenuCSS;		// this has to go above our design's CSS
{
	HierMenuType hierMenuType = [[[self master] design] hierMenuType];
	if (HIER_MENU_NONE != hierMenuType && self.site.pagesInSiteMenu.count)
	{
		// Now check if we *really* have a hierarchy.  No point in writing out loader if site menu is flat.
		BOOL isHierarchical = NO;
		(void) [self createSiteMenuForestIsHierarchical:&isHierarchical];
		if (isHierarchical)
		{
			SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
			
			NSString *path = nil;
			NSURL *src = nil;
			NSString *srcPath = nil;
			
			// Note: We want to add the CSS as a separate link; *not* merging it into main.css, so that it can access the arrow images in _Resources.
			path = [[NSBundle mainBundle] overridingPathForResource:@"ddsmoothmenu" ofType:@"css"];
			src = [context addResourceAtURL:[NSURL fileURLWithPath:path] destination:SVDestinationResourcesDirectory options:0];
			srcPath = [context relativeStringFromURL:src];
			
			[context writeLinkToStylesheet:srcPath title:nil media:nil];	// nil title; we don't want a title! https://bugs.webkit.org/show_bug.cgi?id=43870
		}
	}
}

- (void)writeHierMenuScript;
{
	HierMenuType hierMenuType = [[[self master] design] hierMenuType];
	if (HIER_MENU_NONE != hierMenuType && self.site.pagesInSiteMenu.count)
	{
		// Now check if we *really* have a hierarchy.  No point in writing out loader if site menu is flat.
		BOOL isHierarchical = NO;
		(void) [self createSiteMenuForestIsHierarchical:&isHierarchical];
		if (isHierarchical)
		{
			SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
			
			NSString *path = nil;
			NSURL *src = nil;
			NSString *srcPath = nil;
						
			path = [[NSBundle mainBundle] overridingPathForResource:@"ddsmoothmenu" ofType:@"js"];
			src = [context addResourceAtURL:[NSURL fileURLWithPath:path] destination:SVDestinationResourcesDirectory options:0];
			srcPath = [context relativeStringFromURL:src];
			
			NSString *prelude = [NSString stringWithFormat:@"\n%@\n%@\n%@\n%@\n%@", 
@"/***********************************************",
@"* Smooth Navigational Menu- (c) Dynamic Drive DHTML code library (www.dynamicdrive.com)",
@"* This notice MUST stay intact for legal use",
@"* Visit Dynamic Drive at http://www.dynamicdrive.com/ for full source code",
@"***********************************************/"];
			
			[context startJavascriptElementWithSrc:srcPath];
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
			NSURL *arrowDownSrc = [context addResourceAtURL:arrowDown destination:SVDestinationResourcesDirectory options:0];

			NSURL *arrowRight = [NSURL fileURLWithPath:[[NSBundle mainBundle]
														pathForResource:@"right"
														ofType:@"gif"]];
			NSURL *arrowRightSrc = [context addResourceAtURL:arrowRight destination:SVDestinationResourcesDirectory options:0];
			
			[context startJavascriptElementWithSrc:nil];
			
			// [context startJavascriptCDATA];		// probably not needed
			[context writeString:[NSString stringWithFormat:
								  @"ddsmoothmenu.arrowimages = {down:['downarrowclass', '%@', 23], right:['rightarrowclass', '%@']}",
								  [context relativeStringFromURL:arrowDownSrc], [context relativeStringFromURL:arrowRightSrc]]];
			[context writeString:@"\n"];
			
			BOOL isVertical = hierMenuType == HIER_MENU_VERTICAL || (hierMenuType == HIER_MENU_VERTICAL_IF_SIDEBAR && [[self showSidebar] boolValue]);
			
			[context writeString:[NSString stringWithFormat:
								  @"ddsmoothmenu.init({ mainmenuid: 'sitemenu-content',orientation:'%@', classname:'%@',contentsource:'markup'})",					  
								  (isVertical ? @"v" : @"h"),
								  (isVertical ? @"ddsmoothmenu-v" : @"ddsmoothmenu")]];
			// [context endJavascriptCDATA];
			[context endElement];
		}
	}
}

- (void)writeSiteMenu
{
	// Add dependency whether or not there are any in the site menu, so we can get messages even if there are zero pages in it.
	SVHTMLContext *context = [[SVHTMLTemplateParser currentTemplateParser] HTMLContext];
	[context addDependencyOnObject:self keyPath:@"site.pagesInSiteMenu"];

	if (self.site.pagesInSiteMenu.count)	// Are there any pages in the site menu?
	{
		[context startElement:@"div" idName:@"sitemenu" className:nil];			// <div id="sitemenu">
		[context startElement:@"h2" idName:nil className:@"hidden"];				// hidden skip navigation menu
		[context writeString:
		 NSLocalizedStringWithDefaultValue(@"skipNavigationTitleHTML", nil, [NSBundle mainBundle], @"Site Navigation", @"Site navigation title on web pages (can be empty if link is understandable)")];

		[context startAnchorElementWithHref:@"#page-content" title:nil target:nil rel:@"nofollow"];
		[context writeString:NSLocalizedStringWithDefaultValue(@"skipNavigationLinkHTML", nil, [NSBundle mainBundle], @"[Skip]", @"Skip navigation LINK on web pages")];
		
		[context endElement];	// a
		[context endElement];	// h2
		
		
		[context startElement:@"div" idName:@"sitemenu-content" className:nil];		// <div id="sitemenu-content">
	
		
		NSArray *forest = [self createSiteMenuForestIsHierarchical:nil];
		[self writeMenu:context forSiteMenuItems:forest treeLevel:0];

		
		
		[context writeEndTagWithComment:@"/sitemenu-content"];
		[context writeEndTagWithComment:@"/sitemenu"];
	}
}

@end

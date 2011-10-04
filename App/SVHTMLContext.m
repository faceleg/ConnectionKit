//
//  SVHTMLContext.m
//  Sandvox
//
//  Created by Mike on 19/10/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVWebEditorHTMLContext.h"

#import "SVCallout.h"
#import "KTDesign.h"
#import "SVEnclosure.h"
#import "KTHostProperties.h"
#import "SVHTMLTemplateParser.h"
#import "SVHTMLTextBlock.h"
#import "KTImageScalingSettings.h"
#import "KTImageScalingURLProtocol.h"
#import "KTMaster.h"
#import "SVMediaGraphic.h"
#import "SVMediaRequest.h"
#import "KTPage.h"
#import "SVPagesController.h"
#import "SVSidebarDOMController.h"
#import "KTSite.h"
#import "SVTemplate.h"
#import "SVTextAttachment.h"
#import "SVTextBox.h"
#import "SVTitleBox.h"
#import "SVWebEditingURL.h"
#import "NSBundle+KTExtensions.h"

#import "SVCalloutDOMController.h"  // don't like having to do this

#import "NSIndexPath+Karelia.h"
#import "NSString+Karelia.h"
#import "KSURLUtilities.h"
#import "NSObject+Karelia.h"

#import "KSPathUtilities.h"
#import "KSSHA1Stream.h"
#import "KSBufferedWriter.h"

#import "Registration.h"

#import <Connection/Connection.h>


NSString * const SVDestinationResourcesDirectory = @"_Resources";
NSString * const SVDestinationDesignDirectory = @"_Design";
NSString * const SVDestinationMainCSS = @"_Design/main.css";


@interface SVHTMLIterator : NSObject
{
    NSUInteger  _iteration;
    NSUInteger  _count;
}

- (id)initWithCount:(NSUInteger)count;
@property(nonatomic, readonly) NSUInteger count;

@property(nonatomic, readonly) NSUInteger iteration;
- (NSUInteger)nextIteration;

@end


@interface SVHTMLContext ()

- (void)pushAttributes:(NSDictionary *)attributes;

- (SVHTMLIterator *)currentIterator;

- (void)startPlaceholder;
- (void)endPlaceholder;

- (NSMutableString *)endBodyMarkup; // can append to, query, as you like while parsing

@end


#pragma mark -


@implementation SVHTMLContext

#pragma mark Init & Dealloc

- (id)initWithOutputWriter:(id)output; // designated initializer
{
    if (!output || [output conformsToProtocol:@protocol(KSMultiBufferingWriter)])
    {
        if (self = [super initWithOutputWriter:output])
        {
            _buffer = [output retain];
            
            _includeStyling = YES;
            
            _liveDataFeeds = YES;
            
            _headerLevel = 1;
            
            _preHTMLMarkup = [[NSMutableArray alloc] init];
            _extraHeadMarkup = [[NSMutableArray alloc] init];
            _endBodyMarkup = [[NSMutableString alloc] init];
            _iteratorsStack = [[NSMutableArray alloc] init];
            _graphicContainers = [[NSMutableArray alloc] init];
        }
    }
    else
    {
        KSStringWriter *stringWriter = [[KSBufferedWriter alloc] initWithOutputWriter:output];
        self = [self initWithOutputWriter:stringWriter];
        [stringWriter release];
    }
    
    return self;
}

- (id)initWithOutputWriter:(id <KSWriter>)output inheritFromContext:(SVHTMLContext *)context;
{
	OBPRECONDITION(context);
    NSStringEncoding encoding = (context ? [context encoding] : NSUTF8StringEncoding);
    
    if (self = [self initWithOutputWriter:output docType:[context docType] encoding:encoding])
    {
        // Copy across properties
        [self setIndentationLevel:[context indentationLevel]];
        _currentPage = [[context page] retain];
        _baseURL = [[context baseURL] copy];
        [self setIncludeStyling:[context includeStyling]];
        [self setLiveDataFeeds:[context liveDataFeeds]];
        _sidebarPageletsController = [context->_sidebarPageletsController retain];
    }
    
    return self;
}

- (void)dealloc
{
    [_language release];
    [_baseURL release];
    [_currentPage release];
    [_article release];
    
    [_mainCSSURL release];
    
    [_preHTMLMarkup release];
    [_extraHeadMarkup release];
    [_endBodyMarkup release];
    [_iteratorsStack release];
    [_graphicContainers release];
    
    [_sidebarPageletsController release];
    
    [super dealloc];
}

#pragma mark Status

- (BOOL)isWritingPagelet; { return _writingPagelet; }

#pragma mark Document

- (void)startDocumentWithPage:(KTPage *)page
{
    OBPRECONDITION(page);
    
    
    // Store the page
    [page retain];
    [_currentPage release]; _currentPage = page;
    
    id article = [[page article] retain];
    [_article release]; _article = article;
    
    
	// Prepare global properties
    [self setLanguage:[[page master] language]];
    
    
    // For publishing, want to know the URL of main.css *on the server*
    if (![self isForEditing])
    {
        NSURL *cssURL = [self URLOfDesignFile:@"main.css"];
        [_mainCSSURL release]; _mainCSSURL = [cssURL copy];
    }
    
    
    // First Code Injection.  Can't use a convenience method since we need this context.  Make sure this matches the convenience methods though!
	[self writePreHTMLMarkup];
    [page write:self codeInjectionSection:@"beforeHTML" masterFirst:YES];
    
    
    // Start the document
    [self startDocumentWithDocType:KSHTMLWriterDocTypeHTML_5
                          encoding:[[[page master] charset] encodingFromCharset]];
    
    
    // Global CSS
    NSString *path = [[NSBundle mainBundle] pathForResource:@"sandvox" ofType:@"css"];
    if (path) [self addResourceAtURL:[NSURL fileURLWithPath:path] destination:SVDestinationMainCSS options:0];
}

- (void)writeDocumentContentsWithPage:(KTPage *)page;
{
    // It's template time!
	SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc] initWithPage:page];
    [parser parseIntoHTMLContext:self];
    [parser release];
    
    
    // If we're for editing, include additional editing CSS. Used to write the design CSS just here as well, but that interferes with animations. #96704
	if ([self isForEditing])
	{
		NSString *editingCSSPath = [[NSBundle mainBundle] pathForResource:@"design-time"
                                                                   ofType:@"css"];
        if (editingCSSPath) [self addResourceAtURL:[NSURL fileURLWithPath:editingCSSPath] destination:SVDestinationMainCSS options:0];
	}    
}

- (void)writeDocumentWithPage:(KTPage *)page;
{
    [self startDocumentWithPage:page];
    [self writeDocumentContentsWithPage:page];
    [self flush];   // so any extra headers etc. get written
}

- (void)writeDocumentWithArchivePage:(SVArchivePage *)archive;
{
    KTPage *collection = [archive collection];
    [self startDocumentWithPage:collection];
    
    [self setBaseURL:[archive URL]];
    
    [_article release];
    _article = [archive retain];
    
    [self writeDocumentContentsWithPage:collection];
}

- (void)writeJQueryImport
{
	// We might want to update this if a major new stable update comes along. We'd put fresh copies in the app resources.
#define JQUERY_BUNDLED_VERSION @"1.5.2"
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSURL *jQueryURL = nil;
	NSString *minimizationSuffix = @".min";
	if ([defaults boolForKey:@"jQueryDebug"])
	{
		minimizationSuffix = @"";	// Empty suffix means we'll bring in the non minimized version.
	}
	

	NSString *scheme = [self.baseURL scheme];
	if (!scheme) scheme = @"http";		// for instance, when newly set up. Better to show something for page source.

	NSString *jQueryPreferredVersion = JQUERY_BUNDLED_VERSION;	// try this initially
	if ([defaults stringForKey:@"jQueryVersion"])
	{
		jQueryPreferredVersion = [defaults stringForKey:@"jQueryVersion"];	// Version we will link to, or try to bundle.
	}
	
	// This is either the local version, or not uploaded to a web server, or user preference to keep their own copy of jQuery.
	// Use the overridingPathForResource method to try and look in an installed place.
	if ([self isForEditing] || [scheme isEqualToString:@"file"] || [defaults boolForKey:@"jQueryLocal"])
	{
		NSString *localJQueryPath = [[NSBundle mainBundle]
									 overridingPathForResource:[NSString stringWithFormat:@"jquery-%@%@", jQueryPreferredVersion, minimizationSuffix]
									 ofType:@"js"];
		if (!localJQueryPath)	// Not finding the version we hoped to find?
		{
			localJQueryPath = [[NSBundle mainBundle]
							   pathForResource:[NSString stringWithFormat:@"jquery-%@%@", JQUERY_BUNDLED_VERSION, minimizationSuffix]
							   ofType:@"js"];
		}
		NSURL *localJQueryURL = [NSURL fileURLWithPath:localJQueryPath];
		
		jQueryURL = [self addResourceAtURL:localJQueryURL destination:SVDestinationResourcesDirectory options:0];
		
		// One enhancement we could do would be to download and cache that file ourselves rather than requiring people to install it!
		
	}
	else	// Normal publishing case: remote version from google, fastest for downloading.
			// Match http/https scheme of uploaded site.
	{
		jQueryURL = [NSURL URLWithString:
					 [NSString stringWithFormat:@"%@://ajax.googleapis.com/ajax/libs/jquery/%@/jquery%@.js",
					  scheme, jQueryPreferredVersion, minimizationSuffix]];
	}
	
	[self writeJavascriptWithSrc:[self relativeStringFromURL:jQueryURL] encoding:NSUTF8StringEncoding];
    
	// Note: I may want to also get: http://ajax.googleapis.com/ajax/libs/jqueryui/1.8.2/jquery-ui.min.js
	// I would just put in parallel code.  However this might be better to be added with code injection by people who want it.
}

#pragma mark Properties

@synthesize outputStringWriter = _buffer;
@synthesize totalCharactersWritten = _charactersWritten;

@synthesize baseURL = _baseURL;
@synthesize liveDataFeeds = _liveDataFeeds;
@synthesize language = _language;

#pragma mark Doctype

+ (NSString *)nameOfDocType:(NSString *)docType localize:(BOOL)shouldLocalizeForDisplay;
{
	NSString *result = nil;
	NSString *localizedResult = nil;
	
    if ([docType isEqualToString:KSHTMLWriterDocTypeHTML_4_01_Strict] ||
        [docType isEqualToString:KSHTMLWriterDocTypeHTML_4_01_Transitional] ||
        [docType isEqualToString:KSHTMLWriterDocTypeHTML_4_01_Frameset])
	{
        result = @"HTML 4.01 Transitional";
        localizedResult = NSLocalizedString(@"HTML 4.01", @"Description of style of HTML - note that we do not say Transitional");
    }
    else if ([docType isEqualToString:KSHTMLWriterDocTypeXHTML_1_0_Transitional] ||
             [docType isEqualToString:KSHTMLWriterDocTypeXHTML_1_0_Frameset])
    {
        result = @"XHTML 1.0 Transitional";
        localizedResult = NSLocalizedString(@"XHTML 1.0 Transitional", @"Description of style of HTML");
    }
    else if	([docType isEqualToString:KSHTMLWriterDocTypeXHTML_1_0_Strict])
    {
        result = @"XHTML 1.0 Strict";
        localizedResult = NSLocalizedString(@"XHTML 1.0 Strict", @"Description of style of HTML");
    }
    else if ([docType isEqualToString:KSHTMLWriterDocTypeHTML_5])
    {
        result = @"HTML5";
        localizedResult = NSLocalizedString(@"HTML5", @"Description of style of HTML");
	}
        
	return shouldLocalizeForDisplay ? localizedResult : result;
}

#pragma mark Purpose

- (KTHTMLGenerationPurpose)generationPurpose; { return kSVHTMLGenerationPurposeNormal; }

- (BOOL)isForEditing; { return [self generationPurpose] == kSVHTMLGenerationPurposeEditing; }

- (BOOL)isEditable { return [self isForEditing]; }  // left in for compat. for now
+ (NSSet *)keyPathsForValuesAffectingEditable
{
    return [NSSet setWithObject:@"generationPurpose"];
}

- (BOOL)isForQuickLookPreview;
{
    BOOL result = [self generationPurpose] == kSVHTMLGenerationPurposeQuickLookPreview;
    return result;
}

- (BOOL)isForPublishing
{
    BOOL result = [self generationPurpose] == kSVHTMLGenerationPurposeNormal;
    return result;
}

// Similar to above, but might be overridden by subclass to prevent sending to HTML validator
- (BOOL)shouldWriteServerSideScripts; { return [self isForPublishing]; }

- (BOOL)canWriteCodeInjection;
{
	return [self isForPublishing]
			// Show the code injection in the webview as well, as long as this default is set.
			|| ([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowCodeInjectionInPreview"] && [self isForEditing]);
}

#pragma mark CSS

@synthesize includeStyling = _includeStyling;

@synthesize mainCSSURL = _mainCSSURL;

- (NSURL *)addCSSString:(NSString *)css;
{
    OBPRECONDITION(css);
    
    if ([self isForPublishing])
    {
        return [self mainCSSURL];
    }
    else
    {
        if (_extraHeadBuffer > 0)
        {
            NSMutableString *html = [[NSMutableString alloc] init];
            KSHTMLWriter *writer = [[KSHTMLWriter alloc] initWithOutputWriter:html];
            
            [writer writeStyleElementWithCSSString:css];
            [writer writeString:@"\n"];
            
            [self addMarkupToHead:html];
            [html release];
            [writer release];
        }
        else
        {
            [self writeStyleElementWithCSSString:css];
        }
        
        return nil;
    }
}

- (NSURL *)addCSSWithURL:(NSURL *)cssURL;
{
    return [self addResourceAtURL:cssURL destination:SVDestinationMainCSS options:0];
}

- (NSURL *)addCSSWithTemplateAtURL:(NSURL *)templateURL object:(id)object;
{
    // Run through template
    NSString *css = [self parseTemplateAtURL:templateURL object:object];
    return [self addCSSString:css];
}

#pragma mark Header Tags

@synthesize currentHeaderLevel = _headerLevel;

- (NSString *)currentHeaderLevelTagName;
{
    NSString *result = [NSString stringWithFormat:@"h%u", [self currentHeaderLevel]];
    return result;
}

- (void)incrementHeaderLevel;
{
    [self setCurrentHeaderLevel:[self currentHeaderLevel] + 1];
}

- (void)decrementHeaderLevel;
{
    [self setCurrentHeaderLevel:[self currentHeaderLevel] - 1];
}

- (NSUInteger)startHeadingWithAttributes:(NSDictionary *)attributes;
{
    [self startElement:[self currentHeaderLevelTagName] attributes:attributes];
    return [self currentHeaderLevel];
}

#pragma mark Elements/Comments

// Override to sort the keys so that they are always consistently written.
- (void)startElement:(NSString *)elementName attributes:(NSDictionary *)attributes;
{
	[self pushAttributes:attributes];
    [self startElement:elementName];
}

- (void)pushAttributes:(NSDictionary *)attributes;
{
    NSArray *sortedAttributes = [[attributes allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    for (NSString *aName in sortedAttributes)
    {
        NSString *aValue = [attributes objectForKey:aName];
        [self pushAttribute:aName value:aValue];
    }
}

#pragma mark Preferred ID

- (NSString *)pushPreferredIdName:(NSString *)preferredID;
{
    NSString *result = preferredID;
    NSUInteger count = 1;
    while (![self isIDValid:result])
    {
        count++;
        result = [NSString stringWithFormat:@"%@-%u", preferredID, count];
    }
    
    [self pushAttribute:@"id" value:result];
    
    return result;
}

- (NSString *)startElement:(NSString *)tagName
           preferredIdName:(NSString *)preferredID
                 className:(NSString *)className
                attributes:(NSDictionary *)attributes;
{
    NSString *result = [self pushPreferredIdName:preferredID];
    [self pushAttributes:attributes];
    [self startElement:tagName className:className];
    
    return result;
}

#pragma mark Graphics

- (void)writeGraphic:(id <SVGraphic>)graphic;
{
    // Update number of graphics
    _numberOfGraphics++;
    BOOL written = NO;
    
    id <SVComponent> container = [self currentGraphicContainer];
    if ([container respondsToSelector:@selector(HTMLContext:writeGraphic:)])
    {
        if ([graphic isPagelet])
        {
            _writingPagelet = YES;
            @try
            {
                written = [container HTMLContext:self writeGraphic:graphic];
            }
            @finally
            {
                _writingPagelet = NO;
            }
        }
        else
        {
            written = [container HTMLContext:self writeGraphic:graphic];
        }
    }
    
    if (!written)
    {
        [self beginGraphicContainer:graphic];
        [graphic writeHTML:self];
        [self endGraphicContainer];
    }
}

- (void)writeGraphics:(NSArray *)graphics;  // convenience
{
    if ([graphics count]) [self beginIteratingWithCount:[graphics count]];
    
    for (SVGraphic *anObject in graphics)
    {
        [self writeGraphic:anObject];
        
        [self nextIteration];
    }
}

- (NSUInteger)numberOfGraphicsOnPage; { return _numberOfGraphics; }

#pragma mark Graphic Containers

- (id <SVComponent>)currentGraphicContainer;
{
    return [_graphicContainers lastObject];
}

- (void)beginGraphicContainer:(id <SVComponent>)container;
{
    [_graphicContainers addObject:container];
}

- (void)endGraphicContainer;
{
    [_graphicContainers removeLastObject];
}

#pragma mark Placeholder

- (void)startInvisibleBadge;
{
    [self startElement:@"span" className:@"svx-invisibadge"];
}

- (void)endInvisibleBadge;
{
    [self endElement];
}

- (void)writeInvisibleBadgeWithText:(NSString *)text options:(NSUInteger)options;
{
	[self startInvisibleBadge];
	[self writeCharacters:text];
	[self endInvisibleBadge];
}

- (void)writeInvisibleBadgeWithText:(NSString *)text;
{
    [self writeInvisibleBadgeWithText:text options:0];
}

- (void)writePlaceholderWithText:(NSString *)text options:(NSUInteger)options;
{
    if (options & SVPlaceholderInvisible)
    {
        return [self writeInvisibleBadgeWithText:text];
    }
    
	[self startPlaceholder];
	[self writeCharacters:text];
	[self endPlaceholder];
}

- (void)writePlaceholderWithText:(NSString *)text;
{
    [self writePlaceholderWithText:text options:0];
}

- (void)startPlaceholder;
{
    [self startElement:@"div" className:@"svx-placeholder"];
    [self startElement:@"div"];
}

- (void)endPlaceholder;
{
    [self endElement];
    [self endElement];
}

#pragma mark Metrics

- (void)startResizableElement:(NSString *)elementName
                       object:(NSObject *)object
                      options:(SVResizingOptions)options
                    sizeDelta:(NSSize)sizeDelta;
{
    [self buildAttributesForResizableElement:elementName object:object DOMControllerClass:nil sizeDelta:sizeDelta options:options];
    
    [self startElement:elementName];
}

- (void)buildAttributesForResizableElement:(NSString *)elementName
                                    object:(NSObject *)object
                        DOMControllerClass:(Class)controllerClass
                                 sizeDelta:(NSSize)sizeDelta
                                   options:(SVResizingOptions)options;
{
    int w = [object integerForKey:@"width"];
	int h = [object integerForKey:@"height"];
    NSNumber *width  = (w+sizeDelta.width <= 0) ? nil : [NSNumber numberWithInt:w+sizeDelta.width];
	NSNumber *height = (h+sizeDelta.height <= 0) ? nil : [NSNumber numberWithInt:h+sizeDelta.height];
    
    // HACK so that heights of inline graphics don't show up
    if (options & SVResizingDisableVertically) height = nil;
    
    // Only some elements support directly sizing. Others have to use CSS
    if ([elementName isEqualToString:@"img"] ||
        [elementName isEqualToString:@"video"] ||
        [elementName isEqualToString:@"object"] ||
        [elementName isEqualToString:@"embed"] ||
        [elementName isEqualToString:@"iframe"])
    {
        if (width) [self pushAttribute:@"width" value:[width description]];
        if (height) [self pushAttribute:@"height" value:[height description]];
    }
    else
    {
		NSMutableString *style = [NSMutableString string];
		if (width)  [style appendFormat:@"width:%@px;",  width];
		if (width && height) [style appendString:@" "];	// space between if both set
		if (height) [style appendFormat:@"height:%@px;", height];
        [self pushAttribute:@"style" value:style];
    }
}

- (NSString *)startResizableElement:(NSString *)elementName
                             plugIn:(SVPlugIn *)plugIn
                            options:(SVResizingOptions)options
                    preferredIdName:(NSString *)preferredID
                         attributes:(NSDictionary *)attributes;
{
    if (preferredID) preferredID = [self pushPreferredIdName:preferredID];
    
    // Push the extra attributes
    [self pushAttributes:attributes];
    
    // During editing, placeholders want to recognise this specific content
    [self pushClassName:@"graphic"];
    if ([self isForEditing]) [self pushClassName:@"svx-size-bound"];
    
    [self buildAttributesForResizableElement:elementName
                   object:[plugIn performSelector:@selector(container)]
                 DOMControllerClass:nil
                          sizeDelta:NSMakeSize([[plugIn elementWidthPadding] unsignedIntegerValue],
                                               [[plugIn elementHeightPadding] unsignedIntegerValue])
                            options:options];
    
    [self startElement:elementName];
    
    return preferredID;
}

#pragma mark Text Blocks

- (void)willWriteSummaryOfPage:(SVSiteItem *)page; { }

#pragma mark Sidebar

@synthesize sidebarPageletsController = _sidebarPageletsController;
- (SVSidebarPageletsController *)sidebarPageletsController;
{
    if (!_sidebarPageletsController)
    {
        // This does the job nicely; if a client needs the controller to live-update they can turn that on
        _sidebarPageletsController = [[SVSidebarPageletsController alloc] initWithPageletsInSidebarOfPage:[self page]];
    }
    
    return _sidebarPageletsController;
}

#pragma mark URLs/Paths

- (NSString *)relativeStringFromURL:(NSURL *)URL;
{
    NSString *result;
    if ([self isForEditing])
    {
        result = [URL webEditorPreviewPath];
        if (!result) result = [URL absoluteString];
    }
    else
    {
        result = [URL ks_stringRelativeToURL:[self baseURL]];
    }
    
    return result;
}

- (NSURL *)URLForPage:(SVSiteItem *)page;
{
    OBPRECONDITION(page);
    
    NSURL *result = nil;
    
    if ([self isForQuickLookPreview])
    {
        result = [NSURL URLWithString:@"javascript:void(0)"];
    }
    else if ([self isForEditing])
    {
        result = [NSURL URLWithString:[page previewPath]];
    }
    else
    {
        result = [page URL];
    }
    
    return result;
}

/*	Generates the path to the specified file with the current page's design.
 *	Takes into account the HTML Generation Purpose to handle Quick Look etc.
 */
- (NSURL *)URLOfDesignFile:(NSString *)whichFileName;
{
	NSURL *result = nil;
	
	// Return nil if the file doesn't actually exist
	
	KTDesign *design = [[[self page] master] design];
	NSString *localPath = [[[design bundle] bundlePath] stringByAppendingPathComponent:whichFileName];
	if ([[NSFileManager defaultManager] fileExistsAtPath:localPath])
	{
		if ([self isForEditing] && ![self baseURL])
        {
            result = [NSURL fileURLWithPath:localPath];
			
			// Append variation index as fragment, so that we can switch among variations and see a different URL
			if (NSNotFound != design.variationIndex)
			{
				result = [NSURL URLWithString:
                          [[result absoluteString]
                           stringByAppendingFormat:@"#var%d", design.variationIndex]];
			}
        }
        else
        {
            KTMaster *master = [[self page] master];
            result = [NSURL URLWithString:whichFileName relativeToURL:[master designDirectoryURL]];
        }
	}
	
	return result;
}

#pragma mark Media

- (NSURL *)addMedia:(SVMedia *)media;
{
    SVMediaRequest *request = [[SVMediaRequest alloc] initWithMedia:media preferredUploadPath:nil];
    NSURL *result = [self addMediaWithRequest:request];
    [request release];
    return result;
}

- (NSURL *)addMediaWithRequest:(SVMediaRequest *)request;
{
    return [[request media] mediaURL];
}

- (NSURL *)addImageMedia:(SVMedia *)media
                   width:(NSNumber *)width
                  height:(NSNumber *)height
                    type:(NSString *)type
       preferredFilename:(NSString *)preferredFilename
           scalingSuffix:(NSString *)suffix;
{
    // When scaling an image, need full suite of parameters
    if (width || height)
    {
        OBPRECONDITION(type);
    }
    
    
    NSString *path = nil;
    if ([preferredFilename isEqualToString:@"../favicon.ico"])  // DIRTY HACK
    {
        path = @"favicon.ico";
    }
    else if (preferredFilename)
    {
        path = [[[[media preferredUploadPath]
                  stringByDeletingLastPathComponent]
                 stringByAppendingPathComponent:preferredFilename]
                stringByStandardizingHTTPPath];
    }
    
    SVMediaRequest *request = [[SVMediaRequest alloc] initWithMedia:media
                                                              width:width
                                                             height:height
                                                               type:type
                                                            options:0
                                                preferredUploadPath:path
                                                      scalingSuffix:suffix];
    
    NSURL *result = [self addMediaWithRequest:request];
    [request release];
    
    return result;
}

- (void)writeImageWithSourceMedia:(id <SVMedia>)media
                              alt:(NSString *)altText
                            width:(NSNumber *)width
                           height:(NSNumber *)height
                             type:(NSString *)type;
{
    NSURL *URL = [self addImageMedia:media width:width height:height type:type preferredFilename:nil scalingSuffix:nil];
    NSString *src = (URL ? [self relativeStringFromURL:URL] : @"");
    
    [self writeImageWithSrc:src
                        alt:altText
                      width:width
                     height:height];
}

- (void)writeImageRepresentationOfPage:(SVSiteItem *)page  // nil page will write a placeholder image
                                 width:(NSUInteger)width
                                height:(NSUInteger)height
                            attributes:(NSDictionary *)attributes  // e.g. custom CSS class
                               options:(SVPageImageRepresentationOptions)options;
{
    if (page)
    {
         [page writeThumbnail:self
                              width:width
                             height:height
                         attributes:attributes
                            options:options];
    }
    else
    {            
        // Write design's example image
        KTDesign *design = [[[self page] master] design];
        NSURL *thumbURL = [KTDesign placeholderImageURLForDesign:design];
        SVMedia *media = [[SVMedia alloc] initByReferencingURL:thumbURL];
        
        [self writeThumbnailImageWithSourceMedia:media
                                             alt:@""
                                           width:width
                                          height:height
                                            type:nil
                                         options:options];
    }
}

- (NSURL *)URLForImageRepresentationOfPage:(SVSiteItem *)page
                                     width:(NSUInteger)width
                                    height:(NSUInteger)height
                                   options:(SVPageImageRepresentationOptions)options;
{
    return [page addImageRepresentationToContext:self
                                            type:[[page thumbnailType] intValue]
                                           width:width
                                          height:height
                                         options:options];
}

- (NSURL *)addThumbnailMedia:(SVMedia *)media
                       width:(NSUInteger)width
                      height:(NSUInteger)height
                        type:(NSString *)type
               scalingSuffix:(NSString *)suffix
                     options:(SVPageImageRepresentationOptions)options;
{
    // Scale to fit?
    KSImageScalingMode scaling = KSImageScalingModeCropCenter;
    
    if (options & SVImageScaleAspectFit)
    {
        scaling = KSImageScalingModeFill;
        
        
        KTImageScalingSettings *settings = [KTImageScalingSettings settingsWithBehavior:KTScaleToSize size:NSMakeSize(width, height)];
        
        CGImageSourceRef source = nil;
        if ([media mediaData]) source = CGImageSourceCreateWithData((CFDataRef)[media mediaData], NULL);
        if (!source) source = CGImageSourceCreateWithURL((CFURLRef)[media mediaURL], NULL);
        
        if (source)
        {
            CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
            if (properties)
            {
                width = [(NSNumber *)CFDictionaryGetValue(properties, kCGImagePropertyPixelWidth) unsignedIntegerValue];
                height = [(NSNumber *)CFDictionaryGetValue(properties, kCGImagePropertyPixelHeight) unsignedIntegerValue];
                
                NSSize size = [settings scaledSizeForImageOfSize:NSMakeSize(width, height)];
                width = size.width;
                height = size.height;
                
                CFRelease(properties);
            }
            
        
            CFRelease(source);
        }
    }
    
    if (options & SVImagePushSizeToCurrentElement)
    {
		if (width)  [self pushAttribute:@"width" value:[NSNumber numberWithUnsignedInteger:width]];
		if (height) [self pushAttribute:@"height" value:[NSNumber numberWithUnsignedInteger:height]];
    }
    
    
    if (!type)
    {
        type = [media performSelector:@selector(typeOfFile)];
        if (![type isEqualToString:(NSString *)kUTTypeJPEG]) type = (NSString *)kUTTypePNG;
    }
    
	
    // During editing, cheat and use special URL if possible. #98041
    if ([self isForEditing] && ![media mediaData])
    {
        NSURL *url = [NSURL sandvoxImageURLWithFileURL:[media mediaURL]
                                                  size:NSMakeSize(width, height)
                                           scalingMode:scaling
                                            sharpening:0.0f
                                     compressionFactor:0.7f
                                              fileType:type];
        
        return url;
    }
    else
    {
		return [self addImageMedia:media
                             width:[NSNumber numberWithUnsignedInteger:width]
                            height:[NSNumber numberWithUnsignedInteger:height]
                              type:type
                 preferredFilename:nil
                     scalingSuffix:suffix];
    }
}

- (void)writeThumbnailImageWithSourceMedia:(SVMedia *)media
                                       alt:(NSString *)altText
                                     width:(NSUInteger)width
                                    height:(NSUInteger)height
                                      type:(NSString *)type // may be nil for context to guess
                                   options:(SVPageImageRepresentationOptions)options;
{
	NSURL *url = [self addThumbnailMedia:media
								   width:width
								  height:height
									type:type
                           scalingSuffix:nil
								 options:(options | SVImagePushSizeToCurrentElement)];
	
	[self writeImageWithSrc:[self relativeStringFromURL:url]
						alt:altText
					  width:nil     // -addThumbnailMedia… took care of supplying width & height for us
					 height:nil];
}

#pragma mark Resource Files

- (NSURL *)addResourceWithURL:(NSURL *)resourceURL;
{
    return [self addResourceAtURL:resourceURL destination:SVDestinationResourcesDirectory options:0];
}

- (void)linkToCSSAtURL:(NSURL *)fileURL
{
    if (_extraHeadBuffer > 0)
    {
        NSMutableString *html = [[NSMutableString alloc] init];
        KSHTMLWriter *writer = [[KSHTMLWriter alloc] initWithOutputWriter:html];
        
        [writer writeLinkToStylesheet:[self relativeStringFromURL:fileURL]
                                title:nil
                                media:nil];
        
        [writer writeString:@"\n"];
        [self addMarkupToHead:html];
        [html release];
        [writer release];
    }
    else
    {
        [self writeLinkToStylesheet:[self relativeStringFromURL:fileURL] title:nil media:nil];
    }
}

- (NSURL *)addResourceAtURL:(NSURL *)fileURL
                destination:(NSString *)uploadPath
                    options:(NSUInteger)options;    // pass in 0
{
    OBPRECONDITION(fileURL);
    OBPRECONDITION(uploadPath);
    
    
    // CSS must be handled specially...
    if ([uploadPath isEqualToString:SVDestinationMainCSS])
    {
        if ([self isForEditing])
        {
            [self linkToCSSAtURL:fileURL];
            return fileURL;
        }
        else if ([self isForQuickLookPreview])
        {
            // CSS other than design should be written inline
            NSString *designPath = [[[[[[self page] master] design] bundle] bundlePath] stringByResolvingSymlinksInPath];
            if (designPath && [[[fileURL path] stringByResolvingSymlinksInPath] ks_isSubpathOfPath:designPath])
            {
                [self linkToCSSAtURL:fileURL];
                return fileURL;
            }
            
            NSString *css = [NSString stringWithContentsOfURL:fileURL
                                                     encoding:NSUTF8StringEncoding
                                                        error:NULL];
            return (css ? [self addCSSString:css] : nil);
        }
    }
    
    // ...everything else reference direct
    else if (![self isForPublishing])
    {
        return fileURL;
    }
    
    
    // Handle constants to figure real upload path
    if ([uploadPath isEqualToString:SVDestinationMainCSS])
    {
        return [self mainCSSURL];
    }
    else if ([uploadPath hasPrefix:SVDestinationResourcesDirectory]) // not exhaustive check, but good first pass
    {
        NSString *resourcesPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultResourcesPath"];
        
        if ([uploadPath isEqualToString:SVDestinationResourcesDirectory])
        {
            uploadPath = [resourcesPath stringByAppendingPathComponent:[fileURL ks_lastPathComponent]];
        }
        else
        {
            NSArray *components = [uploadPath pathComponents];
            if ([[components objectAtIndex:0] isEqualToString:SVDestinationResourcesDirectory])
            {
                NSRange range = NSMakeRange(0, [SVDestinationResourcesDirectory length]);
                uploadPath = [uploadPath stringByReplacingCharactersInRange:range withString:resourcesPath];
            }
        }
    }
    else if ([uploadPath hasPrefix:SVDestinationDesignDirectory])
    {
        NSString *designPath = [[[[self page] master] design] remotePath];
        if (!designPath) return nil;
        
        if ([uploadPath isEqualToString:SVDestinationDesignDirectory])
        {
            uploadPath = [designPath stringByAppendingPathComponent:[fileURL ks_lastPathComponent]];
        }
        else
        {
            NSArray *components = [uploadPath pathComponents];
            if ([[components objectAtIndex:0] isEqualToString:SVDestinationDesignDirectory])
            {
                NSRange range = NSMakeRange(0, [SVDestinationDesignDirectory length]);
                uploadPath = [uploadPath stringByReplacingCharactersInRange:range withString:designPath];
            }
        }
    }
    
    
    // Figure URL from upload path
    NSURL *siteURL = [[[[self page] site] hostProperties] siteURL];
    //if (!siteURL) return nil;
    
    return [NSURL ks_URLWithPath:uploadPath relativeToURL:siteURL isDirectory:NO];
}

- (NSString *)inventFilenameForData:(NSData *)data MIMEType:(NSString *)mimeType
{
    // Invent a filename
    NSString *result = [data ks_SHA1DigestString];
    
    if (mimeType) 
    {
        NSString *type = [KSWORKSPACE ks_typeForMIMEType:mimeType];
        if (type)
        {
            NSString *extension = [KSWORKSPACE preferredFilenameExtensionForType:type];
            if (extension)
            {
                OBASSERT(![result isEqualToString:@""]);
                result = [result stringByAppendingPathExtension:extension];
            }
        }
    }
    
    return result;
}

- (NSURL *)addResourceWithData:(NSData *)data
                      MIMEType:(NSString *)mimeType
              textEncodingName:(NSString *)encoding
                   destination:(NSString *)uploadPath
                       options:(NSUInteger)options;
{
    OBPRECONDITION(data);
    OBPRECONDITION(uploadPath);
    
    
    // CSS must be handled specially
    if ([uploadPath isEqualToString:SVDestinationMainCSS])
    {
        NSString *css = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (css)
        {
            [self addCSSString:css];
            [css release];
            
            return [self mainCSSURL];
        }
        
        return nil;
    }
    
    // Handle constants to figure real upload path
    else if ([uploadPath hasPrefix:SVDestinationResourcesDirectory]) // not exhaustive check, but good first pass
    {
        NSString *resourcesPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultResourcesPath"];
        
        if ([uploadPath isEqualToString:SVDestinationResourcesDirectory])
        {
            NSString *filename = [self inventFilenameForData:data MIMEType:mimeType];
            uploadPath = [resourcesPath stringByAppendingPathComponent:filename];
        }
        else
        {
            NSArray *components = [uploadPath pathComponents];
            if ([[components objectAtIndex:0] isEqualToString:SVDestinationResourcesDirectory])
            {
                NSRange range = NSMakeRange(0, [SVDestinationResourcesDirectory length]);
                uploadPath = [uploadPath stringByReplacingCharactersInRange:range withString:resourcesPath];
            }
        }
    }
    else if ([uploadPath hasPrefix:SVDestinationDesignDirectory])
    {
        NSString *designPath = [[[[self page] master] design] remotePath];
        if (!designPath) return nil;
        
        if ([uploadPath isEqualToString:SVDestinationDesignDirectory])
        {
            NSString *filename = [self inventFilenameForData:data MIMEType:mimeType];
            uploadPath = [designPath stringByAppendingPathComponent:filename];
        }
        else
        {
            NSArray *components = [uploadPath pathComponents];
            if ([[components objectAtIndex:0] isEqualToString:SVDestinationDesignDirectory])
            {
                NSRange range = NSMakeRange(0, [SVDestinationDesignDirectory length]);
                uploadPath = [uploadPath stringByReplacingCharactersInRange:range withString:designPath];
            }
        }
    }
    
    
    // Figure URL from upload path
    NSURL *siteURL = [[[[self page] site] hostProperties] siteURL];
    //if (!siteURL) return nil;
    
    return [NSURL ks_URLWithPath:uploadPath relativeToURL:siteURL isDirectory:NO];
}

- (void)addJavascriptResourceWithTemplateAtURL:(NSURL *)templateURL
                                        object:(id)object;
{
    NSParameterAssert(templateURL);
    
    
    NSMutableString *script = [[NSMutableString alloc] init];
    SVHTMLContext *context = [[SVHTMLContext alloc] initWithOutputWriter:script inheritFromContext:self];
    
    if ([self isForPublishing])
    {
        // Proper publishing subclass will override to publish parsed string
        NSURL *url = [self addResourceWithURL:templateURL]; 
        if (url) [context writeJavascriptWithSrc:[self relativeStringFromURL:url] encoding:NSUTF8StringEncoding];
    }
    else
    {
        // Run through template
        NSString *parsedResource = [self parseTemplateAtURL:templateURL object:object];
        if (parsedResource)
        {
            // Publish
            [context writeJavascript:parsedResource useCDATA:YES];
        }
    }
    
    [self addMarkupToEndOfBody:script];
    [context release];
    [script release];
}

- (NSString *)parseTemplate:(SVTemplate *)template object:(id)object;
{
	NSString *result = nil;
    // Run through template
    if (template)
    {
        SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc]
                                        initWithTemplate:[template templateString]
                                        component:object];
        
        NSMutableString *buffer = [NSMutableString string];
        
        SVHTMLContext *fakeContext = [[SVHTMLContext alloc] initWithOutputWriter:buffer
                                                              inheritFromContext:self];
        
        [parser parseIntoHTMLContext:fakeContext];
        [parser release];
        [fakeContext release];
		result = [NSString stringWithString:buffer];
	}
    return result;
}

- (NSString *)parseTemplateAtURL:(NSURL *)templateURL object:(id)object;
{
    // Run through template
    SVTemplate *template = [[SVTemplate alloc] initWithContentsOfURL:templateURL];
	NSString *result = [self parseTemplate:template object:object];
	[template release];
	return result;
}

#pragma mark Design

- (NSURL *)addGraphicalTextData:(NSData *)imageData idName:(NSString *)idName;
{
    OBASSERT(![[idName legalizedWebPublishingFileName] isEqualToString:@""]);
    NSString *filename = [[idName legalizedWebPublishingFileName]
                          stringByAppendingPathExtension:@"png"];
    
    NSURL *result = [NSURL URLWithString:filename relativeToURL:[self mainCSSURL]];
    return result;
}

#pragma mark Iterations

- (NSUInteger)currentIteration; { return [[self currentIterator] iteration]; }

- (NSUInteger)currentIterationsCount; { return [[self currentIterator] count]; }

- (void)nextIteration;  // increments -currentIteration. Pops the iterators stack if this was the last one.
{
    if ([[self currentIterator] nextIteration] == NSNotFound)
    {
        [self popIterator];
    }
}

- (SVHTMLIterator *)currentIterator { return [_iteratorsStack lastObject]; }

- (void)beginIteratingWithCount:(NSUInteger)count;  // Pushes a new iterator on the stack
{
    OBPRECONDITION(count > 0);
    
    SVHTMLIterator *iterator = [[SVHTMLIterator alloc] initWithCount:count];
    [_iteratorsStack addObject:iterator];
    [iterator release];
}

- (void)popIterator;  // Pops the iterators stack early
{
    [_iteratorsStack removeLastObject];
}

- (NSString *)currentIterationCSSClassNameIncludingArticle:(BOOL)includeArticle;
{
    unsigned int index = [self currentIteration];
    int count = [self currentIterationsCount];
    
	NSMutableArray *classes = [NSMutableArray array];
	if (includeArticle)
	{
		[classes addObject:@"article"];
	}
    if (index != NSNotFound)
    {
        NSString *indexClass = [NSString stringWithFormat:@"i%i", index + 1];
        [classes addObject:indexClass];
        
        NSString *eoClass = (0 == ((index + 1) % 2)) ? @"e" : @"o";
        [classes addObject:eoClass];
        
        if (index == (count - 1))
        {
            [classes addObject:@"last-item"];
        }
    }
    
    NSString *result = [classes componentsJoinedByString:@" "];
    return result;
}

#pragma mark Extra markup

- (void)_writePreHTMLMarkup:(NSString *)markup;
{
    NSUInteger buffer = (_preHTMLBuffer - 1);   // want to write just before the buffer
    [[self outputStringWriter] writeString:markup toBufferAtIndex:buffer];
    
    if (![markup hasSuffix:@"\n"])
    {
        [[self outputStringWriter] writeString:@"\n" toBufferAtIndex:buffer];
    }
}

- (void)writePreHTMLMarkup;
{
    OBASSERT(_preHTMLBuffer == 0);
    
    // Time to start buffering in case a plug-in wants to inject code here
    KSStringWriter *stringWriter = [self outputStringWriter];
    if (!stringWriter) return;  // nowt to do
    
    [stringWriter beginBuffering];
    _preHTMLBuffer = [stringWriter numberOfBuffers];
    OBASSERT(_preHTMLBuffer > 0);
    
    
    // Write any pending markup
    for (NSString *aString in _preHTMLMarkup)
    {
        [self _writePreHTMLMarkup:aString];
    }
}

- (void)addMarkupBeforeHTML:(NSString *)markup;
{
    if ([_preHTMLMarkup containsObject:markup]) return; // ignore dupes
    [_preHTMLMarkup addObject:markup];
    
    if (_preHTMLBuffer > 0)
    {
        [self _writePreHTMLMarkup:markup];
    }
}

- (void)_writeExtraHeader:(NSString *)markup;
{
    NSUInteger buffer = (_extraHeadBuffer - 1);   // want to write just before the buffer
    [[self outputStringWriter] writeString:markup toBufferAtIndex:buffer];
    
    if (![markup hasSuffix:@"\n"])
    {
        [[self outputStringWriter] writeString:@"\n" toBufferAtIndex:buffer];
    }
}

- (void)writeExtraHeaders;  // writes any code plug-ins etc. have requested should inside the <head> element
{
    OBASSERT(_extraHeadBuffer == 0);
    
    // Time to start buffering in case a plug-in wants to inject code here
    KSStringWriter *stringWriter = [self outputStringWriter];
    if (!stringWriter) return;  // nowt to do
    
    [stringWriter beginBuffering];
    _extraHeadBuffer = [stringWriter numberOfBuffers];
    OBASSERT(_extraHeadBuffer > 0);
    
    
    // Write any pending markup
    for (NSString *aString in _extraHeadMarkup)
    {
        [self _writeExtraHeader:aString];
    }
}

- (void)addMarkupToHead:(NSString *)markup;
{
    if ([_extraHeadMarkup containsObject:markup]) return; // ignore dupes
    [_extraHeadMarkup addObject:markup];
    
    if (_extraHeadBuffer > 0)
    {
        [self _writeExtraHeader:markup];
    }
}

- (NSMutableString *)endBodyMarkup; // can append to, query, as you like while parsing
{
    return _endBodyMarkup;
}

- (void)addMarkupToEndOfBody:(NSString *)markup;
{
    if ([[self endBodyMarkup] rangeOfString:markup].location == NSNotFound)
    {
        [[self endBodyMarkup] appendString:markup];
    }
}

- (void)writeEndBodyString; // writes any code plug-ins etc. have requested should go at the end of the page, before </body>
{
    // Write the end body markup
    [self writeString:[self endBodyMarkup]];
}

#pragma mark Content

// Two methods do the same thing. Need to ditch -addDependencyOnObject:keyPath: at some point
- (void)addDependencyOnObject:(NSObject *)object keyPath:(NSString *)keyPath { }
- (void)addDependencyForKeyPath:(NSString *)keyPath ofObject:(NSObject *)object;
{
    [self addDependencyOnObject:object keyPath:keyPath];
}

- (void)writeElement:(NSString *)elementName
     withTitleOfPage:(id <SVPage>)page
         asPlainText:(BOOL)plainText
          attributes:(NSDictionary *)attributes;
{
    [self startElement:elementName attributes:attributes];
    
    if (plainText)
    {
        [self writeCharacters:[page title]];
    }
    else
    {
        [(SVSiteItem *)page writeTitle:self];
    }
    
    [self endElement];
}

#pragma mark Rich Text

+ (NSCharacterSet *)uniqueIDCharacters
{
	static NSCharacterSet *result;
	
	if (!result)
	{
		result = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEF"] retain];
	}
	
	return result;
}

- (SVSiteItem *)siteItemWithUniqueID:(NSString *)ID;
{
    return [SVSiteItem pageWithUniqueID:ID
                 inManagedObjectContext:[[self page] managedObjectContext]];
}

- (NSAttributedString *)processLinks:(NSAttributedString *)attributedHTMLString
{
    if (![self isForEditing] && [attributedHTMLString length])
    {
        /*!	Given the page text, scan for all page ID references and convert to the proper relative links. #110486
         */
        NSCharacterSet *nonIDChars = [[[self class] uniqueIDCharacters] invertedSet];
        
        
        NSMutableAttributedString *buffer = [attributedHTMLString mutableCopy];
        
        NSRange searchRange = NSMakeRange(0, [buffer length]);
        while (searchRange.length)
        {
            // Look for a page ID designator
            NSRange idDesignatorRange = [[buffer string] rangeOfString:kKTPageIDDesignator
                                                               options:0
                                                                 range:searchRange];
            
            if (idDesignatorRange.location == NSNotFound) break;
            
            // Look for page ID
            searchRange.location = idDesignatorRange.location + idDesignatorRange.length;
            searchRange.length = [buffer length] - searchRange.location;
            
            NSRange postIDRange = [[buffer string] rangeOfCharacterFromSet:nonIDChars
                                                                   options:0
                                                                     range:searchRange];
            
            if (postIDRange.location == NSNotFound) postIDRange.location = [buffer length];
            
            // Locate the corresponding page
            NSRange idRange = NSMakeRange(idDesignatorRange.location + idDesignatorRange.length, 0);
            idRange.length = postIDRange.location - idRange.location;
            
            NSString *idString = [[buffer string] substringWithRange:idRange];
            SVSiteItem *thePage = [self siteItemWithUniqueID:idString];
            
            // Figure out correct path
            NSString *newPath = nil;
            if (thePage) newPath = [self relativeStringFromURL:[self URLForPage:thePage]];
            if (!newPath) newPath = @"#";	// Fallback
            
            // Substitute new path
            NSRange replacementRange = NSMakeRange(idDesignatorRange.location, idDesignatorRange.length + idRange.length);
            [buffer replaceCharactersInRange:replacementRange withString:newPath];
            
            // Carry on searching
            searchRange.location = replacementRange.location + [newPath length];
            searchRange.length = [buffer length] - searchRange.location;
        }
        
        attributedHTMLString = [buffer autorelease];
    }
    
    
    return attributedHTMLString;
}

- (void)writeCalloutWithGraphics:(NSArray *)pagelets;
{
    SVCallout *callout = [[SVCallout alloc] init];
    [callout setPagelets:pagelets];
    
    [callout writeHTML:self];
    
    [callout release];
}

- (void)writeAttributedHTMLString:(NSAttributedString *)attributedHTML;
{
    // Process links first, has no effect during editing
    attributedHTML = [self processLinks:attributedHTML];
    
    
    NSRange range = NSMakeRange(0, [attributedHTML length]);
    NSUInteger location = 0;
    
    BOOL firstItem = YES;
    
    while (location < range.length)
    {
        NSRange effectiveRange;
        SVTextAttachment *attachment = [attributedHTML attribute:@"SVAttachment"
                                                         atIndex:location
                                           longestEffectiveRange:&effectiveRange
                                                         inRange:range];
        
        if (attachment)
        {
            // Write the graphic
            [self pushClassName:(firstItem ? @"first" : @"not-first-item")];
            
            SVGraphic *graphic = [attachment graphic];
            
            
            
            // Possible callout.
            BOOL callout = [graphic isCallout];
            if (callout)
            {
                // Look for other graphics that are part of the same callout
                NSMutableArray *pagelets = [NSMutableArray arrayWithObject:graphic];
                
                NSScanner *scanner = [[NSScanner alloc] initWithString:[attributedHTML string]];
                [scanner setCharactersToBeSkipped:nil];
                
                while (attachment)
                {
                    [scanner setScanLocation:(effectiveRange.location + effectiveRange.length)];
                    [scanner scanCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]
                                        intoString:NULL];
                    
                    attachment = nil;
                    location = [scanner scanLocation];
                    if (location < range.location + range.length)
                    {
                        attachment = [attributedHTML attribute:@"SVAttachment"
                                                       atIndex:location
                                         longestEffectiveRange:&effectiveRange
                                                       inRange:range];
                        
                        if (attachment)
                        {
                            if ([[attachment placement] intValue] == SVGraphicPlacementCallout)
                            {
                                [pagelets addObject:[attachment graphic]];
                            }
                            else
                            {
                                attachment = nil;
                            }
                        }
                        
                        if (!attachment) effectiveRange.length = 0; // reset search
                    }
                }
                [scanner release];
                
                [self writeCalloutWithGraphics:pagelets];
            }
            else
            {
                [self writeGraphic:graphic];
            }
            
            
            // Having written the first bit of content, it's time to start marking that
            firstItem = NO;
        }
        else
        {
            NSString *html = [[attributedHTML string] substringWithRange:effectiveRange];
            [self writeHTMLString:html];
        }
        
        // Advance the search
        location = effectiveRange.location + effectiveRange.length;
    }
}

- (void)writeString:(NSString *)string;
{
    [super writeString:string];
    _charactersWritten += [string length];
}

- (void)close;
{
    [_buffer flush];
    
    [super close];
    
    [_buffer release]; _buffer = nil;
}

#pragma mark Pages

@synthesize page = _currentPage;

- (NSArray *)childrenOfPage:(id <SVPage>)page;
{
    NSArrayController *controller = [SVPagesController
                                     controllerWithPagesInCollection:page
                                     bind:[self isForEditing]];
    
    [self addDependencyOnObject:controller keyPath:@"arrangedObjects"];
    
    return [controller arrangedObjects];
}

- (NSArray *)indexChildrenOfPage:(id <SVPage>)page;
{
    NSArrayController *controller = [SVPagesController
                                     controllerWithPagesInCollection:page
                                     bind:[self isForEditing]];
    
    [controller setFilterPredicate:[NSPredicate predicateWithFormat:@"shouldIncludeInIndexes == YES"]];
    
    [self addDependencyOnObject:controller keyPath:@"arrangedObjects"];
    
    return [controller arrangedObjects];
}

- (NSArray *)sitemapChildrenOfPage:(id <SVPage>)page;
{
    if (![page isKindOfClass:[KTPage class]]) return nil;
    
    NSArrayController *controller = [SVPagesController
                                     controllerWithPagesInCollection:page
                                     bind:[self isForEditing]];
    
    [controller setFilterPredicate:[NSPredicate predicateWithFormat:@"shouldIncludeInSiteMaps == YES"]];
    
    [self addDependencyOnObject:controller keyPath:@"arrangedObjects"];
    
    return [controller arrangedObjects];
}

#pragma mark RSS

- (void)writeEnclosure:(id <SVEnclosure>)enclosure;
{
    @try    // enclosure is probably an SVPlugIn so play it safe
    {
        // Figure out the URL when published. Ideally this is from some media, but if not the published URL
        NSURL *URL = [enclosure addToContext:self];
        
        
        // Write
        if (URL)
        {
            [self pushAttribute:@"url" value:[self relativeStringFromURL:URL]];
            
            if ([enclosure length])
            {
                [self pushAttribute:@"length"
                              value:[[NSNumber numberWithLongLong:[enclosure length]] description]];
            }
            
            if ([enclosure MIMEType]) [self pushAttribute:@"type" value:[enclosure MIMEType]];
            
            [self startElement:@"enclosure"];
            [self endElement];
        }
    }
    @catch (NSException *e)
    {
        // TODO: Log
    }
}

- (BOOL)startAnchorElementWithFeedForPage:(NSObject <SVPage> *)page attributes:(NSDictionary *)attributes
{
    OBPRECONDITION(page);
    
    [self addDependencyOnObject:page keyPath:@"hasFeed"];
    if ( [page hasFeed] )
    {
        NSString *href = [self relativeStringFromURL:[(KTPage *)page feedURL]];
        if ( href ) [self pushAttribute:@"href" value:href];
        
        NSString *title = NSLocalizedString(@"To subscribe to this feed, drag or copy/paste this link to an RSS reader application", "RSS badge tooltip");
        if ( title ) [self pushAttribute:@"title" value:href];
        
        for ( NSString *attribute in [attributes allKeys] )
        {
            id value = [attributes objectForKey:attribute];
            if ( value )
            {
                [self pushAttribute:attribute value:value];
            }
        }
        [self startElement:@"a"];
        
        return YES;
    }
    else
    {
        // write out placeholder with button to turn on feed for page
        [self startPlaceholder];
        {
            [self startElement:@"p"];
            {
                NSString *title = [page title];
                if (title)
                {
					NSString *noFeed = NSLocalizedString(@"“%@” has no RSS feed", "no RSS placeholder for page title");
                    [self writeCharacters:[NSString stringWithFormat:noFeed, title]];
                }
                else
                {
                    [self writeCharacters:NSLocalizedString(@"No RSS feed", "RSS badge feed placeholder")];
                }
            }
            [self endElement];
            
            
            NSString *buttonTitle = NSLocalizedString(@"Generate Feed", "");
            [self writeHTMLFormat:@"<p><button onclick=\"window.location = 'x-sandvox-rssfeed-activate:%@';\">%@</button></p>", [(SVSiteItem *)page identifier], buttonTitle];
            
            [self writeElement:@"p" text:NSLocalizedString(@"Or select a different collection in the Inspector", "placeholder")];
        }
        [self endPlaceholder];
        
        return NO;
    }
}

#pragma mark Publishing

- (void)disableChangeTracking; { }
- (void)enableChangeTracking; { }
- (BOOL)isChangeTrackingEnabled; { return NO; }

#pragma mark SVPlugInContext

- (id)objectForCurrentTemplateIteration;
{
    SVHTMLTemplateParser *parser = [SVHTMLTemplateParser currentTemplateParser];
    return [parser currentIterationObject];
}

- (NSString *)visibleSiteTitle;
{
    KTMaster *master = [[self page] master];
    if (![[[master siteTitle] hidden] boolValue])
    {
        return [[master siteTitle] text];
    }
    return nil;
}

- (void)startAnchorElementWithPage:(id <SVPage>)page attributes:(NSDictionary *)attributes;
{
    [self pushAttributes:attributes];
    [self startAnchorElementWithPage:page];
}

- (void)startAnchorElementWithPage:(id <SVPage>)page;
{
    OBPRECONDITION(page);
    
    NSString *href = [self relativeStringFromURL:[self URLForPage:page]];
    if (!href) href = @"";  // happens for a site with no -siteURL set yet
    
    NSString *target = ([[(SVSiteItem *)page openInNewWindow] boolValue] ? @"_blank" : nil);
    
    [self startAnchorElementWithHref:href 
                               title:[page title]
                              target:target
                                 rel:nil];
    
}

#pragma mark Debugging

- (NSString *)description;
{
    return [[super description] stringByAppendingFormat:@"\n%@", [self outputStringWriter]];
}

@end


#pragma mark -



@implementation SVHTMLIterator

- (id)initWithCount:(NSUInteger)count;
{
    [self init];
    _count = count;
    return self;
}

@synthesize count = _count;

@synthesize iteration = _iteration;

- (NSUInteger)nextIteration;
{
    _iteration = [self iteration] + 1;
    if (_iteration == [self count]) _iteration = NSNotFound;
    return _iteration;
}

@end


#pragma mark -


@implementation KSHTMLWriter (SVHTMLContext)

- (void)writeEndTagWithComment:(NSString *)comment;
{
    [self endElement];
    
    [self writeString:@" "];
    
    [self openComment];
    [self writeString:@" "];
    [self writeCharacters:comment];
    [self writeString:@" "];
    [self closeComment];
}

@end



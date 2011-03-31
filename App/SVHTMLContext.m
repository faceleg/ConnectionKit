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
#import "KTPage.h"
#import "SVSidebarDOMController.h"
#import "KTSite.h"
#import "SVTemplate.h"
#import "SVTextAttachment.h"
#import "SVTextBox.h"
#import "SVTitleBox.h"
#import "SVWebEditingURL.h"

#import "SVCalloutDOMController.h"  // don't like having to do this

#import "NSIndexPath+Karelia.h"
#import "NSString+Karelia.h"
#import "KSURLUtilities.h"
#import "NSObject+Karelia.h"

#import "KSStringWriter.h"

#import "Registration.h"


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
@end


#pragma mark -


@implementation SVHTMLContext

#pragma mark Init & Dealloc

- (id)initWithOutputWriter:(id <KSWriter>)output; // designated initializer
{
    [super initWithOutputWriter:output];
    
    
    _includeStyling = YES;
    
    _liveDataFeeds = YES;
        
    _headerLevel = 1;
    
    _headerMarkup = [[NSMutableString alloc] init];
    _endBodyMarkup = [[NSMutableString alloc] init];
    _iteratorsStack = [[NSMutableArray alloc] init];
    _graphicContainers = [[NSMutableArray alloc] init];
    
    return self;
}

- (id)initWithOutputStringWriter:(KSStringWriter *)output;
{
    if (self = [self initWithOutputWriter:output])
    {
        _output = [output retain];
    }
    
    return self;
}

- (id)init;
{
    KSStringWriter *output = [[KSStringWriter alloc] init];
    self = [self initWithOutputStringWriter:output];
    [output release];
    return self;
}

- (id)initWithOutputWriter:(id <KSWriter>)output inheritFromContext:(SVHTMLContext *)context;
{
	OBPRECONDITION(context);
    NSStringEncoding encoding = (context ? [context encoding] : NSUTF8StringEncoding);
    
    if (self = [self initWithOutputWriter:output docType:[context docType] encoding:encoding])
    {
        if ([output isKindOfClass:[KSStringWriter class]]) _output = [output retain];
        
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
        
    [_headerMarkup release]; _headerMarkup = nil;   // accessed in -flush
    [_endBodyMarkup release];
    [_iteratorsStack release];
    [_graphicContainers release];
    
    [_sidebarPageletsController release];
    
    [super dealloc];
}

#pragma mark Status

- (void)reset;
{
    [[self outputStringWriter] removeAllCharacters];
}

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
    
    
    // First Code Injection
	[page write:self codeInjectionSection:@"beforeHTML" masterFirst:NO];
    
    
    // Start the document
    [self startDocumentWithDocType:KSHTMLWriterDocTypeHTML_5
                          encoding:[[[page master] charset] encodingFromCharset]];
    
    
    // Global CSS
    NSString *path = [[NSBundle mainBundle] pathForResource:@"sandvox" ofType:@"css"];
    if (path) [self addCSSWithURL:[NSURL fileURLWithPath:path]];
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
        if (editingCSSPath) [self addCSSWithURL:[NSURL fileURLWithPath:editingCSSPath]];
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
#define JQUERY_VERSION @"1.5.1"
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSURL *jQueryURL = nil;
	NSString *minimizationSuffix = @".min";

	NSString *scheme = [self.baseURL scheme];
	if (!scheme) scheme = @"http";		// for instance, when newly set up. Better to show something for page source.
    
	if ([defaults boolForKey:@"jQueryDevelopment"])
	{
		minimizationSuffix = @"";		// Use the development version instead, not the minimized.
	}
	
	// This is either the local version, or not uploaded to a web server, or user preference to keep their own copy of jQuery.
	if ([self isForEditing] || [scheme isEqualToString:@"file"] || [defaults boolForKey:@"jQueryLocal"])
	{
		NSURL *localJQueryURL = [NSURL fileURLWithPath:[[NSBundle mainBundle]
                                                        pathForResource:[NSString stringWithFormat:@"jquery-%@%@", JQUERY_VERSION, minimizationSuffix]
                                                        ofType:@"js"]];
		
		jQueryURL = [self addResourceWithURL:localJQueryURL];
		
	}
	else	// Normal publishing case: remote version from google, fastest for downloading.
			// Match http/https scheme of uploaded site.
	{
		jQueryURL = [NSURL URLWithString:
					 [NSString stringWithFormat:@"%@://ajax.googleapis.com/ajax/libs/jquery/%@/jquery%@.js",
					  scheme, JQUERY_VERSION, minimizationSuffix]];
	}
	
	[self writeJavascriptWithSrc:[self relativeStringFromURL:jQueryURL]];
    
	// Note: I may want to also get: http://ajax.googleapis.com/ajax/libs/jqueryui/1.8.2/jquery-ui.min.js
	// I would just put in parallel code.  However this might be better to be added with code injection by people who want it.
}

#pragma mark Properties

@synthesize outputStringWriter = _output;
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

- (void)addCSSString:(NSString *)css;
{
    if (![self isForPublishing])
    {
        if (_headerMarkupIndex != NSNotFound)
        {
            KSHTMLWriter *writer = [[KSHTMLWriter alloc] initWithOutputWriter:[self extraHeaderMarkup]];
            
            [writer writeStyleElementWithCSSString:css];
            [writer writeString:@"\n"];
            
            [writer release];
        }
        else
        {
            [self writeStyleElementWithCSSString:css];
        };
    }
}

- (void)addCSSWithURL:(NSURL *)cssURL;
{
    if (![self isForPublishing])
    {
        if (_headerMarkupIndex != NSNotFound)
        {
            KSHTMLWriter *writer = [[KSHTMLWriter alloc] initWithOutputWriter:[self extraHeaderMarkup]];
            
            [writer writeLinkToStylesheet:[self relativeStringFromURL:cssURL]
                                  title:nil
                                  media:nil];
            
            [writer writeString:@"\n"];
            [writer release];
        }
        else
        {
            [self writeLinkToStylesheet:[self relativeStringFromURL:cssURL] title:nil media:nil];
        }
    }
}

- (void)addCSSWithTemplateAtURL:(NSURL *)templateURL object:(id)object;
{
    // Run through template
    NSString *css = [self parseTemplateAtURL:templateURL object:object];
    [self addCSSString:css];
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

- (void)startHeadingWithAttributes:(NSDictionary *)attributes;
{
    [self startElement:[self currentHeaderLevelTagName] attributes:attributes];
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

- (void)writeBodyOfGraphic:(id <SVGraphic>)graphic;
{
    [self incrementHeaderLevel];
    @try
    {
        // Graphic body
        if (![graphic isPagelet] && ![graphic shouldWriteHTMLInline])
        {
            [self startElement:@"div"]; // <div class="graphic">
            
            
            [self pushClassName:@"figure-content"];  // identifies for #84956
        }
        
        if (![graphic isKindOfClass:[SVPlugInGraphic class]] || [graphic isKindOfClass:[SVMediaGraphic class]])
        {
            // It's almost certainly media, generate DOM controller to match
            [graphic writeBody:self];
        }
        else
        {
            @try
            {
                [[self writeElement:@"div" contentsInvocationTarget:graphic]
                 writeBody:self];
            }
            @catch (NSException *exception)
            {
                // Was probably caused by a plug-in. Log and soldier on. #88083
                NSLog(@"Writing graphic body raised exception, probably due to incorrect use of HTML Writer");
            }
        }
        
        if (![graphic isPagelet] && ![graphic shouldWriteHTMLInline])
        {
            [self endElement];
        }
    }
    @finally
    {
        [self decrementHeaderLevel];
    }
}

- (void)writeGraphic:(id <SVGraphic>)graphic;
{
    // Special case. When writing a graphic nested in itself that's our cue to generate the body
    if (graphic == [self currentGraphicContainer])
    {
        return [self writeBodyOfGraphic:graphic];
    }
    
    
    // Update number of graphics
    _numberOfGraphics++;
    
    id <SVGraphicContainer> container = [self currentGraphicContainer];
    [self beginGraphicContainer:graphic];
    
    if (container)
    {
        if ([graphic isPagelet])
        {
            _writingPagelet = YES;
            @try
            {
                [container write:self graphic:graphic];
            }
            @finally
            {
                _writingPagelet = NO;
            }
        }
        else
        {
            [container write:self graphic:graphic];
        }
    }
    else 
    {
        [graphic writeBody:self];
    }
    
    [self endGraphicContainer];
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

- (id <SVGraphicContainer>)currentGraphicContainer;
{
    return [_graphicContainers lastObject];
}

- (void)beginGraphicContainer:(id <SVGraphicContainer>)container;
{
    [_graphicContainers addObject:container];
}

- (void)endGraphicContainer;
{
    [_graphicContainers removeLastObject];
}

- (void)writeCalloutWithGraphics:(NSArray *)pagelets;
{
    SVCallout *callout = [[SVCallout alloc] init];
    [callout write:self pagelets:pagelets];
    [callout release];
}

#pragma mark Placeholder

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

#pragma mark Metrics

- (void)startElement:(NSString *)elementName bindSizeToObject:(NSObject *)object;
{
    [self buildAttributesForElement:elementName bindSizeToObject:object DOMControllerClass:nil  sizeDelta:NSZeroSize];
    [self startElement:elementName];
}

- (void)buildAttributesForElement:(NSString *)elementName bindSizeToObject:(NSObject *)object DOMControllerClass:(Class)controllerClass  sizeDelta:(NSSize)sizeDelta;
{
    id graphic = ([object isKindOfClass:[SVGraphic class]] ? object : [object valueForKey:@"container"]);
    if (![self isWritingPagelet] && ![graphic shouldWriteHTMLInline])
    {
        [self pushClassName:@"graphic"];    // so it gets laid out right when a few levels of tags down. #98767
    }
    
    
	int w = [object integerForKey:@"width"];
	int h = [object integerForKey:@"height"];
    NSNumber *width  = (w+sizeDelta.width <= 0) ? nil : [NSNumber numberWithInt:w+sizeDelta.width];
	NSNumber *height = (h+sizeDelta.height <= 0) ? nil : [NSNumber numberWithInt:h+sizeDelta.height];
    
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

- (void)startElement:(NSString *)elementName
    bindSizeToPlugIn:(SVPlugIn *)plugIn
          attributes:(NSDictionary *)attributes;
{
    // Push the extra attributes
    [self pushAttributes:attributes];
    
    // During editing, placeholders want to recognise this specific content
    if ([self isForEditing])
    {
        [self pushClassName:@"svx-size-bound"];
    }
    
    [self buildAttributesForElement:elementName
                   bindSizeToObject:[plugIn performSelector:@selector(container)]
                 DOMControllerClass:nil
                          sizeDelta:NSMakeSize([[plugIn elementWidthPadding] unsignedIntegerValue],
                                               [[plugIn elementHeightPadding] unsignedIntegerValue])];
    
    [self startElement:elementName];
}

- (NSString *)startElement:(NSString *)elementName
          bindSizeToPlugIn:(SVPlugIn *)plugIn
           preferredIdName:(NSString *)idName
                attributes:(NSDictionary *)attributes;
{
    if (idName) idName = [self pushPreferredIdName:idName];
    [self startElement:elementName bindSizeToPlugIn:plugIn attributes:attributes];
    return idName;
}

- (NSString *)startResizableElement:(NSString *)elementName
                              plugIn:(SVPlugIn *)plugIn
                             options:(NSUInteger)options    // pass 0 for now, we may add options later
                     preferredIdName:(NSString *)preferredID
                          attributes:(NSDictionary *)attributes;
{
    return [self startElement:elementName bindSizeToPlugIn:plugIn preferredIdName:preferredID attributes:attributes];
}

#pragma mark Text Blocks

- (void)willBeginWritingHTMLTextBlock:(SVHTMLTextBlock *)block; { }
- (void)didEndWritingHTMLTextBlock; { }
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
    OBPRECONDITION(URL);
    
    NSString *result;
    
    switch ([self generationPurpose])
    {
        case kSVHTMLGenerationPurposeEditing:
            result = [URL webEditorPreviewPath];
            if (!result) result = [URL absoluteString];
            break;
            
        default:
            result = [URL ks_stringRelativeToURL:[self baseURL]];
            break;
    }
    
    return result;
}

- (NSString *)relativeURLStringOfSiteItem:(SVSiteItem *)page;
{
    OBPRECONDITION(page);
    
    NSString *result = nil;
    
    if ([self isForQuickLookPreview])
    {
        result = @"javascript:void(0)";
    }
    else if ([self isForEditing])
    {
        result = [page previewPath];
    }
    else
    {
        NSURL *URL = [page URL];
        if (URL) result = [self relativeStringFromURL:URL];
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

- (NSURL *)addMedia:(id <SVMedia>)media;
{
    OBPRECONDITION(media);
    
    NSURL *result = [media mediaURL];
    return result;
}

- (NSURL *)addImageMedia:(id <SVMedia>)media
                   width:(NSNumber *)width
                  height:(NSNumber *)height
                    type:(NSString *)type
       preferredFilename:(NSString *)preferredFilename;
{
    return [self addMedia:media];
}

- (void)writeImageWithSourceMedia:(id <SVMedia>)media
                              alt:(NSString *)altText
                            width:(NSNumber *)width
                           height:(NSNumber *)height
                             type:(NSString *)type
                preferredFilename:(NSString *)filename;
{
    NSURL *URL = [self addImageMedia:media width:width height:height type:type preferredFilename:filename];
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
                               preferredFilename:nil
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
                                         options:options
                        pushSizeToCurrentElement:NO];
}

- (NSURL *)addThumbnailMedia:(SVMedia *)media
                       width:(NSUInteger)width
                      height:(NSUInteger)height
                        type:(NSString *)type
           preferredFilename:(NSString *)filename
                     options:(SVPageImageRepresentationOptions)options
    pushSizeToCurrentElement:(BOOL)push;
{
    // Scale to fit?
    KSImageScalingMode scaling = KSImageScalingModeCropCenter;
    
    if (options & SVImageScaleAspectFit)
    {
        scaling = KSImageScalingModeFill;
        
        KTImageScalingSettings *settings = [KTImageScalingSettings settingsWithBehavior:KTScaleToSize size:NSMakeSize(width, height)];
        
        CIImage *image = [[CIImage alloc] initWithContentsOfURL:[media mediaURL]];
        if (!image) image = [[CIImage alloc] initWithData:[media mediaData]];
        
        CGSize size = [settings scaledCGSizeForImageOfSize:[image extent].size];
        width = size.width;
        height = size.height;
        
        [image release];
    }
    
    if (push)
    {
		if (width)  [self pushAttribute:@"width" value:[NSNumber numberWithUnsignedInteger:width]];
		if (height) [self pushAttribute:@"height" value:[NSNumber numberWithUnsignedInteger:height]];
    }
    
    
    if (!type) type = (NSString *)kUTTypePNG;
    
	
    // During editing, cheat and use special URL if possible. #98041
    if ([self isForEditing] && ![media mediaData])
    {
        NSURL *url = [NSURL sandvoxImageURLWithFileURL:[media mediaURL]
                                                  size:NSMakeSize(width, height)
                                           scalingMode:scaling
                                            sharpening:0.0f
                                     compressionFactor:1.0f
                                              fileType:type];
        
        return url;
    }
    else
    {
		return [self addImageMedia:media
                             width:[NSNumber numberWithUnsignedInteger:width]
                            height:[NSNumber numberWithUnsignedInteger:height]
                              type:type
                 preferredFilename:filename];
    }
}

- (void)writeThumbnailImageWithSourceMedia:(SVMedia *)media
                                       alt:(NSString *)altText
                                     width:(NSUInteger)width
                                    height:(NSUInteger)height
                                      type:(NSString *)type // may be nil for context to guess
                         preferredFilename:(NSString *)filename
                                   options:(SVPageImageRepresentationOptions)options;
{
	NSURL *url = [self addThumbnailMedia:media
								   width:width
								  height:height
									type:type
					   preferredFilename:filename
								 options:options
				pushSizeToCurrentElement:YES];
	
	[self writeImageWithSrc:[self relativeStringFromURL:url]
						alt:altText
					  width:nil     // -addThumbnailMedia… took care of suppluying width & height for us
					 height:nil];
}

#pragma mark Resource Files

- (NSURL *)addResourceWithURL:(NSURL *)resourceURL;
{
    OBPRECONDITION(resourceURL);
    return resourceURL; // subclasses will correct for publishing
}

- (void)addJavascriptResourceWithTemplateAtURL:(NSURL *)templateURL
                                        object:(id)object;
{
    NSMutableString *script = [[NSMutableString alloc] init];
    SVHTMLContext *context = [[SVHTMLContext alloc] initWithOutputWriter:script inheritFromContext:self];
    
    if ([self isForPublishing])
    {
        // Proper publishing subclass will override to publish parsed string
        NSURL *url = [self addResourceWithURL:templateURL]; 
        [context writeJavascriptWithSrc:[self relativeStringFromURL:url]];
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

- (NSURL *)addDesignResourceWithURL:(NSURL *)fileURL; // can pass in a folder URL and whole thing will be published
{
    return fileURL;
}

- (NSURL *)addBannerWithURL:(NSURL *)sourceURL;
{
    return sourceURL;
}

- (NSURL *)addGraphicalTextData:(NSData *)imageData idName:(NSString *)idName;
{
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

- (NSString *)currentIterationCSSClassName;
{
    unsigned int index = [self currentIteration];
    int count = [self currentIterationsCount];
    
    NSMutableArray *classes = [NSMutableArray arrayWithObject:@"article"];
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

- (void)addMarkupToEndOfBody:(NSString *)markup;
{
    if ([[self endBodyMarkup] rangeOfString:markup].location == NSNotFound)
    {
        [[self endBodyMarkup] appendString:markup];
    }
}

- (NSMutableString *)extraHeaderMarkup; // can append to, query, as you like while parsing
{
    return _headerMarkup;
}

- (void)writeExtraHeaders;  // writes any code plug-ins etc. have requested should inside the <head> element
{
    // Record where to make the insert
    _headerMarkupIndex = [[self outputStringWriter] length];
}

- (NSMutableString *)endBodyMarkup; // can append to, query, as you like while parsing
{
    return _endBodyMarkup;
}

- (void)writeEndBodyString; // writes any code plug-ins etc. have requested should go at the end of the page, before </body>
{
    // Write the end body markup
    [self writeString:[self endBodyMarkup]];
}

- (void)flush;
{
    [super flush];
    
    // Finish buffering extra header
    if (_headerMarkupIndex < NSNotFound && _headerMarkup)
    {
        [[self outputStringWriter] insertString:[self extraHeaderMarkup]
                                        atIndex:_headerMarkupIndex];
        
        [_headerMarkup deleteCharactersInRange:NSMakeRange(0, [_headerMarkup length])];
        _headerMarkupIndex = NSNotFound; // so nothing gets mistakenly written afterwards
    }
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

- (void)writeAttributedHTMLString:(NSAttributedString *)attributedHTML;
{
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
            
            
            
            // If the placement changes, want whole Text Area to update
            [self addDependencyForKeyPath:@"textAttachment.placement" ofObject:graphic];
            // Used to register title, intro etc. as dependencies here, but that shouldn't be necessary any more
            
            
            // Possible callout.
            BOOL callout = [graphic isCallout];
            if (callout)
            {
                // Look for other graphics that are part of the same callout
                NSMutableArray *pagelets = [NSMutableArray arrayWithObject:graphic];
                
                NSScanner *scanner = [[NSScanner alloc] initWithString:[attributedHTML string]];
                
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
    [super close];
    
    [_output release]; _output = nil;
}

#pragma mark Legacy

@synthesize page = _currentPage;

#pragma mark RSS

- (void)writeEnclosure:(id <SVEnclosure>)enclosure;
{
    // Figure out the URL when published. Ideally this is from some media, but if not the published URL
    NSURL *URL = nil;
    
    id <SVMedia> media = [enclosure media];
    if (media)
    {
        URL = [self addMedia:media];
    }
    else
    {
        URL = [enclosure URL];
    }
    
    
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

- (void)startAnchorElementWithPage:(id <SVPage>)page;
{
    OBPRECONDITION(page);
    
    NSString *href = [self relativeURLStringOfSiteItem:(SVSiteItem *)page];
    if (!href) href = @"";  // happens for a site with no -siteURL set yet
    
    NSString *target = ([[(SVSiteItem *)page openInNewWindow] boolValue] ? @"_blank" : nil);
    
    [self startAnchorElementWithHref:href 
                               title:[page title]
                              target:target
                                 rel:nil];
    
}

- (BOOL)startAnchorElementWithPageRSSFeed:(id <SVPage>)page options:(NSUInteger)options
{
    OBPRECONDITION(page);
    if ( [(KTPage *)page feedURL] )
    {
        // write out link
        NSString *href = [[(KTPage *)page feedURL] ks_stringRelativeToURL:[self baseURL]];
        if ( href ) [self pushAttribute:@"href" value:href];

        NSString *title = NSLocalizedString(@"To subscribe to this feed, drag or copy/paste this link to an RSS reader application.", "RSS Badge");
        if ( title ) [self pushAttribute:@"title" value:href];

        if ( options == 1 ) [self pushAttribute:@"class" value:@"imageLink"];
        
        [self startElement:@"a"];
        return YES;
    }
    else
    {
        // write out placeholder with button to turn on feed for page
//         NSString *text = NSLocalizedString(@"The chosen collection has no RSS feed. Please use the Inspector to set it to generate an RSS feed.", "RSS Badge");
//        [self writePlaceholderWithText:text];
        return NO;
    }
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



//
//  SVHTMLContext.m
//  Sandvox
//
//  Created by Mike on 19/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorHTMLContext.h"

#import "KTHostProperties.h"
#import "KTPage.h"
#import "KTSite.h"
#import "BDAlias+QuickLook.h"
#import "SVMediaRecord.h"

#import "SVCalloutDOMController.h"  // don't like having to do this

#import "NSIndexPath+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"


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
- (SVHTMLIterator *)currentIterator;
@end


#pragma mark -


@implementation SVHTMLContext

#pragma mark Init & Dealloc

- (id)initWithOutputWriter:(id <KSWriter>)output; // designated initializer
{
    // One buffer to hold page markup until we have collected all head info
    _postHeaderBuffer = [[KSMegaBufferedWriter alloc] initWithOutputWriter:output];
    
    // And another buffer for grouping callouts
    _calloutBuffer = [[KSMegaBufferedWriter alloc] initWithOutputWriter:_postHeaderBuffer];
    [_calloutBuffer setDelegate:self];
    
    
    [super initWithOutputWriter:_calloutBuffer];
    
    
    _includeStyling = YES;
    _mainCSS = [[NSMutableString alloc] init];
    
    _liveDataFeeds = YES;
    [self setEncoding:NSUTF8StringEncoding];
    _docType = KTDocTypeAll;
    
    _headerLevel = 1;
    _headerMarkup = [[NSMutableString alloc] init];
    _endBodyMarkup = [[NSMutableString alloc] init];
    _iteratorsStack = [[NSMutableArray alloc] init];
    
    return self;
}

- (void)dealloc
{
    [_language release];
    [_baseURL release];
    [_currentPage release];
    
    [_mainCSSURL release];
    [_mainCSS release];
    
    [_headerMarkup release];
    [_endBodyMarkup release];
    [_iteratorsStack release];
    
    [super dealloc];
    
    OBASSERT(!_postHeaderBuffer);   // super should have called -close to set this to nil
    OBASSERT(!_calloutBuffer);
}

#pragma mark Properties

@synthesize baseURL = _baseURL;
@synthesize liveDataFeeds = _liveDataFeeds;
@synthesize encoding = _stringEncoding;
@synthesize language = _language;

@synthesize maxDocType = _docType;

- (void)limitToMaxDocType:(KTDocType)docType;
{
    if (docType < [self maxDocType]) [self setMaxDocType:docType];
}

- (KTHTMLGenerationPurpose)generationPurpose; { return kSVHTMLGenerationPurposeNormal; }

- (BOOL)isForEditing; { return [self generationPurpose] == kSVHTMLGenerationPurposeEditing; }

- (BOOL)isEditable { return [self isForEditing]; }
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

- (void)copyPropertiesFromContext:(SVHTMLContext *)context;
{
    // Copy across properties
    [self setIndentationLevel:[context indentationLevel]];
    [self setPage:[context page]];
    [self setBaseURL:[context baseURL]];
    [self setIncludeStyling:[context includeStyling]];
    [self setLiveDataFeeds:[context liveDataFeeds]];
    [self setXHTML:[context isXHTML]];
    [self setEncoding:[context encoding]];
}

#pragma mark CSS

@synthesize includeStyling = _includeStyling;

@synthesize mainCSS = _mainCSS;
@synthesize mainCSSURL = _mainCSSURL;

- (void)addCSSWithURL:(NSURL *)cssURL;
{
    [self writeLinkToStylesheet:[self relativeURLStringOfURL:cssURL]
                          title:nil
                          media:nil];
}

#pragma mark Header Tags

@synthesize currentHeaderLevel = _headerLevel;

- (NSString *)currentHeaderLevelTagName;
{
    NSString *result = [NSString stringWithFormat:@"h%u", [self currentHeaderLevel]];
    return result;
}

#pragma mark Elements/Comments

- (void)writeEndTagWithComment:(NSString *)comment;
{
    [self endElement];
    
    [self writeString:@" "];
    
    [self openComment];
    [self writeString:@" "];
    [self writeText:comment];
    [self writeString:@" "];
    [self closeComment];
}

#pragma mark Callouts

- (void)beginCalloutWithAlignmentClassName:(NSString *)alignment;
{
    if ([alignment isEqualToString:_calloutAlignment])
    {
        // Suitable div is already open, so cancel the buffer and carry on writing
        [_calloutBuffer discardBuffer];
    }
    else
    {
        // Write the opening tags
        [self startElement:@"div"
                     idName:[[self currentDOMController] elementIdName]
                  className:[@"callout-container " stringByAppendingString:alignment]];
        
        [self startElement:@"div" idName:nil className:@"callout"];
        
        [self startElement:@"div" idName:nil className:@"callout-content"];
        
        
        OBASSERT(!_calloutAlignment);
        _calloutAlignment = [alignment copy];
    }
}

- (void)endCallout;
{
    // Buffer this call so consecutive matching callouts can be blended into one
    [_calloutBuffer beginBuffering];
    
    [self endElement]; // callout-content
    [self endElement]; // callout
    [self endElement]; // callout-container
    
    [_calloutBuffer flushOnNextWrite];
}

- (void)megaBufferedWriterWillFlush:(KSMegaBufferedWriter *)buffer;
{
    OBASSERT(buffer == _calloutBuffer);
    [_calloutAlignment release]; _calloutAlignment = nil;
}

#pragma mark URLs/Paths

- (NSString *)relativeURLStringOfURL:(NSURL *)URL;
{
    OBPRECONDITION(URL);
    
    NSString *result;
    
    switch ([self generationPurpose])
    {
        case kSVHTMLGenerationPurposeEditing:
            result = [URL absoluteString];
            break;
        default:
            result = [URL stringRelativeToURL:[self baseURL]];
            break;
    }
    
    return result;
}

- (NSString *)relativeURLStringOfSiteItem:(SVSiteItem *)page;
{
    OBPRECONDITION(page);
    
    NSString *result = nil;
    
    switch ([self generationPurpose])
    {
        case kSVHTMLGenerationPurposeEditing:
            result = [page previewPath];
            break;
        case kSVHTMLGenerationPurposeQuickLookPreview:
            result= @"javascript:void(0)";
            break;
        default:
        {
            NSURL *URL = [page URL];
            if (URL) result = [self relativeURLStringOfURL:URL];
            break;
        }
    }
    
    return result;
}

- (NSString *)relativeURLStringOfPage:(id <SVPage>)page;
{
    return [self relativeURLStringOfSiteItem:(SVSiteItem *)page];
}

- (NSString *)relativeURLStringOfResourceFile:(NSURL *)resourceURL;
{
    NSString *result;
	switch ([self generationPurpose])
	{
		case kSVHTMLGenerationPurposeEditing:
			result = [resourceURL absoluteString];
			break;
            
		case kSVHTMLGenerationPurposeQuickLookPreview:
			result = [[BDAlias aliasWithPath:[resourceURL path]] quickLookPseudoTag];
			break;
			
		default:
		{
			KTHostProperties *hostProperties = [[[self page] site] hostProperties];
			NSURL *resourceFileURL = [hostProperties URLForResourceFile:[resourceURL lastPathComponent]];
			result = [resourceFileURL stringRelativeToURL:[self baseURL]];
			break;
		}
	}
    
	// TODO: Tell the delegate
	//[self didEncounterResourceFile:resourceURL];
    
	return result;
}

#pragma mark Media

- (NSURL *)addMedia:(id <SVMedia>)media;
{
    return [self addMedia:media width:nil height:nil fileType:nil];
}

- (NSURL *)addMedia:(id <SVMedia>)media
              width:(NSNumber *)width
             height:(NSNumber *)height
           fileType:(NSString *)type;
{
    OBPRECONDITION(media);
    
    NSURL *result = [media fileURL];
    if (!result) result = [[(SVMediaRecord *)media URLResponse] URL];
    
    return result;
}

- (void)writeImageWithIdName:(NSString *)idName
                   className:(NSString *)className
                 sourceMedia:(SVMediaRecord *)media
                         alt:(NSString *)altText
                       width:(NSNumber *)width
                      height:(NSNumber *)height;
{
    NSURL *URL = [self addMedia:media width:width height:height fileType:nil];
    NSString *src = (URL ? [self relativeURLStringOfURL:URL] : @"");
    
    [self writeImageWithIdName:idName
                     className:className
                           src:src
                           alt:altText
                         width:[width description]
                        height:[height description]];
}

#pragma mark Resource Files

- (NSURL *)addResourceWithURL:(NSURL *)resourceURL;
{
    return resourceURL; // subclasses will correct for publishing
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

#pragma mark Extra markup

- (NSMutableString *)extraHeaderMarkup; // can append to, query, as you like while parsing
{
    return _headerMarkup;
}

- (void)writeExtraHeaders;  // writes any code plug-ins etc. have requested should inside the <head> element
{
    // Start buffering into a temporary string writer
    [_postHeaderBuffer beginBuffering];
}

- (NSMutableString *)endBodyMarkup; // can append to, query, as you like while parsing
{
    return _endBodyMarkup;
}

- (void)writeEndBodyString; // writes any code plug-ins etc. have requested should go at the end of the page, before </body>
{
    // Finish buffering extra header
    [[[_postHeaderBuffer valueForKey:@"_outputs"] objectAtIndex:0]  // hack to get underlying stream
     writeString:[self extraHeaderMarkup]];
    
    [_postHeaderBuffer flush];
    
    
    // Write the end body markup
    [self writeString:[self endBodyMarkup]];
}

#pragma mark Content

- (void)willBeginWritingGraphic:(SVGraphic *)object;
{
    _numberOfGraphics++;
}

- (void)didEndWritingGraphic; { }

- (NSUInteger)numberOfGraphicsOnPage; { return _numberOfGraphics; }

// Two methods do the same thing. Need to ditch -addDependencyOnObject:keyPath: at some point
- (void)addDependencyOnObject:(NSObject *)object keyPath:(NSString *)keyPath { }
- (void)addDependencyForKeyPath:(NSString *)keyPath ofObject:(NSObject *)object;
{
    [self addDependencyOnObject:object keyPath:keyPath];
}

- (void)startElement:(NSString *)element andWriteTitleOfPage:(id <SVPage>)page;
{
    [self startElement:element];
    
    [self writeText:[page title]];
}

#pragma mark Raw Writing

// Ignore
- (void)writeNewline { }

- (void)writeAttributedHTMLString:(NSAttributedString *)attributedHTML;
{
    //  Pretty similar to -[SVRichText richText]. Perhaps we can merge the two eventually?
    
    
    NSRange range = NSMakeRange(0, [attributedHTML length]);
    NSUInteger location = 0;
    
    while (location < range.length)
    {
        NSRange effectiveRange;
        SVGraphic *attachment = [attributedHTML attribute:@"SVAttachment"
                                                  atIndex:location
                                    longestEffectiveRange:&effectiveRange
                                                  inRange:range];
        
        if (attachment)
        {
            // Write the graphic
            [attachment writeHTML:self];
        }
        else
        {
            NSString *html = [[attributedHTML string] substringWithRange:effectiveRange];
            [self writeHTMLString:html];
        }
        
        // Advance the search
        location = location + effectiveRange.length;
    }
}

- (void)close;
{
    [super close];
    
    [_postHeaderBuffer release]; _postHeaderBuffer = nil;
    [_calloutBuffer release]; _calloutBuffer = nil;
}

#pragma mark Legacy

@synthesize page = _currentPage;

#pragma mark SVPlugInContext

- (id <SVHTMLWriter>)HTMLWriter; { return self; }

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


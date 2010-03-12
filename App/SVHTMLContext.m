//
//  SVHTMLContext.m
//  Sandvox
//
//  Created by Mike on 19/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVHTMLContext.h"

#import "KTHostProperties.h"
#import "KTPage.h"
#import "KTSite.h"
#import "BDAlias+QuickLook.h"

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

- (id)initWithStringWriter:(id <KSStringWriter>)writer; // designated initializer
{
    [super initWithStringWriter:writer];
    
    _stringWriter = [writer retain];
    
    _generationPurpose = kSVHTMLGenerationPurposeNormal;
    
    _includeStyling = YES;
    _mainCSS = [[NSMutableString alloc] init];
    
    _liveDataFeeds = YES;
    [self setEncoding:NSUTF8StringEncoding];
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
    
    [_endBodyMarkup release];
    [_iteratorsStack release];
    [_stringWriter release];
    
    [super dealloc];
}

#pragma mark Properties

@synthesize baseURL = _baseURL;
@synthesize liveDataFeeds = _liveDataFeeds;
@synthesize encoding = _stringEncoding;
@synthesize language = _language;

@synthesize generationPurpose = _generationPurpose;

- (BOOL)isEditable { return [self generationPurpose] == kSVHTMLGenerationPurposeEditing; }
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
    [self setCurrentPage:[context currentPage]];
    [self setBaseURL:[context baseURL]];
    [self setIncludeStyling:[context includeStyling]];
    [self setLiveDataFeeds:[context liveDataFeeds]];
    [self setXHTML:[context isXHTML]];
    [self setEncoding:[context encoding]];
    [self setGenerationPurpose:[context generationPurpose]];
}

#pragma mark CSS

@synthesize includeStyling = _includeStyling;

@synthesize mainCSS = _mainCSS;
@synthesize mainCSSURL = _mainCSSURL;

#pragma mark Header Tags

@synthesize currentHeaderLevel = _headerLevel;

- (NSString *)currentHeaderLevelTagName;
{
    NSString *result = [NSString stringWithFormat:@"h%u", [self currentHeaderLevel]];
    return result;
}

#pragma mark Callouts

- (void)writeCalloutStartWithAlignmentClassName:(NSString *)alignment;
{
    [self writeStartTag:@"div"
                 idName:nil
              className:[@"callout-container " stringByAppendingString:alignment]];
    
    [self writeStartTag:@"div" idName:nil className:@"callout"];
    
    [self writeStartTag:@"div" idName:nil className:@"callout-content"];
    
    
    OBASSERT(!_calloutAlignment);
    _calloutAlignment = [alignment copy];
}

- (void)writeCalloutEnd;    // written lazily so consecutive matching callouts are blended into one
{
    [_calloutAlignment release]; _calloutAlignment = nil;
    
    
    [self writeEndTag]; // callout-content
    [self writeEndTag]; // callout
    [self writeEndTag]; // callout-container
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

- (NSString *)relativeURLStringOfPage:(KTPage *)page;   // will generate a relative URL string when possible
{
    OBPRECONDITION(page);
    
    NSString *result;
    
    switch ([self generationPurpose])
    {
        case kSVHTMLGenerationPurposeEditing:
            result = [page previewPath];
            break;
        case kSVHTMLGenerationPurposeQuickLookPreview:
            result= @"javascript:void(0)";
            break;
        default:
            result = [self relativeURLStringOfURL:[page URL]];
            break;
    }
    
    return result;
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
			KTHostProperties *hostProperties = [[[self currentPage] site] hostProperties];
			NSURL *resourceFileURL = [hostProperties URLForResourceFile:[resourceURL lastPathComponent]];
			result = [resourceFileURL stringRelativeToURL:[self baseURL]];
			break;
		}
	}
    
	// TODO: Tell the delegate
	//[self didEncounterResourceFile:resourceURL];
    
	return result;
}

#pragma mark Resource Files
- (void)addResource:(NSURL *)resourceURL;   // call to register the resource for needing publishing
{
    // TODO: Actually record the resource
}

- (NSURL *)URLOfResource:(NSURL *)resource; // the URL of a resource once published. Calls -addResource internally
{
    [self addResource:resource];
    return [[[[self currentPage] site] hostProperties] URLForResourceFile:
            [resource lastPathComponent]];
}

//- (NSString *)uploadPathOfResource:(NSURL *)resource; // counterpart to -URLOfResource

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
    NSMutableString *buffer = [[NSMutableString alloc] init];
    [_stringWriter release]; _stringWriter = buffer;
}

- (id <KSStringWriter>)stringWriter
{
    //  Override to force use of our own writer
    return _stringWriter;
}

- (NSMutableString *)endBodyMarkup; // can append to, query, as you like while parsing
{
    return _endBodyMarkup;
}

- (void)writeEndBodyString; // writes any code plug-ins etc. have requested should go at the end of the page, before </body>
{
    // Finish buffering extra header
    id <KSStringWriter> buffer = _stringWriter;
    _stringWriter = [[super stringWriter] retain];
    
    [self writeString:[self extraHeaderMarkup]];
    
    [self writeString:(NSString *)buffer];
    [buffer release];
    
    
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

- (void)addDependencyOnObject:(NSObject *)object keyPath:(NSString *)keyPath { }

#pragma mark Legacy

@synthesize currentPage = _currentPage;
- (void)setCurrentPage:(KTPage *)page
{
    page = [page retain];
    [_currentPage release], _currentPage = page;
    
    [self setBaseURL:[page URL]];
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


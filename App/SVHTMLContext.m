//
//  SVHTMLContext.m
//  Sandvox
//
//  Created by Mike on 19/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVHTMLContext.h"

#import "KTHostProperties.h"
#import "KTAbstractPage.h"
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

- (id)initWithStringStream:(id <KSStringOutputStream>)stream; // designated initializer
{
    [super init];
    
    _stream = [stream retain];
    _generationPurpose = kSVHTMLGenerationPurposeNormal;
    _includeStyling = YES;
    _liveDataFeeds = YES;
    [self setEncoding:NSUTF8StringEncoding];
    _openElements = [[NSMutableArray alloc] init];
    _iteratorsStack = [[NSMutableArray alloc] init];
    _textBlocks = [[NSMutableArray alloc] init];
    
    return self;
}

- (id)init;
{
    return [self initWithStringStream:nil];
}

- (void)dealloc
{
    [_baseURL release];
    [_currentPage release];
    [_iteratorsStack release];
    [_textBlocks release];
    [_stream release];
    
    [super dealloc];
}

#pragma mark High-level Writing

- (void)writeHTMLString:(NSString *)html;
{
    [self writeString:html];
}

- (void)writeHTMLFormat:(NSString *)format , ...
{
	va_list argList;
	va_start(argList, format);
	NSString *aString = [[[NSString alloc] initWithFormat:format arguments:argList] autorelease];
	va_end(argList);
	
    [self writeHTMLString:aString];
}

- (void)writeText:(NSString *)string;       // escapes the string and calls -writeHTMLString:
{
    NSString *html = [string stringByEscapingHTMLEntities];
    [self writeHTMLString:html];
}

- (void)writeComment:(NSString *)comment;   // escapes the string, and wraps in a comment tag
{
    [self writeString:@"<!--"];
    [self writeString:[comment stringByEscapingHTMLEntities]];
    [self writeString:@"-->"];
}

- (void)writeNewline;   // writes a newline character and the tabs to match -indentationLevel
{
    [self writeString:@"\n"];
    _needsToWriteIndentation = YES;
}

#pragma mark Elements

- (void)openTag:(NSString *)tagName;        //  <tagName
{
    [self writeString:@"<"];
    [self writeString:[tagName lowercaseString]];
    
    // Must do this AFTER writing the string so subclasses can take early action in a -writeString: override
    [_openElements addObject:[tagName uppercaseString]];
}

- (void)closeStartTag;
{
    [self writeString:@">"];
    [self increaseIndentationLevel];
}

- (void)closeEmptyElementTag;               //   />    OR    >    depending on -isXHTML
{
    if ([self isXHTML])
    {
        [self writeString:@" />"];
    }
    else
    {
        [self writeString:@">"];
    }
    
    [_openElements removeLastObject];
}

- (void)writeEndTag;
{
	[self decreaseIndentationLevel];

	[self writeString:@"</"];
    [self writeString:[[_openElements lastObject] lowercaseString]];
    [self writeString:@">"];
    
    [_openElements removeLastObject];
}

#pragma mark Element Attributes

- (void)writeAttribute:(NSString *)attribute
                 value:(NSString *)value;
{
    [self writeString:@" "];
    [self writeString:attribute];
    [self writeString:@"=\""];
    [self writeString:[value stringByEscapingHTMLEntitiesWithQuot:YES]];	// make sure to escape the quote mark
    [self writeString:@"\""];
}

#pragma mark Querying Open Elements Stack

- (NSString *)lastOpenElementTagName;
{
    return [_openElements lastObject];
}

- (BOOL)hasOpenElementWithTagName:(NSString *)tagName;
{
    BOOL result = [_openElements containsObject:[tagName uppercaseString]];
    return result;
}

#pragma mark Indentation

@synthesize indentationLevel = _indentation;

- (void)increaseIndentationLevel;
{
    [self setIndentationLevel:[self indentationLevel] + 1];
}

- (void)decreaseIndentationLevel;
{
    [self setIndentationLevel:[self indentationLevel] - 1];
}

#pragma mark Primitive

- (void)writeString:(NSString *)string;
{
    if (_needsToWriteIndentation)
    {
        _needsToWriteIndentation = NO;  // don't want to get stuck in an infinite loop!
        for (int i = 0; i < [self indentationLevel]; i++)
        {
            [self writeString:@"\t"];
        }
    }
    
    [[self stringStream] writeString:string];
}

@synthesize stringStream = _stream;

#pragma mark Properties

@synthesize baseURL = _baseURL;
@synthesize includeStyling = _includeStyling;
@synthesize liveDataFeeds = _liveDataFeeds;
@synthesize XHTML = _isXHTML;
@synthesize encoding = _stringEncoding;

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

- (NSString *)relativeURLStringOfPage:(KTAbstractPage *)page;   // will generate a relative URL string when possible
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

#pragma mark Content

- (void)addDependencyOnObject:(NSObject *)object keyPath:(NSString *)keyPath { }

- (NSArray *)generatedTextBlocks { return [[_textBlocks copy] autorelease]; }

- (void)didGenerateTextBlock:(SVHTMLTextBlock *)textBlock;
{
    OBPRECONDITION(_textBlocks);
    
    [_textBlocks addObject:textBlock];
}

#pragma mark Legacy

@synthesize currentPage = _currentPage;
- (void)setCurrentPage:(KTAbstractPage *)page
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


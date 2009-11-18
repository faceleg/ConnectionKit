//
//  SVHTMLContext.m
//  Sandvox
//
//  Created by Mike on 19/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVHTMLContext.h"

#import "NSURL+Karelia.h"

#import "KTHostProperties.h"
#import "KTAbstractPage.h"
#import "KTSite.h"
#import "BDAlias+QuickLook.h"


@implementation SVHTMLContext

#pragma mark Stack

+ (SVHTMLContext *)currentContext
{
    SVHTMLContext *result = [[[[NSThread currentThread] threadDictionary] objectForKey:@"SVHTMLGenerationContextStack"] lastObject];
    return result;
}

+ (void)pushContext:(SVHTMLContext *)context
{
    NSMutableArray *stack = [[[NSThread currentThread] threadDictionary] objectForKey:@"SVHTMLGenerationContextStack"];
    if (!stack) stack = [NSMutableArray arrayWithCapacity:1];
    [stack addObject:context];
    [[[NSThread currentThread] threadDictionary] setObject:stack forKey:@"SVHTMLGenerationContextStack"];
}

+ (void)popContext
{
    NSMutableArray *stack = [[[NSThread currentThread] threadDictionary] objectForKey:@"SVHTMLGenerationContextStack"];
    if ([stack count] > 0) [stack removeLastObject];
}

#pragma mark Init & Dealloc

- (id)init
{
    [super init];
    
    _includeStyling = YES;
    _textBlocks = [[NSMutableArray alloc] init];
    
    return self;
}

- (void)dealloc
{
    [_baseURL release];
    [_currentPage release];
    [_textBlocks release];
    
    [super dealloc];
}

#pragma mark Properties

@synthesize baseURL = _baseURL;
@synthesize includeStyling = _includeStyling;
@synthesize liveDataFeeds = _liveDataFeeds;

@synthesize generationPurpose = _generationPurpose;

- (BOOL)isEditable { return [self generationPurpose] == kGeneratingPreview; }
+ (NSSet *)keyPathsForValuesAffectingEditable
{
    return [NSSet setWithObject:@"generationPurpose"];
}

- (BOOL)isPublishing
{
    BOOL result = ([self generationPurpose] != kGeneratingPreview &&
                   [self generationPurpose] != kGeneratingQuickLookPreview);
    return result;
}

#pragma mark URLs/Paths

- (NSString *)URLStringForResourceFile:(NSURL *)resourceURL;
{
    NSString *result;
	switch ([self generationPurpose])
	{
		case kGeneratingPreview:
			result = [resourceURL absoluteString];
			break;
            
		case kGeneratingQuickLookPreview:
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

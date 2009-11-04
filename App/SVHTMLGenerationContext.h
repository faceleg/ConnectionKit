//
//  SVHTMLGenerationContext.h
//  Sandvox
//
//  Created by Mike on 19/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


// publishing mode
typedef enum {
	kGeneratingPreview = 0,
	kGeneratingLocal,
	kGeneratingRemote,
	kGeneratingRemoteExport,
	kGeneratingQuickLookPreview = 10,
} KTHTMLGenerationPurpose;


@class KTAbstractPage, SVHTMLTemplateTextBlock;
@interface SVHTMLGenerationContext : NSObject
{
    NSURL                   *_baseURL;
    KTAbstractPage			*_currentPage;
	KTHTMLGenerationPurpose	_generationPurpose;
	BOOL					_includeStyling;
	BOOL                    _liveDataFeeds;
    
    NSMutableArray  *_textBlocks;
}

+ (SVHTMLGenerationContext *)currentContext;
+ (void)pushContext:(SVHTMLGenerationContext *)context;
+ (void)popContext;


@property(nonatomic, copy) NSURL *baseURL;
@property(nonatomic) BOOL includeStyling;
@property(nonatomic) BOOL liveDataFeeds;

@property(nonatomic) KTHTMLGenerationPurpose generationPurpose;
- (BOOL)isPublishing;


#pragma mark Content

@property(nonatomic, copy, readonly) NSArray *generatedTextBlocks;
- (void)didGenerateTextBlock:(SVHTMLTemplateTextBlock *)textBlock;




// In for compatibility, overrides -baseURL
@property(nonatomic, retain) KTAbstractPage *currentPage;

@end

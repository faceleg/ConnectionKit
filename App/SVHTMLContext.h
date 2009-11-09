//
//  SVHTMLContext.h
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
@interface SVHTMLContext : NSObject
{
    NSURL                   *_baseURL;
    KTAbstractPage			*_currentPage;
	KTHTMLGenerationPurpose	_generationPurpose;
	BOOL					_includeStyling;
	BOOL                    _liveDataFeeds;
    
    NSMutableArray  *_textBlocks;
}

+ (SVHTMLContext *)currentContext;
+ (void)pushContext:(SVHTMLContext *)context;
+ (void)popContext;


@property(nonatomic, copy) NSURL *baseURL;
@property(nonatomic) BOOL includeStyling;
@property(nonatomic) BOOL liveDataFeeds;

@property(nonatomic) KTHTMLGenerationPurpose generationPurpose;
- (BOOL)isPublishing;


#pragma mark URLs/Paths
- (NSString *)URLStringForResourceFile:(NSURL *)resourceURL;


#pragma mark Content

// Default implementation does nothing. Subclasses can implement for introspecting the dependencies (WebView loading does)
- (void)addDependencyOnObject:(NSObject *)object keyPath:(NSString *)keyPath;
                               
@property(nonatomic, copy, readonly) NSArray *generatedTextBlocks;
- (void)didGenerateTextBlock:(SVHTMLTemplateTextBlock *)textBlock;




// In for compatibility, overrides -baseURL
@property(nonatomic, retain) KTAbstractPage *currentPage;

@end

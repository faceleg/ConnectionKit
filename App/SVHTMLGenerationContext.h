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


@class KTAbstractPage;
@interface SVHTMLGenerationContext : NSObject
{
    NSURL                   *_baseURL;
    KTAbstractPage			*_currentPage;
	KTHTMLGenerationPurpose	_generationPurpose;
	BOOL					_includeStyling;
	BOOL                    _liveDataFeeds;
}

+ (SVHTMLGenerationContext *)currentContext;
+ (void)pushContext:(SVHTMLGenerationContext *)context;
+ (void)popContext;


@property(nonatomic, copy) NSURL *baseURL;
@property(nonatomic) BOOL includeStyling;
@property(nonatomic) BOOL liveDataFeeds;

@property(nonatomic) KTHTMLGenerationPurpose generationPurpose;
- (BOOL)isPublishing;



// In for compatibility, overrides -baseURL
@property(nonatomic, retain) KTAbstractPage *currentPage;

@end

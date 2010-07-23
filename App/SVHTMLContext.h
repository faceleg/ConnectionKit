//
//  SVHTMLContext.h
//  Sandvox
//
//  Created by Mike on 19/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSHTMLWriter.h"
#import "SVPlugIn.h"
#import "KSMegaBufferedWriter.h"

#import "KT.h"  // for KTDocType. We need to fix this!


// publishing mode
typedef enum {
	kSVHTMLGenerationPurposeNormal = -1,    // publishing
    kSVHTMLGenerationPurposeEditing,        // (previously known as preview)
    kSVHTMLGenerationPurposeQuickLookPreview = 10,
} KTHTMLGenerationPurpose;


#pragma mark -


@class KTPage, SVSiteItem, SVGraphic, SVHTMLTextBlock, SVLink, SVMediaRecord;
@protocol SVMedia;


@interface SVHTMLContext : KSHTMLWriter <SVPlugInContext, SVHTMLWriter, KSMegaBufferedWriterDelegate>
{
  @private
    NSMutableString *_output;
    
    NSURL   *_baseURL;
    KTPage	*_currentPage;
    
	BOOL                _liveDataFeeds;
    NSStringEncoding    _stringEncoding;
    NSString            *_language;
    
    KTDocType   _docType;
    KTDocType   _maxDocType;
    
    BOOL            _includeStyling;
    NSURL           *_mainCSSURL;
    
    NSUInteger  _headerLevel;
	
    NSString                *_calloutAlignment;
    KSMegaBufferedWriter    *_calloutBuffer;
    
    NSMutableString         *_headerMarkup;
    NSMutableString         *_endBodyMarkup;
    KSMegaBufferedWriter    *_postHeaderBuffer;
    
    NSMutableArray  *_iteratorsStack;
    
    NSUInteger      _numberOfGraphics;
}

#pragma mark Init

// Like -initWithOutputWriter: but gives the context more info about the output. In practice this means that if a page component changes the doctype, the output will be wiped and the page rewritten with the new doctype.
- (id)initWithMutableString:(NSMutableString *)output;

- (id)init; // calls through to -initWithMutableString:

// For if you need a fresh context based off an existing one
- (id)initWithOutputWriter:(id <KSWriter>)output inheritFromContext:(SVHTMLContext *)context;


#pragma mark Status
// Throws away any data that can be, ready for more to write. Mainly used to retry writing after a doctype change
- (void)reset;


#pragma mark Document
// Sets various context properties to match the page too
- (void)writeDocumentWithPage:(KTPage *)page;


#pragma mark Properties

// Not 100% sure I want to expose this!
@property(nonatomic, retain, readonly) NSMutableString *mutableString;


@property(nonatomic, retain, readonly) KTPage *page;    // does NOT affect .baseURL
@property(nonatomic, copy) NSURL *baseURL;
@property(nonatomic) BOOL liveDataFeeds;
@property(nonatomic) NSStringEncoding encoding;   // UTF-8 by default
@property(nonatomic, copy) NSString *language;

@property(nonatomic, readonly) KTHTMLGenerationPurpose generationPurpose;
- (BOOL)isForEditing;		// Synonym, apparently...
- (BOOL)isForQuickLookPreview;
- (BOOL)isForPublishing;
- (BOOL)isForPublishingProOnly;


#pragma mark Doctype

@property(nonatomic) KTDocType docType;

// Call if your component supports only particular HTML doc types. Otherwise, leave alone! Calling mid-write may have no immediate effect; instead the system will try another write after applying the limit.
- (void)limitToMaxDocType:(KTDocType)docType;

+ (NSString *)titleOfDocType:(KTDocType)docType localize:(BOOL)shouldLocalizeForDisplay;
+ (NSString *)stringFromDocType:(KTDocType)docType;


#pragma mark CSS
@property(nonatomic) BOOL includeStyling;
@property(nonatomic, copy, readonly) NSURL *mainCSSURL;


#pragma mark Elements/Comments
//  For when you have just closed an element and want to end up with this:
//  </div> <!-- comment -->
- (void)writeEndTagWithComment:(NSString *)comment;


#pragma mark Header Tags
@property (nonatomic) NSUInteger currentHeaderLevel;    // if you need to write a header tag, use this level
- (NSString *)currentHeaderLevelTagName;                // takes, .currentHeaderLevel and produces h3 etc.


#pragma mark Graphics
- (void)writeGraphic:(SVGraphic *)graphic;  // takes care of callout stuff for you
- (void)writeGraphics:(NSArray *)graphics;  // convenience
- (void)writeGraphicIgnoringCallout:(SVGraphic *)graphic;   // for subclassers
- (NSUInteger)numberOfGraphicsOnPage; // incremented for each call to -writeGraphic:


#pragma mark Callouts
- (void)startCalloutForGraphic:(SVGraphic *)graphic;
- (BOOL)isWritingCallout;
@property(nonatomic, retain, readonly) KSMegaBufferedWriter *calloutBuffer;


#pragma mark Iterations

// It's pretty common to loop through a series of items when generating HTML. e.g. Pagelets in the Sidebar. When doing so, it's nice to generate a CSS class name that corresponds so special styling can be applied based on that. The Template Parser provides nice functions for generating these class names, but the stack of such iterations is maintained here.
// IMPORTANT: Iteration in the context is 0-based. For CSS class names you generally want it to be 1-based, so bump up values by 1. The HTML Template Parser functions do this automatically interally.

@property(nonatomic, readonly) NSUInteger currentIteration;
@property(nonatomic, readonly) NSUInteger currentIterationsCount;
- (void)nextIteration;  // increments -currentIteration. Pops the iterators stack if this was the last one.
- (void)beginIteratingWithCount:(NSUInteger)count;  // Pushes a new iterator on the stack
- (void)popIterator;  // Pops the iterators stack early


#pragma mark URLs/Paths
// These methods try to generate as simple a URL string when possible. e.g. relative path, or page ID
- (NSString *)relativeURLStringOfSiteItem:(SVSiteItem *)page;
- (NSString *)relativeURLStringOfResourceFile:(NSURL *)resourceURL;


#pragma mark Media

// These method return the URL to find the media at. It can be passed on to -relativeURLStringOfURL: etc.
// For most use cases -addMedia: is good enough. The longer method exists so as to get the URL of the image after scaling. For example during editing, we load full-size images and get WebKit to scale them, but during publishing want to point to a separate scaled version of the image. Potentially one day this method could support movies etc.
- (NSURL *)addMedia:(id <SVMedia>)media;
- (NSURL *)addMedia:(id <SVMedia>)media
              width:(NSNumber *)width   // nil means don't resize
             height:(NSNumber *)height  // ditto
               type:(NSString *)type;   // nil means keep in native format

- (void)writeImageWithIdName:(NSString *)idName
                   className:(NSString *)className
                 sourceMedia:(SVMediaRecord *)media
                         alt:(NSString *)altText
                       width:(NSNumber *)width
                      height:(NSNumber *)height
                        type:(NSString *)type;


#pragma mark Resource Files
// Call to register the resource for needing publishing. Returns the URL to reference the resource by
- (NSURL *)addResourceWithURL:(NSURL *)resourceURL;


#pragma mark Extra markup

- (NSMutableString *)extraHeaderMarkup;
- (void)writeExtraHeaders;  // writes any code plug-ins etc. have requested should be inside the <head> element

- (NSMutableString *)endBodyMarkup; // can append to, query, as you like while parsing
- (void)writeEndBodyString; // writes any code plug-ins etc. have requested should go at the end of the page, before </body>


#pragma mark Content
// Default implementation does nothing. Subclasses can implement for introspecting the dependencies (WebView loading does)
- (void)addDependencyOnObject:(NSObject *)object keyPath:(NSString *)keyPath;


#pragma mark Raw Writing
- (void)writeAttributedHTMLString:(NSAttributedString *)attributedHTML;


@end


#pragma mark -


@interface SVHTMLContext (CurrentContext)

+ (SVHTMLContext *)currentContext;
+ (void)pushContext:(SVHTMLContext *)context;
+ (void)popContext;

// Convenience methods for pushing and popping that will just do the right thing when the receiver is nil
- (void)push;
- (void)pop;    // only pops if receiver is the current context

@end


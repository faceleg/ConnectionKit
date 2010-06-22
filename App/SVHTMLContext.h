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
    NSURL   *_baseURL;
    KTPage	*_currentPage;
    
	BOOL                _liveDataFeeds;
    NSStringEncoding    _stringEncoding;
    NSString            *_language;
    KTDocType           _docType;
    
    BOOL            _includeStyling;
    NSURL           *_mainCSSURL;
    NSMutableString *_mainCSS;
    
    NSUInteger  _headerLevel;
	
    NSString                *_calloutAlignment;
    KSMegaBufferedWriter    *_calloutBuffer;
    
    NSMutableString         *_headerMarkup;
    NSMutableString         *_endBodyMarkup;
    KSMegaBufferedWriter    *_postHeaderBuffer;
    
    NSMutableArray  *_iteratorsStack;
    
    NSUInteger      _numberOfGraphics;
}

#pragma mark Properties

@property(nonatomic, copy) NSURL *baseURL;
@property(nonatomic) BOOL liveDataFeeds;
@property(nonatomic) NSStringEncoding encoding;   // UTF-8 by default
@property(nonatomic, copy) NSString *language;

@property(nonatomic) KTDocType maxDocType;
- (void)limitToMaxDocType:(KTDocType)docType;

@property(nonatomic, readonly) KTHTMLGenerationPurpose generationPurpose;
- (BOOL)isEditable; // YES if HTML is intended to be edited directly in a Web Editor
- (BOOL)isForQuickLookPreview;
- (BOOL)isForPublishing;

- (void)copyPropertiesFromContext:(SVHTMLContext *)context;


#pragma mark CSS

@property(nonatomic) BOOL includeStyling;

@property(nonatomic, readonly) NSMutableString *mainCSS;
- (void)addCSSWithURL:(NSURL *)cssURL;
@property(nonatomic, copy) NSURL *mainCSSURL;


#pragma mark Elements/Comments
//  For when you have just closed an element and want to end up with this:
//  </div> <!-- comment -->
- (void)writeEndTagWithComment:(NSString *)comment;


#pragma mark Header Tags
@property (nonatomic) NSUInteger currentHeaderLevel;    // if you need to write a header tag, use this level
- (NSString *)currentHeaderLevelTagName;                // takes, .currentHeaderLevel and produces h3 etc.


#pragma mark Callouts
- (void)beginCalloutWithAlignmentClassName:(NSString *)alignment;
- (void)endCallout;    // written lazily so consecutive matching callouts are blended into one
- (BOOL)isWritingCallout;


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
- (NSString *)relativeURLStringOfURL:(NSURL *)URL;
- (NSString *)relativeURLStringOfSiteItem:(SVSiteItem *)page;
- (NSString *)relativeURLStringOfResourceFile:(NSURL *)resourceURL;


#pragma mark Media

// These method return the URL to find the media at. It can be passed on to -relativeURLStringOfURL: etc.
// For most use cases -addMedia: is good enough. The longer method exists so as to get the URL of the image after scaling. For example during editing, we load full-size images and get WebKit to scale them, but during publishing want to point to a separate scaled version of the image. Potentially one day this method could support movies etc.
- (NSURL *)addMedia:(id <SVMedia>)media;
- (NSURL *)addMedia:(id <SVMedia>)media
              width:(NSNumber *)width   // nil means don't resize
             height:(NSNumber *)height  // ditto
           fileType:(NSString *)type;   // nil means keep in native format

- (void)writeImageWithIdName:(NSString *)idName
                   className:(NSString *)className
                 sourceMedia:(SVMediaRecord *)media
                         alt:(NSString *)altText
                       width:(NSNumber *)width
                      height:(NSNumber *)height;


#pragma mark Resource Files
// Call to register the resource for needing publishing. Returns the URL to reference the resource by
- (NSURL *)addResourceWithURL:(NSURL *)resourceURL;


#pragma mark Extra markup

- (NSMutableString *)extraHeaderMarkup;
- (void)writeExtraHeaders;  // writes any code plug-ins etc. have requested should be inside the <head> element

- (NSMutableString *)endBodyMarkup; // can append to, query, as you like while parsing
- (void)writeEndBodyString; // writes any code plug-ins etc. have requested should go at the end of the page, before </body>


#pragma mark Content

- (void)willBeginWritingGraphic:(SVGraphic *)object;
- (void)didEndWritingGraphic;
- (NSUInteger)numberOfGraphicsOnPage; // incremented for each call to -willWriteContentObject:

// Default implementation does nothing. Subclasses can implement for introspecting the dependencies (WebView loading does)
- (void)addDependencyOnObject:(NSObject *)object keyPath:(NSString *)keyPath;


#pragma mark Raw Writing
- (void)writeAttributedHTMLString:(NSAttributedString *)attributedHTML;


// In for compatibility. Does NOT affect -baseURL; change manually if you need to
@property(nonatomic, retain) KTPage *page;

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


//
//  SVHTMLContext.h
//  Sandvox
//
//  Created by Mike on 19/10/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//
//  An HTML Context provides rich set of methods and properties for building up HTML for use in Sandvox. Takes KSHTMLWriter and builds on it.
//  Different parts of the system subclass SVHTMLContext to tailor their behaviour to what the HTML is intended for. For example, publishing requires a context that uploads all media/resources referenced. The Web Editor has its own context that references local files where possible, and leaves much work to be performed dynamically by the app.
//  Bear in mind that a subset of SVHTMLContext's functionality is exposed to plug-ins throught the SVPlugInContext protocol, and much of the API is defined there instead.


#import "KSHTMLWriter.h"

#import "SVPlugIn.h"
#import "KSMegaBufferedWriter.h"
#import "KT.h"

#import <iMedia/iMedia.h>


// publishing mode
typedef enum {
	kSVHTMLGenerationPurposeNormal = -1,    // publishing
    kSVHTMLGenerationPurposeEditing,        // (previously known as preview)
    kSVHTMLGenerationPurposeQuickLookPreview = 10,
} KTHTMLGenerationPurpose;


#pragma mark -


@class KSStringWriter;
@class KTPage, SVSiteItem, SVArchivePage, SVGraphic, SVHTMLTextBlock, SVLink, SVMediaRecord, SVSidebarPageletsController;
@protocol SVGraphic, SVMedia, SVEnclosure;


@interface SVHTMLContext : KSHTMLWriter <SVPlugInContext>
{
  @private
    KSStringWriter  *_output;
    NSUInteger      _charactersWritten;
    
    NSURL   *_baseURL;
    
    KTPage	*_currentPage;
    id      _article;
    
	BOOL                _liveDataFeeds;
    NSString            *_language;
    
    KTDocType   _docType;
    KTDocType   _maxDocType;
    
    BOOL    _includeStyling;
    NSURL   *_mainCSSURL;
    
    NSUInteger      _headerLevel;
	
    NSMutableString         *_headerMarkup;
    NSMutableString         *_endBodyMarkup;
    NSUInteger              _headerMarkupIndex;
    
    NSMutableArray  *_iteratorsStack;
    BOOL            _writingPagelet;
    
    NSUInteger      _numberOfGraphics;
    
    SVSidebarPageletsController *_sidebarPageletsController;
}

#pragma mark Init

// Like -initWithOutputWriter: but gives the context more info about the output. In practice this means that if a page component changes the doctype, the output will be wiped and the page rewritten with the new doctype.
- (id)initWithOutputStringWriter:(KSStringWriter *)output;

- (id)init; // calls through to -initWithMutableString:

// For if you need a fresh context based off an existing one
- (id)initWithOutputWriter:(id <KSWriter>)output inheritFromContext:(SVHTMLContext *)context;


#pragma mark Status
// Throws away any data that can be, ready for more to write. Mainly used to retry writing after a doctype change
- (void)reset;


#pragma mark Document
// Sets various context properties to match the page too
- (void)writeDocumentWithPage:(KTPage *)page;
- (void)writeDocumentWithArchivePage:(SVArchivePage *)archive;


#pragma mark Properties

// Not 100% sure I want to expose this!
@property(nonatomic, retain, readonly) KSStringWriter *outputStringWriter;
@property(nonatomic, readonly) NSUInteger totalCharactersWritten;

@property(nonatomic, retain, readonly) KTPage *page;    // does NOT affect .baseURL
@property(nonatomic, copy) NSURL *baseURL;
@property(nonatomic) BOOL liveDataFeeds;
@property(nonatomic, copy) NSString *language;
- (BOOL)shouldWriteServerSideScripts;   // YES when -isForPublishing, but not when validating page

@property(nonatomic, readonly) KTHTMLGenerationPurpose generationPurpose;
- (BOOL)isForEditing;		// Synonym, apparently...
- (BOOL)isForQuickLookPreview;
- (BOOL)isForPublishing;
- (BOOL)canWriteCodeInjection;


#pragma mark Doctype

@property(nonatomic) KTDocType docType;

// Call if your component supports only particular HTML doc types. Otherwise, leave alone! Calling mid-write may have no immediate effect; instead the system will try another write after applying the limit.
- (void)limitToMaxDocType:(KTDocType)docType;

+ (NSString *)titleOfDocType:(KTDocType)docType localize:(BOOL)shouldLocalizeForDisplay;
+ (NSString *)stringFromDocType:(KTDocType)docType;


#pragma mark CSS
@property(nonatomic) BOOL includeStyling;
@property(nonatomic, copy, readonly) NSURL *mainCSSURL;


#pragma mark Attributes
- (void)pushAttributes:(NSDictionary *)attributes;
- (NSString *)pushPreferredIdName:(NSString *)preferredID;


#pragma mark Header Tags
@property (nonatomic) NSUInteger currentHeaderLevel;    // if you need to write a header tag, use this level
- (void)incrementHeaderLevel;
- (void)decrementHeaderLevel;


#pragma mark Graphics

- (void)writeGraphic:(id <SVGraphic>)graphic;
- (void)writeGraphics:(NSArray *)graphics;  // uses Iterations to process each graphic

// For subclassers:
- (void)writeGraphicBody:(id <SVGraphic>)graphic;

- (NSUInteger)numberOfGraphicsOnPage; // incremented for each call to -writeGraphic:


#pragma mark Metrics
// These methods take care of generating width, height or style attributes matching the object's size (which depends on the element being written).
// In addition, when editing, the context will keep the DOM matching the object's size, live
- (void)startElement:(NSString *)elementName bindSizeToObject:(NSObject *)object;
- (void)buildAttributesForElement:(NSString *)elementName bindSizeToObject:(NSObject *)object DOMControllerClass:(Class)controllerClass sizeDelta:(NSSize)sizeDelta;  // support


#pragma mark Text Blocks
- (void)willBeginWritingHTMLTextBlock:(SVHTMLTextBlock *)textBlock;
- (void)didEndWritingHTMLTextBlock;
- (void)willWriteSummaryOfPage:(SVSiteItem *)page;


#pragma mark Sidebar
// The context will provide a single controller for sidebar pagelets (pre-sorted etc.)
@property(nonatomic, retain) SVSidebarPageletsController *sidebarPageletsController;


#pragma mark Iterations

// It's pretty common to loop through a series of items when generating HTML. e.g. Pagelets in the Sidebar. When doing so, it's nice to generate a CSS class name that corresponds so special styling can be applied based on that. The Template Parser provides nice functions for generating these class names, but the stack of such iterations is maintained here.
// IMPORTANT: Iteration in the context is 0-based. For CSS class names you generally want it to be 1-based, so bump up values by 1. The HTML Template Parser functions do this automatically interally.

@property(nonatomic, readonly) NSUInteger currentIteration;
@property(nonatomic, readonly) NSUInteger currentIterationsCount;
- (void)nextIteration;  // increments -currentIteration. Pops the iterators stack if this was the last one.
- (void)beginIteratingWithCount:(NSUInteger)count;  // Pushes a new iterator on the stack
- (void)popIterator;  // Pops the iterators stack early


#pragma mark URLs/Paths
- (NSURL *)URLOfDesignFile:(NSString *)whichFileName;
- (NSString *)relativeURLStringOfSiteItem:(SVSiteItem *)page;


#pragma mark Media

// Returns the URL to find the media at. It can be passed on to -relativeStringFromURL: etc.
- (NSURL *)addMedia:(id <SVMedia>)media;

// When dealing with images specifically, you probably want this method. Rules:
//  - media is mandatory (obviously!)
//  - If width is non-nil, so must be height, and visa versa (for now anyway)
//  - If specifying size, MUST also specify type for resulting image
//
// Pass preferredFilename as nil if you want to use the default (same as source media)
- (NSURL *)addImageMedia:(id <SVMedia>)media
                   width:(NSNumber *)width
                  height:(NSNumber *)height
                    type:(NSString *)type
       preferredFilename:(NSString *)preferredFilename;

- (void)writeImageWithSourceMedia:(id <SVMedia>)media
                              alt:(NSString *)altText
                            width:(NSNumber *)width
                           height:(NSNumber *)height
                             type:(NSString *)type
                preferredFilename:(NSString *)preferredFilename;


#pragma mark Resource Files
// Call to register the resource for needing publishing. Returns the URL to reference the resource by
- (NSURL *)addResourceWithURL:(NSURL *)resourceURL;
- (NSString *)parseTemplateAtURL:(NSURL *)resource plugIn:(SVPlugIn *)plugIn;


#pragma mark Design
- (NSURL *)addBannerWithURL:(NSURL *)sourceURL;
- (NSURL *)addGraphicalTextData:(NSData *)imageData idName:(NSString *)idName;


#pragma mark Extra markup

- (NSMutableString *)extraHeaderMarkup;
- (NSMutableString *)endBodyMarkup; // can append to, query, as you like while parsing

- (void)writeExtraHeaders;  // writes any code plug-ins etc. have requested should be inside the <head> element

- (void)writeEndBodyString; // writes any code plug-ins etc. have requested should go at the end of the page, before </body>


#pragma mark Content
// Default implementation does nothing. Subclasses can implement for introspecting the dependencies (WebView loading does)
- (void)addDependencyOnObject:(NSObject *)object keyPath:(NSString *)keyPath;


#pragma mark Rich Text
- (void)writeAttributedHTMLString:(NSAttributedString *)attributedHTML;
- (void)writeCalloutWithGraphics:(NSArray *)pagelets;


#pragma mark RSS
- (void)writeEnclosure:(id <SVEnclosure>)enclosure;


@end


#pragma mark -


@interface KSHTMLWriter (SVHTMLContext)

//  For when you have just closed an element and want to end up with this:
//  </div> <!-- comment -->
- (void)writeEndTagWithComment:(NSString *)comment;

@end



/*  VERY IMPORTANT:
 *  SVHTMLContext conforms to SVPlugInContext, so look there for more methods/docs
 *  END VERY IMPORANT MESSAGE
 */


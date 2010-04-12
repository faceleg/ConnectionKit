//
//  SVHTMLContext.h
//  Sandvox
//
//  Created by Mike on 19/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSHTMLWriter.h"

#import <WebKit/DOMCore.h>


// publishing mode
typedef enum {
	kSVHTMLGenerationPurposeNormal = -1,    // publishing
    kSVHTMLGenerationPurposeEditing,        // (previously known as preview)
    kSVHTMLGenerationPurposeQuickLookPreview = 10,
} KTHTMLGenerationPurpose;


#pragma mark -


@class KTPage, KTPage, SVGraphic, SVHTMLTextBlock, SVLink, SVMediaRecord;
@protocol SVMedia;


@interface SVHTMLContext : KSHTMLWriter
{
  @private
    NSURL   *_baseURL;
    KTPage	*_currentPage;
    
	BOOL                    _liveDataFeeds;
    NSStringEncoding        _stringEncoding;
    NSString                *_language;
    
    BOOL            _includeStyling;
    NSURL           *_mainCSSURL;
    NSMutableString *_mainCSS;
    
    NSUInteger  _headerLevel;
	
    NSString    *_calloutAlignment;
    
    NSMutableString     *_headerMarkup;
    NSMutableString     *_endBodyMarkup;
    id <KSStringWriter> _stringWriter;
    
    NSMutableArray  *_iteratorsStack;
    
    NSUInteger      _numberOfGraphics;
}

#pragma mark Properties

@property(nonatomic, copy) NSURL *baseURL;
@property(nonatomic) BOOL liveDataFeeds;
@property(nonatomic) NSStringEncoding encoding;   // UTF-8 by default
@property(nonatomic, copy) NSString *language;

@property(nonatomic, readonly) KTHTMLGenerationPurpose generationPurpose;
@property(nonatomic, readonly, getter=isEditable) BOOL editable; // YES if HTML is intended to be edited directly in a Web Editor
- (BOOL)isForQuickLookPreview;
- (BOOL)isForPublishing;

- (void)copyPropertiesFromContext:(SVHTMLContext *)context;


#pragma mark CSS

@property(nonatomic) BOOL includeStyling;

@property(nonatomic, readonly) NSMutableString *mainCSS;
@property(nonatomic, copy) NSURL *mainCSSURL;


#pragma mark Header Tags
@property (nonatomic) NSUInteger currentHeaderLevel;    // if you need to write a header tag, use this level
- (NSString *)currentHeaderLevelTagName;                // takes, .currentHeaderLevel and produces h3 etc.


#pragma mark Callouts
- (void)writeCalloutStartTagsWithAlignmentClassName:(NSString *)alignment;
- (void)writeCalloutEnd;    // written lazily so consecutive matching callouts are blended into one


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
- (NSString *)relativeURLStringOfPage:(KTPage *)page;   
- (NSString *)relativeURLStringOfResourceFile:(NSURL *)resourceURL;


#pragma mark Media

- (NSURL *)addMedia:(id <SVMedia>)media;    // returns the URL to find the media at. Pass on to -relativeURLStringOfURL: etc.

- (void)writeImageWithIdName:(NSString *)idName
                   className:(NSString *)className
                 sourceMedia:(SVMediaRecord *)media
                         alt:(NSString *)altText
                       width:(NSString *)width
                      height:(NSString *)height;


#pragma mark Resource Files
- (void)addResource:(NSURL *)resourceURL;   // call to register the resource for needing publishing
- (NSURL *)URLOfResource:(NSURL *)resource; // the URL of a resource once published. Calls -addResource internally
//- (NSString *)uploadPathOfResource:(NSURL *)resource; // counterpart to -URLOfResource


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



// In for compatibility, overrides -baseURL
@property(nonatomic, retain) KTPage *currentPage;

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



#pragma mark -


@interface SVHTMLContext (HTMLElements)

#pragma mark Links

//  <a href="...." target="..." rel="nofollow">
- (void)writeAnchorStartTagWithHref:(NSString *)href title:(NSString *)titleString target:(NSString *)targetString rel:(NSString *)relString;


#pragma mark Images

//  <img src="..." alt="..." width="..." height="..." />
- (void)writeImageWithIdName:(NSString *)idName
                   className:(NSString *)className
                         src:(NSString *)src
                         alt:(NSString *)alt
                       width:(NSString *)width
                      height:(NSString *)height;


#pragma mark Link

- (void)writeLinkWithHref:(NSString *)href
                     type:(NSString *)type
                      rel:(NSString *)rel
                    title:(NSString *)title
                    media:(NSString *)media;

- (void)writeLinkToStylesheet:(NSString *)href
                        title:(NSString *)title
                        media:(NSString *)media;


#pragma mark Style

- (void)writeStyleStartTagWithType:(NSString *)type;


#pragma mark General

//  <tagName id="idName" class="className">
//  Calls -openTag: and -writeAttribute:value: appropriately for you
- (void)writeStartTag:(NSString *)tagName   
               idName:(NSString *)idName
            className:(NSString *)className;

@end


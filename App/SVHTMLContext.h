//
//  SVHTMLContext.h
//  Sandvox
//
//  Created by Mike on 19/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVTemplateContext.h"
#import <WebKit/DOMCore.h>


// publishing mode
typedef enum {
	kSVHTMLGenerationPurposeNormal = -1,    // publishing
    kSVHTMLGenerationPurposeEditing,        // (previously known as preview)
    kSVHTMLGenerationPurposeQuickLookPreview = 10,
} KTHTMLGenerationPurpose;


@class KTAbstractPage, SVHTMLTextBlock, SVLink;


@interface SVHTMLContext : SVTemplateContext
{
    NSMutableArray  *_openElements;
    NSInteger  _indentation;
    
    NSURL                   *_baseURL;
    KTAbstractPage			*_currentPage;
    
	KTHTMLGenerationPurpose	_generationPurpose;
	BOOL					_includeStyling;
	BOOL                    _liveDataFeeds;
    BOOL                    _isXHTML;
    NSStringEncoding        _stringEncoding;
    
    NSMutableArray  *_iteratorsStack;
    
    NSMutableArray  *_textBlocks;
}

#pragma mark Creating a Context
- (id)init;
- (id)initWithContext:(SVHTMLContext *)context; // new context gains all settings of old one


#pragma mark Managing the Context Stack

+ (SVHTMLContext *)currentContext;
+ (void)pushContext:(SVHTMLContext *)context;
+ (void)popContext;

// Convenience methods for pushing and popping that will just do the right thing when the receiver is nil
- (void)push;
- (void)pop;    // only pops if receiver is the current context


#pragma mark Basic Writing

- (void)writeHTMLString:(NSString *)html;
- (void)writeHTMLFormat:(NSString *)format , ...;
- (void)writeText:(NSString *)string;       // escapes the string and calls -writeHTMLString
- (void)writeComment:(NSString *)comment;   // escapes the string, and wraps in a comment tag

- (void)writeNewline;   // writes a newline character and then enough tab characters to meet -indentationLevel


#pragma mark Elements

//  <tagName
//  Records the tag on a stack for if you want to call -writeEndTag later
- (void)openTag:(NSString *)tagName;

//  >
//  Increases indentation level ready for if you want to do a -writeNewline
- (void)closeStartTag;     

//   />    OR    >
//  Which is used depends on -isXHTML
- (void)closeEmptyElementTag;             

//  </tagName>
//  The start tag must have been written by -openTag: or one of the higher-level methods that calls through to it, otherwise won't know what to write
- (void)writeEndTag;
- (void)writeEndTagWithNewline:(BOOL)aNewline;


#pragma mark Querying Open Elements Stack
- (NSString *)lastOpenElementTagName;
- (BOOL)hasOpenElementWithTagName:(NSString *)tagName;


#pragma mark Element Attributes
//   attribute="value"
- (void)writeAttribute:(NSString *)attribute
                 value:(NSString *)value;


#pragma mark Indentation

// Setting the indentation level does not write to the context in any way. It is up to methods that actually do some writing to respect the indent level. e.g. starting a new line should indent that line to match.
@property(nonatomic) NSInteger indentationLevel;
- (void)indent;
- (void)outdent;


#pragma mark Primitive
- (void)writeString:(NSString *)string;     // primitive method any subclass MUST override


#pragma mark Properties

@property(nonatomic, copy) NSURL *baseURL;
@property(nonatomic) BOOL includeStyling;
@property(nonatomic) BOOL liveDataFeeds;
@property(nonatomic, getter=isXHTML) BOOL XHTML;
@property(nonatomic) NSStringEncoding encoding;   // UTF-8 by default

@property(nonatomic) KTHTMLGenerationPurpose generationPurpose;
@property(nonatomic, readonly, getter=isEditable) BOOL editable; // YES if HTML is intended to be edited directly in a Web Editor
- (BOOL)isPublishing;


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
- (NSString *)relativeURLStringOfPage:(KTAbstractPage *)page;   
- (NSString *)relativeURLStringOfResourceFile:(NSURL *)resourceURL;


#pragma mark Content

// Default implementation does nothing. Subclasses can implement for introspecting the dependencies (WebView loading does)
- (void)addDependencyOnObject:(NSObject *)object keyPath:(NSString *)keyPath;
                               
@property(nonatomic, copy, readonly) NSArray *generatedTextBlocks;
- (void)didGenerateTextBlock:(SVHTMLTextBlock *)textBlock;




// In for compatibility, overrides -baseURL
@property(nonatomic, retain) KTAbstractPage *currentPage;

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


#pragma mark General

//  <tagName id="idName" class="className">
//  Calls -openTag: and -writeAttribute:value: appropriately for you
- (void)writeStartTag:(NSString *)tagName   
               idName:(NSString *)idName
            className:(NSString *)className;

@end


#pragma mark -


@interface SVHTMLContext (DOM)

- (DOMNode *)writeDOMElement:(DOMElement *)element; // returns the next sibling to write
- (void)openTagWithDOMElement:(DOMElement *)element;    // open the tag and write attributes

@end


@interface DOMElement (SVHTMLContext)

- (void)writeInnerHTMLToContext:(SVHTMLContext *)context;
- (void)writeInnerHTMLStartingWithChild:(DOMNode *)aNode toContext:(SVHTMLContext *)context; // if node is nil, nothing gets written

- (void)writeCleanedInnerHTMLToContext:(SVHTMLContext *)context;
- (void)writeCleanedHTMLToContext:(SVHTMLContext *)context innards:(BOOL)writeInnards;

@end


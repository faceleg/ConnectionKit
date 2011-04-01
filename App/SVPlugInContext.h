//
//  SVPlugIn.h
//  Sandvox
//
//  Created by Mike on 29/12/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

//  This header should be well commented as to its functionality. Further information can be found at 
//  http://docs.karelia.com/z/Sandvox_Developers_Guide.html


#import <Cocoa/Cocoa.h>


extern NSString * const SVDestinationResourcesDirectory;    // upload *into* the _Resources folder
extern NSString * const SVDestinationDesignDirectory;       // upload *into* the design's folder
extern NSString * const SVDestinationMainCSS;               // *append* to design's main.css


enum {
    SVImageScaleAspectFit = 1 << 0,             // without this, image will be cropped to fill width & height
                                                // one day, might have option to control if can scale up
    SVPageImageRepresentationLink = 1 << 5,     // if possible an <A> element will also be written linking to the page
};
typedef NSUInteger SVPageImageRepresentationOptions;

enum {
    SVPlaceholderInvisible = 1 << 0,    // placeholder represents content visible only on published site
};
typedef NSUInteger SVPlaceholderOptions;


#pragma mark -


@class SVPlugIn, SVInspectorViewController;
@protocol SVPage;


#pragma mark -


@protocol SVPlugInContext

#pragma mark Properties
@property(nonatomic, copy, readonly) NSURL *baseURL;    // where the HTML is destined for. -relativeStringFromURL: figures its result by comparing a URL to -baseURL.
- (id <SVPage>)page;    // the page whose HTML is being built


#pragma mark Purpose
- (BOOL)isForEditing; // YES if the HTML is to appear in Sandvox's web view
- (BOOL)isForQuickLookPreview;  // yeah, you get the idea
- (BOOL)liveDataFeeds;  // When NO, you should write placeholders instead of loading from the web


#pragma mark State
- (BOOL)isWritingPagelet;   // YES if currently writing a plug-in for the sidebar or callout
- (NSString *)currentIterationCSSClassName;
- (id)objectForCurrentTemplateIteration;


#pragma mark URLs
// To make markup more flexible, relative string should generally be used instead of full URLs. This method quickly generates the best way to get from the current page to a given URL.
- (NSString *)relativeStringFromURL:(NSURL *)URL;


#pragma mark Basic HTML Writing

/*  SVPlugInContext is heavily based on Karelia's open source KSHTMLWriter class. You can generate HTML by writing a series of elements, text and comments. For more information https://github.com/karelia/KSHTMLWriter should prove helpful.
 *  I've documented the equivalent markup each method produces below
 *
 *  Note that in some Sandvox releases, SVPlugInContext is implemented using KSHTMLWriter, but do NOT attempt to use any methods not listed in this header as it may well change in the future.
 */

// Each call to start an element should be balanced with a later call to end it
- (void)startElement:(NSString *)elementName attributes:(NSDictionary *)attributes; // <tag>
- (void)endElement;                                                                 // </tag>

// Escapes the string
- (void)writeCharacters:(NSString *)string;

// Escapes the string, and wraps in a comment tag
- (void)writeComment:(NSString *)comment;   // <!--comment-->

// Great for when you have an existing snippet of HTML
- (void)writeHTMLString:(NSString *)html;


#pragma mark Element Conveniences
// These are shortcuts to save you building up a dictionary for -startElement:attributes:
// You still have to call -endElement.
- (void)startElement:(NSString *)elementName;
- (void)startElement:(NSString *)elementName className:(NSString *)className;
- (void)startElement:(NSString *)elementName idName:(NSString *)idName className:(NSString *)className;


#pragma mark Unique IDs
// For when you need to guarantee the element's ID is unique within the document. Perfect for hooking up a javascript. Returns the best unique ID available
- (NSString *)startElement:(NSString *)elementName
           preferredIdName:(NSString *)preferredID
                 className:(NSString *)className
                attributes:(NSDictionary *)attributes;


#pragma mark Hyperlinks

//  <a href="...." target="..." rel="nofollow">
- (void)startAnchorElementWithHref:(NSString *)href title:(NSString *)titleString target:(NSString *)targetString rel:(NSString *)relString;

// Takes care of using the right href, title and target for the page
- (void)startAnchorElementWithPage:(id <SVPage>)page;

// Returns YES to signify success.
// Returns NO if the page has no RSS feed, so cannot be linked to. The context will write a placeholder instead if appropriate; you should *not* write any content of your own or call -endElement; just move on!
// Maybe this should be private API until we target 10.6+?
- (BOOL)startAnchorElementWithFeedForPage:(id <SVPage>)page attributes:(NSDictionary *)attributes;


#pragma mark Headings
//  <hX>
// The context will know what is the appropriate level of header to write. E.g. in a pagelet <H5>s are wanted, but for inline graphics use <H3>
- (void)startHeadingWithAttributes:(NSDictionary *)attributes;


#pragma mark Scripts
- (void)writeJavascriptWithSrc:(NSString *)src encoding:(NSStringEncoding)encoding;


#pragma mark CSS, Javascript and other Resources

// These methods return the URL to use for the resource in relation to this context. You can then pass it to -relativeStringFromURL: for example
// You almost always want to use one of the string constants declared above for the destination. If more control is needed, you are welcome to append path components to a directory constant to specify the exact path
- (NSURL *)addResourceAtURL:(NSURL *)fileURL
                destination:(NSString *)uploadPath
                    options:(NSUInteger)options;    // pass in 0

- (void)addJavascriptResourceWithTemplateAtURL:(NSURL *)templateURL
                                        object:(id)object;


/*  All these methods return the URL of the file where the CSS will end up. Presently while editing this is nil
 */

- (NSURL *)addCSSString:(NSString *)css;    // css can be nil if you just want to find location

// For CSS that refers to other files, the context must be asked where those files are. You can do this by hand, building up a string and passing to -addCSSString: or there's this method. The CSS will be parsed just like Template.html. Generally, your plug-in is the object to be parsed
- (NSURL *)addCSSWithTemplateAtURL:(NSURL *)templateURL object:(id)object;

// -addCSSWithURL: has been superseded by the general resource API above


#pragma mark Placeholder
// If you need to generate a stand-in for the real content. e.g. Live data feeds are disabled
- (void)writePlaceholderWithText:(NSString *)text options:(SVPlaceholderOptions)options;


#pragma mark Metrics
// The element's size will be taken from plug-in's .width and .height properties. When editing, that will be kept up-to-date, with resize handles if appropriate
- (NSString *)startResizableElement:(NSString *)elementName
                              plugIn:(SVPlugIn *)plugIn
                             options:(NSUInteger)options    // pass 0 for now, we may add options later
                     preferredIdName:(NSString *)preferredID
                          attributes:(NSDictionary *)attributes;


#pragma mark Page Titles
// element must not be nil. A <SPAN> is often a good choice
// Because this is a -write… method (rather than -start…) it calls -endElement internally, so don't do so yourself
- (void)writeElement:(NSString *)elementName
     withTitleOfPage:(id <SVPage>)page
         asPlainText:(BOOL)plainText
          attributes:(NSDictionary *)attributes;


#pragma mark Page Thumbnails

// Return value is whether a thumbnail was found to be written. Call -URLForImageRepresentationOfPage:… first if you want to know if there is a decent thumbnail before proceeding to write
- (void)writeImageRepresentationOfPage:(id <SVPage>)page  // nil page will write a placeholder image
                                 width:(NSUInteger)width
                                height:(NSUInteger)height
                            attributes:(NSDictionary *)attributes  // e.g. custom CSS class
                               options:(SVPageImageRepresentationOptions)options;

// Pass in 0 width and height to get the largest image available
- (NSURL *)URLForImageRepresentationOfPage:(id <SVPage>)page
                                     width:(NSUInteger)width
                                    height:(NSUInteger)height
                                   options:(SVPageImageRepresentationOptions)options;


#pragma mark Extra markup
// Appends the markup just before the </BODY> tag. If same code has already been added, goes ignored
- (void)addMarkupToEndOfBody:(NSString *)markup;


#pragma mark Dependencies
// When generating HTML using a template, Sandvox automatically registers each keypath it encounters in the template as a dependency. If you need to register any additonal paths — perhaps because you are not using a template or it doesn't appear in the template — do so with this method.
// When a change of the path is detected, Sandvox will take care of reloading the needed bit of the webview.
- (void)addDependencyForKeyPath:(NSString *)keyPath ofObject:(NSObject *)object;


@end


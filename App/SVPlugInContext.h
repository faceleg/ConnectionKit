//
//  SVPlugIn.h
//  Sandvox
//
//  Created by Mike on 29/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class SVPlugIn, SVInspectorViewController;
@protocol SVPage;

@protocol SVPlugInContext

#pragma mark Properties
- (id <SVPage>)page;    // the page whose HTML is being built
- (BOOL)isXHTML;


#pragma mark Purpose
- (BOOL)isForEditing; // YES if HTML is intended to be edited directly in a Web Editor
- (BOOL)isForQuickLookPreview;  // yeah, you get the idea
- (BOOL)isForPublishing;
- (BOOL)liveDataFeeds;  // When NO, you should write placeholders instead of loading from the web


#pragma mark State
- (NSString *)currentIterationCSSClassName;
- (id)objectForCurrentTemplateIteration;


#pragma mark URLs
- (NSString *)relativeURLStringOfURL:(NSURL *)URL;


#pragma mark Resources
- (NSURL *)addResourceWithURL:(NSURL *)fileURL;
- (void)addCSSString:(NSString *)css;
- (void)addCSSWithURL:(NSURL *)cssURL;


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
- (void)writeText:(NSString *)string;

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


#pragma mark Metrics
// The element's size will be taken from plug-in's .width and .height properties. When editing, that will be kept up-to-date, with resize handles if appropriate
- (void)startElement:(NSString *)elementName
    bindSizeToPlugIn:(SVPlugIn *)plugIn
          attributes:(NSDictionary *)attributes;


#pragma mark Page Titles
// element must not be nil. A <SPAN> is often a good choice
// Because this is a -write… method (rather than -start…) it calls -endElement internally, so don't do so yourself
- (void)writeElement:(NSString *)elementName
     withTitleOfPage:(id <SVPage>)page
         asPlainText:(BOOL)plainText
          attributes:(NSDictionary *)attributes;


#pragma mark Extra markup
// Appends the markup just before the </BODY> tag. If same code has already been added, goes ignored
- (void)addMarkupToEndOfBody:(NSString *)markup;


#pragma mark Dependencies
// When generating HTML using a template, Sandvox automatically registers each keypath it encounters in the template as a dependency. If you need to register any additonal paths — perhaps because you are not using a template or it doesn't appear in the template — do so with this method.
// When a change of the path is detected, Sandvox will take care of reloading the needed bit of the webview.
- (void)addDependencyForKeyPath:(NSString *)keyPath ofObject:(NSObject *)object;


@end


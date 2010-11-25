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

#pragma mark Call so Web Editor knows when to update
- (void)addDependencyForKeyPath:(NSString *)keyPath ofObject:(NSObject *)object;


#pragma mark element must not be nil. A <SPAN> is often a good choice
- (void)writeTitleOfPage:(id <SVPage>)page asPlainText:(BOOL)plainText enclosingElement:(NSString *)element attributes:(NSDictionary *)attributes;


#pragma mark URLs
- (NSString *)relativeURLStringOfURL:(NSURL *)URL;


#pragma mark Resources & Design
- (NSURL *)addResourceWithURL:(NSURL *)fileURL;
- (void)addCSSString:(NSString *)css;
- (void)addCSSWithURL:(NSURL *)cssURL;


#pragma mark Extra markup
// If the same markup has already been added, goes ignored
- (void)addMarkupToEndOfBody:(NSString *)markup;


#pragma mark Purpose
- (BOOL)isForEditing; // YES if HTML is intended to be edited directly in a Web Editor
- (BOOL)isForQuickLookPreview;  // yeah, you get the idea
- (BOOL)isForPublishing;
- (BOOL)liveDataFeeds;  // When NO, you should write placeholders instead of loading from the web


#pragma mark State
- (id <SVPage>)page;

- (NSString *)currentIterationCSSClassName;
- (id)objectForCurrentTemplateIteration;


#pragma mark Basics

- (void)startElement:(NSString *)elementName attributes:(NSDictionary *)attributes;
- (void)endElement;

// Convenience methods for -startElement:attributes:
- (void)startElement:(NSString *)tagName;
- (void)startElement:(NSString *)tagName className:(NSString *)className;
- (void)startElement:(NSString *)tagName idName:(NSString *)idName className:(NSString *)className;

- (void)writeText:(NSString *)string;

- (void)writeComment:(NSString *)comment;   // escapes the string, and wraps in a comment tag

- (void)writeHTMLString:(NSString *)html;   // great for when you have an existing snippet of HTML


#pragma mark Convenience/Special

//  <a href="...." target="..." rel="nofollow">
//  Raw version of the above for if you need to link to something over than an SVPage
- (void)startAnchorElementWithHref:(NSString *)href title:(NSString *)titleString target:(NSString *)targetString rel:(NSString *)relString;

// Takes care of using the right href, title and target for the page
- (void)startAnchorElementWithPage:(id <SVPage>)page;

// For when you need to write an element and be sure the ID is unique. Perfect for hooking up a script. Returns the best unique ID available
- (NSString *)startElement:(NSString *)tagName
           preferredIdName:(NSString *)preferredID
                 className:(NSString *)className
                attributes:(NSDictionary *)attributes;

// The element's size will be taken from plug-in's .width and .height properties. When editing, that will be kept up-to-date, live.
- (void)startElement:(NSString *)elementName
    bindSizeToPlugIn:(SVPlugIn *)plugIn
          attributes:(NSDictionary *)attributes;


#pragma mark Properties
- (BOOL)isXHTML;


@end


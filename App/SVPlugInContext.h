//
//  SVPlugIn.h
//  Sandvox
//
//  Created by Mike on 29/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class SVPlugIn, SVInspectorViewController;
@protocol SVHTMLWriter, SVPage;

#pragma mark -


@protocol SVPlugInContext

- (id <SVHTMLWriter>)HTMLWriter;

// Call so Web Editor knows when to update
- (void)addDependencyForKeyPath:(NSString *)keyPath ofObject:(NSObject *)object;

// element must not be nil. A <SPAN> is often a good choice
- (void)writeTitleOfPage:(id <SVPage>)page asPlainText:(BOOL)plainText enclosingElement:(NSString *)element attributes:(NSDictionary *)attributes;

// URLs
- (NSString *)relativeURLStringOfURL:(NSURL *)URL;

// Resources & Design
- (NSURL *)addResourceWithURL:(NSURL *)fileURL;
- (void)addCSSString:(NSString *)css;
- (void)addCSSWithURL:(NSURL *)cssURL;

// Extra markup
- (NSMutableString *)extraHeaderMarkup;
- (NSMutableString *)endBodyMarkup; // can append to, query, as you like while parsing

// Purpose
- (BOOL)isForEditing; // YES if HTML is intended to be edited directly in a Web Editor
- (BOOL)isForQuickLookPreview;  // yeah, you get the idea
- (BOOL)isForPublishing;
- (BOOL)liveDataFeeds;
- (BOOL)shouldWriteServerSideScripts;   // YES when -isForPublishing, but not when validating page

// State
- (id <SVPage>)page;
- (id)objectForCurrentTemplateIteration;
- (NSString *)visibleSiteTitle;

@end


#pragma mark -


@protocol SVHTMLWriter

#pragma mark Basics

- (void)startElement:(NSString *)elementName attributes:(NSDictionary *)attributes;
- (void)startElement:(NSString *)tagName;
- (void)startElement:(NSString *)tagName className:(NSString *)className;
- (void)startElement:(NSString *)tagName idName:(NSString *)idName className:(NSString *)className;
- (void)endElement;

- (void)writeText:(NSString *)string;

//  Writes a newline character and the tabs to match -indentationLevel. Nornally newlines are automatically written for you; call this if you need an extra one.
- (void)startNewline;

- (void)writeComment:(NSString *)comment;   // escapes the string, and wraps in a comment tag

- (void)writeHTMLString:(NSString *)html;   // great for when you have an existing snippet of HTML


#pragma mark Convenience/Special

// Handles subtleties of Sandvox pages
- (void)startAnchorElementWithPage:(id <SVPage>)page;

//  <a href="...." target="..." rel="nofollow">
//  Raw version of the above for if you need to link to something over than an SVPage
- (void)startAnchorElementWithHref:(NSString *)href title:(NSString *)titleString target:(NSString *)targetString rel:(NSString *)relString;

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
- (NSStringEncoding)encoding;   // default is UTF-8


@end


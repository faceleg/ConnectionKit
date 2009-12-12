//
//  SVDOMController.h
//  Sandvox
//
//  Created by Mike on 24/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class SVHTMLContext, SVWebEditorViewController;
@class SVDOMEventListener;


@interface SVDOMController : NSController
{
  @private
    // DOM
    DOMHTMLElement      *_DOMElement;
    SVDOMEventListener  *_eventListener;
    BOOL                _needsUpdate;
    
    // Content
    id              _representedObject;
    SVHTMLContext   *_context;
    
    // Loading by creation
    DOMHTMLDocument *_DOMDocument;
    
    // Tree
    NSArray                 *_childControllers;
    SVDOMController *_parentController;
}

#pragma mark Init

// For subclasses that know how to load HTML element from the document
- (id)initWithHTMLDocument:(DOMHTMLDocument *)document;
@property(nonatomic, retain, readonly) DOMHTMLDocument *HTMLDocument;

// Convenience method:
- (id)initWithHTMLElement:(DOMHTMLElement *)element;


#pragma mark Tree
@property(nonatomic, copy) NSArray *childDOMControllers;
@property(nonatomic, assign) SVDOMController *parentDOMController;  // don't call setter directly
- (void)addChildDOMController:(SVDOMController *)controller;
- (void)removeFromParentDOMController;


#pragma mark DOM

@property(nonatomic, retain) DOMHTMLElement *HTMLElement;
- (void)loadHTMLElement;
- (BOOL)isHTMLElementLoaded;

//  Somewhat problematically, the DOM will retain any event listeners added to it. This can quite easily leave a DOM controller and its HTML element in a retain cycle. When the DOM is torn down, it somehow releases the listener repeatedly, causing a crash.
//  The best solution I can come up with is to avoid the retain cycle between listener and DOM by creating a simple proxy to listen to events and forward them on to the real target, but not retain either object. That object is automatically managed for you and returned here.
@property(nonatomic, retain, readonly) id <DOMEventListener> eventsListener;

- (void)update; //override to push changes through to the DOM
- (void)setNeedsUpdate; // call to mark for needing update. Instantaneous at the moment, but might not be in the future


#pragma mark Content
@property(nonatomic, retain) id representedObject;

@property(nonatomic, retain) SVHTMLContext *HTMLContext;


@end

//
//  SVDOMController.h
//  Sandvox
//
//  Created by Mike on 13/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "WebEditingKit.h"

#import "SVContentObject.h"
#import "SVWebEditorHTMLContext.h"


@class SVWebEditorHTMLContext, SVWebEditorViewController;


@interface SVDOMController : WEKWebEditorItem
{
  @private
    // Updating
    BOOL                    _needsUpdate;
    NSMutableSet            *_dependencies;
    SVWebEditorHTMLContext  *_context;
}

+ (id)DOMControllerWithGraphic:(SVGraphic *)graphic
 createHTMLElementWithDocument:(DOMHTMLDocument *)doc
                       context:(SVHTMLContext *)parentContext;

#pragma mark Content

- (id)initWithRepresentedObject:(id)modelObject;    // convenience

// Convenience method that:
//  1)  Initializes basic controller
//  2)  Stores the content object in .representedObject
//  3)  Calls -loadHTMLElementFromDocument:
- (id)initWithContentObject:(SVContentObject *)contentObject
              inDOMDocument:(DOMDocument *)document;

//  Asks content object to locate node in the DOM, then stores it as receiver's .HTMLElement. Removes the element's ID attribute from the DOM if it's only there for editing support (so as to keep the Web Inspector tidy)
- (void)loadHTMLElementFromDocument:(DOMDocument *)document;

// Uses the receiver's HTML context to call -HTMLString from the represented object
- (void)writeRepresentedObjectHTML;
@property(nonatomic, retain, readwrite) SVWebEditorHTMLContext *HTMLContext;


#pragma mark Updating

- (void)update; // override to push changes through to the DOM. Rarely call directly. MUST call super

@property(nonatomic, readonly) BOOL needsUpdate;
- (void)updateIfNeeded; // recurses down the tree

@property(nonatomic, copy, readonly) NSSet *dependencies;
- (void)addDependency:(KSObjectKeyPathPair *)pair;
- (void)removeAllDependencies;


@end


#pragma mark -


@interface SVContentObject (SVDOMController)

//  A subclass of SVDOMController that the WebEditor will create and maintain in order to edit the object. The default is a vanilla SVDOMController.
//  I appreciate this slightly crosses the MVC divide, but the important thing is that the receiver never knows about any _specific_ controller, just the class involved.
- (SVDOMController *)newDOMController;

@end


#pragma mark -


/*  We want all Web Editor items to be able to handle updating in some form, just not necessarily the full complexity of it.
*/

@interface WEKWebEditorItem (SVDOMController)

#pragma mark DOM
- (void)loadHTMLElementFromDocument:(DOMDocument *)document;    // does nothing


#pragma mark Updating

- (void)update;

- (void)setNeedsUpdate; // WEKWebEditorItem can't manage updating, so passes off to view controller
- (void)updateIfNeeded; // recurses down the tree
- (SVWebEditorHTMLContext *)HTMLContext;


#pragma mark Drag & Drop
- (NSArray *)registeredDraggedTypes;
- (WEKWebEditorItem *)hitTestDOMNode:(DOMNode *)node
                       draggingInfo:(id <NSDraggingInfo>)info;


@end

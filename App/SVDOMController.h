//
//  SVDOMController.h
//  Sandvox
//
//  Created by Mike on 13/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorItem.h"


@class SVContentObject, SVHTMLContext, SVWebEditorViewController;


@interface SVDOMController : SVWebEditorItem
{
  @private
    // Updating
    BOOL    _needsUpdate;
    SVHTMLContext   *_context;
}

#pragma mark Content

// Convenience method that:
//  1)  Locates the DOMNode using SVContentObject's API.
//  2)  Passes that node onto -initWithHTMLElement:
//  3)  Stores the content object in .representedObject.
//  4)  Removes the node's ID attribute from the DOM if it's only there for editing support (so as to keep the Web Inspector tidy)
- (id)initWithContentObject:(SVContentObject *)contentObject
              inDOMDocument:(DOMDocument *)document;

// Uses the receiver's HTML context to call -HTMLString from the represented object
- (void)writeRepresentedObjectHTML;
@property(nonatomic, retain) SVHTMLContext *HTMLContext;


#pragma mark Updating
- (void)update; // override to push changes through to the DOM. Rarely call directly. MUST call super
@property(nonatomic, readonly) BOOL needsUpdate;
- (void)setNeedsUpdate; // call to mark for needing update.
- (void)updateIfNeeded; // recurses down the tree


@end


#pragma mark -


/*  We want all Web Editor items to be able to handle updating in some form, just not necessarily the full complexity of it.
*/

@interface SVWebEditorItem (SVDOMController)

#pragma mark Updating
- (void)update;
- (void)updateIfNeeded; // recurses down the tree


#pragma mark WebEditorViewController
- (SVWebEditorViewController *)webEditorViewController;


@end
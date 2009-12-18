//
//  SVDOMController.h
//  Sandvox
//
//  Created by Mike on 13/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorItem.h"


@class SVContentObject, SVHTMLContext;


@interface SVDOMController : SVWebEditorItem
{
  @private
    // Updating
    BOOL    _needsUpdate;
    SVHTMLContext   *_context;
}

#pragma mark Content

- (id)initWithContentObject:(SVContentObject *)contentObject
              inDOMDocument:(DOMDocument *)document;

// Uses the receiver's HTML context to call -HTMLString from the represented object
- (NSString *)representedObjectHTMLString;
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
- (void)update;
- (void)updateIfNeeded; // recurses down the tree
@end
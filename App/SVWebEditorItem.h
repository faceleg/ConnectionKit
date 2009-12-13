//
//  SVWebEditorItem.h
//  Sandvox
//
//  Created by Mike on 24/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//
//  Concrete implementation of the SVWebEditorItem protocol


#import "KSDOMController.h"


@class SVBodyTextDOMController;
@interface SVWebEditorItem : KSDOMController
{
  @private
    SVBodyTextDOMController  *_bodyText;
}

- (BOOL)isEditable;


// Strictly speaking, there could be more than one per item, but there isn't in practice at the moment, so this is a rather handy optimisation
@property(nonatomic, retain) SVBodyTextDOMController *bodyText;


#pragma mark Content
// Uses the receiver's HTML context to call -HTMLString from the represented object
- (NSString *)representedObjectHTMLString;

@end

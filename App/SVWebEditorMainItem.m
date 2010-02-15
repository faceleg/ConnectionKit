//
//  SVWebEditorMainItem.m
//  Sandvox
//
//  Created by Mike on 15/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVWebEditorMainItem.h"


@implementation SVMainWebEditorItem

- (DOMHTMLElement *)HTMLElement { return nil; }
- (BOOL)isSelectable { return NO; }

@synthesize webEditor = _webEditor;

@end




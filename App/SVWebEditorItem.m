//
//  SVWebEditorItem.m
//  Sandvox
//
//  Created by Mike on 24/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorItem.h"


@implementation SVWebEditorItem

#pragma mark Accessors

- (DOMElement *)DOMElement { return [self HTMLElement]; }

- (BOOL)isEditable { return NO; }

@end

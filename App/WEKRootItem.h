//
//  WEKRootItem.h
//  Sandvox
//
//  Created by Mike on 15/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "WEKWebEditorItem.h"


@interface WEKRootItem : WEKWebEditorItem
{
  @private
    WEKWebEditorView *_webEditor;   //weak ref
}

@property(nonatomic, assign) WEKWebEditorView *webEditor;

@end



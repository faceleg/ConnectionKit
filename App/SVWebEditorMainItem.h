//
//  SVWebEditorMainItem.h
//  Sandvox
//
//  Created by Mike on 15/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVWebEditorItem.h"


@interface SVMainWebEditorItem : SVWebEditorItem
{
    WEKWebEditorView *_webEditor;
}
@property(nonatomic, assign) WEKWebEditorView *webEditor;
@end



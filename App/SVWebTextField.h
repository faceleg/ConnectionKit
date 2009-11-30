//
//  SVWebTextField.h
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebTextArea.h"
#import "SVWebEditorItemProtocol.h"


@interface SVWebTextField : SVWebTextArea <SVWebEditorItem>
{
    NSString    *_placeholder;
}

@property(nonatomic, copy) NSString *placeholderString;

@end

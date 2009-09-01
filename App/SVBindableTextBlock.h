//
//  SVBindableTextBlockDOMController.h
//  Marvel
//
//  Created by Mike on 26/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  Rather than clutter up the main class, we neatly derive a subclass that is designed for binding. It implements the NSEditor protocol and exposes a NSValueBinding binding.

#import "SVTextBlock.h"
#import "KSKeyValueBinding.h"


@interface SVBindableTextBlock : SVTextBlock <KSEditor>
{
    NSString    *_boundValue;
}

@property(nonatomic, readonly, getter=isEditing) BOOL editing;

@end

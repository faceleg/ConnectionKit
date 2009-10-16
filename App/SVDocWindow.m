//
//  SVDocWindow.m
//  Sandvox
//
//  Created by Mike on 15/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVDocWindow.h"


@implementation SVDocWindow

- (BOOL)makeFirstResponder:(NSResponder *)responder
{
    BOOL result = [super makeFirstResponder:responder];
    
    if (result)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:SVDocWindowDidChangeFirstResponderNotification
                                                            object:self];
    }
    
    return result;
}

@end

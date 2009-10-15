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
    [super makeFirstResponder:responder];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SVDocWindowDidChangeFirstResponderNotification
                                                        object:self];
}

@end

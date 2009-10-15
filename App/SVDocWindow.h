//
//  SVDocWindow.h
//  Sandvox
//
//  Created by Mike on 15/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//
//  A super-simple subclass of NSWindow that posts a notification each time the First Responder changes


#import <Cocoa/Cocoa.h>


#define SVDocWindowDidChangeFirstResponderNotification @"WindowDidChangeFirstResponder"


@interface SVDocWindow : NSWindow 
{

}

@end

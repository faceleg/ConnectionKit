//
//  SVLinkInspectorView.h
//  Sandvox
//
//  Created by Mike on 24/09/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SVLinkInspectorView : NSView
{
  @private
    BOOL        _dropping;
    NSObject    *_delegate;
}

@property(nonatomic, assign) NSObject *draggingDestinationDelegate;

@end
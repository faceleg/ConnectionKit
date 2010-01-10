//
//  SVLinkInspector.h
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "KSInspectorViewController.h"


@interface SVLinkInspector : KSInspectorViewController
{
  @private
    NSWindow    *_inspectedWindow;
}

@property(nonatomic, retain) NSWindow *inspectedWindow;

- (IBAction)clearLinkDestination:(id)sender;

@end

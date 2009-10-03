//
//  SVWebEditorLoadingPlaceholderViewController.h
//  Sandvox
//
//  Created by Mike on 04/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SVLoadingPlaceholderViewController : NSViewController
{
  @private
    NSProgressIndicator *_progressIndicator;
}

- (id)init;

@property(nonatomic, retain) IBOutlet NSProgressIndicator *progressIndicator;

@end

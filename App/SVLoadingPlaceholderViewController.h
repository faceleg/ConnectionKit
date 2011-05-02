//
//  SVWebEditorLoadingPlaceholderViewController.h
//  Sandvox
//
//  Created by Mike on 04/10/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import <BWToolkitFramework/BWToolkitFramework.h>


@class YRKSpinningProgressIndicator;


@interface SVLoadingPlaceholderViewController : BWViewController
{
  @private
    NSImageView                     *_imageView;
    YRKSpinningProgressIndicator    *_progressIndicator;
    NSTextField                     *_label;
}

- (id)init;

@property(nonatomic, retain) IBOutlet YRKSpinningProgressIndicator *progressIndicator;
@property(nonatomic, retain) IBOutlet NSTextField *label;   // can use to set custom text
@property(nonatomic, retain) IBOutlet NSImageView *backgroundImageView;

@end

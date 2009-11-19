//
//  SVDesignChooserCollectionViewItem.h
//  Sandvox
//
//  Created by Dan Wood on 11/19/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SVDesignChooserImageView;

@interface SVDesignChooserCollectionViewItem : NSCollectionViewItem {

	IBOutlet SVDesignChooserImageView *oImageView;
	IBOutlet NSButton *oLinkButton;
}

@end

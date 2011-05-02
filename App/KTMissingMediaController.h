//
//  KTMissingMediaController.h
//  Marvel
//
//  Created by Mike on 01/11/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KTMediaManager;


@interface KTMissingMediaController : NSWindowController
{
	IBOutlet NSArrayController	*oMediaArrayController;
	
	KTMediaManager	*myMediaManager;
	NSArray			*myMissingMedia;
}

- (IBAction)findSelectedMediaFile:(id)sender;
- (IBAction)continueOpening:(id)sender;
- (IBAction)cancel:(id)sender;
- (IBAction)showHelp:(id)sender;

- (KTMediaManager *)mediaManager;
- (void)setMediaManager:(KTMediaManager *)mediaManager;

- (NSArray *)missingMedia;
- (void)setMissingMedia:(NSArray *)media;

@end
